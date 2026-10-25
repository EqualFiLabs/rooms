import copy
import json
from pathlib import Path
import unittest
from tools.preflight import validate, digest, Invalid

ROOT = Path(__file__).resolve().parents[2]


def addr(n):
    return "0x" + format(n, "040x")


H = "0x" + "ab" * 32


def fixture():
    manifest = json.loads((ROOT / "candidate-manifest.json").read_text())
    asset, auth, registry, router = (addr(n) for n in range(1, 5))
    config = dict(
        paymentToken=asset,
        baseTicketPrice=3,
        ticketSupply=4,
        salesDuration=8,
        randomnessDelay=0,
        maxTicketsPerPurchase=0,
        potBps=5000,
        operatorBps=2000,
        settlementTipBps=500,
        roomCount=2,
    )
    roles = dict(
        proposers=[addr(5)],
        executors=[addr(6)],
        administrators=[auth],
        cancellers=[addr(5)],
    )
    deployed = {
        key: addr(100 + i)
        for i, key in enumerate(manifest["contracts"])
        if "/facets/" in key
        or key.endswith(":RoomsDiamond")
        or key.endswith(":RoomsInit")
    }
    plan = dict(
        schema=1,
        chainId=46630,
        manifestDigest=digest(manifest),
        authority=dict(address=auth, minDelay=172800, runtimeHash=H, **roles),
        guardian=addr(7),
        treasuryRecipient=addr(8),
        maxActiveRounds=4,
        assets=[
            dict(
                address=asset,
                runtimeHash=H,
                canonical=True,
                exactTransfer=True,
                nonRebasing=True,
                noAliases=True,
            )
        ],
        configs=[config],
        registry=dict(address=registry, runtimeHash=H),
        router=dict(address=router, runtimeHash=H),
        deployed=deployed,
    )
    codes = dict.fromkeys([asset, auth, registry, router], H)
    installed = {}
    for key, a in deployed.items():
        codes[a] = manifest["contracts"][key]["runtimeKeccak256"]
        if "/facets/" in key:
            installed.update(
                {
                    selector: a
                    for selector in manifest["contracts"][key]["selectors"].values()
                }
            )
    observed = dict(
        schema=1,
        manifestDigest=digest(manifest),
        block=dict(chainId=46630, number=10, hash=H),
        timelock=dict(
            address=auth,
            minDelay=172800,
            roleHistoryReviewed=True,
            **copy.deepcopy(roles)
        ),
        codeHashes=codes,
        diamond=dict(
            authority=auth,
            selectors=installed,
            initialized=True,
            cutsDisabled=False,
            configs=[config],
            approvedAssets=[asset],
            guardian=addr(7),
            treasuryRecipient=addr(8),
            maxActiveRounds=4,
            integrationVersion=1,
            registry=registry,
            router=router,
        ),
        routerReadiness={
            asset: dict(
                bootstrapFinalized=True,
                totalEffectiveWeight=1,
                registered=True,
                enabled=True,
            )
        },
        registryProbe=dict(boundary=100, round=34, roundTime=102, cached=False),
        targetClientExecution=dict(osakaCompatible=True, receiptHash=H),
    )
    return plan, manifest, observed


class PreflightTest(unittest.TestCase):
    def test_explicit_consistent_fixture(self):
        self.assertFalse(validate(*fixture())["liveExecutionPerformedByValidator"])

    def test_rejects_independent_observation_and_plan_drift(self):
        changes = [
            lambda p, m, o: o["block"].update(chainId=1),
            lambda p, m, o: o.update(manifestDigest="wrong"),
            lambda p, m, o: o["codeHashes"].update(
                {p["authority"]["address"]: "0x" + "cd" * 32}
            ),
            lambda p, m, o: o["timelock"].update(minDelay=1),
            lambda p, m, o: o["timelock"].update(roleHistoryReviewed=False),
            lambda p, m, o: o["timelock"]["administrators"].append(addr(999)),
            lambda p, m, o: o["diamond"].update(selectors={}),
            lambda p, m, o: o["diamond"].update(configs=[]),
            lambda p, m, o: o["targetClientExecution"].update(osakaCompatible=False),
            lambda p, m, o: o["registryProbe"].update(cached=True),
            lambda p, m, o: p["assets"][0].update(exactTransfer=False),
            lambda p, m, o: p["configs"][0].update(salesDuration=3),
            lambda p, m, o: p["configs"][0].update(operatorBps=3000),
            lambda p, m, o: o["routerReadiness"][p["assets"][0]["address"]].update(
                enabled=False
            ),
        ]
        for change in changes:
            with self.subTest(change=changes.index(change)):
                p, m, o = copy.deepcopy(fixture())
                change(p, m, o)
                with self.assertRaises(Invalid):
                    validate(p, m, o)

    def test_unset_template_is_rejected(self):
        p, m, o = fixture()
        p = json.loads((ROOT / "rehearsal/launch-inputs.example.json").read_text())
        with self.assertRaises((Invalid, TypeError)):
            validate(p, m, o)
