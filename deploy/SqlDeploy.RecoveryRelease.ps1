# Exact reviewed recovery chain, executed under the module runner's transaction.
# This is a coordinated profile, never selected by discovering pending SQL files.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Assert-K98RecoveryPrincipal($Connection,$Transaction) {
    # The coordinated release has one application identity. Neither the profile
    # nor a caller can choose a beneficiary or broaden the permission delta.
    $null=Invoke-K98ModuleQuery $Connection $Transaction @'
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name=N'S11_ExportApplication' AND type IN ('S','U'))
 OR ISNULL(IS_ROLEMEMBER(N'ExportExecutionAuthority',N'S11_ExportApplication'),0)<>1
 OR ISNULL(IS_ROLEMEMBER(N'ExportLegacyEntryReader',N'S11_ExportApplication'),0)<>1
 OR ISNULL(IS_ROLEMEMBER(N'ExportExecutionReader',N'S11_ExportApplication'),1)<>0
 OR ISNULL(IS_ROLEMEMBER(N'db_owner',N'S11_ExportApplication'),1)<>0
 THROW 51951,'Reviewed recovery application principal and roles required.',1;
'@
}

function Get-K98RecoveryApplicationGrants {
    # Exact 22 additions from the reviewed bot grant plan. All objects are new in
    # this chain; existing grants/roles are preserved and checked by image pins.
    return @'
GRANT SELECT ON OBJECT::dbo.ExportContainedStream TO [S11_ExportApplication];
GRANT SELECT ON OBJECT::dbo.ExportContainedTarget TO [S11_ExportApplication];
GRANT SELECT ON OBJECT::dbo.ExportReplacementActivation TO [S11_ExportApplication];
GRANT INSERT,SELECT ON OBJECT::dbo.ExportReplacementDelivery TO [S11_ExportApplication];
GRANT SELECT ON OBJECT::dbo.ExportReplacementPlan TO [S11_ExportApplication];
GRANT SELECT ON OBJECT::dbo.ExportReplacementTarget TO [S11_ExportApplication];
GRANT SELECT ON OBJECT::dbo.ExportReplacementVerification TO [S11_ExportApplication];
GRANT SELECT ON OBJECT::dbo.ExportTargetContainment TO [S11_ExportApplication];
GRANT SELECT,INSERT,UPDATE ON OBJECT::dbo.RecoveryAction TO [S11_ExportApplication];
GRANT SELECT,INSERT,UPDATE ON OBJECT::dbo.RecoveryIncident TO [S11_ExportApplication];
GRANT SELECT,INSERT,UPDATE ON OBJECT::dbo.RecoveryInputDraft TO [S11_ExportApplication];
GRANT EXECUTE ON OBJECT::dbo.usp_ExportJobContainTargets TO [S11_ExportApplication];
GRANT EXECUTE ON OBJECT::dbo.usp_ExportReplacementActivate TO [S11_ExportApplication];
GRANT EXECUTE ON OBJECT::dbo.usp_ExportReplacementPlanCreate TO [S11_ExportApplication];
GRANT EXECUTE ON OBJECT::dbo.usp_ExportReplacementVerificationTransition TO [S11_ExportApplication];
'@
}

function Get-K98RecoveryImage($Connection,$Transaction,[string]$Name) {
    # Stable names replace object/principal IDs. Runtime rows, identity counters,
    # physical allocation and statistics are deliberately not schema evidence.
    $rows=Invoke-K98ModuleQuery $Connection $Transaction @'
DECLARE @id int=OBJECT_ID(@name);
IF @id IS NULL BEGIN SELECT N'absent' AS image; RETURN; END;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 OR EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@id)
 OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@id)
 OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@id AND (user_type_id<>system_type_id OR encryption_type IS NOT NULL))
 OR EXISTS(SELECT 1 FROM sys.masked_columns WHERE object_id=@id AND is_masked=1)
 THROW 51951,'Unsupported recovery object security contract.',1;
DECLARE @body nvarchar(max)=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER PROCEDURE%' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN @body LIKE N'CREATE   PROCEDURE%' THEN STUFF(@body,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN @body LIKE N'ALTER PROCEDURE%' THEN STUFF(@body,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @body END;
SELECT (SELECT o.type,USER_NAME(o.principal_id) AS owner,@body AS definition,
 (SELECT uses_ansi_nulls,uses_quoted_identifier,is_schema_bound,execute_as_principal_id FROM sys.sql_modules WHERE object_id=@id FOR JSON PATH) AS module_json,
 (SELECT temporal_type,is_memory_optimized,durability,lock_escalation,is_filetable FROM sys.tables WHERE object_id=@id FOR JSON PATH) AS table_json,
 (SELECT c.column_id,c.name,c.system_type_id,c.max_length,c.precision,c.scale,c.collation_name,c.is_nullable,c.is_identity,c.is_computed,c.is_rowguidcol,c.is_sparse,c.generated_always_type,c.is_filestream,
 d.name AS default_name,d.definition AS default_definition,cc.definition AS computed_definition,cc.is_persisted,
 CONVERT(nvarchar(128),ic.seed_value) AS identity_seed,CONVERT(nvarchar(128),ic.increment_value) AS identity_increment
 FROM sys.columns c LEFT JOIN sys.default_constraints d ON d.object_id=c.default_object_id
 LEFT JOIN sys.computed_columns cc ON cc.object_id=c.object_id AND cc.column_id=c.column_id
 LEFT JOIN sys.identity_columns ic ON ic.object_id=c.object_id AND ic.column_id=c.column_id
 WHERE c.object_id=@id ORDER BY c.column_id FOR JSON PATH) AS columns_json,
 (SELECT i.name,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.ignore_dup_key,i.has_filter,i.filter_definition,i.is_hypothetical,
 (SELECT c.name,ic.index_column_id,ic.key_ordinal,ic.is_descending_key,ic.is_included_column FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) AS keys_json
 FROM sys.indexes i WHERE i.object_id=@id ORDER BY i.name COLLATE Latin1_General_100_BIN2 FOR JSON PATH) AS indexes_json,
 (SELECT name,definition,is_disabled,is_not_trusted,is_not_for_replication FROM sys.check_constraints WHERE parent_object_id=@id ORDER BY name COLLATE Latin1_General_100_BIN2 FOR JSON PATH) AS checks_json,
 (SELECT f.name,f.is_disabled,f.is_not_trusted,f.is_not_for_replication,f.delete_referential_action,f.update_referential_action,
 (SELECT fc.constraint_column_id,pc.name AS parent_column,SCHEMA_NAME(ro.schema_id) AS target_schema,ro.name AS target_table,rc.name AS target_column
 FROM sys.foreign_key_columns fc JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id JOIN sys.objects ro ON ro.object_id=fc.referenced_object_id JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id WHERE fc.constraint_object_id=f.object_id ORDER BY fc.constraint_column_id FOR JSON PATH) AS columns_json
 FROM sys.foreign_keys f WHERE f.parent_object_id=@id ORDER BY f.name COLLATE Latin1_General_100_BIN2 FOR JSON PATH) AS foreign_keys_json,
 (SELECT USER_NAME(grantee_principal_id) AS grantee,USER_NAME(grantor_principal_id) AS grantor,minor_id,type,state FROM sys.database_permissions WHERE class=1 AND major_id=@id ORDER BY USER_NAME(grantee_principal_id) COLLATE Latin1_General_100_BIN2,USER_NAME(grantor_principal_id) COLLATE Latin1_General_100_BIN2,minor_id,type,state FOR JSON PATH) AS permissions_json
 FROM sys.objects o WHERE o.object_id=@id FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS image;
'@ @{name=$Name}
    if($rows.Count -ne 1 -or [string]::IsNullOrEmpty($rows[0].image)){throw ('Missing recovery metadata: '+$Name)}
    return Get-K98ModuleHash ([Text.Encoding]::UTF8.GetBytes($rows[0].image))
}

function Read-K98RecoveryProfile($Profile,[string]$Path) {
    Assert-K98ModuleFields $Profile @('version','profile','migration_id','database_collation','tempdb_collation','compatibility_level','requires','scripts','images')
    if($Profile.version -ne 1 -or $Profile.migration_id -cne '20261016_003_guided_recovery_release' -or $Profile.profile -cne 'coordinated_recovery_v1'){throw 'Exact coordinated recovery profile required'}
    if($Profile.database_collation -cnotmatch '^[A-Za-z0-9_]{1,128}$' -or $Profile.tempdb_collation -cnotmatch '^[A-Za-z0-9_]{1,128}$' -or $Profile.compatibility_level -notin @(130,140,150,160)){throw 'Exact SQL environment required'}
    $ids=@('20261015_001_failed_read_history','20261015_002_guided_recovery','20261015_003_read_prefix_history','20261015_004_failed_publication_probe','20261015_005_read_prefix_closure','20261015_006_failed_probe_request_events','20261015_007_read_dispatch_containment','20261015_008_export_target_containment','20261015_009_guided_export_replacement','20261015_010_configuration_replacement','20261016_001_rollover_replacement','20261016_002_atomic_configuration_publication')
    if(@($Profile.scripts).Count -ne $ids.Count -or @($Profile.images).Count -ne 26 -or @($Profile.requires).Count -gt 64){throw 'Complete bounded recovery chain required'}
    $texts=[Collections.Generic.List[string]]::new()
    for($n=0;$n -lt $ids.Count;$n++) {
        $s=$Profile.scripts[$n]
        Assert-K98ModuleFields $s @('id','sha256')
        if($s.id -cne $ids[$n] -or $s.sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'Recovery migration order/checksum differs'}
        $file=Join-Path (Split-Path -Parent $Path) ($s.id+'.sql')
        $item=Get-Item -LiteralPath $file -Force
        if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -gt 2MB){throw 'Unsupported recovery migration file'}
        $raw=[IO.File]::ReadAllBytes($file)
        if((Get-K98ModuleHash $raw) -cne $s.sha256){throw ('Recovery migration checksum differs: '+$s.id)}
        $text=[Text.UTF8Encoding]::new($false,$true).GetString($raw).TrimStart([char]0xfeff).Replace("`r`n","`n")
        if($text -match '(?im)^\s*(GO(?:\s|$)|USE\s|:)'){throw 'Single-database single-batch migration required'}
        if($n -ne 1) {
            # Remove only these unique outer boundaries, after authenticating the
            # complete reviewed source. Stored-procedure transaction bodies stay
            # byte-for-byte intact. No general SQL transaction rewriting occurs.
            $begin="(?m)^IF @@TRANCOUNT<>0 THROW [0-9]{5},'Own migration transaction required\.',1;\nBEGIN TRANSACTION;\nBEGIN TRY\n"
            $end="`nCOMMIT;`nEND TRY`nBEGIN CATCH`n"
            if([regex]::Matches($text,$begin).Count -ne 1 -or ($text.Split(@($end),[StringSplitOptions]::None).Count - 1) -ne 1){throw 'Reviewed outer transaction boundary differs'}
            $text=[regex]::Replace($text,$begin,"IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 51951,'Recovery outer transaction required.',1;`nBEGIN TRY`n")
            $text=$text.Replace($end,"`nIF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 51951,'Recovery transaction escaped.',1;`nEND TRY`nBEGIN CATCH`n")
        }
        $texts.Add($text)
    }
    $seen=@{}
    foreach($i in $Profile.images) {
        Assert-K98ModuleFields $i @('name','before','after')
        if($i.name -cnotmatch '^(dbo|KVK)\.[A-Za-z_][A-Za-z0-9_]{0,127}$' -or $seen.ContainsKey($i.name) -or $i.before -cnotmatch '^[a-f0-9]{64}$' -or $i.after -cnotmatch '^[a-f0-9]{64}$'){throw 'Unique pinned recovery images required'}
        $seen[$i.name]=$true
    }
    $objects=@('KVK.SourceOutputPool','dbo.ExportContainedStream','dbo.ExportContainedTarget','dbo.ExportExecutionStream','dbo.ExportPreparation','dbo.ExportReplacementActivation','dbo.ExportReplacementDelivery','dbo.ExportReplacementPlan','dbo.ExportReplacementTarget','dbo.ExportReplacementVerification','dbo.ExportTargetContainment','dbo.RecoveryAction','dbo.RecoveryIncident','dbo.RecoveryInputDraft','dbo.sp_TARGETS_MASTER','dbo.usp_ExportExecutionSessionTransition','dbo.usp_ExportExecutionStreamTransition','dbo.usp_ExportJobContainTargets','dbo.usp_ExportManualOutputEnrollmentTransition','dbo.usp_ExportOutputEnrollmentTransition','dbo.usp_ExportProviderRequestEventAppend','dbo.usp_ExportReconciliationProofIssue','dbo.usp_ExportReplacementActivate','dbo.usp_ExportReplacementPlanCreate','dbo.usp_ExportReplacementVerificationTransition','dbo.usp_ExportRolloverContainTargets')
    if((@($seen.Keys|Sort-Object) -join ',') -cne (@($objects|Sort-Object) -join ',')){throw 'Complete exact recovery object inventory required'}
    foreach($r in $Profile.requires) {
        Assert-K98ModuleFields $r @('migration_id','sha256','status')
        if($r.migration_id -cnotmatch '^[0-9]{8}_[0-9]{3}_[A-Za-z0-9_]+$' -or $r.sha256 -cnotmatch '^[a-f0-9]{64}$' -or $r.status -cnotin @('Applied','Failed')){throw 'Exact predecessor history required'}
    }
    return @{Profile=$Profile;Texts=$texts.ToArray()}
}

function Assert-K98RecoveryImages($Connection,$Transaction,$Loaded,[bool]$After) {
    Assert-K98RecoveryPrincipal $Connection $Transaction
    foreach($i in $Loaded.Profile.images) {
        $expected=if($After){$i.after}else{$i.before}
        if((Get-K98RecoveryImage $Connection $Transaction $i.name) -cne $expected){throw ('Recovery '+$(if($After){'postimage'}else{'preimage'})+' differs: '+$i.name)}
    }
}

function Assert-K98RecoveryHistory($Connection,$Transaction,$Loaded,[string]$Commit,$Attempt,[bool]$After) {
    foreach($s in $Loaded.Profile.scripts) {
        $rows=Invoke-K98ModuleQuery $Connection $Transaction 'SELECT Status,ChecksumSha256,GitCommit,DeploymentId,BranchName,MigrationFile FROM dbo.SchemaMigrationHistory WHERE MigrationId=@id;' @{id=$s.id}
        if(-not $After) {
            if($rows.Count){throw ('Recovery child history already exists: '+$s.id)}
        }elseif($rows.Count -ne 1 -or $rows[0].Status -cne 'Applied' -or $rows[0].ChecksumSha256 -cne $s.sha256 -or $rows[0].GitCommit -cne $Commit -or [string]$rows[0].DeploymentId -cne [string]$Attempt -or $rows[0].BranchName -cne $Loaded.Profile.profile -or $rows[0].MigrationFile -cne ($s.id+'.sql')){throw ('Recovery child receipt differs: '+$s.id)}
    }
}

function Invoke-K98RecoveryChain($Connection,$Transaction,$Loaded,[string]$Commit,[string]$Attempt) {
    Assert-K98RecoveryPrincipal $Connection $Transaction
    Assert-K98RecoveryHistory $Connection $Transaction $Loaded $Commit $Attempt $false
    for($n=0;$n -lt $Loaded.Texts.Count;$n++) {
        # Parameterized sp_executesql isolates migration-local variables/temp
        # tables while sharing the single SqlClient-owned transaction.
        $null=Invoke-K98ModuleQuery $Connection $Transaction 'EXEC sys.sp_executesql @body; IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 51951,''Recovery transaction escaped.'',1;' @{body=$Loaded.Texts[$n]}
        $s=$Loaded.Profile.scripts[$n]
        $null=Invoke-K98ModuleQuery $Connection $Transaction @'
INSERT dbo.SchemaMigrationHistory(MigrationId,MigrationFile,ChecksumSha256,AppliedAtUtc,AppliedBy,MachineName,GitCommit,BranchName,DeploymentId,Status,DurationMs)
VALUES(@id,@file,@hash,SYSUTCDATETIME(),ORIGINAL_LOGIN(),HOST_NAME(),@commit,@profile,@attempt,N'Applied',0);
'@ @{id=$s.id;file=($s.id+'.sql');hash=$s.sha256;commit=$Commit;profile=$Loaded.Profile.profile;attempt=$Attempt}
    }
    $null=Invoke-K98ModuleQuery $Connection $Transaction (Get-K98RecoveryApplicationGrants)
}
