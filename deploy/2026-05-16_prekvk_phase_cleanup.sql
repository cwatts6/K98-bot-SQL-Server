:ON ERROR EXIT

PRINT 'Deploying PreKvK Phase 2B compatibility wrappers and ranking alignment...';

:r sql_schema\dbo.fn_PreKvkPhaseDelta.UserDefinedFunction.sql
:r sql_schema\dbo.v_PreKvk13_Phase1.View.sql
:r sql_schema\dbo.v_PreKvk13_Phase2.View.sql
:r sql_schema\dbo.v_PreKvk13_Phase3.View.sql
:r sql_schema\dbo.sp_Build_Prekvk_And_Honor_Rankings.StoredProcedure.sql

PRINT 'Verifying PreKvK legacy phase objects no longer depend on dbo.PreKvk_Phases...';

IF EXISTS (
    SELECT 1
    FROM sys.sql_expression_dependencies d
    WHERE OBJECT_NAME(d.referencing_id) IN (
        'fn_PreKvkPhaseDelta',
        'v_PreKvk13_Phase1',
        'v_PreKvk13_Phase2',
        'v_PreKvk13_Phase3'
    )
      AND referenced_entity_name = 'PreKvk_Phases'
)
BEGIN
    SELECT
        referencing_schema_name = OBJECT_SCHEMA_NAME(d.referencing_id),
        referencing_object_name = OBJECT_NAME(d.referencing_id),
        referenced_schema_name,
        referenced_entity_name
    FROM sys.sql_expression_dependencies d
    WHERE OBJECT_NAME(d.referencing_id) IN (
        'fn_PreKvkPhaseDelta',
        'v_PreKvk13_Phase1',
        'v_PreKvk13_Phase2',
        'v_PreKvk13_Phase3'
    )
      AND referenced_entity_name = 'PreKvk_Phases';

    THROW 51000, 'PreKvK Phase 2B deploy failed: legacy phase objects still reference dbo.PreKvk_Phases.', 1;
END

PRINT 'PreKvK Phase 2B deployment script completed.';
