SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (
    SELECT *
    FROM sys.types
    WHERE is_table_type = 1
      AND name = N'IntList'
      AND SCHEMA_NAME(schema_id) = N'dbo'
)
CREATE TYPE [dbo].[IntList] AS TABLE(
    [ID] [int] NOT NULL,
    PRIMARY KEY CLUSTERED ([ID] ASC)
)

