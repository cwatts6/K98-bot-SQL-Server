SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ArkAlliances]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ArkAlliances](
	[Alliance] [nchar](255) COLLATE Latin1_General_CI_AS NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
	[RegistrationChannelId] [bigint] NULL,
	[ConfirmationChannelId] [bigint] NULL,
 CONSTRAINT [PK_ArkAlliances] PRIMARY KEY CLUSTERED 
(
	[Alliance] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkAlliances_IsActive]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkAlliances] ADD  CONSTRAINT [DF_ArkAlliances_IsActive]  DEFAULT ((1)) FOR [IsActive]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkAlliances_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkAlliances] ADD  CONSTRAINT [DF_ArkAlliances_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkAlliances_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkAlliances] ADD  CONSTRAINT [DF_ArkAlliances_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

