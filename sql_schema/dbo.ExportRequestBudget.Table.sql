SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10A reference snapshot. Deploy the reviewed migration, not this file.
-- Static shape only: authorized later DAL owns CAS, transitions, immutable inputs,
-- fairness, resource acquisition/release and provider evidence validation.
-- For snapshot reconstruction create all six tables before adding the ownership FKs.
CREATE TABLE dbo.ExportRequestBudget
(
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    BudgetKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    NextAllowedUTC datetime2(3) NOT NULL,
    CooldownUntilUTC datetime2(3) NULL,
    IntervalMilliseconds int NOT NULL,
    PolicyVersion bigint NOT NULL,
    Version bigint NOT NULL,
    CONSTRAINT PK_ExportRequestBudget PRIMARY KEY (AccountKey, BudgetKind),
    CONSTRAINT CK_ExportRequestBudget_Account CHECK (LEN(AccountKey) > 0 AND DATALENGTH(AccountKey) = DATALENGTH(LTRIM(RTRIM(AccountKey)))),
    CONSTRAINT CK_ExportRequestBudget_Kind CHECK (BudgetKind = 'google_request' AND DATALENGTH(BudgetKind) = 14),
    CONSTRAINT CK_ExportRequestBudget_Policy CHECK (IntervalMilliseconds BETWEEN 1 AND 86400000 AND PolicyVersion > 0 AND Version > 0)
);
