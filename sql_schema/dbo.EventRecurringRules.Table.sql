SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EventRecurringRules]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EventRecurringRules](
	[RuleID] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[IsActive] [bit] NOT NULL,
	[Emoji] [nvarchar](16) COLLATE Latin1_General_CI_AS NULL,
	[Title] [nvarchar](200) COLLATE Latin1_General_CI_AS NOT NULL,
	[EventType] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[Variant] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[RecurrenceType] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[IntervalDays] [int] NULL,
	[FirstStartUTC] [datetime2](0) NOT NULL,
	[DurationDays] [int] NOT NULL,
	[RepeatUntilUTC] [datetime2](0) NULL,
	[MaxOccurrences] [int] NULL,
	[AllDay] [bit] NOT NULL,
	[Importance] [nvarchar](32) COLLATE Latin1_General_CI_AS NULL,
	[Description] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[LinkURL] [nvarchar](500) COLLATE Latin1_General_CI_AS NULL,
	[ChannelID] [nvarchar](32) COLLATE Latin1_General_CI_AS NULL,
	[SignupURL] [nvarchar](500) COLLATE Latin1_General_CI_AS NULL,
	[Tags] [nvarchar](400) COLLATE Latin1_General_CI_AS NULL,
	[SortOrder] [int] NULL,
	[NotesInternal] [nvarchar](1000) COLLATE Latin1_General_CI_AS NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
	[ModifiedUTC] [datetime2](0) NOT NULL,
	[SourceRowHash] [varbinary](32) NULL,
 CONSTRAINT [PK_EventRecurringRules] PRIMARY KEY CLUSTERED 
(
	[RuleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EventRecurringRules_IsActive]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[EventRecurringRules] ADD  CONSTRAINT [DF_EventRecurringRules_IsActive]  DEFAULT ((1)) FOR [IsActive]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EventRecurringRules_AllDay]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[EventRecurringRules] ADD  CONSTRAINT [DF_EventRecurringRules_AllDay]  DEFAULT ((0)) FOR [AllDay]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EventRecurringRules_CreatedUTC]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[EventRecurringRules] ADD  CONSTRAINT [DF_EventRecurringRules_CreatedUTC]  DEFAULT (sysutcdatetime()) FOR [CreatedUTC]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EventRecurringRules_ModifiedUTC]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[EventRecurringRules] ADD  CONSTRAINT [DF_EventRecurringRules_ModifiedUTC]  DEFAULT (sysutcdatetime()) FOR [ModifiedUTC]
END

