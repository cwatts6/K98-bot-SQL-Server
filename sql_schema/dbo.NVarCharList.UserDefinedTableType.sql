IF NOT EXISTS (SELECT * FROM sys.types st JOIN sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = N'NVarCharList' AND ss.name = N'dbo')
CREATE TYPE [dbo].[NVarCharList] AS TABLE(
	[Value] [nvarchar](50) COLLATE Latin1_General_CI_AS NOT NULL
)
