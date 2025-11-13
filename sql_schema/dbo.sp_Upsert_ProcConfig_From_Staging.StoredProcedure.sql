SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Upsert_ProcConfig_From_Staging]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Upsert_ProcConfig_From_Staging] AS' 
END
ALTER PROCEDURE [dbo].[sp_Upsert_ProcConfig_From_Staging]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    --------------------
    -- LASTKVKEND
    --------------------
    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'LASTKVKEND', CAST(LASTKVKEND AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE LASTKVKEND IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN MATCHED AND ISNULL(target.ConfigValue, '') <> ISNULL(source.ConfigValue, '')
        THEN UPDATE SET ConfigValue = source.ConfigValue, LastUpdated = GETDATE()
    OUTPUT 'UPDATE', inserted.KVKVersion, inserted.ConfigKey, deleted.ConfigValue, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'LASTKVKEND', CAST(LASTKVKEND AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE LASTKVKEND IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (KVKVersion, ConfigKey, ConfigValue, LastUpdated)
             VALUES (source.KVKVersion, source.ConfigKey, source.ConfigValue, GETDATE())
    OUTPUT 'INSERT', inserted.KVKVersion, inserted.ConfigKey, NULL, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

	--------------------
	-- DRAFTSCAN
	--------------------
	MERGE ProcConfig AS target
	USING (
		SELECT KVK_NO, 'DRAFTSCAN', CAST(DRAFTSCAN AS VARCHAR(20))
		FROM dbo.ProcConfig_Staging
		WHERE DRAFTSCAN IS NOT NULL
	) AS source (KVKVersion, ConfigKey, ConfigValue)
	ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
	WHEN MATCHED AND ISNULL(target.ConfigValue, '') <> ISNULL(source.ConfigValue, '')
		THEN UPDATE SET ConfigValue = source.ConfigValue, LastUpdated = GETDATE()
	OUTPUT 'UPDATE', inserted.KVKVersion, inserted.ConfigKey, deleted.ConfigValue, inserted.ConfigValue
	INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

	MERGE ProcConfig AS target
	USING (
		SELECT KVK_NO, 'DRAFTSCAN', CAST(DRAFTSCAN AS VARCHAR(20))
		FROM dbo.ProcConfig_Staging
		WHERE DRAFTSCAN IS NOT NULL
	) AS source (KVKVersion, ConfigKey, ConfigValue)
	ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
	WHEN NOT MATCHED BY TARGET
		THEN INSERT (KVKVersion, ConfigKey, ConfigValue, LastUpdated)
			 VALUES (source.KVKVersion, source.ConfigKey, source.ConfigValue, GETDATE())
	OUTPUT 'INSERT', inserted.KVKVersion, inserted.ConfigKey, NULL, inserted.ConfigValue
	INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);


    --------------------
    -- MATCHMAKING_SCAN
    --------------------
    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'MATCHMAKING_SCAN', CAST(MATCHMAKING_SCAN AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE MATCHMAKING_SCAN IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN MATCHED AND ISNULL(target.ConfigValue, '') <> ISNULL(source.ConfigValue, '')
        THEN UPDATE SET ConfigValue = source.ConfigValue, LastUpdated = GETDATE()
    OUTPUT 'UPDATE', inserted.KVKVersion, inserted.ConfigKey, deleted.ConfigValue, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'MATCHMAKING_SCAN', CAST(MATCHMAKING_SCAN AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE MATCHMAKING_SCAN IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (KVKVersion, ConfigKey, ConfigValue, LastUpdated)
             VALUES (source.KVKVersion, source.ConfigKey, source.ConfigValue, GETDATE())
    OUTPUT 'INSERT', inserted.KVKVersion, inserted.ConfigKey, NULL, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    --------------------
    -- PRE_PASS_4_SCAN
    --------------------
    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'PRE_PASS_4_SCAN', CAST(PRE_PASS_4_SCAN AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE PRE_PASS_4_SCAN IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN MATCHED AND ISNULL(target.ConfigValue, '') <> ISNULL(source.ConfigValue, '')
        THEN UPDATE SET ConfigValue = source.ConfigValue, LastUpdated = GETDATE()
    OUTPUT 'UPDATE', inserted.KVKVersion, inserted.ConfigKey, deleted.ConfigValue, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'PRE_PASS_4_SCAN', CAST(PRE_PASS_4_SCAN AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE PRE_PASS_4_SCAN IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (KVKVersion, ConfigKey, ConfigValue, LastUpdated)
             VALUES (source.KVKVersion, source.ConfigKey, source.ConfigValue, GETDATE())
    OUTPUT 'INSERT', inserted.KVKVersion, inserted.ConfigKey, NULL, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    --------------------
    -- PASS4END
    --------------------
    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'PASS4END', CAST(PASS4END AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE PASS4END IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN MATCHED AND ISNULL(target.ConfigValue, '') <> ISNULL(source.ConfigValue, '')
        THEN UPDATE SET ConfigValue = source.ConfigValue, LastUpdated = GETDATE()
    OUTPUT 'UPDATE', inserted.KVKVersion, inserted.ConfigKey, deleted.ConfigValue, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'PASS4END', CAST(PASS4END AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE PASS4END IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (KVKVersion, ConfigKey, ConfigValue, LastUpdated)
             VALUES (source.KVKVersion, source.ConfigKey, source.ConfigValue, GETDATE())
    OUTPUT 'INSERT', inserted.KVKVersion, inserted.ConfigKey, NULL, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    --------------------
    -- PASS6END
    --------------------
    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'PASS6END', CAST(PASS6END AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE PASS6END IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN MATCHED AND ISNULL(target.ConfigValue, '') <> ISNULL(source.ConfigValue, '')
        THEN UPDATE SET ConfigValue = source.ConfigValue, LastUpdated = GETDATE()
    OUTPUT 'UPDATE', inserted.KVKVersion, inserted.ConfigKey, deleted.ConfigValue, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'PASS6END', CAST(PASS6END AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE PASS6END IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (KVKVersion, ConfigKey, ConfigValue, LastUpdated)
             VALUES (source.KVKVersion, source.ConfigKey, source.ConfigValue, GETDATE())
    OUTPUT 'INSERT', inserted.KVKVersion, inserted.ConfigKey, NULL, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    --------------------
    -- PASS7END
    --------------------
    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'PASS7END', CAST(PASS7END AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE PASS7END IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN MATCHED AND ISNULL(target.ConfigValue, '') <> ISNULL(source.ConfigValue, '')
        THEN UPDATE SET ConfigValue = source.ConfigValue, LastUpdated = GETDATE()
    OUTPUT 'UPDATE', inserted.KVKVersion, inserted.ConfigKey, deleted.ConfigValue, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'PASS7END', CAST(PASS7END AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE PASS7END IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (KVKVersion, ConfigKey, ConfigValue, LastUpdated)
             VALUES (source.KVKVersion, source.ConfigKey, source.ConfigValue, GETDATE())
    OUTPUT 'INSERT', inserted.KVKVersion, inserted.ConfigKey, NULL, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    --------------------
    -- KVK_END_SCAN
    --------------------
    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'KVK_END_SCAN', CAST(KVK_END_SCAN AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE KVK_END_SCAN IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN MATCHED AND ISNULL(target.ConfigValue, '') <> ISNULL(source.ConfigValue, '')
        THEN UPDATE SET ConfigValue = source.ConfigValue, LastUpdated = GETDATE()
    OUTPUT 'UPDATE', inserted.KVKVersion, inserted.ConfigKey, deleted.ConfigValue, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'KVK_END_SCAN', CAST(KVK_END_SCAN AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE KVK_END_SCAN IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (KVKVersion, ConfigKey, ConfigValue, LastUpdated)
             VALUES (source.KVKVersion, source.ConfigKey, source.ConfigValue, GETDATE())
    OUTPUT 'INSERT', inserted.KVKVersion, inserted.ConfigKey, NULL, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    --------------------
    -- CURRENTKVK3
    --------------------
    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'CURRENTKVK3', CAST(CURRENTKVK3 AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE CURRENTKVK3 IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN MATCHED AND ISNULL(target.ConfigValue, '') <> ISNULL(source.ConfigValue, '')
        THEN UPDATE SET ConfigValue = source.ConfigValue, LastUpdated = GETDATE()
    OUTPUT 'UPDATE', inserted.KVKVersion, inserted.ConfigKey, deleted.ConfigValue, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

    MERGE ProcConfig AS target
    USING (
        SELECT KVK_NO, 'CURRENTKVK3', CAST(CURRENTKVK3 AS VARCHAR(20))
        FROM dbo.ProcConfig_Staging
        WHERE CURRENTKVK3 IS NOT NULL
    ) AS source (KVKVersion, ConfigKey, ConfigValue)
    ON target.KVKVersion = source.KVKVersion AND target.ConfigKey = source.ConfigKey
    WHEN NOT MATCHED BY TARGET
        THEN INSERT (KVKVersion, ConfigKey, ConfigValue, LastUpdated)
             VALUES (source.KVKVersion, source.ConfigKey, source.ConfigValue, GETDATE())
    OUTPUT 'INSERT', inserted.KVKVersion, inserted.ConfigKey, NULL, inserted.ConfigValue
    INTO dbo.ProcConfig_AuditLog (OperationType, KVKVersion, ConfigKey, OldValue, NewValue);

END;

