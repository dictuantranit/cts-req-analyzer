/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CTS_MatchMonitor_FraudTicketsSummary]
		@FraudTickets				VARCHAR(MAX) = NULL
AS
/*
	Created: 20231116@Long.Luu:
	Task : CTS - Match Monitor - Get Fraud Tickets' Summary
	DB	 : bodb02

	Revisions:
		- 20231116@Long.Luu: 	Initialize [Redmine ID: 195042]
		- 20231212@Long.Luu: 	Remove duplicate tickets catched by many reasons [Redmine ID: 196396]
		- 20250318@Thomas.Nguyen: 	Rename SP from CTS_Rpt_MatchMonitor_FraudTicketsSummary [Redmine ID: #219681]

	Params Explaination:
		-	@FraudTickets is in Json format
			'[{"MatchID":10,"DataSource":0,"IsLive":1,"Bettype":1,"BetID":0,"FraudTrans":"1,2,3"},etc]'
			
	Example:
		EXEC [dbo].[CTS_MatchMonitor_FraudTicketsSummary] @FraudTickets = '[{"MatchID":10,"DataSource":0,"IsLive":1,"Bettype":1,"BetID":0,"FraudTrans":"1,2,3"}]';
*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @CONST_DATASOURCE_ORIGIN	TINYINT = 0
		,	@CONST_DATASOURCE_14		TINYINT = 1
		,	@CONST_DATASOURCE_BK		TINYINT = 2;

	IF	OBJECT_ID('tempdb..#tmpRawFraudInfo') IS NOT NULL
	BEGIN
		DROP TABLE #tmpRawFraudInfo;
	END;

	CREATE TABLE #tmpRawFraudInfo(
			MatchId			INT
		,	DataSource		TINYINT
		,	IsLive			BIT
		,	Bettype			SMALLINT
		,	BetId			BIGINT
		,	FraudTrans		VARCHAR(MAX)
	);

	CREATE CLUSTERED INDEX #CIX_tmpRawFraudInfo_DataSource ON #tmpRawFraudInfo (
			DataSource			DESC
	);
	
	IF	OBJECT_ID('tempdb..#tmpParsedFraudInfo') IS NOT NULL
	BEGIN
		DROP TABLE #tmpParsedFraudInfo;
	END;

	CREATE TABLE #tmpParsedFraudInfo(
			MatchId			INT
		,	DataSource		TINYINT
		,	IsLive			BIT
		,	Bettype			SMALLINT
		,	BetId			BIGINT
		,	TransId			BIGINT
	);

	IF	OBJECT_ID('tempdb..#tmpTickets') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTickets;
	END;

	IF @FraudTickets <> ''
		BEGIN
			-- Parse raw data
			INSERT INTO #tmpRawFraudInfo (MatchId,DataSource,IsLive,Bettype,BetId,FraudTrans)
			SELECT	j.MatchId
				,	j.DataSource
				,	j.IsLive
				,	j.Bettype
				,	j.BetId
				,	j.FraudTrans
			FROM OPENJSON (@FraudTickets) WITH (
					MatchId			INT '$.MatchId'
				,	DataSource		TINYINT '$.DataSource'
				,	IsLive			BIT '$.IsLive'
				,	Bettype			SMALLINT '$.Bettype'
				,	BetId			BIGINT '$.BetId'
				,	FraudTrans		VARCHAR(MAX) '$.FraudTrans'
				) AS j;

			-- Pivot the fraud tickets list to transIDs
			;WITH Temp_Intermediate(MatchId,DataSource,IsLive,Bettype,BetId,TransId,FraudTrans) AS
			(
				SELECT	MatchId
					,	DataSource
					,	IsLive
					,	Bettype
					,	BetId
					,	LEFT(FraudTrans, CHARINDEX(',', FraudTrans + ',') - 1)
					,	STUFF(FraudTrans, 1, CHARINDEX(',', FraudTrans + ','), '')
				FROM #tmpRawFraudInfo
				UNION ALL
				SELECT	MatchId
					,	DataSource
					,	IsLive
					,	Bettype
					,	BetId
					,	LEFT(FraudTrans, CHARINDEX(',', FraudTrans + ',') - 1)
					,	STUFF(FraudTrans, 1, CHARINDEX(',', FraudTrans + ','), '')
				FROM Temp_Intermediate
				WHERE	FraudTrans > ''
			)
			INSERT INTO #tmpParsedFraudInfo(MatchId,DataSource,IsLive,Bettype,BetId,TransId)
			SELECT	DISTINCT MatchId
				,	DataSource
				,	IsLive
				,	Bettype
				,	BetId
				,	TransId
			FROM Temp_Intermediate WITH(NOLOCK)
			OPTION (MAXRECURSION 0);

			CREATE CLUSTERED INDEX #CIX_tmpParsedFraudInfo ON #tmpParsedFraudInfo (
				TransId			DESC
			)
			;

			-- Return the data
			SELECT DISTINCT t.MatchId, t.IsLive, t.Bettype, t.BetId, t.betteam AS Betteam, t.Turnover, t.BetCount
			FROM (
					SELECT	t.MatchId
						,	t.IsLive
						,	t.Bettype
						,	b.betteam
						,	t.BetId
						,	SUM(b.stake * b.actualrate) AS Turnover
						,	COUNT(DISTINCT b.transid) AS BetCount
					FROM #tmpParsedFraudInfo AS t WITH(NOLOCK)
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS b WITH(NOLOCK) ON b.TransId = t.TransId
					WHERE t.DataSource = @CONST_DATASOURCE_BK
					GROUP BY t.MatchId, t.IsLive, t.Bettype, t.BetId, b.Betteam
					UNION
					SELECT	t.MatchId
						,	t.IsLive
						,	t.Bettype
						,	b.betteam
						,	t.BetId
						,	SUM(b.stake * b.actualrate) AS Turnover
						,	COUNT(DISTINCT b.transid) AS BetCount
					FROM #tmpParsedFraudInfo AS t WITH(NOLOCK)
						INNER JOIN bodb02.dbo.bettrans14 AS b WITH(NOLOCK) ON b.TransId = t.TransId
					WHERE t.DataSource = @CONST_DATASOURCE_14
					GROUP BY t.MatchId, t.IsLive, t.Bettype, t.BetId, b.Betteam
					UNION
					SELECT	t.MatchId
						,	t.IsLive
						,	t.Bettype
						,	b.betteam
						,	t.BetId
						,	SUM(b.stake * b.actualrate) AS Turnover
						,	COUNT(DISTINCT b.transid) AS BetCount
					FROM #tmpParsedFraudInfo AS t WITH(NOLOCK)
						INNER JOIN bodb02.dbo.bettrans AS b WITH(NOLOCK) ON b.TransId = t.TransId
					WHERE t.DataSource = @CONST_DATASOURCE_ORIGIN
					GROUP BY t.MatchId, t.IsLive, t.Bettype, t.BetId, b.Betteam
				) AS t;
		END;

	DROP TABLE IF EXISTS #tmpRawFraudInfo;
	DROP TABLE IF EXISTS #tmpParsedFraudInfo;

END;

GO