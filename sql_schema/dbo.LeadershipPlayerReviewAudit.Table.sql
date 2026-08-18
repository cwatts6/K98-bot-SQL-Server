SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAudit]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[LeadershipPlayerReviewAudit](
	[AuditID] [bigint] IDENTITY(1,1) NOT NULL,
	[ExecutedAtUtc] [datetime2](3) NOT NULL,
	[ActorDiscordID] [bigint] NOT NULL,
	[TargetGovernorID] [bigint] NULL,
	[GuildID] [bigint] NOT NULL,
	[ChannelID] [bigint] NOT NULL,
	[AuthorizationBasis] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[AuthorizationRoleID] [bigint] NULL,
	[Action] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[Outcome] [nvarchar](24) COLLATE Latin1_General_CI_AS NOT NULL,
	[ErrorCode] [nvarchar](48) COLLATE Latin1_General_CI_AS NULL,
	[RequestCorrelationID] [uniqueidentifier] NOT NULL,
	[ExpiresAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_LeadershipPlayerReviewAudit] PRIMARY KEY CLUSTERED 
(
	[AuditID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAudit_Action]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAudit]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAudit]  WITH CHECK ADD  CONSTRAINT [CK_LeadershipPlayerReviewAudit_Action] CHECK  (([Action]=N'refresh' OR [Action]=N'definitions' OR [Action]=N'change_player' OR [Action]=N'linked_governor_change' OR [Action]=N'period_change' OR [Action]=N'page_change' OR [Action]=N'ambiguity_select' OR [Action]=N'open'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAudit_Action]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAudit]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAudit] CHECK CONSTRAINT [CK_LeadershipPlayerReviewAudit_Action]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAudit_Basis]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAudit]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAudit]  WITH CHECK ADD  CONSTRAINT [CK_LeadershipPlayerReviewAudit_Basis] CHECK  (([AuthorizationBasis]=N'LEADERSHIP_ROLE_ID' AND [AuthorizationRoleID] IS NOT NULL AND [AuthorizationRoleID]>(0) OR ([AuthorizationBasis]=N'NONE' OR [AuthorizationBasis]=N'ADMIN_USER_ID') AND [AuthorizationRoleID] IS NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAudit_Basis]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAudit]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAudit] CHECK CONSTRAINT [CK_LeadershipPlayerReviewAudit_Basis]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAudit_Expiry]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAudit]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAudit]  WITH CHECK ADD  CONSTRAINT [CK_LeadershipPlayerReviewAudit_Expiry] CHECK  (([ExpiresAtUtc]>[ExecutedAtUtc]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAudit_Expiry]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAudit]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAudit] CHECK CONSTRAINT [CK_LeadershipPlayerReviewAudit_Expiry]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAudit_IDs]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAudit]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAudit]  WITH CHECK ADD  CONSTRAINT [CK_LeadershipPlayerReviewAudit_IDs] CHECK  (([ActorDiscordID]>(0) AND [GuildID]>(0) AND [ChannelID]>(0) AND ([TargetGovernorID] IS NULL OR [TargetGovernorID]>(0))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAudit_IDs]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAudit]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAudit] CHECK CONSTRAINT [CK_LeadershipPlayerReviewAudit_IDs]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAudit_Outcome]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAudit]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAudit]  WITH CHECK ADD  CONSTRAINT [CK_LeadershipPlayerReviewAudit_Outcome] CHECK  (([Outcome]=N'EXPIRED' OR [Outcome]=N'STALE_SUPPRESSED' OR [Outcome]=N'FAILED' OR [Outcome]=N'SUCCEEDED' OR [Outcome]=N'DENIED' OR [Outcome]=N'ALLOWED'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAudit_Outcome]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAudit]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAudit] CHECK CONSTRAINT [CK_LeadershipPlayerReviewAudit_Outcome]
