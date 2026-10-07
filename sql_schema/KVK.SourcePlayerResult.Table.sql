SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourcePlayerResult](
	[PublicationID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[ConfigVersionID] [uniqueidentifier] NOT NULL,
	[RosterID] [uniqueidentifier] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[b0_kingdom] [int] NOT NULL,
	[CampID] [tinyint] NOT NULL,
	[name] [nvarchar](256) COLLATE Latin1_General_CI_AS NULL,
	[FieldStatusJson] [nvarchar](4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[starting_power] [bigint] NULL,
	[starting_power_rank] [int] NULL,
	[starting_power_cohort] [int] NULL,
	[power] [bigint] NULL,
	[power_rank] [int] NULL,
	[power_cohort] [int] NULL,
	[troops_power] [bigint] NULL,
	[troops_power_rank] [int] NULL,
	[troops_power_cohort] [int] NULL,
	[t1_kills] [bigint] NULL,
	[t1_kills_rank] [int] NULL,
	[t1_kills_cohort] [int] NULL,
	[t2_kills] [bigint] NULL,
	[t2_kills_rank] [int] NULL,
	[t2_kills_cohort] [int] NULL,
	[t3_kills] [bigint] NULL,
	[t3_kills_rank] [int] NULL,
	[t3_kills_cohort] [int] NULL,
	[t4_kills] [bigint] NULL,
	[t4_kills_rank] [int] NULL,
	[t4_kills_cohort] [int] NULL,
	[t5_kills] [bigint] NULL,
	[t5_kills_rank] [int] NULL,
	[t5_kills_cohort] [int] NULL,
	[total_kill_points] [bigint] NULL,
	[total_kill_points_rank] [int] NULL,
	[total_kill_points_cohort] [int] NULL,
	[dead] [bigint] NULL,
	[dead_rank] [int] NULL,
	[dead_cohort] [int] NULL,
	[healed] [bigint] NULL,
	[healed_rank] [int] NULL,
	[healed_cohort] [int] NULL,
	[acclaim] [bigint] NULL,
	[acclaim_rank] [int] NULL,
	[acclaim_cohort] [int] NULL,
	[highest_acclaim] [bigint] NULL,
	[highest_acclaim_rank] [int] NULL,
	[highest_acclaim_cohort] [int] NULL,
	[kp_t4_t5] [decimal](38, 6) NULL,
	[kp_t4_t5_rank] [int] NULL,
	[kp_t4_t5_cohort] [int] NULL,
	[dkp] [decimal](38, 6) NULL,
	[dkp_rank] [int] NULL,
	[dkp_cohort] [int] NULL,
	[healed_points] [decimal](38, 6) NULL,
	[healed_points_rank] [int] NULL,
	[healed_points_cohort] [int] NULL,
	[dkp_power_ratio] [decimal](38, 12) NULL,
	[dkp_power_ratio_rank] [int] NULL,
	[dkp_power_ratio_cohort] [int] NULL,
 CONSTRAINT [PK_SourcePlayerResult] PRIMARY KEY CLUSTERED 
(
	[PublicationID] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]') AND name = N'IX_SourcePlayerResult_Camp')
CREATE NONCLUSTERED INDEX [IX_SourcePlayerResult_Camp] ON [KVK].[SourcePlayerResult]
(
	[PublicationID] ASC,
	[CampID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]') AND name = N'IX_SourcePlayerResult_Kingdom')
CREATE NONCLUSTERED INDEX [IX_SourcePlayerResult_Kingdom] ON [KVK].[SourcePlayerResult]
(
	[PublicationID] ASC,
	[b0_kingdom] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePlayerResult_Camp]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [FK_SourcePlayerResult_Camp] FOREIGN KEY([ConfigVersionID], [b0_kingdom], [CampID])
REFERENCES [KVK].[SourceCampConfig] ([ConfigVersionID], [Kingdom], [CampID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePlayerResult_Camp]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [FK_SourcePlayerResult_Camp]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePlayerResult_Eligible]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [FK_SourcePlayerResult_Eligible] FOREIGN KEY([RosterID], [GovernorID], [b0_kingdom])
REFERENCES [KVK].[SourceRosterMember] ([RosterID], [GovernorID], [b0_kingdom])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePlayerResult_Eligible]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [FK_SourcePlayerResult_Eligible]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePlayerResult_Publication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [FK_SourcePlayerResult_Publication] FOREIGN KEY([SourceKey], [KVK_NO], [PublicationID], [ConfigVersionID], [RosterID])
REFERENCES [KVK].[SourcePublication] ([SourceKey], [KVK_NO], [PublicationID], [ConfigVersionID], [RosterID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePlayerResult_Publication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [FK_SourcePlayerResult_Publication]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_acclaim]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_acclaim] CHECK  ((json_value([FieldStatusJson],'$.acclaim') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.acclaim'))=(2)*len(json_value([FieldStatusJson],'$.acclaim')) AND (json_value([FieldStatusJson],'$.acclaim')=N'available' AND [acclaim] IS NOT NULL AND [acclaim]>=(0) OR (json_value([FieldStatusJson],'$.acclaim')=N'not_applicable' OR json_value([FieldStatusJson],'$.acclaim')=N'missing_configuration' OR json_value([FieldStatusJson],'$.acclaim')=N'unsupported' OR json_value([FieldStatusJson],'$.acclaim')=N'counter_regression' OR json_value([FieldStatusJson],'$.acclaim')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.acclaim')=N'missing_end' OR json_value([FieldStatusJson],'$.acclaim')=N'missing_start') AND [acclaim] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_acclaim]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_acclaim]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_acclaim_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_acclaim_Rank] CHECK  (([acclaim_rank] IS NULL AND [acclaim_cohort] IS NULL OR [acclaim] IS NOT NULL AND [acclaim_rank] IS NOT NULL AND [acclaim_cohort] IS NOT NULL AND [acclaim_rank]>=(1) AND [acclaim_rank]<=[acclaim_cohort] AND [acclaim_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_acclaim_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_acclaim_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_dead] CHECK  ((json_value([FieldStatusJson],'$.dead') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.dead'))=(2)*len(json_value([FieldStatusJson],'$.dead')) AND (json_value([FieldStatusJson],'$.dead')=N'available' AND [dead] IS NOT NULL AND [dead]>=(0) OR (json_value([FieldStatusJson],'$.dead')=N'not_applicable' OR json_value([FieldStatusJson],'$.dead')=N'missing_configuration' OR json_value([FieldStatusJson],'$.dead')=N'unsupported' OR json_value([FieldStatusJson],'$.dead')=N'counter_regression' OR json_value([FieldStatusJson],'$.dead')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.dead')=N'missing_end' OR json_value([FieldStatusJson],'$.dead')=N'missing_start') AND [dead] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_dead]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dead_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_dead_Rank] CHECK  (([dead_rank] IS NULL AND [dead_cohort] IS NULL OR [dead] IS NOT NULL AND [dead_rank] IS NOT NULL AND [dead_cohort] IS NOT NULL AND [dead_rank]>=(1) AND [dead_rank]<=[dead_cohort] AND [dead_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dead_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_dead_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dkp]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_dkp] CHECK  ((json_value([FieldStatusJson],'$.dkp') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.dkp'))=(2)*len(json_value([FieldStatusJson],'$.dkp')) AND (json_value([FieldStatusJson],'$.dkp')=N'available' AND [dkp] IS NOT NULL OR (json_value([FieldStatusJson],'$.dkp')=N'not_applicable' OR json_value([FieldStatusJson],'$.dkp')=N'missing_configuration' OR json_value([FieldStatusJson],'$.dkp')=N'unsupported' OR json_value([FieldStatusJson],'$.dkp')=N'counter_regression' OR json_value([FieldStatusJson],'$.dkp')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.dkp')=N'missing_end' OR json_value([FieldStatusJson],'$.dkp')=N'missing_start') AND [dkp] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dkp]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_dkp]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dkp_power_ratio]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_dkp_power_ratio] CHECK  ((json_value([FieldStatusJson],'$.dkp_power_ratio') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.dkp_power_ratio'))=(2)*len(json_value([FieldStatusJson],'$.dkp_power_ratio')) AND (json_value([FieldStatusJson],'$.dkp_power_ratio')=N'available' AND [dkp_power_ratio] IS NOT NULL OR (json_value([FieldStatusJson],'$.dkp_power_ratio')=N'not_applicable' OR json_value([FieldStatusJson],'$.dkp_power_ratio')=N'missing_configuration' OR json_value([FieldStatusJson],'$.dkp_power_ratio')=N'unsupported' OR json_value([FieldStatusJson],'$.dkp_power_ratio')=N'counter_regression' OR json_value([FieldStatusJson],'$.dkp_power_ratio')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.dkp_power_ratio')=N'missing_end' OR json_value([FieldStatusJson],'$.dkp_power_ratio')=N'missing_start') AND [dkp_power_ratio] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dkp_power_ratio]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_dkp_power_ratio]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dkp_power_ratio_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_dkp_power_ratio_Rank] CHECK  (([dkp_power_ratio_rank] IS NULL AND [dkp_power_ratio_cohort] IS NULL OR [dkp_power_ratio] IS NOT NULL AND [dkp_power_ratio_rank] IS NOT NULL AND [dkp_power_ratio_cohort] IS NOT NULL AND [dkp_power_ratio_rank]>=(1) AND [dkp_power_ratio_rank]<=[dkp_power_ratio_cohort] AND [dkp_power_ratio_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dkp_power_ratio_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_dkp_power_ratio_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dkp_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_dkp_Rank] CHECK  (([dkp_rank] IS NULL AND [dkp_cohort] IS NULL OR [dkp] IS NOT NULL AND [dkp_rank] IS NOT NULL AND [dkp_cohort] IS NOT NULL AND [dkp_rank]>=(1) AND [dkp_rank]<=[dkp_cohort] AND [dkp_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_dkp_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_dkp_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_healed]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_healed] CHECK  ((json_value([FieldStatusJson],'$.healed') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.healed'))=(2)*len(json_value([FieldStatusJson],'$.healed')) AND (json_value([FieldStatusJson],'$.healed')=N'available' AND [healed] IS NOT NULL AND [healed]>=(0) OR (json_value([FieldStatusJson],'$.healed')=N'not_applicable' OR json_value([FieldStatusJson],'$.healed')=N'missing_configuration' OR json_value([FieldStatusJson],'$.healed')=N'unsupported' OR json_value([FieldStatusJson],'$.healed')=N'counter_regression' OR json_value([FieldStatusJson],'$.healed')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.healed')=N'missing_end' OR json_value([FieldStatusJson],'$.healed')=N'missing_start') AND [healed] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_healed]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_healed]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_healed_points]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_healed_points] CHECK  ((json_value([FieldStatusJson],'$.healed_points') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.healed_points'))=(2)*len(json_value([FieldStatusJson],'$.healed_points')) AND (json_value([FieldStatusJson],'$.healed_points')=N'available' AND [healed_points] IS NOT NULL AND [healed_points]>=(0) OR (json_value([FieldStatusJson],'$.healed_points')=N'not_applicable' OR json_value([FieldStatusJson],'$.healed_points')=N'missing_configuration' OR json_value([FieldStatusJson],'$.healed_points')=N'unsupported' OR json_value([FieldStatusJson],'$.healed_points')=N'counter_regression' OR json_value([FieldStatusJson],'$.healed_points')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.healed_points')=N'missing_end' OR json_value([FieldStatusJson],'$.healed_points')=N'missing_start') AND [healed_points] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_healed_points]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_healed_points]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_healed_points_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_healed_points_Rank] CHECK  (([healed_points_rank] IS NULL AND [healed_points_cohort] IS NULL OR [healed_points] IS NOT NULL AND [healed_points_rank] IS NOT NULL AND [healed_points_cohort] IS NOT NULL AND [healed_points_rank]>=(1) AND [healed_points_rank]<=[healed_points_cohort] AND [healed_points_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_healed_points_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_healed_points_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_healed_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_healed_Rank] CHECK  (([healed_rank] IS NULL AND [healed_cohort] IS NULL OR [healed] IS NOT NULL AND [healed_rank] IS NOT NULL AND [healed_cohort] IS NOT NULL AND [healed_rank]>=(1) AND [healed_rank]<=[healed_cohort] AND [healed_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_healed_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_healed_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_highest_acclaim]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_highest_acclaim] CHECK  ((json_value([FieldStatusJson],'$.highest_acclaim') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.highest_acclaim'))=(2)*len(json_value([FieldStatusJson],'$.highest_acclaim')) AND (json_value([FieldStatusJson],'$.highest_acclaim')=N'available' AND [highest_acclaim] IS NOT NULL AND [highest_acclaim]>=(0) OR (json_value([FieldStatusJson],'$.highest_acclaim')=N'not_applicable' OR json_value([FieldStatusJson],'$.highest_acclaim')=N'missing_configuration' OR json_value([FieldStatusJson],'$.highest_acclaim')=N'unsupported' OR json_value([FieldStatusJson],'$.highest_acclaim')=N'counter_regression' OR json_value([FieldStatusJson],'$.highest_acclaim')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.highest_acclaim')=N'missing_end' OR json_value([FieldStatusJson],'$.highest_acclaim')=N'missing_start') AND [highest_acclaim] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_highest_acclaim]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_highest_acclaim]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_highest_acclaim_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_highest_acclaim_Rank] CHECK  (([highest_acclaim_rank] IS NULL AND [highest_acclaim_cohort] IS NULL OR [highest_acclaim] IS NOT NULL AND [highest_acclaim_rank] IS NOT NULL AND [highest_acclaim_cohort] IS NOT NULL AND [highest_acclaim_rank]>=(1) AND [highest_acclaim_rank]<=[highest_acclaim_cohort] AND [highest_acclaim_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_highest_acclaim_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_highest_acclaim_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_Identity] CHECK  (([GovernorID]>(0) AND [b0_kingdom]>(0) AND ([CampID]>=(1) AND [CampID]<=(8))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_Identity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_kp_t4_t5]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_kp_t4_t5] CHECK  ((json_value([FieldStatusJson],'$.kp_t4_t5') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.kp_t4_t5'))=(2)*len(json_value([FieldStatusJson],'$.kp_t4_t5')) AND (json_value([FieldStatusJson],'$.kp_t4_t5')=N'available' AND [kp_t4_t5] IS NOT NULL AND [kp_t4_t5]>=(0) OR (json_value([FieldStatusJson],'$.kp_t4_t5')=N'not_applicable' OR json_value([FieldStatusJson],'$.kp_t4_t5')=N'missing_configuration' OR json_value([FieldStatusJson],'$.kp_t4_t5')=N'unsupported' OR json_value([FieldStatusJson],'$.kp_t4_t5')=N'counter_regression' OR json_value([FieldStatusJson],'$.kp_t4_t5')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.kp_t4_t5')=N'missing_end' OR json_value([FieldStatusJson],'$.kp_t4_t5')=N'missing_start') AND [kp_t4_t5] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_kp_t4_t5]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_kp_t4_t5]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_kp_t4_t5_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_kp_t4_t5_Rank] CHECK  (([kp_t4_t5_rank] IS NULL AND [kp_t4_t5_cohort] IS NULL OR [kp_t4_t5] IS NOT NULL AND [kp_t4_t5_rank] IS NOT NULL AND [kp_t4_t5_cohort] IS NOT NULL AND [kp_t4_t5_rank]>=(1) AND [kp_t4_t5_rank]<=[kp_t4_t5_cohort] AND [kp_t4_t5_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_kp_t4_t5_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_kp_t4_t5_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_power] CHECK  ((json_value([FieldStatusJson],'$.power') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.power'))=(2)*len(json_value([FieldStatusJson],'$.power')) AND (json_value([FieldStatusJson],'$.power')=N'available' AND [power] IS NOT NULL OR (json_value([FieldStatusJson],'$.power')=N'not_applicable' OR json_value([FieldStatusJson],'$.power')=N'missing_configuration' OR json_value([FieldStatusJson],'$.power')=N'unsupported' OR json_value([FieldStatusJson],'$.power')=N'counter_regression' OR json_value([FieldStatusJson],'$.power')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.power')=N'missing_end' OR json_value([FieldStatusJson],'$.power')=N'missing_start') AND [power] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_power]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_power_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_power_Rank] CHECK  (([power_rank] IS NULL AND [power_cohort] IS NULL OR [power] IS NOT NULL AND [power_rank] IS NOT NULL AND [power_cohort] IS NOT NULL AND [power_rank]>=(1) AND [power_rank]<=[power_cohort] AND [power_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_power_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_power_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_starting_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_starting_power] CHECK  ((json_value([FieldStatusJson],'$.starting_power') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.starting_power'))=(2)*len(json_value([FieldStatusJson],'$.starting_power')) AND (json_value([FieldStatusJson],'$.starting_power')=N'available' AND [starting_power] IS NOT NULL AND [starting_power]>=(0) OR (json_value([FieldStatusJson],'$.starting_power')=N'not_applicable' OR json_value([FieldStatusJson],'$.starting_power')=N'missing_configuration' OR json_value([FieldStatusJson],'$.starting_power')=N'unsupported' OR json_value([FieldStatusJson],'$.starting_power')=N'counter_regression' OR json_value([FieldStatusJson],'$.starting_power')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.starting_power')=N'missing_end' OR json_value([FieldStatusJson],'$.starting_power')=N'missing_start') AND [starting_power] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_starting_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_starting_power]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_starting_power_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_starting_power_Rank] CHECK  (([starting_power_rank] IS NULL AND [starting_power_cohort] IS NULL OR [starting_power] IS NOT NULL AND [starting_power_rank] IS NOT NULL AND [starting_power_cohort] IS NOT NULL AND [starting_power_rank]>=(1) AND [starting_power_rank]<=[starting_power_cohort] AND [starting_power_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_starting_power_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_starting_power_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_StatusJson]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_StatusJson] CHECK  ((isjson([FieldStatusJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_StatusJson]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_StatusJson]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t1_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_t1_kills] CHECK  ((json_value([FieldStatusJson],'$.t1_kills') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.t1_kills'))=(2)*len(json_value([FieldStatusJson],'$.t1_kills')) AND (json_value([FieldStatusJson],'$.t1_kills')=N'available' AND [t1_kills] IS NOT NULL AND [t1_kills]>=(0) OR (json_value([FieldStatusJson],'$.t1_kills')=N'not_applicable' OR json_value([FieldStatusJson],'$.t1_kills')=N'missing_configuration' OR json_value([FieldStatusJson],'$.t1_kills')=N'unsupported' OR json_value([FieldStatusJson],'$.t1_kills')=N'counter_regression' OR json_value([FieldStatusJson],'$.t1_kills')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.t1_kills')=N'missing_end' OR json_value([FieldStatusJson],'$.t1_kills')=N'missing_start') AND [t1_kills] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t1_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_t1_kills]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t1_kills_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_t1_kills_Rank] CHECK  (([t1_kills_rank] IS NULL AND [t1_kills_cohort] IS NULL OR [t1_kills] IS NOT NULL AND [t1_kills_rank] IS NOT NULL AND [t1_kills_cohort] IS NOT NULL AND [t1_kills_rank]>=(1) AND [t1_kills_rank]<=[t1_kills_cohort] AND [t1_kills_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t1_kills_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_t1_kills_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t2_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_t2_kills] CHECK  ((json_value([FieldStatusJson],'$.t2_kills') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.t2_kills'))=(2)*len(json_value([FieldStatusJson],'$.t2_kills')) AND (json_value([FieldStatusJson],'$.t2_kills')=N'available' AND [t2_kills] IS NOT NULL AND [t2_kills]>=(0) OR (json_value([FieldStatusJson],'$.t2_kills')=N'not_applicable' OR json_value([FieldStatusJson],'$.t2_kills')=N'missing_configuration' OR json_value([FieldStatusJson],'$.t2_kills')=N'unsupported' OR json_value([FieldStatusJson],'$.t2_kills')=N'counter_regression' OR json_value([FieldStatusJson],'$.t2_kills')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.t2_kills')=N'missing_end' OR json_value([FieldStatusJson],'$.t2_kills')=N'missing_start') AND [t2_kills] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t2_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_t2_kills]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t2_kills_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_t2_kills_Rank] CHECK  (([t2_kills_rank] IS NULL AND [t2_kills_cohort] IS NULL OR [t2_kills] IS NOT NULL AND [t2_kills_rank] IS NOT NULL AND [t2_kills_cohort] IS NOT NULL AND [t2_kills_rank]>=(1) AND [t2_kills_rank]<=[t2_kills_cohort] AND [t2_kills_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t2_kills_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_t2_kills_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t3_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_t3_kills] CHECK  ((json_value([FieldStatusJson],'$.t3_kills') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.t3_kills'))=(2)*len(json_value([FieldStatusJson],'$.t3_kills')) AND (json_value([FieldStatusJson],'$.t3_kills')=N'available' AND [t3_kills] IS NOT NULL AND [t3_kills]>=(0) OR (json_value([FieldStatusJson],'$.t3_kills')=N'not_applicable' OR json_value([FieldStatusJson],'$.t3_kills')=N'missing_configuration' OR json_value([FieldStatusJson],'$.t3_kills')=N'unsupported' OR json_value([FieldStatusJson],'$.t3_kills')=N'counter_regression' OR json_value([FieldStatusJson],'$.t3_kills')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.t3_kills')=N'missing_end' OR json_value([FieldStatusJson],'$.t3_kills')=N'missing_start') AND [t3_kills] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t3_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_t3_kills]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t3_kills_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_t3_kills_Rank] CHECK  (([t3_kills_rank] IS NULL AND [t3_kills_cohort] IS NULL OR [t3_kills] IS NOT NULL AND [t3_kills_rank] IS NOT NULL AND [t3_kills_cohort] IS NOT NULL AND [t3_kills_rank]>=(1) AND [t3_kills_rank]<=[t3_kills_cohort] AND [t3_kills_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t3_kills_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_t3_kills_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t4_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_t4_kills] CHECK  ((json_value([FieldStatusJson],'$.t4_kills') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.t4_kills'))=(2)*len(json_value([FieldStatusJson],'$.t4_kills')) AND (json_value([FieldStatusJson],'$.t4_kills')=N'available' AND [t4_kills] IS NOT NULL AND [t4_kills]>=(0) OR (json_value([FieldStatusJson],'$.t4_kills')=N'not_applicable' OR json_value([FieldStatusJson],'$.t4_kills')=N'missing_configuration' OR json_value([FieldStatusJson],'$.t4_kills')=N'unsupported' OR json_value([FieldStatusJson],'$.t4_kills')=N'counter_regression' OR json_value([FieldStatusJson],'$.t4_kills')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.t4_kills')=N'missing_end' OR json_value([FieldStatusJson],'$.t4_kills')=N'missing_start') AND [t4_kills] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t4_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_t4_kills]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t4_kills_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_t4_kills_Rank] CHECK  (([t4_kills_rank] IS NULL AND [t4_kills_cohort] IS NULL OR [t4_kills] IS NOT NULL AND [t4_kills_rank] IS NOT NULL AND [t4_kills_cohort] IS NOT NULL AND [t4_kills_rank]>=(1) AND [t4_kills_rank]<=[t4_kills_cohort] AND [t4_kills_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t4_kills_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_t4_kills_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t5_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_t5_kills] CHECK  ((json_value([FieldStatusJson],'$.t5_kills') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.t5_kills'))=(2)*len(json_value([FieldStatusJson],'$.t5_kills')) AND (json_value([FieldStatusJson],'$.t5_kills')=N'available' AND [t5_kills] IS NOT NULL AND [t5_kills]>=(0) OR (json_value([FieldStatusJson],'$.t5_kills')=N'not_applicable' OR json_value([FieldStatusJson],'$.t5_kills')=N'missing_configuration' OR json_value([FieldStatusJson],'$.t5_kills')=N'unsupported' OR json_value([FieldStatusJson],'$.t5_kills')=N'counter_regression' OR json_value([FieldStatusJson],'$.t5_kills')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.t5_kills')=N'missing_end' OR json_value([FieldStatusJson],'$.t5_kills')=N'missing_start') AND [t5_kills] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t5_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_t5_kills]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t5_kills_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_t5_kills_Rank] CHECK  (([t5_kills_rank] IS NULL AND [t5_kills_cohort] IS NULL OR [t5_kills] IS NOT NULL AND [t5_kills_rank] IS NOT NULL AND [t5_kills_cohort] IS NOT NULL AND [t5_kills_rank]>=(1) AND [t5_kills_rank]<=[t5_kills_cohort] AND [t5_kills_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_t5_kills_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_t5_kills_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_total_kill_points]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_total_kill_points] CHECK  ((json_value([FieldStatusJson],'$.total_kill_points') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.total_kill_points'))=(2)*len(json_value([FieldStatusJson],'$.total_kill_points')) AND (json_value([FieldStatusJson],'$.total_kill_points')=N'available' AND [total_kill_points] IS NOT NULL AND [total_kill_points]>=(0) OR (json_value([FieldStatusJson],'$.total_kill_points')=N'not_applicable' OR json_value([FieldStatusJson],'$.total_kill_points')=N'missing_configuration' OR json_value([FieldStatusJson],'$.total_kill_points')=N'unsupported' OR json_value([FieldStatusJson],'$.total_kill_points')=N'counter_regression' OR json_value([FieldStatusJson],'$.total_kill_points')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.total_kill_points')=N'missing_end' OR json_value([FieldStatusJson],'$.total_kill_points')=N'missing_start') AND [total_kill_points] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_total_kill_points]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_total_kill_points]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_total_kill_points_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_total_kill_points_Rank] CHECK  (([total_kill_points_rank] IS NULL AND [total_kill_points_cohort] IS NULL OR [total_kill_points] IS NOT NULL AND [total_kill_points_rank] IS NOT NULL AND [total_kill_points_cohort] IS NOT NULL AND [total_kill_points_rank]>=(1) AND [total_kill_points_rank]<=[total_kill_points_cohort] AND [total_kill_points_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_total_kill_points_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_total_kill_points_Rank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_troops_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_troops_power] CHECK  ((json_value([FieldStatusJson],'$.troops_power') IS NOT NULL AND datalength(json_value([FieldStatusJson],'$.troops_power'))=(2)*len(json_value([FieldStatusJson],'$.troops_power')) AND (json_value([FieldStatusJson],'$.troops_power')=N'available' AND [troops_power] IS NOT NULL OR (json_value([FieldStatusJson],'$.troops_power')=N'not_applicable' OR json_value([FieldStatusJson],'$.troops_power')=N'missing_configuration' OR json_value([FieldStatusJson],'$.troops_power')=N'unsupported' OR json_value([FieldStatusJson],'$.troops_power')=N'counter_regression' OR json_value([FieldStatusJson],'$.troops_power')=N'invalid_source_value' OR json_value([FieldStatusJson],'$.troops_power')=N'missing_end' OR json_value([FieldStatusJson],'$.troops_power')=N'missing_start') AND [troops_power] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_troops_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_troops_power]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_troops_power_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerResult_troops_power_Rank] CHECK  (([troops_power_rank] IS NULL AND [troops_power_cohort] IS NULL OR [troops_power] IS NOT NULL AND [troops_power_rank] IS NOT NULL AND [troops_power_cohort] IS NOT NULL AND [troops_power_rank]>=(1) AND [troops_power_rank]<=[troops_power_cohort] AND [troops_power_cohort]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerResult_troops_power_Rank]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerResult]'))
ALTER TABLE [KVK].[SourcePlayerResult] CHECK CONSTRAINT [CK_SourcePlayerResult_troops_power_Rank]
