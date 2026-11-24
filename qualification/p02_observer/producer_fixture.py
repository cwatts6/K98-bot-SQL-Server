"""Read-only business preflight and one fresh recovery snapshot for DB16."""

import json
from pathlib import Path
import re

PRIOR_PATH = r"Q:\P02Observer\20261121081714051\receipt.json"
PRIOR_SHA = "1a91de92143c90ffa7b4991d15981dce7139617f0b5e17ccf8044167aa627e38"
ACTIVE_SQL = """SELECT s.session_id,s.host_process_id,r.status AS request_status,
r.command,r.wait_type,r.blocking_session_id,
CASE WHEN t.objectid=OBJECT_ID(N'dbo.SP_Stats_for_Upload')
 OR t.text LIKE N'%EXEC dbo.SP_Stats_for_Upload;%' THEN 1 ELSE 0 END AS report_batch
FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id=r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE s.is_user_process=1 AND s.login_name=N'S11_ExportApplication'
AND s.host_process_id IN (?,?) AND r.database_id=DB_ID() ORDER BY s.session_id"""
ORIGINAL_PREPARATIONS = """SELECT COUNT_BIG(*) AS original_count,
LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',
(SELECT p.* FROM dbo.ExportPreparation p WHERE p.AccountKey<>?
 ORDER BY p.PreparationID FOR JSON PATH,INCLUDE_NULL_VALUES)),2)) AS original_sha256
FROM dbo.ExportPreparation WHERE AccountKey<>?"""
FRESH_ACCOUNT = """SELECT PreparationID,State,OwnerID,Fence,Version,StorageOwner,SpoolKey,SpoolBytes,
LOWER(CONVERT(varchar(64),SpoolHash,2)) AS SpoolHash,RequestJson,GenerationJson
FROM dbo.ExportPreparation WHERE AccountKey=? ORDER BY EnqueueSequence,PreparationID"""
RESOURCE_SQL = """SELECT ResourceKey,ActiveJobID,ActivePreparationID,ActiveOutputOperationID,
OwnerID,Fence,Version,CASE WHEN BlockedReason IS NULL THEN 0 ELSE 1 END AS blocked
FROM dbo.ExportResource WHERE ResourceKey IN (N'sql_snapshot:legacy_outputs',?)
ORDER BY ResourceKey"""
SNAPSHOT_SQL = """SET NOCOUNT ON;
IF DB_NAME()<>N'ROK_TRACKER' OR DB_ID()<>16 OR @@TRANCOUNT<>0
 OR IS_SRVROLEMEMBER('sysadmin')<>1 THROW 51976,'Exact DB16 snapshot owner required.',1;
DECLARE @Name sysname=?,@File nvarchar(260)=?,@Logical sysname;
IF @Name NOT LIKE N'K98_P02Capture_[0-9]%' OR DB_ID(@Name) IS NOT NULL
 THROW 51976,'Fresh lab snapshot name required.',1;
IF (SELECT COUNT(*) FROM sys.database_files WHERE type=0)<>1
 THROW 51976,'One retained source data file required.',1;
SELECT @Logical=name FROM sys.database_files WHERE type=0
 AND physical_name=N'Q:\\P02Release\\K98_P02Release_20261120153927686\\baseline.mdf';
IF @Logical IS NULL THROW 51976,'Exact retained source data file required.',1;
DECLARE @Sql nvarchar(max)=N'CREATE DATABASE '+QUOTENAME(@Name)+N' ON (NAME='
+QUOTENAME(@Logical)+N',FILENAME=N'+QUOTENAME(@File,CHAR(39))+N') AS SNAPSHOT OF [ROK_TRACKER];';
EXEC sys.sp_executesql @Sql;
SELECT name,database_id,source_database_id,state_desc,is_read_only
FROM sys.databases WHERE name=@Name;"""
REPORT_SOURCE_SQL = """SELECT MAX(SCANORDER) AS max_scan FROM dbo.KingdomScanData4"""
REPORT_CONFIG_SQL = """SELECT KVKVersion,ConfigKey,ConfigValue FROM dbo.ProcConfig
WHERE KVKVersion=(SELECT MAX(KVKVersion) FROM dbo.ProcConfig
 WHERE ConfigKey='MATCHMAKING_SCAN' AND TRY_CONVERT(int,ConfigValue) IS NOT NULL
 AND ConfigValue=CONVERT(float,TRY_CONVERT(int,ConfigValue))
 AND TRY_CONVERT(int,ConfigValue)<=?) ORDER BY ConfigKey"""
REPORT_HEADER_SQL = """SELECT KVK_NO,FinalScanOrder,OutputRowCount,Revision,State,
FinalizationBasis,FinalDataAtUtc FROM dbo.KVKFinalReportHeader WHERE KVK_NO=?"""
REPORT_DATE_SQL = """SELECT COUNT_BIG(*) AS scan_rows,
MIN(CONVERT(datetime2(0),ScanDate)) AS first_date,
MAX(CONVERT(datetime2(0),ScanDate)) AS last_date
FROM dbo.KingdomScanData4 WHERE SCANORDER=?"""
REPORT_VALUE_SQL = """SELECT COUNT_BIG(*) AS rows_count,
LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',
(SELECT s.* FROM dbo.STATS_FOR_UPLOAD s ORDER BY s.Gov_ID
 FOR JSON PATH,INCLUDE_NULL_VALUES)),2)) AS rows_sha256
FROM dbo.STATS_FOR_UPLOAD"""
REPORT_COUNT_SQL = """SELECT COUNT_BIG(*) AS report_rows,
MIN(LAST_REFRESH) AS first_refresh,MAX(LAST_REFRESH) AS last_refresh
FROM dbo.STATS_FOR_UPLOAD"""


def require_prior(value):
    if (
        value.get("outcome") != "passed"
        or value.get("first_failure") is not None
        or value.get("cleanup_failures")
        or value.get("check_failures")
        or value.get("before") != value.get("after")
        or value.get("master_before") != value.get("master_after")
        or value.get("owners_before") != value.get("owners_after")
        or value.get("login_disabled") is not True
        or value.get("admin_connections_closed") != 1
        or value.get("configured_reader", {}).get("complete_parity_passed") is not True
        or value.get("windows", {}).get("child_settled") is not True
    ):
        raise ValueError("Exact completed native boundary and settled ownership required")


def capture_configuration(packet, manifest):
    """Fresh non-provider registration; preserve every actual reviewed export job."""
    jobs = json.loads((packet / "bot/config/sheet_config.json").read_bytes())
    titles = sorted({j["sheet"] for j in jobs})
    prefix = manifest["account"].replace(":", "_")
    sheets = {title: prefix + "_output_" + str(i) for i, title in enumerate(titles)}
    config = {
        "scan_data": dict(
            consumer="scan_data",
            destinations=sorted(sheets.values()),
            spreadsheets=sheets,
            exports=jobs,
        ),
        "all_kvk": dict(
            consumer="all_kvk",
            kvk_no=16,
            destinations=[prefix + "_unused_kvk"],
            spreadsheets={"P02 unused KVK scope": prefix + "_unused_kvk"},
            primary_sheet="P02 unused KVK scope",
        ),
        "config": dict(consumer="config", destinations=[prefix + "_unused_configuration"]),
    }
    from services.export_runtime_composition import validate_capture_configuration

    validate_capture_configuration(config, jobs)
    return config


def count_sql(statement):
    # Source jobs are sealed and additionally restricted before interpolation.
    match = re.fullmatch(
        r"SELECT (?:\*|\[GovernorID\], LTRIM\(RTRIM\(\[GovernorName\]\)\) AS GovernorName) FROM "
        r"(?P<source>(?:\[?ROK_TRACKER\]?\.)?(?:\[?dbo\]?\.)?\[?[A-Za-z_][A-Za-z0-9_]*\]?)",
        statement,
    )
    if not match:
        raise ValueError("Unexpected reviewed capture query shape")
    return "SELECT COUNT_BIG(*) AS rows_to_capture FROM " + match["source"]


def preflight(connection, packet, manifest, prior):
    from independent_readers import query
    from release_boundary import owner_inventory

    owners = owner_inventory(connection)
    if owners != prior["owners_after"]:
        raise ValueError("Retained producer ownership changed")
    resource = owners["resource"]
    if (
        len(resource) != 1
        or owners["active_preparation"]
        or any(
            resource[0][k] is not None
            for k in ("ActiveJobID", "ActivePreparationID", "ActiveOutputOperationID", "OwnerID")
        )
        or resource[0]["blocked"]
    ):
        raise ValueError("Existing global output owner must not be reclaimed")
    if query(connection, FRESH_ACCOUNT, manifest["account"]):
        raise ValueError("Fresh qualification account already has work")
    resources = query(connection, RESOURCE_SQL, "account:" + manifest["account"])
    if len(resources) != 1:
        raise ValueError("Fresh account resource already exists")
    configuration = capture_configuration(packet, manifest)
    counts = []
    for export in configuration["scan_data"]["exports"]:
        rows = query(connection, count_sql(export["query"]))
        if len(rows) != 1 or not 0 <= rows[0]["rows_to_capture"] <= 100000:
            raise ValueError("Reviewed capture exceeds this finite lab case")
        counts.append(dict(query=export["query"], rows=rows[0]["rows_to_capture"]))
    if sum(r["rows"] for r in counts) > 250000:
        raise ValueError("Combined capture exceeds this finite lab case")
    latest = query(connection, REPORT_SOURCE_SQL)
    if len(latest) != 1 or type(latest[0]["max_scan"]) is not int:
        raise ValueError("Genuine report source scan required")
    config = query(connection, REPORT_CONFIG_SQL, latest[0]["max_scan"])
    if not config:
        raise ValueError("Genuine report configuration required")
    season = config[0]["KVKVersion"]
    header = query(connection, REPORT_HEADER_SQL, season)
    values = {r["ConfigKey"]: r["ConfigValue"] for r in config}
    end = values.get("KVK_END_SCAN")
    if (
        type(season) is not int
        or not 1 <= season <= 2147483647
        or type(end) not in (int, float)
        or not 0 < end <= 2147483647
        or int(end) != end
        or len(header) != 1
        or header[0]["State"] != "OUTPUT_COMPLETE"
        or header[0]["Revision"] <= 0
        or not 0 < header[0]["OutputRowCount"] <= 100000
        or header[0]["FinalScanOrder"] != min(latest[0]["max_scan"], int(end))
    ):
        raise ValueError("Genuine current report header/configuration required")
    dates = query(connection, REPORT_DATE_SQL, header[0]["FinalScanOrder"])
    if (
        len(dates) != 1
        or dates[0]["scan_rows"] <= 0
        or dates[0]["first_date"] is None
        or dates[0]["first_date"] != dates[0]["last_date"]
    ):
        raise ValueError("Genuine consistent source scan date required")
    shape = query(connection, source_shape_sql(season), season)
    if (
        len(shape) != 1
        or shape[0]["source_rows"] != header[0]["OutputRowCount"]
        or shape[0]["distinct_governors"] != shape[0]["source_rows"]
        or shape[0]["invalid_governors"]
        or shape[0]["wrong_kvk"]
    ):
        raise ValueError("Genuine report input shape differs from its publication header")
    return dict(
        owners=owners,
        configuration=configuration,
        capture_counts=counts,
        source=latest,
        config=config,
        header=header,
        dates=dates,
        source_shape=shape,
        original_preparations=query(
            connection, ORIGINAL_PREPARATIONS, manifest["account"], manifest["account"]
        ),
        original_report=query(connection, REPORT_COUNT_SQL),
    )


def create_snapshot(connection, manifest):
    from independent_readers import query

    stamp = Path(manifest["guest_directory"]).name
    if not re.fullmatch(r"[0-9]{17}", stamp):
        raise ValueError("Exact fixture stamp required")
    name = "K98_P02Capture_" + stamp
    path = str(Path(manifest["guest_directory"]) / "baseline.ss")
    if manifest["snapshot"] != dict(name=name, path=path):
        raise ValueError("Exact fresh recovery snapshot binding required")
    rows = query(connection, SNAPSHOT_SQL, name, path)
    if (
        len(rows) != 1
        or rows[0]["name"] != name
        or rows[0]["source_database_id"] != 16
        or rows[0]["state_desc"] != "ONLINE"
        or rows[0]["is_read_only"] is not True
    ):
        raise ValueError("Fresh recovery snapshot acknowledgement differs")
    return rows[0]


def source_shape_sql(season):
    if type(season) is not int or not 1 <= season <= 2147483647:
        raise ValueError("Exact positive SQL season required")
    return """SELECT COUNT_BIG(*) AS source_rows,
COUNT_BIG(DISTINCT TRY_CONVERT(bigint,Gov_ID)) AS distinct_governors,
COALESCE(SUM(CONVERT(bigint,CASE WHEN TRY_CONVERT(bigint,Gov_ID) IS NULL
 OR TRY_CONVERT(bigint,Gov_ID)<=0 THEN 1 ELSE 0 END)),0) AS invalid_governors,
COALESCE(SUM(CONVERT(bigint,CASE WHEN TRY_CONVERT(int,KVK_NO)<>?
 OR KVK_NO IS NULL THEN 1 ELSE 0 END)),0) AS wrong_kvk
FROM dbo.[EXCEL_FOR_KVK_""" + str(season) + "]"
