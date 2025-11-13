SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HoH_Deads]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[HoH_Deads](
	[GovernorID] [float] NOT NULL,
	[T4_Deads] [float] NULL,
	[T5_Deads] [float] NULL,
	[KVK_START_SCANORDER] [float] NULL
) ON [PRIMARY]
END
