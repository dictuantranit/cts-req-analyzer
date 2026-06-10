/*<info serverAlias="DBCTS-WASAVerse" executers="bodbSPUNet" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[CTS_TWGroupBetting_GetRules]
AS
/*
	Created: 20220314@Harvey.Nguyen
	Task : Caculate Group betting ticket
	DB	 : DBCTS.WASAVerse

	Revisions:
		- 20220314@Harvey.Nguyen: Scan ticket 								[Redmine ID: #169671]
		- 20220711@Harvey.Nguyen: Change solution to scan on each ticket	[Redmine ID: #169671]
		- 20240130@Victoria.Le:	  Change tables - TWGB Migrate data from bodb02 to WASAVerse [Redmine ID: #191955]

	Params Explaination:
		EXECUTE [dbo].[CTS_TWGroupBetting_GetRules]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT RuleId
		,RuleName
		,LimitSecond
	FROM dbo.TWGroupBettingRule WITH (NOLOCK);
END