/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CTS_MatchMonitorParlay_FraudTicketSummary]
		@FraudTickets VARCHAR(MAX) = NULL

AS
/*
	Created: 20240822@Casey.Huynh
	Task : CTS - Match Monitor Parlay, Get New Ticket
	DB	 : bodb02

	Revisions:
		- 20240822@Casey.Huynh: Created [Redmine ID: 207397]
		- 20241205@Casey.Huynh: Tunning Performance BK
		- 20241210@Thomas.Nguyen: Add EventDate for Tunning Performance BK [Redmine ID: #214867]

	Params Explaination:
	-	@FraudTickets is in Json format
		'[{"MatchID":10,"DataSource":0,"IsLive":1,"Bettype":1,"BetID":0,"FraudTrans":"1,2,3","FraudRefno":"4,5,6","FraudTransm":",11,12,13,21,22,31,32,"},etc]'
			
	Example:

		EXEC CTS_MatchMonitorParlay_FraudTicketSummary
		@FraudTickets = '[{"MatchId":83677751
			,"DataSource":0,"IsLive":0
			,"Bettype":1,"BetId":0
			,"FraudTrans":"292913011495010305,292913110279258114,292913032969846785,292913097394356226"
			,"FraudRefno":"18307063218438144,18307069392453632,18307064560615424,18307068587147264"}]';
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
		,	EventDate		DATETIME
		,	DataSource		TINYINT
		,	IsLive			BIT
		,	Bettype			SMALLINT
		,	BetId			BIGINT
		,	FraudRefno		VARCHAR(MAX)
	);

	
	IF	OBJECT_ID('tempdb..#tmpParsedRefno') IS NOT NULL
	BEGIN
		DROP TABLE #tmpParsedRefno;
	END;
	CREATE TABLE #tmpParsedRefno(
			MatchId		INT
		,	EventDate	DATETIME
		,	DataSource	TINYINT
		,	IsLive		BIT
		,	Bettype		SMALLINT
		,	BetId		BIGINT
		,	Refno		BIGINT 
		,	CustID		INT
	);

	IF	OBJECT_ID('tempdb..#tmpTurnOver') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTurnOver;
	END;
	CREATE TABLE #tmpTurnOver(
			
			Refno		BIGINT
		,	TurnOver	MONEY
		,	MatchId		INT
		,	IsLive		BIT
		,	Bettype		SMALLINT
		,	BetId		BIGINT		
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
		,	Refno			BIGINT		
	);

	IF @FraudTickets <> ''
	BEGIN
		-- Parse raw data
		INSERT INTO #tmpRawFraudInfo(MatchId,EventDate,DataSource,IsLive,Bettype,BetId,FraudRefno)
		SELECT	j.MatchId
			,	j.EventDate
			,	j.DataSource
			,	j.IsLive
			,	j.Bettype
			,	j.BetId
			,	j.FraudRefno
		FROM OPENJSON (@FraudTickets) WITH (
					MatchId			INT				'$.MatchId'
				,	EventDate		DATETIME		'$.EventDate'
				,	DataSource		TINYINT			'$.DataSource'
				,	IsLive			BIT				'$.IsLive'
				,	Bettype			SMALLINT		'$.Bettype'
				,	BetId			BIGINT			'$.BetId'
				,	FraudRefno		VARCHAR(MAX)	'$.FraudRefno'
			) AS j; 

		--==============GET Refno====================================

		WITH Temp_Intermediate(MatchID, EventDate, DataSource, IsLive, Bettype, BetId, Refno, FraudRefno) AS
		(
			SELECT  MatchID
				,	EventDate
				,	DataSource
				,	IsLive
				,	Bettype
				,	BetId
				,	LEFT(FraudRefno, CHARINDEX(',', FraudRefno + ',') - 1)
				,	STUFF(FraudRefno, 1, CHARINDEX(',', FraudRefno + ','), '')
			FROM  #tmpRawFraudInfo
			UNION ALL
			SELECT  MatchID
				,	EventDate
				,	DataSource
				,	IsLive
				,	Bettype
				,	BetId
				,	LEFT(FraudRefno, CHARINDEX(',', FraudRefno + ',') - 1)
				,	STUFF(FraudRefno, 1, CHARINDEX(',', FraudRefno + ','), '')
			FROM Temp_Intermediate
			WHERE FraudRefno > ''
		)
		INSERT INTO #tmpParsedRefno(MatchID, EventDate, DataSource, IsLive, Bettype, BetId, Refno)
		SELECT	MatchID
			,	EventDate
			,	DataSource
			,	IsLive
			,	Bettype
			,	BetId
			,	Refno
		FROM Temp_Intermediate WITH(NOLOCK)
		OPTION (MAXRECURSION 0);

		CREATE CLUSTERED INDEX #CIX_tmpParsedRefno ON #tmpParsedRefno(Refno	DESC);

		----Clone #tmpParsedRefno--------------------
		INSERT INTO #tmpParsedFraudInfo (MatchID, DataSource, IsLive, Bettype, BetId, Refno)
		SELECT	MatchID
			,	DataSource
			,	IsLive
			,	Bettype
			,	BetId
			,	Refno
		FROM #tmpParsedRefno WITH(NOLOCK)

		--==============GET Turn Over Origin====================================
		INSERT INTO #tmpTurnOver(MatchID, IsLive, Bettype, BetID, Refno,TurnOver)
		SELECT	tmpTo.MatchID
			,	tmpTo.IsLive
			,	tmpTo.Bettype
			,	tmpTo.BetId
			,	tmpTo.Refno
			,	bt.Stake * bt.actualrate AS TurnOver
		FROM #tmpParsedRefno AS tmpTo WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Bettrans AS bt WITH(NOLOCK) on bt.Refno = tmpTo.Refno;
		
		DELETE tmpRn
		FROM #tmpParsedRefno AS tmpRn WITH(NOLOCK)
			INNER JOIN #tmpTurnOver AS tmpTo WITH(NOLOCK) ON tmpTo.Refno = tmpRn.Refno ;

		--==============GET Turn Over - 14====================================
		INSERT INTO #tmpTurnOver(MatchID, IsLive, Bettype, BetId, Refno,TurnOver)
		SELECT	tmpTo.MatchID
			,	tmpTo.IsLive
			,	tmpTo.Bettype
			,	tmpTo.BetId
			,	tmpTo.Refno
			,	bt.Stake * bt.actualrate AS TurnOver
		FROM #tmpParsedRefno AS tmpTo WITH(NOLOCK)
			INNER JOIN bodb02.dbo.Bettrans14 AS bt WITH(NOLOCK) on bt.Refno = tmpTo.Refno;
		
		DELETE tmpRn
		FROM #tmpParsedRefno AS tmpRn WITH(NOLOCK)
			INNER JOIN #tmpTurnOver AS tmpTo WITH(NOLOCK) ON tmpTo.Refno = tmpRn.Refno;

		--==============GET Turn Over - BK====================================
		UPDATE tmp WITH(ROWLOCK, UPDLOCK)
		SET tmp.custid = cus.custid
		FROM #tmpParsedRefno AS tmp
			CROSS APPLY 
			(
				SELECT TOP(1) bt.CustID
				FROM bodb_Archive.dbo.Bettransm AS bt WITH(NOLOCK)
				WHERE bt.refno = tmp.Refno
			) AS cus;

		INSERT INTO #tmpTurnOver(MatchID, IsLive, Bettype, BetId, Refno,TurnOver)
		SELECT	tmpTo.MatchID
			,	tmpTo.IsLive
			,	tmpTo.Bettype
			,	tmpTo.BetId
			,	tmpTo.Refno
			,	bt.Stake * bt.actualrate AS TurnOver
		FROM #tmpParsedRefno AS tmpTo WITH(NOLOCK)
			INNER JOIN bodb_Archive.dbo.Bettrans_bk AS bt WITH(NOLOCK) on  bt.custid = tmpTo.custid AND bt.matchid = 29 AND bt.winlostdate IN (DATEADD(DD, -1, tmpTo.EventDate), tmpTo.EventDate)
		WHERE bt.Refno = tmpTo.Refno;

		DELETE tmpRn
		FROM #tmpParsedRefno AS tmpRn WITH(NOLOCK)
			INNER JOIN #tmpTurnOver AS tmpTo WITH(NOLOCK) ON tmpTo.Refno = tmpRn.Refno;	

		IF EXISTS (SELECT TOP 1 1 FROM #tmpParsedRefno AS tmpRn WITH(NOLOCK))
		BEGIN
			INSERT INTO #tmpTurnOver(MatchID, IsLive, Bettype, BetId, Refno,TurnOver)
			SELECT	tmpTo.MatchID
				,	tmpTo.IsLive
				,	tmpTo.Bettype
				,	tmpTo.BetId
				,	tmpTo.Refno
				,	bt.Stake * bt.actualrate AS TurnOver
			FROM #tmpParsedRefno AS tmpTo WITH(NOLOCK)
				INNER JOIN bodb_Archive.dbo.Bettrans_bk AS bt WITH(NOLOCK) on  bt.custid = tmpTo.custid AND bt.matchid = 29
			WHERE bt.Refno = tmpTo.Refno
			OPTION (MAXDOP 4);
			
			DELETE tmpRn
			FROM #tmpParsedRefno AS tmpRn WITH(NOLOCK)
				INNER JOIN #tmpTurnOver AS tmpTo WITH(NOLOCK) ON tmpTo.Refno = tmpRn.Refno;		
		END;

		CREATE CLUSTERED INDEX #CIX_tmpTurnOver ON #tmpTurnOver(
				MatchID	DESC
			,	IsLive
			,	Bettype
			,	BetId
		);
	
		CREATE CLUSTERED INDEX #CIX_tmpParsedFraudInfo ON #tmpParsedFraudInfo (
			Refno	DESC
		);

		-- Return the data
		SELECT DISTINCT tmp.MatchId, tmp.IsLive, tmp.Bettype, tmp.BetId, tmp.betteam AS Betteam, tmp.Turnover, tmp.BetCount
		FROM (
				SELECT	t.MatchId
					,	t.IsLive
					,	t.Bettype
					,	b.betteam
					,	t.BetId
					,	SUM(tmpTo.TurnOver) AS Turnover
					,	COUNT(DISTINCT t.Refno) AS BetCount
				FROM #tmpParsedFraudInfo AS t WITH(NOLOCK)
					INNER JOIN bodb_Archive.dbo.bettransm AS b WITH(NOLOCK) ON b.Refno = t.Refno AND  b.MatchID = t.MatchID
					LEFT JOIN #tmpTurnover AS tmpTo WITH(NOLOCK) ON t.MatchId = tmpTo.MatchId AND t.IsLive = tmpTo.IsLive
												AND t.Bettype = tmpTo.Bettype AND t.BetId = tmpTo.BetId AND b.refno = tmpTo.refno
				WHERE t.DataSource = @CONST_DATASOURCE_BK 
				GROUP BY t.MatchId, t.IsLive, t.Bettype, t.BetId, b.Betteam
				UNION
				SELECT	t.MatchId
					,	t.IsLive
					,	t.Bettype
					,	b.betteam
					,	t.BetId
					,	SUM(tmpTo.TurnOver) AS Turnover
					,	COUNT(DISTINCT t.Refno) AS BetCount
				FROM #tmpParsedFraudInfo AS t WITH(NOLOCK)
					INNER JOIN bodb02.dbo.bettransm14 AS b WITH(NOLOCK) ON b.Refno = t.Refno AND  b.MatchID = t.MatchID
					INNER JOIN #tmpTurnover AS tmpTo WITH(NOLOCK) ON t.MatchId = tmpTo.MatchId AND t.IsLive = tmpTo.IsLive
												AND t.Bettype = tmpTo.Bettype AND t.BetId = tmpTo.BetId AND b.refno = tmpTo.refno
				WHERE t.DataSource = @CONST_DATASOURCE_14
				GROUP BY t.MatchId, t.IsLive, t.Bettype, t.BetId, b.Betteam
				UNION
				SELECT	t.MatchId
					,	t.IsLive
					,	t.Bettype
					,	b.betteam
					,	t.BetId
					,	SUM(tmpTo.TurnOver) AS Turnover
					,	COUNT(DISTINCT t.Refno) AS BetCount
				FROM #tmpParsedFraudInfo AS t WITH(NOLOCK)
					INNER JOIN bodb02.dbo.bettransm AS b WITH(NOLOCK) ON b.Refno = t.Refno AND b.MatchID = t.MatchID
					INNER JOIN #tmpTurnover AS tmpTo WITH(NOLOCK) ON t.MatchId = tmpTo.MatchId AND t.IsLive = tmpTo.IsLive
												AND t.Bettype = tmpTo.Bettype AND t.BetId = tmpTo.BetId AND b.refno = tmpTo.refno
				WHERE t.DataSource = @CONST_DATASOURCE_ORIGIN
				GROUP BY t.MatchId, t.IsLive, t.Bettype, t.BetId, b.Betteam
			) AS tmp;
	END;

	DROP TABLE IF EXISTS #tmpRawFraudInfo;
	DROP TABLE IF EXISTS #tmpParsedFraudInfo;

END;
GO
