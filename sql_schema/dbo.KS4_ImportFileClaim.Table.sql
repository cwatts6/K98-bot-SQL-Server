SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS4_ImportFileClaim]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS4_ImportFileClaim](
	[CompletedFileName] [nvarchar](260) COLLATE Latin1_General_CI_AS NOT NULL,
	[ReadyPath] [nvarchar](4000) COLLATE Latin1_General_CI_AS NOT NULL,
	[ClaimedPath] [nvarchar](4000) COLLATE Latin1_General_CI_AS NOT NULL,
	[ArchivePath] [nvarchar](4000) COLLATE Latin1_General_CI_AS NOT NULL,
	[FileDigest] [binary](32) NULL,
	[ClaimStatus] [nvarchar](24) COLLATE Latin1_General_CI_AS NOT NULL,
	[ClaimRequestedAtUtc] [datetime2](3) NOT NULL,
	[ClaimedAtUtc] [datetime2](3) NULL,
	[ImportCommittedAtUtc] [datetime2](3) NULL,
	[ArchivedAtUtc] [datetime2](3) NULL,
	[LastError] [nvarchar](2000) COLLATE Latin1_General_CI_AS NULL,
	[AclHardenedAtUtc] [datetime2](3) NULL,
	[AclOwnerIdentity] [nvarchar](256) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_KS4_ImportFileClaim] PRIMARY KEY CLUSTERED 
(
	[CompletedFileName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KS4_ImportFileClaim_ArchivePath] UNIQUE NONCLUSTERED 
(
	[ArchivePath] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KS4_ImportFileClaim_ClaimedPath] UNIQUE NONCLUSTERED 
(
	[ClaimedPath] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KS4_ImportFileClaim_ReadyPath] UNIQUE NONCLUSTERED 
(
	[ReadyPath] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[KS4_ImportFileClaim]') AND name = N'IX_KS4_ImportFileClaim_FileDigest')
CREATE NONCLUSTERED INDEX [IX_KS4_ImportFileClaim_FileDigest] ON [dbo].[KS4_ImportFileClaim]
(
	[FileDigest] ASC
)
INCLUDE([ClaimStatus],[CompletedFileName]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KS4_ImportFileClaim_AclEvidence]') AND parent_object_id = OBJECT_ID(N'[dbo].[KS4_ImportFileClaim]'))
ALTER TABLE [dbo].[KS4_ImportFileClaim]  WITH CHECK ADD  CONSTRAINT [CK_KS4_ImportFileClaim_AclEvidence] CHECK  (([AclHardenedAtUtc] IS NULL AND [AclOwnerIdentity] IS NULL OR [AclHardenedAtUtc] IS NOT NULL AND [AclOwnerIdentity] IS NOT NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KS4_ImportFileClaim_AclEvidence]') AND parent_object_id = OBJECT_ID(N'[dbo].[KS4_ImportFileClaim]'))
ALTER TABLE [dbo].[KS4_ImportFileClaim] CHECK CONSTRAINT [CK_KS4_ImportFileClaim_AclEvidence]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KS4_ImportFileClaim_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[KS4_ImportFileClaim]'))
ALTER TABLE [dbo].[KS4_ImportFileClaim]  WITH CHECK ADD  CONSTRAINT [CK_KS4_ImportFileClaim_Status] CHECK  (([ClaimStatus]=N'failed' OR [ClaimStatus]=N'duplicate_archived' OR [ClaimStatus]=N'duplicate' OR [ClaimStatus]=N'archived' OR [ClaimStatus]=N'imported' OR [ClaimStatus]=N'claimed' OR [ClaimStatus]=N'claiming'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KS4_ImportFileClaim_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[KS4_ImportFileClaim]'))
ALTER TABLE [dbo].[KS4_ImportFileClaim] CHECK CONSTRAINT [CK_KS4_ImportFileClaim_Status]
