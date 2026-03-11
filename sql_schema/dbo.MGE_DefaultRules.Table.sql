SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_DefaultRules]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_DefaultRules](
	[RuleKey] [nvarchar](50) COLLATE Latin1_General_CI_AS NOT NULL,
	[RuleMode] [nvarchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[RuleText] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
	[UpdatedUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_MGE_DefaultRules] PRIMARY KEY CLUSTERED 
(
	[RuleKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_DefaultRules_IsActive]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_DefaultRules] ADD  CONSTRAINT [DF_MGE_DefaultRules_IsActive]  DEFAULT ((1)) FOR [IsActive]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_DefaultRules_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_DefaultRules] ADD  CONSTRAINT [DF_MGE_DefaultRules_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_DefaultRules_UpdatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_DefaultRules] ADD  CONSTRAINT [DF_MGE_DefaultRules_UpdatedUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_DefaultRules_RuleMode]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_DefaultRules]'))
ALTER TABLE [dbo].[MGE_DefaultRules]  WITH CHECK ADD  CONSTRAINT [CK_MGE_DefaultRules_RuleMode] CHECK  (([RuleMode]=N'open' OR [RuleMode]=N'fixed'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_DefaultRules_RuleMode]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_DefaultRules]'))
ALTER TABLE [dbo].[MGE_DefaultRules] CHECK CONSTRAINT [CK_MGE_DefaultRules_RuleMode]
