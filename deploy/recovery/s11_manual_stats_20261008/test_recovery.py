"""Native local-only transaction tests; synthetic data and producer, never production."""
from contextlib import closing
import hashlib
import json
from pathlib import Path
import re
import unittest
from uuid import uuid4

import pyodbc

SERVER = r"9SX2VF4\K98DEV"
DATABASE = "S11_ManualStats_Test_20261008_" + uuid4().hex[:8]
WORKER = Path(__file__).with_name("settle.sql").read_text(encoding="utf-8-sig")
P = "c9831a9d-3031-4954-9da9-79815406ec0b"
W = "aab3d39c-1ba6-4902-a8e7-732be9722b1b"
A = "sheets-service@statsupdate.iam.gserviceaccount.com"
SESSION = "6b3f98d0-b4a7-41cb-9f4f-3ca2f84655bf"
PREFIX = "DECLARE @ExpectedServer nvarchar(128)=?,@ExpectedDatabase sysname=?,@StatsHash binary(32)=?,@ImportLockHash binary(32)=?;\n"


def connect(database=DATABASE):
    if database != "master" and not re.fullmatch(r"S11_ManualStats_Test_20261008_[a-f0-9]{8}", database):
        raise ValueError("Local fixture name required")
    cn = pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};SERVER=lpc:localhost\\K98DEV;"
        f"DATABASE={database};Trusted_Connection=yes;TrustServerCertificate=yes",
        autocommit=True, timeout=5,
    )
    cn.timeout = 10
    actual = cn.cursor().execute("SELECT @@SERVERNAME,DB_NAME()").fetchone()
    if actual[0].lower() != SERVER.lower() or actual[1] != database:
        cn.close()
        raise ValueError("Local fixture target differs")
    return cn


DDL = """
CREATE TABLE dbo.ExportPreparation (
PreparationID uniqueidentifier PRIMARY KEY,AccountKey varchar(128),ConsumerKind varchar(32),
State varchar(32),OwnerID uniqueidentifier,Fence bigint,Version bigint,EnqueueSequence bigint,
RequestHash binary(32),GenerationJson nvarchar(max),SpoolKey varchar(128),SpoolBytes bigint,
SpoolHash binary(32),JobID uniqueidentifier,Reason nvarchar(1024),CreatedUTC datetime2(3),UpdatedUTC datetime2(3));
CREATE TABLE dbo.ExportPreparationResource(PreparationID uniqueidentifier,ResourceKey varchar(256),PRIMARY KEY(PreparationID,ResourceKey));
CREATE TABLE dbo.ExportResource(ResourceKey varchar(256) PRIMARY KEY,ResourceKind varchar(32),ActivePreparationID uniqueidentifier,
OwnerID uniqueidentifier,Fence bigint,Version bigint,ActiveJobID uniqueidentifier,ActiveOutputOperationID uniqueidentifier,BlockedReason nvarchar(1024));
CREATE TABLE dbo.ExportExecutionStream(StreamID uniqueidentifier PRIMARY KEY,AccountKey varchar(128),State varchar(16),PreparationID uniqueidentifier);
CREATE TABLE dbo.ExportExecutionSession(SessionID uniqueidentifier PRIMARY KEY,HostIdentity varchar(128),State varchar(16),Version bigint,AuthorityPrincipal nvarchar(128),ManifestHash binary(32));
CREATE TABLE dbo.STATS_FOR_UPLOAD(Gov_ID bigint,KVK_NO int,LAST_REFRESH datetime2(7),Points bigint);
CREATE TABLE dbo.SyntheticProducerCalls(CallID int);
"""


class RecoveryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with closing(connect("master")) as cn:
            cn.cursor().execute(f"CREATE DATABASE [{DATABASE}]")
        cls.cn = connect()
        cls.cn.cursor().execute(DDL)
        cls.cn.cursor().execute("CREATE PROCEDURE dbo.ACQUIRE_KS4_IMPORT_LOCK AS BEGIN SET NOCOUNT ON; END")

    @classmethod
    def tearDownClass(cls):
        cls.cn.close()
        # Retain the synthetic database for inspection; no DROP of arbitrary state.
        print("Retained synthetic database:", DATABASE)

    def setUp(self):
        cur = self.cn.cursor()
        for table in ("ExportPreparationResource", "ExportResource", "ExportExecutionStream", "ExportExecutionSession", "ExportPreparation", "STATS_FOR_UPLOAD", "SyntheticProducerCalls"):
            cur.execute(f"DELETE FROM dbo.{table}")
        cur.execute("""INSERT dbo.ExportPreparation(PreparationID,AccountKey,ConsumerKind,State,OwnerID,Fence,Version,EnqueueSequence,RequestHash,Reason,CreatedUTC,UpdatedUTC)
        VALUES(?,?,'scan_data','uncertain','d34ee646-7b5b-4b00-8644-22a3b718ce9e',238,5,360,
        0x278A54D6EE8C14B5A5022C406021F1093C5C1AB977F5C4BBE2A368F9331A9D7B,'scan_data','2026-10-08T11:14:16.274','2026-10-08T11:14:29.735'),
        (?,?,'scan_data','sql_pending','c03c155e-3937-48b5-bd76-9150048ca77b',238,3,401,0x01,'scan_data','2026-10-08T14:39:30.904','2026-10-08T14:39:31.191')""", P, A, W, A)
        cur.execute("INSERT dbo.ExportPreparationResource VALUES(?,?),(?,'sql_snapshot:legacy_outputs')", P, "account:"+A, P)
        cur.execute("INSERT dbo.ExportResource VALUES(?,'account',NULL,NULL,238,479,NULL,NULL,NULL),('sql_snapshot:legacy_outputs','sql_snapshot',?,'d34ee646-7b5b-4b00-8644-22a3b718ce9e',238,18,NULL,NULL,'Preparation requires authoritative reconciliation')", "account:"+A, P)
        cur.execute("INSERT dbo.ExportExecutionSession VALUES(?,'mini_AMD','open',1,'S11_ExportApplication',0x287A049603B361510E0745E94300645D9516C347AAC00368B415D03D039AE73E)", SESSION)
        cur.execute("INSERT dbo.STATS_FOR_UPLOAD VALUES(1,16,'2026-09-29',10)")
        self.producer()

    def producer(self, suffix=""):
        self.cn.cursor().execute("""CREATE OR ALTER PROCEDURE dbo.SP_Stats_for_Upload AS
        BEGIN SET NOCOUNT ON; DELETE dbo.STATS_FOR_UPLOAD;
        INSERT dbo.STATS_FOR_UPLOAD VALUES(1,16,'2026-10-08',20);
        INSERT dbo.SyntheticProducerCalls VALUES(1); """ + suffix + " END")

    def hashes(self):
        values = []
        for name in ("dbo.SP_Stats_for_Upload", "dbo.ACQUIRE_KS4_IMPORT_LOCK"):
            definition = self.cn.cursor().execute("SELECT OBJECT_DEFINITION(OBJECT_ID(?))", name).fetchval().replace("\r\n", "\n")
            definition = definition[definition.upper().index("PROCEDURE"):].strip()
            values.append(hashlib.sha256(definition.encode("utf-16le")).digest())
        return values

    def execute(self, hashes=None):
        cur = self.cn.cursor().execute(PREFIX + WORKER, SERVER, DATABASE, *(hashes or self.hashes()))
        while cur.description is None:
            if not cur.nextset():
                self.fail("Missing receipt")
        return cur.fetchone()

    def assert_unchanged(self):
        self.assertEqual(tuple(self.cn.cursor().execute("SELECT State,Version,GenerationJson FROM dbo.ExportPreparation WHERE PreparationID=?", P).fetchone()), ("uncertain",5,None))
        self.assertEqual(self.cn.cursor().execute("SELECT Points FROM dbo.STATS_FOR_UPLOAD").fetchval(), 10)
        self.assertEqual(self.cn.cursor().execute("SELECT COUNT(*) FROM dbo.SyntheticProducerCalls").fetchval(), 0)
        self.assertEqual(self.cn.cursor().execute("SELECT @@TRANCOUNT").fetchval(), 0)

    def test_commit_and_repeated_invocation_do_not_repeat_producer(self):
        row = self.execute()
        self.assertEqual(row[0], "COMMITTED_MANUAL_SUPERSESSION")
        audit = json.loads(row[2])["operator_reconciliation"]
        self.assertEqual(audit["historical_sql_outcome"], "unknown")
        self.assertFalse(audit["historical_commit_proven"])
        self.assertEqual(len(audit["previous_preparations"]), 2)
        self.assertEqual(self.execute()[0], "ALREADY_COMMITTED_NO_REPLAY")
        self.assertEqual(self.cn.cursor().execute("SELECT COUNT(*) FROM dbo.SyntheticProducerCalls").fetchval(), 1)
        self.assertEqual(tuple(self.cn.cursor().execute("SELECT Version,ActivePreparationID,BlockedReason FROM dbo.ExportResource WHERE ResourceKind='sql_snapshot'").fetchone()), (19,None,None))
        self.assertEqual(tuple(self.cn.cursor().execute("SELECT State,Version,Fence FROM dbo.ExportPreparation WHERE PreparationID=?", W).fetchone()), ("unavailable",4,239))

    def test_producer_failure_rolls_back_business_and_metadata(self):
        self.producer("THROW 51999,'Synthetic failure after replacement',1;")
        with self.assertRaises(pyodbc.Error): self.execute()
        self.assert_unchanged()

    def test_invalid_candidate_rolls_back(self):
        self.producer("INSERT dbo.STATS_FOR_UPLOAD VALUES(1,16,'2026-10-08',30);")
        with self.assertRaises(pyodbc.Error): self.execute()
        self.assert_unchanged()

    def test_wrong_module_hash_stops_before_producer(self):
        with self.assertRaises(pyodbc.Error): self.execute([bytes(32), self.hashes()[1]])
        self.assert_unchanged()

    def test_stale_fence_stops_before_producer(self):
        self.cn.cursor().execute("UPDATE dbo.ExportResource SET Fence=239 WHERE ResourceKind='sql_snapshot'")
        with self.assertRaises(pyodbc.Error): self.execute()
        self.assert_unchanged()

    def test_open_provider_stream_blocks_settlement(self):
        self.cn.cursor().execute("INSERT dbo.ExportExecutionStream VALUES(NEWID(),?,'open',NULL)", A)
        with self.assertRaises(pyodbc.Error): self.execute()
        self.assert_unchanged()

    def test_live_producer_session_lock_blocks_settlement(self):
        with closing(connect()) as holder:
            holder.cursor().execute("EXEC sys.sp_getapplock @Resource=N'k98-legacy-output-snapshot',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0")
            try:
                with self.assertRaises(pyodbc.Error): self.execute()
                self.assert_unchanged()
            finally:
                holder.cursor().execute("EXEC sys.sp_releaseapplock @Resource=N'k98-legacy-output-snapshot',@LockOwner='Session'")

    def test_competing_account_transaction_blocks_settlement(self):
        with closing(connect()) as holder:
            key = "k98-export:" + hashlib.sha256(("account:"+A).encode()).hexdigest()
            holder.cursor().execute("BEGIN TRAN")
            holder.cursor().execute("EXEC sys.sp_getapplock @Resource=?,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0",key)
            try:
                with self.assertRaises(pyodbc.Error): self.execute()
            finally: holder.cursor().execute("ROLLBACK")
            self.assert_unchanged()

    def test_z_canonical_stats_procedure_retains_atomic_transaction(self):
        schema = Path(__file__).resolve().parents[3] / "sql_schema"
        cur = self.cn.cursor()
        cur.execute("EXEC sp_rename 'dbo.STATS_FOR_UPLOAD','SyntheticStats'")
        try:
            cur.execute((schema / "dbo.STATS_FOR_UPLOAD.Table.sql").read_text(encoding="utf-8-sig"))
            cur.execute("""CREATE ROLE K98ImportLockPrincipal;
            CREATE TABLE dbo.KingdomScanData4(SCANORDER int,ScanDate datetime2);
            CREATE TABLE dbo.ProcConfig(KVKVersion int,ConfigKey varchar(64),ConfigValue float);
            CREATE TABLE dbo.KVKFinalReportHeader(KVK_NO int,FinalScanOrder int,OutputRowCount int,Revision int,State nvarchar(24),FinalizationBasis nvarchar(24),FinalDataAtUtc datetime2);
            CREATE TABLE dbo.EXEMPT_FROM_STATS(GovernorID bigint,KVK_NO int);
            SELECT TOP(0) * INTO dbo.EXCEL_FOR_KVK_16 FROM dbo.STATS_FOR_UPLOAD;
            INSERT dbo.KingdomScanData4 VALUES(100,'2026-10-08');
            INSERT dbo.ProcConfig VALUES(16,'MATCHMAKING_SCAN',90),(16,'KVK_END_SCAN',100);
            INSERT dbo.KVKFinalReportHeader VALUES(16,100,1,1,'OUTPUT_COMPLETE','TEST','2026-10-08');
            INSERT dbo.EXCEL_FOR_KVK_16(Gov_ID,KVK_NO,Governor_Name) VALUES(1,16,'Synthetic governor');""")
            for name in ("ACQUIRE_KS4_IMPORT_LOCK", "SP_Stats_for_Upload"):
                source = (schema / ("dbo."+name+".StoredProcedure.sql")).read_text(encoding="utf-8-sig")
                match = list(re.finditer(r"(?im)^(?:CREATE OR ALTER|ALTER) PROCEDURE", source))[-1]
                body = re.sub(r"(?im)^GO\s*$", "", source[match.start():]).strip()
                body = re.sub(r"^(?:CREATE OR ALTER|ALTER) PROCEDURE", "CREATE OR ALTER PROCEDURE", body)
                cur.execute(body)
            # Deliberately stale header: authoritative procedure must refuse and preserve hold.
            cur.execute("UPDATE dbo.KVKFinalReportHeader SET FinalScanOrder=99")
            with self.assertRaisesRegex(pyodbc.Error, "52806"):
                self.execute()
            self.assertEqual(cur.execute("SELECT State FROM dbo.ExportPreparation WHERE PreparationID=?", P).fetchval(), "uncertain")
            self.assertEqual(cur.execute("SELECT COUNT(*) FROM dbo.STATS_FOR_UPLOAD").fetchval(), 0)
            cur.execute("UPDATE dbo.KVKFinalReportHeader SET FinalScanOrder=100")
            self.assertEqual(self.execute()[0], "COMMITTED_MANUAL_SUPERSESSION")
            self.assertEqual(cur.execute("SELECT STATUS FROM dbo.STATS_FOR_UPLOAD").fetchval(), "INCLUDED")
            self.assertEqual(self.execute()[0], "ALREADY_COMMITTED_NO_REPLAY")
        finally:
            cur.execute("DROP TABLE IF EXISTS dbo.STATS_FOR_UPLOAD; EXEC sp_rename 'dbo.SyntheticStats','STATS_FOR_UPLOAD'")

    def test_client_discards_commit_result_then_reconnects(self):
        cur = self.cn.cursor().execute(PREFIX + WORKER,SERVER,DATABASE,*self.hashes())
        while cur.description is None:
            if not cur.nextset(): self.fail("Missing completion")
        cur.fetchall()  # Transport completed; caller deliberately does not accept the receipt.
        cur.close()
        self.cn.close()
        type(self).cn = connect()
        self.assertEqual(self.execute()[0], "ALREADY_COMMITTED_NO_REPLAY")
        self.assertEqual(self.cn.cursor().execute("SELECT COUNT(*) FROM dbo.SyntheticProducerCalls").fetchval(), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
