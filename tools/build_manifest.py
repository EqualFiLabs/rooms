#!/usr/bin/env python3
"""Emit deterministic compiler, dependency, selector and runtime provenance."""
from pathlib import Path
import hashlib
import os
import json
import re
import subprocess
import sys
import tomllib

def require(condition, message='Invalid build provenance'):
    if not condition:
        raise ValueError(message)
ROOT = Path(__file__).resolve().parents[1]
PINS = {'forge-std': 'bf647bd6046f2f7da30d0c2bf435e5c76a780c1b', 'openzeppelin-contracts': '5fd1781b1454fd1ef8e722282f86f9293cacf256', 'drand-registry': '118a94d2e447055d1a47d1a13488e887aaa4a822', 'operator-fee-router': 'a6afe541c6261f1febb2eaf0f4d68ef5aa16548e'}

def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True, env=dict(os.environ, FOUNDRY_DISABLE_NIGHTLY_WARNING='1')).strip()

def build():
    config = tomllib.loads((ROOT / 'foundry.toml').read_text())['profile']['default']
    require((config['solc'], config['evm_version'], config['optimizer'], config['optimizer_runs']) == ('0.8.33', 'osaka', True, 200))
    require(not config.get('via_ir', False))
    for name, pin in PINS.items():
        require(command('git', '-C', f'lib/{name}', 'rev-parse', 'HEAD') == pin)
        require(not command('git', '-C', f'lib/{name}', 'status', '--porcelain', '--untracked-files=no'))
    files = sorted((ROOT / 'src').rglob('*.sol')) + sorted((ROOT / 'script').rglob('*.sol'))
    sources = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    contracts = {}
    for p in files:
        artifact = ROOT / 'out' / p.name / f'{p.stem}.json'
        if not artifact.exists():
            require(not re.search('^(?:abstract )?(?:contract|interface|library) ' + re.escape(p.stem) + '\\b', p.read_text(), re.M), f'Missing artifact for {p.stem}')
            continue
        data = json.loads(artifact.read_text())
        runtime = data['deployedBytecode']['object']
        if runtime in ('', '0x'):
            continue
        metadata = data['metadata']
        require(metadata['compiler']['version'] == '0.8.33+commit.64118f21')
        require(metadata['sources'][str(p.relative_to(ROOT))]['keccak256'] == command('cast', 'keccak', '0x' + p.read_bytes().hex()))
        settings = metadata['settings']
        require(not settings.get('viaIR', False))
        require(settings['evmVersion'] == 'osaka' and settings['optimizer'] == {'enabled': True, 'runs': 200})
        contracts[f'{p.relative_to(ROOT)}:{p.stem}'] = {'runtimeKeccak256': command('cast', 'keccak', runtime), 'runtimeBytes': len(runtime.removeprefix('0x')) // 2, 'selectors': data['methodIdentifiers']}
    require('src/RoomsDiamond.sol:RoomsDiamond' in contracts)
    storage = {}
    for name in ('LibRoomsStorage', 'LibDiamond'):
        text = (ROOT / 'src/libraries' / f'{name}.sol').read_text()
        domains = re.findall('keccak256\\("([^"]+)"\\)', text)
        structs = re.findall('struct \\w+\\s*\\{[^}]+\\}', text)
        storage[name] = {'namespaces': {domain: command('cast', 'keccak', domain) for domain in domains}, 'orderedSchemaSHA256': hashlib.sha256('\n'.join(structs).encode()).hexdigest()}
    storage['valueTypesSHA256'] = hashlib.sha256((ROOT / 'src/shared/Types.sol').read_bytes()).hexdigest()
    assembly = {}
    for key, contract in contracts.items():
        if '/facets/' in key:
            for signature, selector in contract['selectors'].items():
                require(selector not in assembly, f'Selector collision: {signature}')
                assembly[selector] = {'contract': key, 'signature': signature}
    require(len(assembly) == 51)
    return {'schema': 1, 'storageSchemas': storage, 'selectorAssembly': assembly, 'sourceCommit': command('git', 'rev-parse', 'HEAD'), 'compiler': '0.8.33+commit.64118f21', 'evmVersion': 'osaka', 'optimizerRuns': 200, 'viaIR': False, 'dependencies': PINS, 'sourceSHA256': sources, 'contracts': contracts}
if __name__ == '__main__':
    result = json.dumps(build(), sort_keys=True, indent=2) + '\n'
    if len(sys.argv) == 2:
        Path(sys.argv[1]).write_text(result)
    else:
        print(result, end='')
