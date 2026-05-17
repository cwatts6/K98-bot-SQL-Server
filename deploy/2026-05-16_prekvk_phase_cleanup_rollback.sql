:ON ERROR EXIT

PRINT 'Rolling back PreKvK Phase 2B compatibility wrappers and ranking alignment...';

:r deploy\rollback\2026-05-16_prekvk_phase_cleanup\dbo.fn_PreKvkPhaseDelta.UserDefinedFunction.sql
:r deploy\rollback\2026-05-16_prekvk_phase_cleanup\dbo.v_PreKvk13_Phase1.View.sql
:r deploy\rollback\2026-05-16_prekvk_phase_cleanup\dbo.v_PreKvk13_Phase2.View.sql
:r deploy\rollback\2026-05-16_prekvk_phase_cleanup\dbo.v_PreKvk13_Phase3.View.sql
:r deploy\rollback\2026-05-16_prekvk_phase_cleanup\dbo.sp_Build_Prekvk_And_Honor_Rankings.StoredProcedure.sql

PRINT 'PreKvK Phase 2B rollback script completed.';
