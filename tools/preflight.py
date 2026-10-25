#!/usr/bin/env python3
"""Validate explicit launch inputs against supplied, block-pinned read observations.

This command never connects to an RPC, signs, deploys, or treats attestations as proofs.
"""
import argparse
import hashlib
import json
import re

class Invalid(ValueError):
    pass

def require(condition, message):
    if not condition:
        raise Invalid(message)

def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

def address(value):
    require(isinstance(value, str) and re.fullmatch(r'0x[0-9a-fA-F]{40}', value) and int(value, 16) != 0, 'nonzero address required')
    return value.lower()

def integer(value, low, high):
    require(type(value) is int and low <= value <= high, 'integer outside bound')
    return value

def hash32(value):
    require(isinstance(value, str) and re.fullmatch(r'0x[0-9a-fA-F]{64}', value) and int(value, 16) != 0, 'hash required')
    return value.lower()

def validate(plan, manifest, observed):
    require(plan['schema'] == 1 and observed['schema'] == 1, 'schema')
    require(plan['chainId'] == observed['block']['chainId'] == 46630, 'chain')
    integer(observed['block']['number'], 1, 2**64-1)
    hash32(observed['block']['hash'])
    require(plan['manifestDigest'] == observed['manifestDigest'] == digest(manifest), 'candidate binding')
    require((manifest['compiler'], manifest['evmVersion'], manifest['optimizerRuns'], manifest['viaIR']) == ('0.8.33+commit.64118f21', 'osaka', 200, False), 'compiler settings')
    require(bool(manifest['storageSchemas']) and len(manifest['selectorAssembly']) == 51, 'layout/selector manifest')
    integer(plan['maxActiveRounds'], 1, 65535)
    authority = plan['authority']
    auth = address(authority['address'])
    address(plan['guardian']); address(plan['treasuryRecipient'])
    integer(authority['minDelay'], 1, 2**64-1)
    timelock = observed['timelock']
    require(address(timelock['address']) == auth and timelock['minDelay'] == authority['minDelay'], 'timelock identity/delay')
    require(timelock['roleHistoryReviewed'] is True, 'complete role history review required')
    for role in ('proposers', 'executors', 'administrators', 'cancellers'):
        expected = [address(x) for x in authority[role]]
        actual = [address(x) for x in timelock[role]]
        require(expected and len(expected) == len(set(expected)) and sorted(expected) == sorted(actual), 'role inventory')
    require(auth in [address(x) for x in authority['administrators']], 'self administration')
    expected_codes = {auth: hash32(authority['runtimeHash'])}
    assets = {}
    for asset in plan['assets']:
        a = address(asset['address'])
        require(a not in assets, 'duplicate asset')
        for policy in ('canonical', 'exactTransfer', 'nonRebasing', 'noAliases'):
            require(asset[policy] is True, 'asset attestation')
        assets[a] = asset
        require(a not in expected_codes, 'asset identity collision')
        expected_codes[a] = hash32(asset['runtimeHash'])
    require(bool(assets) and bool(plan['configs']), 'launch inputs unset')
    for config in plan['configs']:
        require(address(config['paymentToken']) in assets, 'unsupported config asset')
        integer(config['baseTicketPrice'], 1, 2**96-1)
        integer(config['ticketSupply'], 1, 2**256-1)
        integer(config['salesDuration'], 4, 2**32-1)
        integer(config['randomnessDelay'], 0, 2**32-1)
        integer(config['maxTicketsPerPurchase'], 0, 2**32-1)
        integer(config['settlementTipBps'], 0, 9999)
        integer(config['roomCount'], 2, 24)
        require(config['potBps'] == 5000 and config['operatorBps'] == 2000, 'initial split')
    for name in ('registry', 'router'):
        endpoint = plan[name]
        endpoint_address = address(endpoint['address'])
        require(endpoint_address not in expected_codes, 'integration identity collision')
        expected_codes[endpoint_address] = hash32(endpoint['runtimeHash'])
    deployed = plan['deployed']
    require(set(deployed) == {key for key in manifest['contracts'] if '/facets/' in key or key.endswith(':RoomsDiamond') or key.endswith(':RoomsInit')}, 'complete assembly')
    installed = {}
    for key, a in deployed.items():
        a = address(a)
        require(a not in expected_codes, 'duplicate deployment address')
        expected_codes[a] = manifest['contracts'][key]['runtimeKeccak256']
        if '/facets/' in key:
            for selector in manifest['contracts'][key]['selectors'].values():
                require(selector not in installed, 'selector collision')
                installed[selector] = a
    diamond = address(deployed['src/RoomsDiamond.sol:RoomsDiamond'])
    require(address(plan['treasuryRecipient']) != diamond, 'treasury self')
    require(observed['diamond']['authority'].lower() == auth and observed['diamond']['selectors'] == installed, 'installed authority/selectors')
    state = observed['diamond']
    require(state['configs'] == plan['configs'] and state['approvedAssets'] == sorted(assets), 'initial config/asset snapshots')
    require(address(state['guardian']) == address(plan['guardian']) and address(state['treasuryRecipient']) == address(plan['treasuryRecipient']) and state['maxActiveRounds'] == plan['maxActiveRounds'], 'initial governance')
    require(state['integrationVersion'] == 1 and state['registry'].lower() == plan['registry']['address'].lower() and state['router'].lower() == plan['router']['address'].lower(), 'integration snapshot')
    require(observed['diamond']['initialized'] is True and observed['diamond']['cutsDisabled'] is False, 'activation state')
    require({address(k): hash32(v) for k, v in observed['codeHashes'].items()} == expected_codes, 'runtime identity')
    require(set(observed['routerReadiness']) == set(assets), 'asset readiness inventory')
    for state in observed['routerReadiness'].values():
        require(state['bootstrapFinalized'] is True and state['registered'] is True and state['enabled'] is True and state['totalEffectiveWeight'] > 0, 'router readiness')
    probe = observed['registryProbe']
    integer(probe['round'], 1, 2**64-1)
    require(probe['roundTime'] > probe['boundary'] and probe['cached'] is False, 'future beacon probe')
    require(observed['targetClientExecution']['osakaCompatible'] is True, 'target EVM execution required')
    hash32(observed['targetClientExecution']['receiptHash'])
    return {'schema': 1, 'chainId': 46630, 'manifestDigest': digest(manifest), 'block': observed['block'], 'status': 'supplied observations consistent', 'liveExecutionPerformedByValidator': False}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for item in ('plan', 'manifest', 'observed'):
        parser.add_argument(item)
    args = parser.parse_args()
    try:
        result = validate(*(json.load(open(getattr(args, item))) for item in ('plan', 'manifest', 'observed')))
    except (Invalid, KeyError, TypeError, ValueError) as error:
        parser.exit(1, f'Preflight rejected: {error}\n')
    print(json.dumps(result, sort_keys=True, indent=2))

if __name__ == '__main__':
    main()
