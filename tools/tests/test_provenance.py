import copy
import json
from pathlib import Path
import unittest
from tools.build_manifest import verify_sources

ROOT=Path(__file__).resolve().parents[2]
class ProvenanceTest(unittest.TestCase):
    def test_transitive_source_identity(self):
        metadata=json.loads((ROOT/'out/RoomsFacet.sol/RoomsFacet.json').read_text())['metadata']
        verify_sources(metadata)
        stale=copy.deepcopy(metadata)
        imported=next(k for k in stale['sources'] if k.endswith('/LibRoomsPurchase.sol'))
        stale['sources'][imported]['keccak256']='0x'+'00'*32
        with self.assertRaisesRegex(ValueError,'Stale imported source'):
            verify_sources(stale)
