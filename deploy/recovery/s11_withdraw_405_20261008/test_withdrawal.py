"""Native local fixture only; no production connection and no producer execution."""
from contextlib import closing
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

import pyodbc

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("fixture", ROOT.parent / "s11_manual_stats_20261008" / "test_recovery.py")
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)
WORKER = (ROOT / "withdraw.sql").read_text(encoding="utf-8")
P = "340b9372-e6ee-44de-927a-d10483eefe1a"


class WithdrawalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture.RecoveryTests.setUpClass()
        cls.cn = fixture.RecoveryTests.cn

    @classmethod
    def tearDownClass(cls):
        fixture.RecoveryTests.tearDownClass()

    def setUp(self):
        fixture.RecoveryTests().setUp()
        self.cn.cursor().execute("""UPDATE dbo.ExportPreparation SET State='unavailable',Version=6,
        GenerationJson=N'{"operator_reconciliation":{"recovery_id":"50A5B6E5-D1D0-49DC-BF04-AB566047E152"}}'
        WHERE PreparationID=?;
        INSERT dbo.ExportPreparation(PreparationID,AccountKey,ConsumerKind,State,OwnerID,Fence,Version,EnqueueSequence,RequestHash,Reason,CreatedUTC,UpdatedUTC)
        VALUES(?,?,'scan_data','pending',NULL,0,1,405,
        0x80718563BB8BCE4CA05CC48638A7CC2EC9DEDCF159D290079B2B44AA6652F52C,'scan_data','2026-10-08T14:45:24.378','2026-10-08T14:45:24.378');
        """, fixture.P, P, fixture.A)

    def execute(self):
        cur = self.cn.cursor().execute("DECLARE @ExpectedServer nvarchar(128)=?,@ExpectedDatabase sysname=?;"+WORKER, fixture.SERVER, fixture.DATABASE)
        while cur.description is None:
            if not cur.nextset(): self.fail("No receipt")
        return cur.fetchone()

    def assert_pending(self):
        self.assertEqual(tuple(self.cn.cursor().execute("SELECT State,Version,Fence,OwnerID FROM dbo.ExportPreparation WHERE PreparationID=?", P).fetchone()), ("pending",1,0,None))
        self.assertEqual(self.cn.cursor().execute("SELECT COUNT(*) FROM dbo.SyntheticProducerCalls").fetchval(), 0)
        self.assertEqual(self.cn.cursor().execute("SELECT @@TRANCOUNT").fetchval(), 0)

    def test_withdraw_and_repeat_without_producer_or_resource_changes(self):
        before = [tuple(r) for r in self.cn.cursor().execute("SELECT * FROM dbo.ExportResource ORDER BY ResourceKey")]
        prior = tuple(self.cn.cursor().execute("SELECT * FROM dbo.ExportPreparation WHERE PreparationID=?", fixture.P).fetchone())
        result = self.execute()
        self.assertEqual(result[0], "WITHDRAWN_UNCLAIMED_PREPARATION")
        audit = json.loads(result[2])["operator_reconciliation"]
        self.assertFalse(audit["producer_replayed"])
        self.assertEqual(audit["previous_preparation"]["State"], "pending")
        self.assertEqual(self.execute()[0], "ALREADY_WITHDRAWN_NO_CHANGE")
        self.assertEqual(tuple(self.cn.cursor().execute("SELECT State,Version,Fence FROM dbo.ExportPreparation WHERE PreparationID=?", P).fetchone()), ("unavailable",2,1))
        self.assertEqual(before, [tuple(r) for r in self.cn.cursor().execute("SELECT * FROM dbo.ExportResource ORDER BY ResourceKey")])
        self.assertEqual(prior, tuple(self.cn.cursor().execute("SELECT * FROM dbo.ExportPreparation WHERE PreparationID=?", fixture.P).fetchone()))
        self.assertEqual(self.cn.cursor().execute("SELECT COUNT(*) FROM dbo.SyntheticProducerCalls").fetchval(), 0)

    def test_claimed_row_is_never_withdrawn(self):
        self.cn.cursor().execute("UPDATE dbo.ExportPreparation SET State='preflight',Version=2,OwnerID=NEWID(),Fence=1 WHERE PreparationID=?",P)
        with self.assertRaisesRegex(pyodbc.Error, "51932"): self.execute()
        self.assertEqual(self.cn.cursor().execute("SELECT State FROM dbo.ExportPreparation WHERE PreparationID=?",P).fetchval(), "preflight")

    def test_active_resource_refuses(self):
        self.cn.cursor().execute("UPDATE dbo.ExportResource SET ActivePreparationID=? WHERE ResourceKind='account'",P)
        with self.assertRaisesRegex(pyodbc.Error, "51932"): self.execute()
        self.assert_pending()

    def test_even_closed_provider_evidence_refuses(self):
        self.cn.cursor().execute("INSERT dbo.ExportExecutionStream VALUES(NEWID(),?,'closed',?)", fixture.A,P)
        with self.assertRaisesRegex(pyodbc.Error, "51932"): self.execute()
        self.assert_pending()

    def test_wrong_request_hash_refuses(self):
        self.cn.cursor().execute("UPDATE dbo.ExportPreparation SET RequestHash=0x01 WHERE PreparationID=?",P)
        with self.assertRaisesRegex(pyodbc.Error, "51932"): self.execute()
        self.assert_pending()

    def test_missing_prior_receipt_refuses(self):
        self.cn.cursor().execute("UPDATE dbo.ExportPreparation SET GenerationJson=NULL WHERE PreparationID=?",fixture.P)
        with self.assertRaisesRegex(pyodbc.Error, "51932"): self.execute()
        self.assert_pending()

    def test_live_account_mutex_refuses(self):
        with closing(fixture.connect()) as holder:
            key = "k98-export:" + hashlib.sha256(("account:"+fixture.A).encode()).hexdigest()
            holder.cursor().execute("BEGIN TRAN")
            holder.cursor().execute("EXEC sys.sp_getapplock @Resource=?,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0",key)
            try:
                with self.assertRaisesRegex(pyodbc.Error, "51931"): self.execute()
            finally:
                holder.cursor().execute("ROLLBACK")
        self.assert_pending()


if __name__ == "__main__":
    unittest.main(verbosity=2)
