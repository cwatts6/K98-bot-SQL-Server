SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[VoteSurveyDeletionAudit](
	[DeletionAuditID] [bigint] IDENTITY(1,1) NOT NULL,
	[ContentKind] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[ContentID] [bigint] NOT NULL,
	[Title] [nvarchar](200) COLLATE Latin1_General_CI_AS NOT NULL,
	[Status] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[GuildID] [bigint] NOT NULL,
	[ChannelID] [bigint] NOT NULL,
	[MessageID] [bigint] NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[ClosesAtUtc] [datetime2](0) NOT NULL,
	[ClosedAtUtc] [datetime2](0) NULL,
	[DeletedAtUtc] [datetime2](0) NOT NULL,
	[DeletedBy] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[Reason] [nvarchar](500) COLLATE Latin1_General_CI_AS NOT NULL,
	[BreakGlassProductionDelete] [bit] NOT NULL,
	[RowCountsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[LocalAuditSummaryJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_VoteSurveyDeletionAudit] PRIMARY KEY CLUSTERED 
(
	[DeletionAuditID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]') AND name = N'IX_VoteSurveyDeletionAudit_Content')
CREATE NONCLUSTERED INDEX [IX_VoteSurveyDeletionAudit_Content] ON [dbo].[VoteSurveyDeletionAudit]
(
	[ContentKind] ASC,
	[ContentID] ASC,
	[DeletedAtUtc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_VoteSurveyDeletionAudit_DeletedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[VoteSurveyDeletionAudit] ADD  CONSTRAINT [DF_VoteSurveyDeletionAudit_DeletedAtUtc]  DEFAULT (sysutcdatetime()) FOR [DeletedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VoteSurveyDeletionAudit_ContentKind]') AND parent_object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]'))
ALTER TABLE [dbo].[VoteSurveyDeletionAudit]  WITH CHECK ADD  CONSTRAINT [CK_VoteSurveyDeletionAudit_ContentKind] CHECK  (([ContentKind]='Survey' OR [ContentKind]='Vote'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VoteSurveyDeletionAudit_ContentKind]') AND parent_object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]'))
ALTER TABLE [dbo].[VoteSurveyDeletionAudit] CHECK CONSTRAINT [CK_VoteSurveyDeletionAudit_ContentKind]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VoteSurveyDeletionAudit_DeletedBy]') AND parent_object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]'))
ALTER TABLE [dbo].[VoteSurveyDeletionAudit]  WITH CHECK ADD  CONSTRAINT [CK_VoteSurveyDeletionAudit_DeletedBy] CHECK  ((len(ltrim(rtrim([DeletedBy])))>=(1) AND len(ltrim(rtrim([DeletedBy])))<=(128)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VoteSurveyDeletionAudit_DeletedBy]') AND parent_object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]'))
ALTER TABLE [dbo].[VoteSurveyDeletionAudit] CHECK CONSTRAINT [CK_VoteSurveyDeletionAudit_DeletedBy]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VoteSurveyDeletionAudit_LocalAuditSummaryJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]'))
ALTER TABLE [dbo].[VoteSurveyDeletionAudit]  WITH CHECK ADD  CONSTRAINT [CK_VoteSurveyDeletionAudit_LocalAuditSummaryJson] CHECK  (([LocalAuditSummaryJson] IS NULL OR isjson([LocalAuditSummaryJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VoteSurveyDeletionAudit_LocalAuditSummaryJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]'))
ALTER TABLE [dbo].[VoteSurveyDeletionAudit] CHECK CONSTRAINT [CK_VoteSurveyDeletionAudit_LocalAuditSummaryJson]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VoteSurveyDeletionAudit_Reason]') AND parent_object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]'))
ALTER TABLE [dbo].[VoteSurveyDeletionAudit]  WITH CHECK ADD  CONSTRAINT [CK_VoteSurveyDeletionAudit_Reason] CHECK  ((len(ltrim(rtrim([Reason])))>=(1) AND len(ltrim(rtrim([Reason])))<=(500)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VoteSurveyDeletionAudit_Reason]') AND parent_object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]'))
ALTER TABLE [dbo].[VoteSurveyDeletionAudit] CHECK CONSTRAINT [CK_VoteSurveyDeletionAudit_Reason]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VoteSurveyDeletionAudit_RowCountsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]'))
ALTER TABLE [dbo].[VoteSurveyDeletionAudit]  WITH CHECK ADD  CONSTRAINT [CK_VoteSurveyDeletionAudit_RowCountsJson] CHECK  ((isjson([RowCountsJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VoteSurveyDeletionAudit_RowCountsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]'))
ALTER TABLE [dbo].[VoteSurveyDeletionAudit] CHECK CONSTRAINT [CK_VoteSurveyDeletionAudit_RowCountsJson]
