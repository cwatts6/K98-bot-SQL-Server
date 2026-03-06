SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EventOverrides]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EventOverrides](
	[OverrideID] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[IsActive] [bit] NOT NULL,
	[TargetKind] [nvarchar](16) COLLATE Latin1_General_CI_AS NOT NULL,
	[TargetID] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[TargetOccurrenceStartUTC] [datetime2](0) NULL,
	[ActionType] [nvarchar](16) COLLATE Latin1_General_CI_AS NOT NULL,
	[NewStartUTC] [datetime2](0) NULL,
	[NewEndUTC] [datetime2](0) NULL,
	[NewTitle] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[NewVariant] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[NewEmoji] [nvarchar](16) COLLATE Latin1_General_CI_AS NULL,
	[NewImportance] [nvarchar](32) COLLATE Latin1_General_CI_AS NULL,
	[NewDescription] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[NewLinkURL] [nvarchar](500) COLLATE Latin1_General_CI_AS NULL,
	[NewChannelID] [nvarchar](32) COLLATE Latin1_General_CI_AS NULL,
	[NewSignupURL] [nvarchar](500) COLLATE Latin1_General_CI_AS NULL,
	[NewTags] [nvarchar](400) COLLATE Latin1_General_CI_AS NULL,
	[NotesInternal] [nvarchar](1000) COLLATE Latin1_General_CI_AS NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
	[ModifiedUTC] [datetime2](0) NOT NULL,
	[SourceRowHash] [varbinary](32) NULL,
 CONSTRAINT [PK_EventOverrides] PRIMARY KEY CLUSTERED 
(
	[OverrideID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EventOverrides_IsActive]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[EventOverrides] ADD  CONSTRAINT [DF_EventOverrides_IsActive]  DEFAULT ((1)) FOR [IsActive]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EventOverrides_CreatedUTC]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[EventOverrides] ADD  CONSTRAINT [DF_EventOverrides_CreatedUTC]  DEFAULT (sysutcdatetime()) FOR [CreatedUTC]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EventOverrides_ModifiedUTC]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[EventOverrides] ADD  CONSTRAINT [DF_EventOverrides_ModifiedUTC]  DEFAULT (sysutcdatetime()) FOR [ModifiedUTC]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_EventOverrides_ActionType]') AND parent_object_id = OBJECT_ID(N'[dbo].[EventOverrides]'))
ALTER TABLE [dbo].[EventOverrides]  WITH CHECK ADD  CONSTRAINT [CK_EventOverrides_ActionType] CHECK  (([ActionType]=N'modify' OR [ActionType]=N'cancel'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_EventOverrides_ActionType]') AND parent_object_id = OBJECT_ID(N'[dbo].[EventOverrides]'))
ALTER TABLE [dbo].[EventOverrides] CHECK CONSTRAINT [CK_EventOverrides_ActionType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_EventOverrides_NewEndAfterStart]') AND parent_object_id = OBJECT_ID(N'[dbo].[EventOverrides]'))
ALTER TABLE [dbo].[EventOverrides]  WITH CHECK ADD  CONSTRAINT [CK_EventOverrides_NewEndAfterStart] CHECK  (([NewEndUTC] IS NULL OR [NewStartUTC] IS NULL OR [NewEndUTC]>[NewStartUTC]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_EventOverrides_NewEndAfterStart]') AND parent_object_id = OBJECT_ID(N'[dbo].[EventOverrides]'))
ALTER TABLE [dbo].[EventOverrides] CHECK CONSTRAINT [CK_EventOverrides_NewEndAfterStart]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_EventOverrides_TargetKind]') AND parent_object_id = OBJECT_ID(N'[dbo].[EventOverrides]'))
ALTER TABLE [dbo].[EventOverrides]  WITH CHECK ADD  CONSTRAINT [CK_EventOverrides_TargetKind] CHECK  (([TargetKind]=N'instance' OR [TargetKind]=N'oneoff' OR [TargetKind]=N'rule'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_EventOverrides_TargetKind]') AND parent_object_id = OBJECT_ID(N'[dbo].[EventOverrides]'))
ALTER TABLE [dbo].[EventOverrides] CHECK CONSTRAINT [CK_EventOverrides_TargetKind]
