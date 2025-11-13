SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LogHealthSamples]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[LogHealthSamples](
	[sample_utc] [datetime2](0) NOT NULL,
	[used_percent] [float] NULL,
	[reuse_wait_desc] [nvarchar](60) COLLATE Latin1_General_CI_AS NULL,
	[recovery_model] [nvarchar](60) COLLATE Latin1_General_CI_AS NULL,
	[last_full_backup] [datetime2](0) NULL,
	[last_log_backup] [datetime2](0) NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__LogHealth__sampl__1F24AE96]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[LogHealthSamples] ADD  DEFAULT (sysutcdatetime()) FOR [sample_utc]
END

