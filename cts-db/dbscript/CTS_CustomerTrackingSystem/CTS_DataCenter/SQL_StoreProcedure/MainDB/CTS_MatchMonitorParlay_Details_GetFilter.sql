/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CTS_MatchMonitorParlay_Details_GetFilter]
		@ViewMode					TINYINT = 0
	,	@Matchid					INT = 0
	,	@EventDate					DATETIME = '1900-09-22'
	,	@ListSportBetType			VARCHAR(MAX)
	,	@IsLive						BIT = 0
	,	@ListSuspiciousRefno		VARCHAR(MAX) = ''
	
	,	@IsExclTestCurr				BIT = 0
	,	@FromTransDate				DATETIME = NULL
	,	@ToTransDate				DATETIME = NULL

	,	@MaxSequenceId				BIGINT		OUTPUT
	,	@TotalTicketAll				BIGINT		OUTPUT
	,	@TotalTicketLicensee		BIGINT		OUTPUT
	,	@TotalTicketCredit			BIGINT		OUTPUT

AS
/*
	Created: 20240822@Casey.Huynh
	Task : CTS - Match Monitor Parlay, Get New Ticket
	DB	 : bodb02

	Revisions:
		- 20240822@Casey.Huynh: Created [Redmine ID: 152883]
		- 20241210@Thomas.Nguyen: HF not show data in MM detail for 14/BK [Redmine ID: #214867]
		- 20250428@Thomas.Nguyen: Upgrade CurrencyID datatype [Redmine ID: #225335]

	Params Explaination:

		@ListSuspiciousRefno: format JSON Get trans from table Bettransm
			@ListSuspiciousRefno = '[{"TransID":1, "Reason":'HED', "GroupId":1},{"TransID":1, "Reason":'GB', "GroupId":1},{"TransID":2, "Reason":'GB', "GroupId":1},{"TransID":3, "Reason":'HED', "Group":1}]'
		
		@ViewMode	: TINYINT
			@ViewMode=0: Ticket Type = 'All Ticket'			
			@ViewMode=1: Ticket Type = 'Suspicious Ticket'

		@ListSportBetType: JSON
			,@ListSportBetType='[	{"SportTypeID":1, "BetTypeID":1, "BetChoiceType":2}
								,	{"SportTypeID":2, "BetTypeID":3, "BetChoiceType":2}
								,	{"SportTypeID":2, "BetTypeID":609, "BetChoiceType":2}]'	

	Example:
		DECLARE @MaxSequenceId BIGINT,@TotalTicketAll BIGINT, @TotalTicketLicensee BIGINT,@TotalTicketCredit BIGINT;
		EXEC CTS_MatchMonitorParlay_Details_GetFilter_xtest
			@ViewMode = 1
			, @Matchid = 83679714
			, @EventDate = '2024-09-09 00:00:00'
			, @ListSportBetType = '[{"SportTypeID":1,"BetTypeID":3,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetIDPattern":null,"BetID":0}]'
			, @IsLive = 0
			, @ListSuspiciousRefno = '[{"Refno":18489152651919360,"Reason":"GB(P)","GroupId":1},{"Refno":18489155067838464,"Reason":"GB(P)","GroupId":1}]'

			, @IsExclTestCurr = 0
			, @FromTransDate = NULL
			, @ToTransDate = NULL

			, @MaxSequenceId = @MaxSequenceId OUTPUT
			, @TotalTicketAll = @TotalTicketAll OUTPUT
			, @TotalTicketLicensee = @TotalTicketLicensee OUTPUT
			, @TotalTicketCredit = @TotalTicketCredit OUTPUT

		SELECT @MaxSequenceId AS MaxSequenceId,@TotalTicketAll AS TotalTicketAll,@TotalTicketLicensee AS TotalTicketLicensee,@TotalTicketCredit AS TotalTicketCredit

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME
		,	@IsGetDataFromOrigin	BIT = 0
		,	@IsGetDataFrom14		BIT = 0
		,	@IsGetDataFromBK		BIT = 0;
		
	SET @ToTransDate = DATEADD(SECOND,1,@ToTransDate);
	
	---====================================================================================
	DECLARE @tmpBUMBData AS TABLE (BUDay DATETIME,	MBDay DATETIME);
	---====================================================================================
	
	IF	OBJECT_ID('tempdb..#tmpTransm') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTransm;
	END;

	CREATE TABLE #tmpTransm(
			TransID				BIGINT PRIMARY KEY
		,	CustID				INT
		,	Hdp1				SMALLMONEY
		,	Hdp2				SMALLMONEY
		,	LiveHomeScore		SMALLINT
		,	LiveAwayScore		SMALLINT
		,	BetTeam				NVARCHAR(10)
		,	CurrencyId			SMALLINT
		,	CurrencyName		NVARCHAR(100)
		,	Hdp					SMALLMONEY DEFAULT 0
		,	IsLicensee			BIT DEFAULT NULL
		,	BetType				SMALLINT
		,	TicketStatus		SMALLINT
		,	Danger1				TINYINT
		,	Danger2				TINYINT
		,	Danger3				TINYINT
		,	Danger4				TINYINT
		,	Danger5				TINYINT
		,	CustomerClass		SMALLINT
		,	SequenceId			BIGINT
		,	TransDate			DATETIME
		,	Refno				BIGINT
	);
	CREATE NONCLUSTERED INDEX #IX_tmpTickets_SequenceId ON #tmpTransm (SequenceId ASC);

	CREATE NONCLUSTERED INDEX #IX_tmpTickets_TransDate ON #tmpTransm (TransDate ASC);

	IF	OBJECT_ID('tempdb..#tmpInputRefno') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpInputRefno;
	END;

	CREATE TABLE #tmpInputRefno(
			Refno				BIGINT 
		,	SuspiciousReason	VARCHAR(50)
		,	SuspiciousGroupId	INT
		,	TransID				BIGINT
	);

	CREATE NONCLUSTERED INDEX #IX_tmpSuspiciousTrans_Refno ON #tmpInputRefno(Refno ASC);

	IF	OBJECT_ID('tempdb..#tmpRefno') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpRefno;
	END;
	
	CREATE TABLE #tmpRefno(
			Refno 			BIGINT 
		,	TransID			BIGINT
	);

	CREATE NONCLUSTERED INDEX #IX_tmpSuspiciousDistinctRefno_Refno ON #tmpRefno(Refno ASC);

	IF	OBJECT_ID('tempdb..#tmpSportBetType') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpSportBetType;
	END;

	CREATE TABLE #tmpSportBetType(
			SportTypeID		SMALLINT
		,	BetTypeID		INT
		,	BetChoiceType	TINYINT
		,	BetIDPattern	NVARCHAR(20)
		,	BetID			NVARCHAR(50)
	);

	CREATE NONCLUSTERED INDEX #IX_tmpSportBetType_SportTypeBetType ON #tmpSportBetType (
			SportTypeID	ASC
		,	BetTypeID	ASC
	);

	--==============================================================================================
	
	--=======GET BALANCE UP/ MOVE BET DAY===========================================================
	INSERT INTO @tmpBUMBData(BUDay,MBDay)
	EXECUTE bodb02.dbo.Age_SelBalanceUpDay;
	
	SELECT	TOP(1) @BalanceUpDay	= BUDay , @MoveBetsDay	= MBDay FROM @tmpBUMBData ;

	IF @EventDate < @BalanceUpDay
	BEGIN
		SELECT @IsGetDataFromBK = 1;
	END
	ELSE IF @EventDate <= @MoveBetsDay
	BEGIN
		SELECT @IsGetDataFrom14 = 1;
	END
	ELSE 
	BEGIN
		SELECT @IsGetDataFromOrigin = 1;
	END;

	--====================DEFINE SPORT BetTypeS=================================================================================================================
	IF @ListSportBetType <> ''
	BEGIN

		INSERT INTO #tmpSportBetType(SportTypeID,BetTypeID,BetChoiceType,BetIDPattern,BetID)
		SELECT	j.SportTypeID
			,	j.BetTypeID
			,	j.BetChoiceType
			,	j.BetIDPattern
			,	(CASE WHEN j.BetID = 0 THEN NULL ELSE CONVERT(NVARCHAR(50),j.BetID) END)
		FROM OPENJSON (@ListSportBetType) WITH (
				SportTypeID			SMALLINT		'$.SportTypeID'
			,	BetTypeID			INT				'$.BetTypeID'
			,	BetChoiceType		TINYINT			'$.BetChoiceType'
			,	BetIDPattern		NVARCHAR(20)	'$.BetIDPattern'
			,	BetID				BIGINT			'$.BetID'
			) AS j;

	END;
	
	--========================================================================================
	IF @ListSuspiciousRefno <> ''
	BEGIN

		INSERT INTO #tmpInputRefno (Refno,SuspiciousReason,SuspiciousGroupId,TransID)
		SELECT	j.Refno
			,	j.Reason
			,	j.GroupId
			,	j.TransID
		FROM OPENJSON (@ListSuspiciousRefno) WITH (
				Refno		BIGINT '$.Refno'
			,	Reason		VARCHAR(50) '$.Reason'
			,	GroupId		INT '$.GroupId'
			,	TransID		BIGINT '$.TransId'
			) AS j;

		INSERT INTO #tmpRefno
		SELECT DISTINCT tmpTs.Refno, tmpTs.TransID
		FROM #tmpInputRefno AS tmpTs WITH(NOLOCK);
		
	END;
	
	IF @ViewMode = 1 --GET Suspicious Ticket Only
	BEGIN
		IF @IsGetDataFromOrigin = 1
		BEGIN
			INSERT INTO #tmpTransm (TransID, CustID, Hdp1, Hdp2, LiveHomeScore, LiveAwayScore, BetTeam, CurrencyName, CurrencyId, BetType, Hdp, TicketStatus, Refno)
			SELECT	b.TransID
				,	b.CustID
				,	b.Hdp1
				,	b.Hdp2
				,	b.LiveHomeScore
				,	b.LiveAwayScore
				,	b.BetTeam
				,	e.Currency
				,	e.ExchangeId
				,	b.BetType
				,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
				,	b.StatusID
				,	b.Refno
			FROM #tmpRefno AS tmpTs WITH(NOLOCK)				
				INNER JOIN bodb02.dbo.bettransm AS b WITH(NOLOCK) ON tmpTs.Refno = b.Refno
				INNER JOIN bodb02.dbo.bettrans AS bt WITH(NOLOCK) ON b.Refno = bt.Refno
				INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
				INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID AND b.BetType = st.BetTypeID AND b.BetCheck = ISNULL(st.BetID,b.BetCheck)
				INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = bt.Currency
			WHERE b.Matchid = @Matchid
				AND b.Liveindicator = @IsLive
				AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND bt.Currency NOT IN (20,27,28)))
				AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate));
		END;
		
		IF @IsGetDataFrom14 = 1
		BEGIN
			INSERT INTO #tmpTransm (TransID, CustID, Hdp1, Hdp2, LiveHomeScore, LiveAwayScore, BetTeam, CurrencyName, CurrencyId, BetType, hdp, TicketStatus, Refno)
			SELECT	b.TransID
				,	b.CustID
				,	b.Hdp1
				,	b.Hdp2
				,	b.LiveHomeScore
				,	b.LiveAwayScore
				,	b.BetTeam
				,	e.Currency
				,	e.ExchangeId
				,	b.BetType
				,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS Hdp
				,	b.StatusID
				,	b.Refno
			FROM #tmpRefno AS tmpTs WITH(NOLOCK)
				INNER JOIN bodb02.dbo.bettransm14 AS b WITH(NOLOCK) ON tmpTs.Refno = b.Refno
				INNER JOIN bodb02.dbo.bettrans14 AS bt WITH(NOLOCK) ON b.Refno = bt.Refno
				INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
				INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID AND b.BetType = st.BetTypeID AND b.BetCheck = ISNULL(st.BetID,b.BetCheck)
				INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = bt.Currency
			WHERE b.Matchid = @Matchid
				AND b.Liveindicator = @IsLive
				AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND bt.Currency NOT IN (20,27,28)))
				AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate));
		END;
		
		IF @IsGetDataFromBK = 1
		BEGIN
			INSERT INTO #tmpTransm (TransID,CustID,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,BetTeam,CurrencyName,CurrencyId,BetType,Hdp,TicketStatus,Refno)
			SELECT	b.TransID
				,	b.CustID
				,	b.Hdp1
				,	b.Hdp2
				,	b.LiveHomeScore
				,	b.LiveAwayScore
				,	b.BetTeam
				,	e.Currency
				,	e.ExchangeId
				,	b.BetType
				,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS Hdp
				,	b.StatusID
				,	b.Refno
			FROM #tmpRefno AS tmpTs WITH(NOLOCK)
				INNER JOIN bodb_Archive.dbo.bettransm AS b WITH(NOLOCK) ON tmpTs.Refno = b.Refno
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS bt WITH(NOLOCK) ON bt.TransID = tmpTs.TransID
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
				INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID AND b.BetType = st.BetTypeID AND b.BetCheck = ISNULL(st.BetID,b.BetCheck)
				INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = bt.Currency
			WHERE b.Matchid = @Matchid
				AND b.Liveindicator = @IsLive
				AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND bt.Currency NOT IN (20,27,28)))
				AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate));
		END;

	END;
	
	IF @ViewMode = 0 --GET All Ticket - MM
	BEGIN
		SELECT @MaxSequenceId = (MAX(SequenceId) + 1) FROM bodb02.dbo.Bettrans WITH(NOLOCK);

		INSERT INTO #tmpTransm (TransID, CustID, Hdp1, Hdp2, LiveHomeScore, LiveAwayScore, BetTeam, CurrencyName, CurrencyId, BetType, Hdp, TicketStatus, SequenceId, Refno)
		SELECT	b.TransID
			,	b.CustID
			,	b.Hdp1
			,	b.Hdp2
			,	b.LiveHomeScore
			,	b.LiveAwayScore
			,	b.BetTeam
			,	e.Currency
			,	e.ExchangeId
			,	b.BetType
			,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS Hdp
			,	b.StatusID				
			,	bt.SequenceId
			,	b.Refno
		FROM bodb02.dbo.bettransm AS b WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettrans AS bt WITH(NOLOCK) ON b.Refno = bt.Refno
			INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
			INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID AND b.BetType = st.BetTypeID AND b.BetCheck = ISNULL(st.BetID,b.BetCheck)
			INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = bt.Currency
		WHERE b.Matchid = @Matchid
			AND b.Liveindicator = @IsLive
			AND (CAST(bt.BetCheck AS INT) & 2 = 2 -- Combo 2 bit 2
					OR CAST(bt.BetCheck AS INT) & 4 = 4) -- Combo 3 bit 3
			AND bt.BetTeam = 1						-- 1:Mix Parlay
			AND bt.BetType = 29
			AND bt.Matchid = 29	
			AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND bt.Currency NOT IN (20,27,28)))
			AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
			AND bt.SequenceId < @MaxSequenceId
	END;	
	
	UPDATE t WITH(ROWLOCK, UPDLOCK)
	SET 	t.IsLicensee = 1
		,	t.Danger1 = ISNULL(c.Danger,0)
		,	t.Danger2 = ISNULL(c.Danger2,0)
		,	t.Danger3 = ISNULL(c.Danger3,0)
		,	t.Danger4 = ISNULL(c.Danger4,0)
		,	t.Danger5 = ISNULL(c.Danger5,0)
		,	t.CustomerClass = ISNULL(c.CustomerClass,0)
	FROM #tmpTransm AS t
		INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON t.CustID = c.CustID
		INNER JOIN bodb02.dbo.Dep_CustSuper AS cs WITH (NOLOCK) ON cs.CustID = c.srecommend;

	UPDATE t WITH(ROWLOCK, UPDLOCK)
	SET 	t.IsLicensee = 0
		,	t.Danger1 = ISNULL(c.Danger,0)
		,	t.Danger2 = ISNULL(c.Danger2,0)
		,	t.Danger3 = ISNULL(c.Danger3,0)
		,	t.Danger4 = ISNULL(c.Danger4,0)
		,	t.Danger5 = ISNULL(c.Danger5,0)
		,	t.CustomerClass = ISNULL(c.CustomerClass,0)
	FROM #tmpTransm AS t
		INNER JOIN bodb02.dbo.CustInfo AS c WITH(NOLOCK) ON t.CustID = c.CustID
		INNER JOIN bodb02.dbo.CustProductStatus AS s WITH (NOLOCK) ON s.CustID = c.CustID
	WHERE t.IsLicensee IS NULL;
	
	CREATE NONCLUSTERED INDEX IX_tmpTrans_IsLicensee ON #tmpTransm (IsLicensee) INCLUDE (LiveHomeScore,LiveAwayScore,CustomerClass,Danger1,Danger2,Danger3,Danger4,Danger5,CurrencyId,CurrencyName,Hdp,Betteam,TicketStatus);
	
	/*Return Output*/

	SELECT @TotalTicketAll = COUNT(1) FROM #tmpTransm;
	SELECT @TotalTicketLicensee = COUNT(1) FROM #tmpTransm WHERE IsLicensee = 1;
	SELECT @TotalTicketCredit = COUNT(1) FROM #tmpTransm  WHERE IsLicensee = 0;
	
	SELECT	DISTINCT 
			tmpTs.LiveHomeScore
		,	tmpTs.LiveAwayScore
		,	tmpTs.IsLicensee		
		,	tmpTs.CustomerClass
		,	tmpTs.Danger1
		,	tmpTs.Danger2
		,	tmpTs.Danger3
		,	tmpTs.Danger4
		,	tmpTs.Danger5
		,	tmpTs.CurrencyId
		,	tmpTs.CurrencyName
		,	tmpSt.SuspiciousReason
		,	tmpSt.SuspiciousGroupId
		,	tmpTs.Hdp
		,	tmpTs.Betteam
		,	tmpTs.TicketStatus
	FROM #tmpTransm AS tmpTs
		LEFT JOIN #tmpInputRefno AS tmpSt ON tmpSt.Refno = tmpTs.Refno
	;

	DROP TABLE IF EXISTS #tmpSportBetType;
	DROP TABLE IF EXISTS #tmpTransm;
	DROP TABLE IF EXISTS #tmpInputRefno;
END;