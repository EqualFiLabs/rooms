import copy
import json
from pathlib import Path
import unittest
from tools.evidence import validate, raw_log, keccak, word, FIELDS, catalog
from tools.preflight import digest, Invalid
from tools.tests.test_preflight import addr, H

ROOT=Path(__file__).resolve().parents[2]

def fixture():
    m=json.loads((ROOT/'candidate-manifest.json').read_text())
    a,d,alice,bob,finalizer,router,treasury=(addr(n) for n in (1,100,2,3,50,4,5))
    c=dict(paymentToken=a,baseTicketPrice=100,ticketSupply=4,salesDuration=8,randomnessDelay=0,maxTicketsPerPurchase=0,potBps=5000,operatorBps=2000,settlementTipBps=500,roomCount=2)
    t=dict(schema=1,chainId=46630,manifestDigest=digest(m),runtimeHashes={k:v['runtimeKeccak256'] for k,v in m['contracts'].items()},diamond=d,assets=[a],configurations={'1':c},integrations={'1':dict(router=router)},treasuryRecipient=treasury,maxActiveRounds=4,beacons={},receipts=[])
    events=catalog()
    def log(name,**v): return raw_log(name,v,d,events)
    def transfer(src,dst,amount): return raw_log('Transfer',{'from':src,'to':dst,'value':amount},a,events)
    def add(at,logs,balance,ledger,pending=None,op=0,tip=0,**kwargs):
        for i,l in enumerate(logs):l['logIndex']=i
        n=len(t['receipts'])+1
        t['receipts'].append(dict(transactionHash='0x'+format(n,'064x'),blockHash='0x'+format(n+100,'064x'),blockNumber=n,transactionIndex=0,timestamp=at,status=1,logs=logs,after=dict(balances={a:balance},accounting={a:dict(zip(FIELDS,ledger))},pendingRollover=pending or {},operatorBuckets={'1:'+a:op} if op else {},finalizerCredits={a+':'+finalizer:tip} if tip else {}),**kwargs))
    add(100,[log('RoundOpened',roundId=1,configVersion=1,integrationVersion=1,openedAt=100,closesAt=108,inheritedPot=0,ticketSupply=4),log('DeadlineCommitted',roundId=1,deadlineTarget=37,effectiveClose=108),log('TicketsPurchased',roundId=1,buyer=alice,room=0,quantity=2,epoch=0,unitPrice=100,payment=200,ticketsRemaining=2),transfer(alice,d,200)],200,[200,0,0,0,0,0],beaconCommitments={'37':dict(boundary=108,firstRoundAfter=37,roundTime=111,cached=False)})
    add(102,[log('TicketsPurchased',roundId=1,buyer=bob,room=0,quantity=2,epoch=1,unitPrice=125,payment=250,ticketsRemaining=0),log('RoundSoldOut',roundId=1,deadlineTarget=37,selectedTarget=35,soldOutAt=102),transfer(bob,d,250)],450,[450,0,0,0,0,0],beaconCommitments={'35':dict(boundary=102,firstRoundAfter=35,roundTime=105,cached=False)})
    randomness=0
    while True:
        rand='0x'+format(randomness,'064x'); seed=keccak('0x'+(word(rand)+word(46630)+word(d)+word(1)).hex())
        if int(seed,16)%2==0:break
        randomness+=1
    t['beacons']['1:35']=dict(roundTime=105,postedAt=106,hasSig=True,randomness=rand)
    deadline=106+30*86400
    add(106,[log('RoundAllocated',roundId=1,asset=a,gross=450,inherited=0,allocations=dict(pot=225,operatorRevenue=90,treasuryGross=135,finalizerTip=6,treasuryNet=129)),log('RolloverCredited',roundId=1,configVersion=1,asset=a,amount=1),log('RoundSettled',roundId=1,winningRoom=0,finalizer=finalizer,seed=seed,winningTickets=4,playerPot=225,payoutPerTicket=56,distributable=224,claimDeadline=deadline)],450,[0,224,1,6,90,129],{'1':1},90,6)
    add(107,[log('PrizeClaimed',roundId=1,player=alice,receiver=alice,tickets=2,amount=112),transfer(d,alice,112)],338,[0,112,1,6,90,129],{'1':1},90,6)
    add(deadline,[log('PrizeExpired',roundId=1,asset=a,amount=112)],338,[0,0,1,6,90,241],{'1':1},90,6)
    add(deadline+1,[transfer(d,router,90),log('OperatorRevenueFlushed',integrationVersion=1,asset=a,router=router,amount=90)],248,[0,0,1,6,0,241],{'1':1},0,6)
    add(deadline+2,[log('FinalizerTipsClaimed',asset=a,finalizer=finalizer,receiver=finalizer,amount=6),transfer(d,finalizer,6)],242,[0,0,1,0,0,241],{'1':1})
    add(deadline+3,[transfer(alice,d,7)],249,[0,0,1,0,0,241],{'1':1},kind='donation')
    add(deadline+4,[log('TokenSurplusAbsorbed',asset=a,amount=7)],249,[0,0,1,0,0,248],{'1':1})
    add(deadline+5,[log('TreasuryFlushed',asset=a,receiver=treasury,amount=248),transfer(d,treasury,248)],1,[0,0,1,0,0,0],{'1':1})
    return t,m

class EvidenceTest(unittest.TestCase):
    def test_full_receipt_fixture(self):
        result=validate(*fixture()); self.assertEqual(result['receipts'],10); self.assertFalse(result['liveExecutionVerified'])

    def test_independent_tampering_is_rejected(self):
        t,m=fixture()
        mutations=[lambda x:x.update(manifestDigest='wrong'),lambda x:x['receipts'][0].update(status=0),lambda x:x['receipts'][1].update(transactionHash=x['receipts'][0]['transactionHash']),lambda x:x['receipts'][0]['logs'][2].update(data='0x'),lambda x:x['receipts'][2]['logs'][0].update(address=addr(999)),lambda x:x['receipts'][1]['beaconCommitments']['35'].update(cached=True),lambda x:x['beacons']['1:35'].update(postedAt=102),lambda x:x['receipts'][3]['after']['balances'].update({addr(1):339}),lambda x:x['receipts'][2]['after'].update(pendingRollover={}),lambda x:x['receipts'][4].update(timestamp=107)]
        for i,mutate in enumerate(mutations):
            with self.subTest(i=i):
                modified=copy.deepcopy(t); mutate(modified)
                with self.assertRaises((Invalid,KeyError)):validate(modified,m)

    def test_semantic_change_with_consistent_raw_encoding_is_rejected(self):
        t,m=fixture()
        log=t['receipts'][3]['logs'][0]
        log['values']['amount']=113
        changed=raw_log(log['event'],log['values'],log['address']);changed['logIndex']=0;t['receipts'][3]['logs'][0]=changed
        with self.assertRaises(Invalid):validate(t,m)

    def test_opening_requires_commitment_and_payment_in_same_receipt(self):
        t,m=fixture(); t['receipts']=t['receipts'][:1]; r=t['receipts'][0];r['logs']=r['logs'][:1]
        a=t['assets'][0];r['after']['balances'][a]=0;r['after']['accounting'][a]=dict.fromkeys(FIELDS,0)
        with self.assertRaises(Invalid):validate(t,m)

    def test_block_global_log_indices_allow_gaps(self):
        t,m=fixture()
        for i,log in enumerate(t['receipts'][0]['logs']):log['logIndex']=7+3*i
        validate(t,m)
        t['receipts'][0]['logs'][1]['logIndex']=7
        with self.assertRaises(Invalid):validate(t,m)

    def test_supplied_candidate_abi_needs_no_local_artifact(self):
        from unittest.mock import patch
        t,m=fixture()
        with patch('tools.evidence.ROOT',Path('unavailable-artifact-root')):
            validate(t,m)
