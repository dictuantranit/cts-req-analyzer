/*<info serverAlias="DBCTS-bodb02" executers="bodbSPUNet" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[CTS_MatchInfo_Get]
		@MatchIds			VARCHAR(MAX) = ''
AS
/*
	Created: 20220628@Long.Luu
	Task : Get Match Info
	DB	 : bodb02

	Revisions:
		- 20220628@Long.Luu: Created [Redmine ID: #174430]

	Params Explaination:
		EXECUTE [dbo].[CTS_MatchInfo_Get] @MatchIds = '40391219,40391223,1207560';
*/
BEGIN
	SET NOCOUNT ON;

	IF	OBJECT_ID('tempdb..#tmpMatches') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatches;
	END;

	CREATE TABLE #tmpMatches(
			MatchId				INT NOT NULL PRIMARY KEY
	);

	IF	OBJECT_ID('tempdb..#tmpMatchesInfo') IS NOT NULL
	BEGIN
		DROP TABLE #tmpMatchesInfo;
	END;

	CREATE TABLE #tmpMatchesInfo (
			MatchId				INT NOT NULL PRIMARY KEY
		,	MatchCode			NVARCHAR(50)
		,	SportType			SMALLINT
		,	LeagueId			INT
		,	EventDate			DATETIME
		,	KickOffTime			DATETIME
		,	HomeId				INT
		,	AwayId				INT
		,	EventStatus			NVARCHAR(50)
		,	LiveHomeScore		INT
		,	LiveAwayScore		INT
		,	HTHomeScore			INT
		,	HTAwayScore			INT
		,	FinalHomeScore		INT
		,	FinalAwayScore		INT
	);

	INSERT INTO #tmpMatches (MatchId)
	SELECT ssk.value FROM STRING_SPLIT (@MatchIds, ',') ssk;

	INSERT INTO #tmpMatchesInfo (MatchId,MatchCode,SportType,LeagueId,EventDate,KickOffTime,HomeId,AwayId,EventStatus,LiveHomeScore,LiveAwayScore,HTHomeScore,HTAwayScore,FinalHomeScore,FinalAwayScore)
	SELECT	m.MatchId
		,	m.MatchCode
		,	m.SportType
		,	m.LeagueId
		,	m.EventDate
		,	m.GlobalShowTime
		,	m.HomeId
		,	m.AwayId
		,	m.EventStatus
		,	m.LiveHomeScore
		,	m.LiveAwayScore
		,	m.HTHomeScore
		,	m.HTAwayScore
		,	m.FinalHomeScore
		,	m.FinalAwayScore
	FROM #tmpMatches AS tm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Match AS m WITH(NOLOCK) ON tm.MatchId = m.matchid;

	DELETE tm
	FROM #tmpMatches AS tm
	INNER JOIN #tmpMatchesInfo AS m WITH(NOLOCK) ON tm.MatchId = m.matchid;

	INSERT INTO #tmpMatchesInfo (MatchId,MatchCode,SportType,LeagueId,EventDate,KickOffTime,HomeId,AwayId,EventStatus,LiveHomeScore,LiveAwayScore,HTHomeScore,HTAwayScore,FinalHomeScore,FinalAwayScore)
	SELECT	m.MatchId
		,	m.MatchCode
		,	m.SportType
		,	m.LeagueId
		,	m.EventDate
		,	m.GlobalShowTime
		,	m.HomeId
		,	m.AwayId
		,	m.EventStatus
		,	m.LiveHomeScore
		,	m.LiveAwayScore
		,	m.HTHomeScore
		,	m.HTAwayScore
		,	m.FinalHomeScore
		,	m.FinalAwayScore
	FROM #tmpMatches AS tm WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Match14 AS m WITH(NOLOCK) ON tm.MatchId = m.matchid;
		
	DELETE tm
	FROM #tmpMatches AS tm
		INNER JOIN #tmpMatchesInfo AS m WITH(NOLOCK) ON tm.MatchId = m.matchid;

	INSERT INTO #tmpMatchesInfo (MatchId,MatchCode,SportType,LeagueId,EventDate,KickOffTime,HomeId,AwayId,EventStatus,LiveHomeScore,LiveAwayScore,HTHomeScore,HTAwayScore,FinalHomeScore,FinalAwayScore)
	SELECT	m.MatchId
		,	m.MatchCode
		,	m.SportType
		,	m.LeagueId
		,	m.EventDate
		,	m.GlobalShowTime
		,	m.HomeId
		,	m.AwayId
		,	m.EventStatus
		,	m.LiveHomeScore
		,	m.LiveAwayScore
		,	m.HTHomeScore
		,	m.HTAwayScore
		,	m.FinalHomeScore
		,	m.FinalAwayScore
	FROM #tmpMatches AS tm WITH(NOLOCK)
		INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON tm.MatchId = m.matchid;
	

	-- Return data
	SELECT	m.MatchId
		,	m.MatchCode
		,	m.SportType
		,	m.LeagueId
		,	m.EventDate
		,	m.KickOffTime
		,	m.HomeId
		,	m.AwayId
		,	m.EventStatus
		,	m.LiveHomeScore
		,	m.LiveAwayScore
		,	m.HTHomeScore
		,	m.HTAwayScore
		,	m.FinalHomeScore
		,	m.FinalAwayScore
	FROM #tmpMatchesInfo AS m WITH(NOLOCK)
	ORDER BY m.EventDate DESC;

	DROP TABLE #tmpMatches;
	DROP TABLE #tmpMatchesInfo

END;

GO
/*<info serverAlias="DBCTS-bodb02" executers="bodbSPUNet" isFunction="0" isNested="0"></info>*/