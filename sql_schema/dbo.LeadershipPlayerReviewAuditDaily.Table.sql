SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAuditDaily]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[LeadershipPlayerReviewAuditDaily](
	[AuditDateUtc] [date] NOT NULL,
	[Action] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[Outcome] [nvarchar](24) COLLATE Latin1_General_CI_AS NOT NULL,
	[EventCount] [bigint] NOT NULL,
	[LastAggregatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_LeadershipPlayerReviewAuditDaily] PRIMARY KEY CLUSTERED 
(
	[AuditDateUtc] ASC,
	[Action] ASC,
	[Outcome] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAuditDaily_Count]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAuditDaily]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAuditDaily]  WITH CHECK ADD  CONSTRAINT [CK_LeadershipPlayerReviewAuditDaily_Count] CHECK  (([EventCount]>=(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_LeadershipPlayerReviewAuditDaily_Count]') AND parent_object_id = OBJECT_ID(N'[dbo].[LeadershipPlayerReviewAuditDaily]'))
ALTER TABLE [dbo].[LeadershipPlayerReviewAuditDaily] CHECK CONSTRAINT [CK_LeadershipPlayerReviewAuditDaily_Count]
