SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourcePlayerSnapshot](
	[RevisionID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[kingdom] [int] NOT NULL,
	[name] [nvarchar](256) COLLATE Latin1_General_CI_AS NULL,
	[alliance] [nvarchar](256) COLLATE Latin1_General_CI_AS NULL,
	[civilization] [nvarchar](256) COLLATE Latin1_General_CI_AS NULL,
	[power] [bigint] NULL,
	[city_hall] [bigint] NULL,
	[vip] [bigint] NULL,
	[t1_kills] [bigint] NULL,
	[t2_kills] [bigint] NULL,
	[t3_kills] [bigint] NULL,
	[t4_kills] [bigint] NULL,
	[t5_kills] [bigint] NULL,
	[total_kill_points] [bigint] NULL,
	[ranged_points] [bigint] NULL,
	[dead] [bigint] NULL,
	[healed] [bigint] NULL,
	[rss_assistance] [bigint] NULL,
	[alliance_helps] [bigint] NULL,
	[rss_gathered] [bigint] NULL,
	[troops_power] [bigint] NULL,
	[tech_power] [bigint] NULL,
	[building_power] [bigint] NULL,
	[commander_power] [bigint] NULL,
	[kvk_played] [bigint] NULL,
	[autarch_times] [bigint] NULL,
	[most_kvk_kill] [bigint] NULL,
	[most_kvk_dead] [bigint] NULL,
	[most_kvk_heal] [bigint] NULL,
	[acclaim] [bigint] NULL,
	[highest_acclaim] [bigint] NULL,
	[aoo_joined] [bigint] NULL,
	[aoo_won] [bigint] NULL,
	[aoo_avg_kill] [bigint] NULL,
	[aoo_avg_dead] [bigint] NULL,
	[aoo_avg_heal] [bigint] NULL,
	[FieldStatusJson] [nvarchar](4000) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[RawProfileJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourcePlayerSnapshot] PRIMARY KEY CLUSTERED 
(
	[RevisionID] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePlayerSnapshot_Revision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [FK_SourcePlayerSnapshot_Revision] FOREIGN KEY([SourceKey], [KVK_NO], [RevisionID])
REFERENCES [KVK].[SourceObservationRevision] ([SourceKey], [KVK_NO], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePlayerSnapshot_Revision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [FK_SourcePlayerSnapshot_Revision]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_acclaim]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_acclaim] CHECK  ((json_value([FieldStatusJson],'$.acclaim') IS NOT NULL AND (json_value([FieldStatusJson],'$.acclaim')='available' AND [acclaim] IS NOT NULL AND [acclaim]>=(0) OR (json_value([FieldStatusJson],'$.acclaim')='not_applicable' OR json_value([FieldStatusJson],'$.acclaim')='unsupported' OR json_value([FieldStatusJson],'$.acclaim')='invalid_source_value') AND [acclaim] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_acclaim]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_acclaim]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_alliance_helps]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_alliance_helps] CHECK  ((json_value([FieldStatusJson],'$.alliance_helps') IS NOT NULL AND (json_value([FieldStatusJson],'$.alliance_helps')='available' AND [alliance_helps] IS NOT NULL AND [alliance_helps]>=(0) OR (json_value([FieldStatusJson],'$.alliance_helps')='not_applicable' OR json_value([FieldStatusJson],'$.alliance_helps')='unsupported' OR json_value([FieldStatusJson],'$.alliance_helps')='invalid_source_value') AND [alliance_helps] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_alliance_helps]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_alliance_helps]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_aoo_avg_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_aoo_avg_dead] CHECK  ((json_value([FieldStatusJson],'$.aoo_avg_dead') IS NOT NULL AND (json_value([FieldStatusJson],'$.aoo_avg_dead')='available' AND [aoo_avg_dead] IS NOT NULL AND [aoo_avg_dead]>=(0) OR (json_value([FieldStatusJson],'$.aoo_avg_dead')='not_applicable' OR json_value([FieldStatusJson],'$.aoo_avg_dead')='unsupported' OR json_value([FieldStatusJson],'$.aoo_avg_dead')='invalid_source_value') AND [aoo_avg_dead] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_aoo_avg_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_aoo_avg_dead]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_aoo_avg_heal]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_aoo_avg_heal] CHECK  ((json_value([FieldStatusJson],'$.aoo_avg_heal') IS NOT NULL AND (json_value([FieldStatusJson],'$.aoo_avg_heal')='available' AND [aoo_avg_heal] IS NOT NULL AND [aoo_avg_heal]>=(0) OR (json_value([FieldStatusJson],'$.aoo_avg_heal')='not_applicable' OR json_value([FieldStatusJson],'$.aoo_avg_heal')='unsupported' OR json_value([FieldStatusJson],'$.aoo_avg_heal')='invalid_source_value') AND [aoo_avg_heal] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_aoo_avg_heal]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_aoo_avg_heal]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_aoo_avg_kill]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_aoo_avg_kill] CHECK  ((json_value([FieldStatusJson],'$.aoo_avg_kill') IS NOT NULL AND (json_value([FieldStatusJson],'$.aoo_avg_kill')='available' AND [aoo_avg_kill] IS NOT NULL AND [aoo_avg_kill]>=(0) OR (json_value([FieldStatusJson],'$.aoo_avg_kill')='not_applicable' OR json_value([FieldStatusJson],'$.aoo_avg_kill')='unsupported' OR json_value([FieldStatusJson],'$.aoo_avg_kill')='invalid_source_value') AND [aoo_avg_kill] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_aoo_avg_kill]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_aoo_avg_kill]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_aoo_joined]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_aoo_joined] CHECK  ((json_value([FieldStatusJson],'$.aoo_joined') IS NOT NULL AND (json_value([FieldStatusJson],'$.aoo_joined')='available' AND [aoo_joined] IS NOT NULL AND [aoo_joined]>=(0) OR (json_value([FieldStatusJson],'$.aoo_joined')='not_applicable' OR json_value([FieldStatusJson],'$.aoo_joined')='unsupported' OR json_value([FieldStatusJson],'$.aoo_joined')='invalid_source_value') AND [aoo_joined] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_aoo_joined]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_aoo_joined]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_aoo_won]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_aoo_won] CHECK  ((json_value([FieldStatusJson],'$.aoo_won') IS NOT NULL AND (json_value([FieldStatusJson],'$.aoo_won')='available' AND [aoo_won] IS NOT NULL AND [aoo_won]>=(0) OR (json_value([FieldStatusJson],'$.aoo_won')='not_applicable' OR json_value([FieldStatusJson],'$.aoo_won')='unsupported' OR json_value([FieldStatusJson],'$.aoo_won')='invalid_source_value') AND [aoo_won] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_aoo_won]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_aoo_won]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_autarch_times]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_autarch_times] CHECK  ((json_value([FieldStatusJson],'$.autarch_times') IS NOT NULL AND (json_value([FieldStatusJson],'$.autarch_times')='available' AND [autarch_times] IS NOT NULL AND [autarch_times]>=(0) OR (json_value([FieldStatusJson],'$.autarch_times')='not_applicable' OR json_value([FieldStatusJson],'$.autarch_times')='unsupported' OR json_value([FieldStatusJson],'$.autarch_times')='invalid_source_value') AND [autarch_times] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_autarch_times]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_autarch_times]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_building_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_building_power] CHECK  ((json_value([FieldStatusJson],'$.building_power') IS NOT NULL AND (json_value([FieldStatusJson],'$.building_power')='available' AND [building_power] IS NOT NULL AND [building_power]>=(0) OR (json_value([FieldStatusJson],'$.building_power')='not_applicable' OR json_value([FieldStatusJson],'$.building_power')='unsupported' OR json_value([FieldStatusJson],'$.building_power')='invalid_source_value') AND [building_power] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_building_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_building_power]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_city_hall]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_city_hall] CHECK  ((json_value([FieldStatusJson],'$.city_hall') IS NOT NULL AND (json_value([FieldStatusJson],'$.city_hall')='available' AND [city_hall] IS NOT NULL AND [city_hall]>=(0) OR (json_value([FieldStatusJson],'$.city_hall')='not_applicable' OR json_value([FieldStatusJson],'$.city_hall')='unsupported' OR json_value([FieldStatusJson],'$.city_hall')='invalid_source_value') AND [city_hall] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_city_hall]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_city_hall]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_commander_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_commander_power] CHECK  ((json_value([FieldStatusJson],'$.commander_power') IS NOT NULL AND (json_value([FieldStatusJson],'$.commander_power')='available' AND [commander_power] IS NOT NULL AND [commander_power]>=(0) OR (json_value([FieldStatusJson],'$.commander_power')='not_applicable' OR json_value([FieldStatusJson],'$.commander_power')='unsupported' OR json_value([FieldStatusJson],'$.commander_power')='invalid_source_value') AND [commander_power] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_commander_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_commander_power]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_dead] CHECK  ((json_value([FieldStatusJson],'$.dead') IS NOT NULL AND (json_value([FieldStatusJson],'$.dead')='available' AND [dead] IS NOT NULL AND [dead]>=(0) OR (json_value([FieldStatusJson],'$.dead')='not_applicable' OR json_value([FieldStatusJson],'$.dead')='unsupported' OR json_value([FieldStatusJson],'$.dead')='invalid_source_value') AND [dead] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_dead]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_healed]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_healed] CHECK  ((json_value([FieldStatusJson],'$.healed') IS NOT NULL AND (json_value([FieldStatusJson],'$.healed')='available' AND [healed] IS NOT NULL AND [healed]>=(0) OR (json_value([FieldStatusJson],'$.healed')='not_applicable' OR json_value([FieldStatusJson],'$.healed')='unsupported' OR json_value([FieldStatusJson],'$.healed')='invalid_source_value') AND [healed] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_healed]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_healed]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_highest_acclaim]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_highest_acclaim] CHECK  ((json_value([FieldStatusJson],'$.highest_acclaim') IS NOT NULL AND (json_value([FieldStatusJson],'$.highest_acclaim')='available' AND [highest_acclaim] IS NOT NULL AND [highest_acclaim]>=(0) OR (json_value([FieldStatusJson],'$.highest_acclaim')='not_applicable' OR json_value([FieldStatusJson],'$.highest_acclaim')='unsupported' OR json_value([FieldStatusJson],'$.highest_acclaim')='invalid_source_value') AND [highest_acclaim] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_highest_acclaim]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_highest_acclaim]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_Identity] CHECK  (([GovernorID]>(0) AND [kingdom]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_Identity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_Json]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_Json] CHECK  ((isjson([FieldStatusJson])=(1) AND isjson([RawProfileJson])=(1) AND datalength([RawProfileJson])<=(16777216)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_Json]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_Json]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_kvk_played]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_kvk_played] CHECK  ((json_value([FieldStatusJson],'$.kvk_played') IS NOT NULL AND (json_value([FieldStatusJson],'$.kvk_played')='available' AND [kvk_played] IS NOT NULL AND [kvk_played]>=(0) OR (json_value([FieldStatusJson],'$.kvk_played')='not_applicable' OR json_value([FieldStatusJson],'$.kvk_played')='unsupported' OR json_value([FieldStatusJson],'$.kvk_played')='invalid_source_value') AND [kvk_played] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_kvk_played]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_kvk_played]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_most_kvk_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_most_kvk_dead] CHECK  ((json_value([FieldStatusJson],'$.most_kvk_dead') IS NOT NULL AND (json_value([FieldStatusJson],'$.most_kvk_dead')='available' AND [most_kvk_dead] IS NOT NULL AND [most_kvk_dead]>=(0) OR (json_value([FieldStatusJson],'$.most_kvk_dead')='not_applicable' OR json_value([FieldStatusJson],'$.most_kvk_dead')='unsupported' OR json_value([FieldStatusJson],'$.most_kvk_dead')='invalid_source_value') AND [most_kvk_dead] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_most_kvk_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_most_kvk_dead]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_most_kvk_heal]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_most_kvk_heal] CHECK  ((json_value([FieldStatusJson],'$.most_kvk_heal') IS NOT NULL AND (json_value([FieldStatusJson],'$.most_kvk_heal')='available' AND [most_kvk_heal] IS NOT NULL AND [most_kvk_heal]>=(0) OR (json_value([FieldStatusJson],'$.most_kvk_heal')='not_applicable' OR json_value([FieldStatusJson],'$.most_kvk_heal')='unsupported' OR json_value([FieldStatusJson],'$.most_kvk_heal')='invalid_source_value') AND [most_kvk_heal] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_most_kvk_heal]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_most_kvk_heal]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_most_kvk_kill]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_most_kvk_kill] CHECK  ((json_value([FieldStatusJson],'$.most_kvk_kill') IS NOT NULL AND (json_value([FieldStatusJson],'$.most_kvk_kill')='available' AND [most_kvk_kill] IS NOT NULL AND [most_kvk_kill]>=(0) OR (json_value([FieldStatusJson],'$.most_kvk_kill')='not_applicable' OR json_value([FieldStatusJson],'$.most_kvk_kill')='unsupported' OR json_value([FieldStatusJson],'$.most_kvk_kill')='invalid_source_value') AND [most_kvk_kill] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_most_kvk_kill]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_most_kvk_kill]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_power] CHECK  ((json_value([FieldStatusJson],'$.power') IS NOT NULL AND (json_value([FieldStatusJson],'$.power')='available' AND [power] IS NOT NULL AND [power]>=(0) OR (json_value([FieldStatusJson],'$.power')='not_applicable' OR json_value([FieldStatusJson],'$.power')='unsupported' OR json_value([FieldStatusJson],'$.power')='invalid_source_value') AND [power] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_power]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_ranged_points]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_ranged_points] CHECK  ((json_value([FieldStatusJson],'$.ranged_points') IS NOT NULL AND (json_value([FieldStatusJson],'$.ranged_points')='available' AND [ranged_points] IS NOT NULL AND [ranged_points]>=(0) OR (json_value([FieldStatusJson],'$.ranged_points')='not_applicable' OR json_value([FieldStatusJson],'$.ranged_points')='unsupported' OR json_value([FieldStatusJson],'$.ranged_points')='invalid_source_value') AND [ranged_points] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_ranged_points]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_ranged_points]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_rss_assistance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_rss_assistance] CHECK  ((json_value([FieldStatusJson],'$.rss_assistance') IS NOT NULL AND (json_value([FieldStatusJson],'$.rss_assistance')='available' AND [rss_assistance] IS NOT NULL AND [rss_assistance]>=(0) OR (json_value([FieldStatusJson],'$.rss_assistance')='not_applicable' OR json_value([FieldStatusJson],'$.rss_assistance')='unsupported' OR json_value([FieldStatusJson],'$.rss_assistance')='invalid_source_value') AND [rss_assistance] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_rss_assistance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_rss_assistance]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_rss_gathered]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_rss_gathered] CHECK  ((json_value([FieldStatusJson],'$.rss_gathered') IS NOT NULL AND (json_value([FieldStatusJson],'$.rss_gathered')='available' AND [rss_gathered] IS NOT NULL AND [rss_gathered]>=(0) OR (json_value([FieldStatusJson],'$.rss_gathered')='not_applicable' OR json_value([FieldStatusJson],'$.rss_gathered')='unsupported' OR json_value([FieldStatusJson],'$.rss_gathered')='invalid_source_value') AND [rss_gathered] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_rss_gathered]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_rss_gathered]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_t1_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_t1_kills] CHECK  ((json_value([FieldStatusJson],'$.t1_kills') IS NOT NULL AND (json_value([FieldStatusJson],'$.t1_kills')='available' AND [t1_kills] IS NOT NULL AND [t1_kills]>=(0) OR (json_value([FieldStatusJson],'$.t1_kills')='not_applicable' OR json_value([FieldStatusJson],'$.t1_kills')='unsupported' OR json_value([FieldStatusJson],'$.t1_kills')='invalid_source_value') AND [t1_kills] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_t1_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_t1_kills]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_t2_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_t2_kills] CHECK  ((json_value([FieldStatusJson],'$.t2_kills') IS NOT NULL AND (json_value([FieldStatusJson],'$.t2_kills')='available' AND [t2_kills] IS NOT NULL AND [t2_kills]>=(0) OR (json_value([FieldStatusJson],'$.t2_kills')='not_applicable' OR json_value([FieldStatusJson],'$.t2_kills')='unsupported' OR json_value([FieldStatusJson],'$.t2_kills')='invalid_source_value') AND [t2_kills] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_t2_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_t2_kills]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_t3_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_t3_kills] CHECK  ((json_value([FieldStatusJson],'$.t3_kills') IS NOT NULL AND (json_value([FieldStatusJson],'$.t3_kills')='available' AND [t3_kills] IS NOT NULL AND [t3_kills]>=(0) OR (json_value([FieldStatusJson],'$.t3_kills')='not_applicable' OR json_value([FieldStatusJson],'$.t3_kills')='unsupported' OR json_value([FieldStatusJson],'$.t3_kills')='invalid_source_value') AND [t3_kills] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_t3_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_t3_kills]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_t4_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_t4_kills] CHECK  ((json_value([FieldStatusJson],'$.t4_kills') IS NOT NULL AND (json_value([FieldStatusJson],'$.t4_kills')='available' AND [t4_kills] IS NOT NULL AND [t4_kills]>=(0) OR (json_value([FieldStatusJson],'$.t4_kills')='not_applicable' OR json_value([FieldStatusJson],'$.t4_kills')='unsupported' OR json_value([FieldStatusJson],'$.t4_kills')='invalid_source_value') AND [t4_kills] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_t4_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_t4_kills]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_t5_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_t5_kills] CHECK  ((json_value([FieldStatusJson],'$.t5_kills') IS NOT NULL AND (json_value([FieldStatusJson],'$.t5_kills')='available' AND [t5_kills] IS NOT NULL AND [t5_kills]>=(0) OR (json_value([FieldStatusJson],'$.t5_kills')='not_applicable' OR json_value([FieldStatusJson],'$.t5_kills')='unsupported' OR json_value([FieldStatusJson],'$.t5_kills')='invalid_source_value') AND [t5_kills] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_t5_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_t5_kills]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_tech_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_tech_power] CHECK  ((json_value([FieldStatusJson],'$.tech_power') IS NOT NULL AND (json_value([FieldStatusJson],'$.tech_power')='available' AND [tech_power] IS NOT NULL AND [tech_power]>=(0) OR (json_value([FieldStatusJson],'$.tech_power')='not_applicable' OR json_value([FieldStatusJson],'$.tech_power')='unsupported' OR json_value([FieldStatusJson],'$.tech_power')='invalid_source_value') AND [tech_power] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_tech_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_tech_power]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_total_kill_points]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_total_kill_points] CHECK  ((json_value([FieldStatusJson],'$.total_kill_points') IS NOT NULL AND (json_value([FieldStatusJson],'$.total_kill_points')='available' AND [total_kill_points] IS NOT NULL AND [total_kill_points]>=(0) OR (json_value([FieldStatusJson],'$.total_kill_points')='not_applicable' OR json_value([FieldStatusJson],'$.total_kill_points')='unsupported' OR json_value([FieldStatusJson],'$.total_kill_points')='invalid_source_value') AND [total_kill_points] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_total_kill_points]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_total_kill_points]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_troops_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_troops_power] CHECK  ((json_value([FieldStatusJson],'$.troops_power') IS NOT NULL AND (json_value([FieldStatusJson],'$.troops_power')='available' AND [troops_power] IS NOT NULL AND [troops_power]>=(0) OR (json_value([FieldStatusJson],'$.troops_power')='not_applicable' OR json_value([FieldStatusJson],'$.troops_power')='unsupported' OR json_value([FieldStatusJson],'$.troops_power')='invalid_source_value') AND [troops_power] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_troops_power]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_troops_power]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_vip]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot]  WITH CHECK ADD  CONSTRAINT [CK_SourcePlayerSnapshot_vip] CHECK  ((json_value([FieldStatusJson],'$.vip') IS NOT NULL AND (json_value([FieldStatusJson],'$.vip')='available' AND [vip] IS NOT NULL AND [vip]>=(0) OR (json_value([FieldStatusJson],'$.vip')='not_applicable' OR json_value([FieldStatusJson],'$.vip')='unsupported' OR json_value([FieldStatusJson],'$.vip')='invalid_source_value') AND [vip] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePlayerSnapshot_vip]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePlayerSnapshot]'))
ALTER TABLE [KVK].[SourcePlayerSnapshot] CHECK CONSTRAINT [CK_SourcePlayerSnapshot_vip]
