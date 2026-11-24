-- Author: K98 programme. Candidate protocol; install only in the isolated lab.
CREATE SEQUENCE dbo.P02ObservationGeneration AS bigint
    START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807
    NO CYCLE NO CACHE;
GO
-- Consume the never-used starting value before an observer can be admitted.
DECLARE @bootstrap bigint=NEXT VALUE FOR dbo.P02ObservationGeneration;
IF @bootstrap<>1 THROW 51970,'Unexpected observation sequence bootstrap.',1;
GO
