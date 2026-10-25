#!/usr/bin/env python3
"""Reconcile normalized receipt logs and source ledgers using the compiled event ABI.

Supplied records are not authenticated chain data. Collect and decode them independently.
"""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import subprocess
if __package__:
    from .preflight import require, address, hash32, digest, integer
    from .build_manifest import ROOT
else:
    from preflight import require, address, hash32, digest, integer
    from build_manifest import ROOT

FIELDS = ('activeRoundEscrow','prizeLiability','pendingRolloverTotal','finalizerLiability','pendingOperatorRevenueTotal','treasuryAvailable')

def keccak(data):
    return subprocess.check_output(['cast','keccak',data],text=True,env=__import__('os').environ | {'FOUNDRY_DISABLE_NIGHTLY_WARNING':'1'}).strip()

def word(value):
    return int(value,16).to_bytes(32,'big') if isinstance(value,str) and value.startswith('0x') else int(value).to_bytes(32,'big')

def abi_type(item):
    return '('+','.join(abi_type(x) for x in item['components'])+')' if item['type']=='tuple' else item['type']

def encode(item,value):
    if item['type']=='tuple':
        return b''.join(encode(x,value[x['name']]) for x in item['components'])
    t=item['type']
    if t=='address':
        require(isinstance(value,str) and len(value)==42, 'ABI address')
        integer(int(value,16),0,2**160-1)
    elif t.startswith('uint'):
        integer(value,0,2**int(t[4:] or '256')-1)
    elif t=='bytes32':
        require(isinstance(value,str) and len(value)==66, 'ABI bytes32')
    elif t=='bool':
        require(type(value) is bool,'ABI bool')
    else:
        raise ValueError('unsupported event ABI')
    return word(value)

def catalog(manifest=None):
    if manifest is None:
        manifest=json.loads((ROOT/'candidate-manifest.json').read_text())
    events=dict(manifest['eventABIs'])
    events['Transfer']=dict(name='Transfer',inputs=[dict(name='from',type='address',indexed=True),dict(name='to',type='address',indexed=True),dict(name='value',type='uint256',indexed=False)])
    return events

def raw_log(event,values,emitter,events=None):
    item=(events or catalog())[event]
    topics=[keccak(item['name']+'('+','.join(abi_type(x) for x in item['inputs'])+')')]
    data=b''
    require(set(values)=={x['name'] for x in item['inputs']},'event fields')
    for field in item['inputs']:
        encoded=encode(field,values[field['name']])
        if field['indexed']: topics.append('0x'+encoded.hex())
        else: data+=encoded
    return dict(address=emitter,event=event,values=values,topics=topics,data='0x'+data.hex())

def validate(trace,manifest):
    require(trace['schema']==1 and trace['chainId']==46630,'evidence schema/chain')
    require(trace['manifestDigest']==digest(manifest),'evidence candidate')
    require(trace['runtimeHashes']=={k:v['runtimeKeccak256'] for k,v in manifest['contracts'].items()},'evidence runtimes')
    diamond=address(trace['diamond']); assets={address(x) for x in trace['assets']}
    rounds={}; pending=defaultdict(int); buckets=defaultdict(int); credits=defaultdict(int)
    ledgers={a:[0]*6 for a in assets}; balances=dict.fromkeys(assets,0)
    events=catalog(manifest); seen=set(); previous=(0,-1); active=set(); blocks={}; block_hashes={}; block_log_indices={}; previous_time=0
    for receipt in trace['receipts']:
        tx=hash32(receipt['transactionHash']); require(tx not in seen,'duplicate receipt'); seen.add(tx)
        bh=hash32(receipt['blockHash']); integer(receipt['blockNumber'],1,2**64-1); integer(receipt['transactionIndex'],0,2**32-1)
        position=(receipt['blockNumber'],receipt['transactionIndex']); require(position>previous,'receipt order'); previous=position
        at=integer(receipt['timestamp'],0,2**64-1)
        require(at>=previous_time,'block time order'); previous_time=at
        number=receipt['blockNumber']; require(number not in blocks or blocks[number]==(bh,at),'inconsistent block observations'); require(bh not in block_hashes or block_hashes[bh]==number,'block hash reuse'); blocks[number]=(bh,at); block_hashes[bh]=number
        require(type(receipt['status']) is int and receipt['status'] in (0,1) and (receipt['status']==1 or not receipt['logs']),'failed receipt logs')
        expected_transfers=[]; actual_transfers=[]; touched=set(); opened_here=set(); allocated_here=set()
        for index,log in enumerate(receipt['logs']):
            log_index=integer(log['logIndex'],0,2**64-1)
            require(log_index>block_log_indices.get(number,-1),'log order'); block_log_indices[number]=log_index
            name=log['event']; v=log['values']; emitter=address(log['address'])
            expected=raw_log(name,v,emitter,events)
            require(log['topics']==expected['topics'] and log['data']==expected['data'],'raw/decoded log mismatch')
            if name=='Transfer':
                require(emitter in assets,'unknown transfer asset')
                src=v['from'].lower(); dst=v['to'].lower(); amount=v['value']
                actual_transfers.append((emitter,src,dst,amount))
                if dst==diamond: balances[emitter]+=amount
                if src==diamond: balances[emitter]-=amount
                require(balances[emitter]>=0,'custody underflow')
                continue
            require(emitter==diamond,'wrong Rooms emitter')
            rid=v.get('roundId'); touched.add(rid)
            if name=='RoundOpened':
                require(rid not in rounds and rid==len(rounds)+1,'round sequence')
                cv=str(v['configVersion']); iv=str(v['integrationVersion']); c=trace['configurations'][cv]
                require(cv not in active and len(active)<trace['maxActiveRounds'],'active capacity')
                a=address(c['paymentToken']); require(a in assets,'round asset')
                require(v['openedAt']==at and v['closesAt']==at+c['salesDuration'] and v['ticketSupply']==c['ticketSupply'],'opening snapshot')
                inherited=pending[cv]; require(v['inheritedPot']==inherited,'inherited pot')
                pending[cv]=0; ledgers[a][2]-=inherited; ledgers[a][0]+=inherited
                rounds[rid]=dict(config=c,cv=cv,iv=iv,asset=a,opened=at,closes=v['closesAt'],effective=v['closesAt'],inherited=inherited,gross=0,total=0,holdings=defaultdict(int),counts=[0]*c['roomCount'],status='open',claimed=set(),rollover=0)
                active.add(cv); opened_here.add(rid)
            elif name in ('DeadlineCommitted','RoundSoldOut'):
                r=rounds[rid]
                boundary=(r['closes'] if name=='DeadlineCommitted' else at)+r['config']['randomnessDelay']
                target=v['deadlineTarget'] if name=='DeadlineCommitted' else v['selectedTarget']
                probe=receipt['beaconCommitments'][str(target)]
                require(probe['boundary']==boundary and probe['firstRoundAfter']==target and probe['roundTime']>boundary and probe['cached'] is False,'commitment evidence')
                if name=='DeadlineCommitted':
                    require('selected' not in r and v['effectiveClose']==r['closes'],'deadline one shot')
                    r['original']=r['selected']=target
                else:
                    require(r['status']=='open' and r['total']==r['config']['ticketSupply'] and at<r['closes'] and v['soldOutAt']==at and v['deadlineTarget']==r['original'],'exact-fill sellout')
                    r.update(status='soldout',selected=target,effective=at)
            elif name=='TicketsPurchased':
                r=rounds[rid]; c=r['config']; q=v['quantity']; room=v['room']; buyer=address(v['buyer'])
                require(r['status']=='open' and r['opened']<=at<r['closes'] and q>0 and room<c['roomCount'],'purchase phase/quantity')
                require(c['maxTicketsPerPurchase']==0 or q<=c['maxTicketsPerPurchase'],'purchase cap')
                epoch=(at-r['opened'])*4//c['salesDuration']; unit=(c['baseTicketPrice']*(10000+2500*epoch)+9999)//10000
                require(v['epoch']==epoch and v['unitPrice']==unit and v['payment']==q*unit,'epoch price')
                r['total']+=q; r['gross']+=q*unit; r['counts'][room]+=q; r['holdings'][(buyer,room)]+=q
                require(r['total']<=c['ticketSupply'] and v['ticketsRemaining']==c['ticketSupply']-r['total'],'supply')
                ledgers[r['asset']][0]+=q*unit; expected_transfers.append((r['asset'],buyer,diamond,q*unit))
            elif name=='RoundAllocated':
                r=rounds[rid]; c=r['config']; a=r['asset']; g=r['gross']
                require(r['status'] in ('open','soldout') and (r['status']=='soldout' or at>=r['closes']) and 'allocations' not in r,'settlement eligibility')
                require(address(v['asset'])==a and v['gross']==g and v['inherited']==r['inherited'],'allocation source')
                pot=g*c['potBps']//10000; op=g*c['operatorBps']//10000; treasury=g-pot-op; tip=treasury*c['settlementTipBps']//10000
                allocations=dict(pot=pot,operatorRevenue=op,treasuryGross=treasury,finalizerTip=tip,treasuryNet=treasury-tip)
                require(v['allocations']==allocations,'allocation amounts'); r['allocations']=allocations
                ledgers[a][0]-=g+r['inherited']; ledgers[a][3]+=tip; ledgers[a][4]+=op; ledgers[a][5]+=treasury-tip
                buckets[r['iv']+':'+a]+=op; allocated_here.add(rid)
            elif name=='RolloverCredited':
                r=rounds[rid]; require(rid in allocated_here and r['status']!='settled' and str(v['configVersion'])==r['cv'] and address(v['asset'])==r['asset'],'rollover provenance')
                pending[r['cv']]+=v['amount']; ledgers[r['asset']][2]+=v['amount']; r['rollover']+=v['amount']
            elif name=='RoundSettled':
                r=rounds[rid]; require(r['status']!='settled' and 'allocations' in r,'settlement one shot')
                beacon=trace['beacons'][r['iv']+':'+str(r['selected'])]
                require(beacon['roundTime']>r['effective']+r['config']['randomnessDelay'] and beacon['postedAt']>r['effective'] and at>=beacon['postedAt'] and beacon['hasSig'] is True,'selected beacon finality')
                seed=keccak('0x'+(word(beacon['randomness'])+word(trace['chainId'])+word(diamond)+word(rid)).hex()); winner=int(seed,16)%r['config']['roomCount']
                n=r['counts'][winner]; pot=r['inherited']+r['allocations']['pot']; unit=pot//n if n else 0; distributable=unit*n
                require(v['seed']==seed and v['winningRoom']==winner and v['winningTickets']==n and v['playerPot']==pot and v['payoutPerTicket']==unit and v['distributable']==distributable and v['claimDeadline']==(at+30*86400 if n else 0),'outcome')
                require(r['rollover']==pot-distributable,'outcome rollover')
                r.update(status='settled',winner=winner,unit=unit,remaining=distributable,deadline=v['claimDeadline'],expired=False)
                ledgers[r['asset']][1]+=distributable; credits[r['asset']+':'+address(v['finalizer'])]+=r['allocations']['finalizerTip']; active.remove(r['cv'])
            elif name=='PrizeClaimed':
                r=rounds[rid]; player=address(v['player']); receiver=address(v['receiver']); n=r['holdings'][(player,r['winner'])]; amount=n*r['unit']
                require(r['status']=='settled' and not r['expired'] and player not in r['claimed'] and at<r['deadline'] and amount>0 and receiver!=diamond and v['tickets']==n and v['amount']==amount,'player claim')
                r['claimed'].add(player); r['remaining']-=amount; ledgers[r['asset']][1]-=amount; expected_transfers.append((r['asset'],diamond,receiver,amount))
            elif name=='PrizeExpired':
                r=rounds[rid]; require(r['status']=='settled' and r['counts'][r['winner']]>0 and not r['expired'] and at>=r['deadline'] and address(v['asset'])==r['asset'] and v['amount']==r['remaining'],'expiry')
                ledgers[r['asset']][1]-=r['remaining']; ledgers[r['asset']][5]+=r['remaining']; r.update(remaining=0,expired=True)
            elif name=='FinalizerTipsClaimed':
                a=address(v['asset']); user=address(v['finalizer']); receiver=address(v['receiver']); key=a+':'+user; amount=v['amount']
                require(amount>0 and amount==credits[key] and receiver!=diamond,'finalizer claim'); credits[key]=0; ledgers[a][3]-=amount; expected_transfers.append((a,diamond,receiver,amount))
            elif name=='OperatorRevenueFlushed':
                a=address(v['asset']); iv=str(v['integrationVersion']); amount=v['amount']; router=address(trace['integrations'][iv]['router']); key=iv+':'+a
                require(address(v['router'])==router and 0<amount<=buckets[key],'operator bucket'); buckets[key]-=amount; ledgers[a][4]-=amount; expected_transfers.append((a,diamond,router,amount))
            elif name=='TreasuryFlushed':
                a=address(v['asset']); amount=v['amount']; receiver=address(v['receiver'])
                require(receiver==address(trace['treasuryRecipient']) and receiver!=diamond and 0<amount<=ledgers[a][5],'treasury delivery'); ledgers[a][5]-=amount; expected_transfers.append((a,diamond,receiver,amount))
            elif name=='TokenSurplusAbsorbed':
                a=address(v['asset']); amount=v['amount']; require(amount>0 and amount==balances[a]-sum(ledgers[a]),'surplus absorption'); ledgers[a][5]+=amount
            else:
                raise ValueError('event outside ERC-20 lifecycle evidence scope')
        for rid in opened_here:
            require('original' in rounds[rid] and rounds[rid]['total']>0,'opening must commit and collect first purchase atomically')
        for rid in touched-{None}:
            r=rounds[rid]; require(r['status']!='open' or r['total']<r['config']['ticketSupply'],'missing atomic sellout')
            require('allocations' not in r or r['status']=='settled','incomplete settlement')
        if receipt.get('kind')=='donation':
            require(not expected_transfers and all(x[2]==diamond and x[1]!=diamond for x in actual_transfers),'donation transfer')
        else:
            require(Counter(actual_transfers)==Counter(expected_transfers),'token transfer/event mismatch')
        snapshot=receipt['after']
        require(snapshot['balances']==balances and snapshot['accounting']=={a:dict(zip(FIELDS,values)) for a,values in ledgers.items()},'custody/source ledger reconciliation')
        for values in ledgers.values(): require(all(x>=0 for x in values),'negative obligation')
        require(all(sum(ledgers[a])<=balances[a] for a in assets),'insolvency')
        for name,values in [('pendingRollover',pending),('operatorBuckets',buckets),('finalizerCredits',credits)]:
            require(snapshot[name]=={k:v for k,v in values.items() if v},'source aggregate reconciliation')
    require(bool(seen),'empty evidence')
    return dict(schema=1,status='consistent supplied evidence',receipts=len(seen),rounds=len(rounds),liveExecutionVerified=False)

def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('trace'); p.add_argument('manifest'); args=p.parse_args()
    try: result=validate(json.load(open(args.trace)),json.load(open(args.manifest)))
    except (ValueError,KeyError,TypeError) as error: p.exit(1,f'Evidence rejected: {error}\n')
    print(json.dumps(result,sort_keys=True,indent=2))

if __name__=='__main__': main()
