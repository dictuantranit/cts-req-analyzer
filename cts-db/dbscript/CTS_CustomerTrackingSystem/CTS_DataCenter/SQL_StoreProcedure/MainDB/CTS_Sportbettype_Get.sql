/*<info serverAlias="DBCTS-bodb02" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[CTS_SportBettype_Get]
		@ProductId INT
	,	@SportBettypeList  VARCHAR(MAX) = NULL

AS
/*
	Created: 20231226@Casey.Huynh
	Task : CTS_SportBettype_Get 
	DB	 : bodb02

	Revisions:
		- 20231226@Casey.Huynh:	Create [Redmine ID: #196361]		
		- 20240322@Vitoria.Le:	Danger Page Main - Get List SportType,Bettype which they ared seperated by LeagueGroupID [Redmine ID: #201380]		
		- 20250318@Jonas.Huynh: Danger Monitor - Change datatype of parameter [Redmine ID: #217765]		

	Params Explaination:		
		- LeagueGroupID	|	LeagueGroupName 		|	SportType
			42			|		Virtual				|		0 -- GET FROM SportBettypeMatrix
			74			|	Virtual Sport Bacarrat	|		1
			108			|		Virtual Futsal		|		1
			113			|		SABA PinGoal		|		1
			122			|	SABA Basketball PinGoal	|		2
			151			|	SABA E-Sports PinGoal	|		43
		- SportGroup:
			1: Main Sport - SportType IN (1,2,5,6,7,8,9,18,43,50)
			2: Saba Virtual Sport
			3: Others
		- SportType IN (1,2,5,6,7,8,9,18,43,50):
			1: 	Soccer | 2: Basketball | 5: Tennis
			6: 	Volleyball | 7: Snooker/Pool	| 8: Baseball
			9: 	Badminton | 18: Table Tennis | 43: E-Sports
			50: Cricket
			....
			
	Example:
		EXEC CTS_SportBettype_Get @ProductID=1, @SportBettypeList= '[1,2,3,6,7,8,12,126,413,414,20,609,610,612,501,9404,9405]'
		EXEC CTS_SportBettype_Get @ProductID=1
*/
BEGIN
	SET NOCOUNT ON;
	
	IF	OBJECT_ID('tempdb..#tmpSportBettype') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpSportBettype;
	END;

	CREATE TABLE	#tmpSportBettype(
			SporttypeId		INT
		,	BettypeId		INT
	);

	INSERT INTO #tmpSportBettype (SporttypeId,BettypeId)
	SELECT DISTINCT sb.SportType, sb.BetType 
	FROM bodb02.dbo.SportBettypeMatrix AS sb WITH(NOLOCK)
	WHERE sb.ProductID = @ProductID
		AND (CASE WHEN @SportBettypeList IS NULL THEN 1
				  WHEN @SportBettypeList IS NOT NULL AND sb.BetType IN (SELECT CAST(value AS INT) FROM OPENJSON(@SportBettypeList)) THEN 1
				  ELSE 0 END = 1)
		AND sb.IsTest = 0
		AND sb.SportType NOT IN (27, 154) --Exclude Cricket and Horse Racing Fixed Odds
		AND sb.BetType NOT IN (9, 29, 999) -- Exclude Parlay and Odds Spread Adjustment
		AND sb.SubProduct NOT IN ('CO-Cashout', 'CO-Bought', 'CO-Comm', 'CO-Winloss',
								  'Bet Builder');
	
	CREATE NONCLUSTERED INDEX #IX_tmpSportBettype_SporttypeId ON #tmpSportBettype (SporttypeId,BettypeId);
	
	WITH CTE_Saba_1 AS (
		SELECT DISTINCT tmp.SporttypeId, tmp.BettypeId, l.LeagueGroupID
		FROM bodb02.dbo.League AS l WITH (NOLOCK)
			INNER JOIN #tmpSportBettype AS tmp ON tmp.SporttypeId = l.SportType
		WHERE l.LeagueGroupID = 42 
	), CTE_Saba_2 AS (
		SELECT DISTINCT tmp.SporttypeId, tmp.BettypeId, lg.GroupID AS LeagueGroupID, lg.GroupName AS LeagueGroupName
		FROM bodb02.dbo.LeagueGroup AS lg WITH (NOLOCK)
			INNER JOIN #tmpSportBettype AS tmp ON tmp.SporttypeId = lg.SportType
		WHERE lg.GroupID IN (74,108,113,122,151) 
	), CTE_All AS (
		SELECT SporttypeId,BettypeId,LeagueGroupID,NULL AS LeagueGroupName
		FROM CTE_Saba_1
		UNION ALL
		SELECT SporttypeId,BettypeId,LeagueGroupID,LeagueGroupName
		FROM CTE_Saba_2
	)
	SELECT DISTINCT
			(CASE WHEN s.SportType in(1,2,5,6,7,8,9,18,43,50) THEN 1
				  ELSE 3 END) AS SportGroup 
		,	s.SportName
		,	s.SportName AS SportNameDisplay
		,	sb.SporttypeId
		,	NULL AS LeagueGroupID
		,	sb.BettypeId 
	FROM #tmpSportBettype AS sb
		INNER JOIN bodb02.dbo.Sports AS s WITH(NOLOCK) ON s.SportType = sb.SporttypeId
		INNER JOIN bodb02.dbo.Bettype AS b WITH(NOLOCK) ON b.typeid = sb.BettypeId
	UNION ALL
	SELECT DISTINCT 
			2 AS SportGroup 
		,	s.SportName
		,	(CASE WHEN c.LeagueGroupID = 42 THEN 'Virtual ' + s.SportName 
				  ELSE c.LeagueGroupName END) AS SportNameDisplay
		,	c.SporttypeId
		,	c.LeagueGroupID
		,	c.BettypeId 
	FROM CTE_All AS c
		INNER JOIN bodb02.dbo.Sports AS s WITH(NOLOCK) ON s.SportType = c.SporttypeId
		INNER JOIN bodb02.dbo.Bettype AS b WITH(NOLOCK) ON b.typeid = c.BettypeId
	ORDER BY SportGroup ASC, SporttypeId ASC;
	
	DROP TABLE IF EXISTS #tmpSportBettype;
	
END