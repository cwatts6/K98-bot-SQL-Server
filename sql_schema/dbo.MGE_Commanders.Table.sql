SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Commanders]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_Commanders](
	[CommanderId] [int] IDENTITY(1,1) NOT NULL,
	[CommanderName] [nvarchar](100) COLLATE Latin1_General_CI_AS NOT NULL,
	[IsActive] [bit] NOT NULL,
	[ReleaseStartUtc] [datetime2](7) NULL,
	[ReleaseEndUtc] [datetime2](7) NULL,
	[ImageUrl] [nvarchar](500) COLLATE Latin1_General_CI_AS NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
	[UpdatedUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_MGE_Commanders] PRIMARY KEY CLUSTERED 
(
	[CommanderId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Commanders]') AND name = N'IX_MGE_Commanders_Active')
CREATE NONCLUSTERED INDEX [IX_MGE_Commanders_Active] ON [dbo].[MGE_Commanders]
(
	[IsActive] ASC
)
INCLUDE([CommanderName],[ReleaseStartUtc],[ReleaseEndUtc]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Commanders]') AND name = N'UX_MGE_Commanders_Name')
CREATE UNIQUE NONCLUSTERED INDEX [UX_MGE_Commanders_Name] ON [dbo].[MGE_Commanders]
(
	[CommanderName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Commanders_IsActive]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Commanders] ADD  CONSTRAINT [DF_MGE_Commanders_IsActive]  DEFAULT ((1)) FOR [IsActive]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Commanders_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Commanders] ADD  CONSTRAINT [DF_MGE_Commanders_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Commanders_UpdatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Commanders] ADD  CONSTRAINT [DF_MGE_Commanders_UpdatedUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedUtc]
END

