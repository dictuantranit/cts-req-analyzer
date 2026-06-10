/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CTS_MatchMonitorParlay_Details_GetTicket]
		@ViewMode				TINYINT = 1
	,	@EventDate				DATETIME = '1900-09-22'
	,	@ListRefno				VARCHAR(MAX)
	,	@Matchid				INT = 0
	,	@IsLive					BIT = 1
	,	@Bettype				INT 
	,	@BetID					BIGINT 
	,	@ListBetType			VARCHAR(MAX)
	,	@FromTransDate			DATETIME = NULL
	,	@ToTransDate			DATETIME = NULL	
	,	@ListScore				VARCHAR(MAX) = NULL
	,	@IsLicensee				BIT = NULL
	,	@ListCustomerClass		VARCHAR(MAX) = NULL	
	,	@ListDanger				VARCHAR(MAX) = NULL
	,	@ListCurrency			VARCHAR(MAX) = NULL
	,	@ListReason				VARCHAR(MAX) = NULL
	,	@ListAGroup				VARCHAR(MAX) = NULL
	,	@ListMGroup				VARCHAR(MAX) = NULL	
	,	@ListHDPBetTeam			VARCHAR(MAX) = NULL
	,	@CustAmountRM			MONEY = 0	
	,	@ListStatus				VARCHAR(50) = NULL
	--============================================================
	,	@LastScannedSequenceID		BIGINT = 0
	,	@LastTransDate				DATETIME = NULL	
	,	@BatchSize					INT = 500	
	,	@IsExclTestCurr				BIT = 0


	,	@MinSequenceId				BIGINT = NULL OUTPUT
	,	@MinTransDate				DATETIME = NULL OUTPUT
	,	@TotalTicket				INT = NULL OUTPUT
AS
/*
	Created: 20240822@Casey.Huynh
	Task : CTS - Match Monitor Parlay, Get New Ticket
	DB	 : bodb02

	Revisions:
		- 20240822@Casey.Huynh: Created [Redmine ID: 152883]
		- 20250428@Thomas.Nguyen: Upgrade CurrencyID datatype [Redmine ID: #225335]

	Params Explaination:

		@ListSuspiciousTransIdm: format JSON Get trans from table Bettransm
			@ListSuspiciousTransIdm = '[{"TransId":1, "Reason":'HED', "GroupId":1},{"TransId":1, "Reason":'GB', "GroupId":1},{"TransId":2, "Reason":'GB', "GroupId":1},{"TransId":3, "Reason":'HED', "Group":1}]'
		
		@ViewMode	: TINYINT (Match Monitor Details Page map TicketType)
			@ViewMode=0: Ticket Type = 'All Ticket'			
			@ViewMode=1: Ticket Type = 'Suspicious Ticket'

		@ListBetType: JSON
			,@ListBetType='[	{"SportTypeID":1, "BetTypeID":1, "BetChoiceType":2}
								,	{"SportTypeID":2, "BetTypeID":3, "BetChoiceType":2}
								,	{"SportTypeID":2, "BetTypeID":609, "BetChoiceType":2}]'	
		@IsLicensee: 1: Licensee ELS 0, (Match Monitor Details Page map Site)

	Example:
		DECLARE @MinSequenceId BIGINT,@TotalTicket BIGINT;

		EXEC CTS_MatchMonitorParlay_Details_GetTicket
			 @ViewMode = 0
			, @EventDate = '2024-09-09'
			, @ListRefno = '[		{"Refno":18489152651919360,"Reason":"GB(P)","AGroup":1,"MGroup":3}
								,	{"Refno":18489155067838464,"Reason":"GB(P)","AGroup":2,"MGroup":4}
							]'
			, @Matchid = 83679714
			, @IsLive = 0
			, @ListBetType = '[{"SportTypeID":1,"BetTypeID":3,"BetChoiceType":2,"BetChoiceHome":"h","BetChoiceAway":"a","BetIDPattern":null,"BetID":0
										, "BetChoiceHomeFullName":"Home", "BetChoiceAwayFullName":"Away"
									}]'
			, @FromTransDate = NULL
			, @ToTransDate = NULL
			, @ListScore = NULL--'0-0'
			, @IsLicensee = NULL--1
			, @ListCustomerClass = NULL--'200'
			, @ListDanger = NULL--'[{"Danger1":0,"Danger2":0,"Danger3":0,"Danger4":0,"Danger5":0}]'
			, @ListCurrency = NULL-- '15,4'
			, @ListReason = NULL-- 'GB(P)'
			, @ListAGroup = 1 --1
			, @ListMGroup = NULL --
			, @ListHDPBetTeam = NULL
			, @CustAmountRM = NULL
			, @ListStatus = NULL

			, @LastScannedSequenceID = 119786280727
			, @LastTransDate = NULL
			, @BatchSize = 100
			, @IsExclTestCurr = NULL
		, @MinSequenceId=@MinSequenceId OUTPUT,@TotalTicket=@TotalTicket OUTPUT;
		SELECT @MinSequenceId AS MinSequenceId ,@TotalTicket AS  TotalTicket;
*/
BEGIN

	SET NOCOUNT ON;

	DECLARE @BalanceUpDay			SMALLDATETIME
		,	@MoveBetsDay			SMALLDATETIME
		,	@IsGetDataFromOrigin	BIT = 0
		,	@IsGetDataFrom14		BIT = 0
		,	@IsGetDataFromBK		BIT = 0
		,	@IsFilter				BIT = 0
		;

	DECLARE @tmpBUMBData AS TABLE (BUDay DATETIME,	MBDay DATETIME);
	
	DECLARE @DBSource_Orig	TINYINT = 1
		,	@DBSource_14	TINYINT = 2
		,	@DBSource_BK	TINYINT = 3

	DECLARE @Order_MainTicket		TINYINT = 0
		,	@Order_SubMainMatch		TINYINT = 1
		,	@Order_SubOtherMatch	TINYINT = 2

	--==================================================================
	IF	OBJECT_ID('tempdb..#tmpRefnoInfo') IS NOT NULL
	BEGIN
		DROP TABLE #tmpRefnoInfo;
	END;

	CREATE TABLE #tmpRefnoInfo(
			Refno		BIGINT  
		,	Reason		VARCHAR(50) DEFAULT '0'
		,	AGroup		INT
		,	MGroup		INT
	);
	--========================================================================
	IF	OBJECT_ID('tempdb..#tmpRefno') IS NOT NULL
	BEGIN
		DROP TABLE #tmpRefno;
	END;

	CREATE TABLE #tmpRefno(
			Refno BIGINT PRIMARY KEY
		,	SequenceID BIGINT
	);

	--========================================================================
	IF	OBJECT_ID('tempdb..#tmpCustRefno') IS NOT NULL
	BEGIN
		DROP TABLE #tmpCustRefno;
	END;

	CREATE TABLE #tmpCustRefno(
			CustID	INT
		,	Refno	BIGINT 
	);

	CREATE CLUSTERED INDEX CIX_#tmpCustRefno_CustIDRefno ON #tmpCustRefno(CustID,Refno);
	--========================================================================
	IF	OBJECT_ID('tempdb..#tmpBetType') IS NOT NULL
	BEGIN
		DROP TABLE #tmpBetType;
	END;

	CREATE TABLE #tmpBetType(
			BetTypeID				INT
		,	BetID					BIGINT
		,	BetChoiceType			TINYINT
		,	BetChoiceHome			NVARCHAR(10)
		,	BetChoiceAway			NVARCHAR(10)
		,	BetChoiceHomeFullName	NVARCHAR(10)
		,	BetChoiceAwayFullName	NVARCHAR(10)
		
	);
	--========================================================================	
	IF	OBJECT_ID('tempdb..#tmpMainTicket') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpMainTicket;
	END;

	CREATE TABLE #tmpMainTicket(
			Refno			BIGINT
		,	TransID			BIGINT
		,	TransDate		DATETIME
		,	Combinition		SMALLINT -- 2: Double, 3: Trible
		,	TicketType		SMALLINT
		,	Stake			MONEY --Amount = Stake* ActualRate
		,	OrgStake		MONEY				
		,	BetFrom			NVARCHAR(4)
		,	Reason			VARCHAR(50) DEFAULT '0'
		,	ListReason		VARCHAR(MAX)
		,	AGroup			INT DEFAULT 0
		,	MGroup			INT DEFAULT 0			
		,	Odds			MONEY

		,	CustID			INT
		,	UserName		NVARCHAR(50)
		,	IsLicensee		BIT
		,	CurrencyName	NVARCHAR(100)
		,	CurrencyID		SMALLINT		
		,	Danger1			TINYINT
		,	Danger2			TINYINT
		,	Danger3			TINYINT
		,	Danger4			TINYINT
		,	Danger5			TINYINT
		,	CustomerClass	SMALLINT
	);

	CREATE CLUSTERED INDEX CIX_tmpMainTicket_Refno ON #tmpMainTicket(Refno);
	--=================================================================================
	IF	OBJECT_ID('tempdb..#tmpMainTicketFormat') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpMainTicketFormat;
	END;

	CREATE TABLE #tmpMainTicketFormat(
			Refno			BIGINT
		,	Odds			SMALLMONEY
		,	MalayOdds		SMALLMONEY
		,	BetTeam			NVARCHAR(10)
		,	ChoiceOrder		NVARCHAR(10)
		,	TicketStatus	SMALLINT
	);
	CREATE CLUSTERED INDEX CIX_tmpMainTicketFormat_Refno ON #tmpMainTicketFormat(Refno);
	--========================================================================
	IF	OBJECT_ID('tempdb..#tmpTicketDetails') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTicketDetails;
	END;

	CREATE TABLE #tmpTicketDetails(
			SequenceID			BIGINT
		,	Refno				BIGINT
		,	DBSource			TINYINT			--1: Bettransm , 2: Bettrans14, 3: Bettrans_bk
		,	TransID				BIGINT
		,	CustID				INT
		,	Stake				MONEY --Amount
		,	OrgStake			MONEY	
		,	TicketOrder			TINYINT
		,	Matchid				INT
		,	EventDate			DATETIME
		,	EventStatus			NVARCHAR(50)
		,	GlobalShowTime			DATETIME
		,	HomeID				INT
		,	AwayID				INT
		,	LeagueID			INT
		,	LeagueName			NVARCHAR(500)
		,	IsMajorLeague		BIT
		,	SportType			SMALLINT
		,	BetType				SMALLINT
		,	BetTeamGroup		NVARCHAR(10)
		,	BetTeam				NVARCHAR(10)
		,	BetTeamFullname		NVARCHAR(10)
		,	ChoiceOrder			NVARCHAR(10)
		,	BetID				BIGINT
		,	Odds				SMALLMONEY
		,	MalayOdds			SMALLMONEY
		,	Hdp1				SMALLMONEY
		,	Hdp2				SMALLMONEY
		,	Hdp					SMALLMONEY
		,	LiveHomeScore		SMALLINT
		,	LiveAwayScore		SMALLINT
		,	LiveIndicator		BIT
		,	TicketStatus		SMALLINT
		
	);	
	CREATE CLUSTERED INDEX CIX_tmpSubTicket_Refno ON #tmpTicketDetails(Refno);
	CREATE NONCLUSTERED INDEX IX_tmpSubTicket_CustIDRefno ON #tmpTicketDetails(CustID,Refno);

	--================================================================================================
	SET @ToTransDate = DATEADD(SECOND,1,@ToTransDate);

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

	IF @BatchSize IS NULL
	BEGIN
		SET @BatchSize = 0
	END

	IF @BatchSize IS NULL OR @BetID = 0
	BEGIN
		SET @BetID = ''
	END
	--==================================================================
	IF @ListBetType <> ''
		BEGIN
			INSERT INTO #tmpBetType(BetTypeID, BetID, BetChoiceType,BetChoiceHome,BetChoiceAway,BetChoiceHomeFullName, BetChoiceAwayFullName)
			SELECT	j.BetTypeID
				,	(CASE WHEN j.BetID = 0 THEN NULL ELSE j.BetID END) AS BetID
				,	j.BetChoiceType
				,	j.BetChoiceHome
				,	j.BetChoiceAway
				,	j.BetChoiceHomeFullName
				,	j.BetChoiceAwayFullName
				
			FROM OPENJSON (@ListBetType) WITH (
					BetTypeID					INT				'$.BetTypeID'
				,	BetID						BIGINT			'$.BetID'
				,	BetChoiceType				TINYINT			'$.BetChoiceType'
				,	BetChoiceHome				NVARCHAR(10)	'$.BetChoiceHome'
				,	BetChoiceAway				NVARCHAR(10)	'$.BetChoiceAway'
				,	BetChoiceHomeFullName		NVARCHAR(10)	'$.BetChoiceHomeFullName'
				,	BetChoiceAwayFullName		NVARCHAR(10)	'$.BetChoiceAwayFullName'	
				) AS j;
				
			CREATE CLUSTERED INDEX CX_tmpBetType_BetTypeIDBetID ON #tmpBetType(BetTypeID, BetID);

		END;
	
	IF @ListRefno <> ''
	BEGIN
		INSERT INTO #tmpRefnoInfo (Refno,Reason,AGroup,MGroup)
		SELECT	j.Refno
			,	j.Reason
			,	j.AGroup
			,	j.MGroup
		FROM OPENJSON (@ListRefno) WITH (
				Refno		BIGINT		'$.Refno'
			,	Reason		VARCHAR(50) '$.Reason'
			,	AGroup		INT			'$.AGroup'
			,	MGroup		INT			'$.MGroup'
			) AS j;
				
		CREATE CLUSTERED INDEX CIX_tmpTransIds_Group ON #tmpRefnoInfo (Refno, Reason);	
	END;

	IF @ViewMode = 1 -- Get Fraud Ticket Only from bk, 14, org
	BEGIN
		--===============================GET SUB PARLAY TICKET - ORIGINAL===========================================
		INSERT INTO #tmpRefno(Refno)
		SELECT DISTINCT rn.Refno 
		FROM #tmpRefnoInfo AS rn WITH(NOLOCK);

		INSERT INTO #tmpTicketDetails(Refno,DBSource,TransID,CustID,TicketOrder,BetType,BetTeamGroup,BetTeam,BetTeamFullname,ChoiceOrder,BetId,Odds,MalayOdds,Hdp1,Hdp2,HDP,LiveHomeScore,LiveAwayScore,LiveIndicator,TicketStatus,Matchid,EventDate,EventStatus,GlobalShowTime,HomeId,AwayId,LeagueId,SportType)
		SELECT 	b.refno
			,	@DBSource_Orig AS DBSource
			,	b.TransID
			,	b.CustID
			,	(CASE WHEN b.Matchid = @Matchid THEN @Order_SubMainMatch 
					 ELSE @Order_SubOtherMatch	END) AS TicketOrder
			,	b.BetType
			,	(CASE WHEN sb.BetChoiceType = 2 THEN b.BetTeam ELSE '1' END) AS BetTeamGroup
			,	b.BetTeam
			,	(CASE WHEN sb.BetTypeID IS NULL THEN b.Betteam 
					ELSE CASE WHEN b.Betteam = sb.BetChoiceHome THEN sb.BetChoiceHomeFullName
							WHEN b.Betteam = sb.BetChoiceAway THEN sb.BetChoiceAwayFullName 
						 END
					END) AS BetTeamFullname
			,	(CASE WHEN b.BetTeam = sb.BetChoiceHome THEN 10
						 WHEN b.BetTeam = sb.BetChoiceAway THEN 20
						 ELSE NULL END) AS ChoiceOrder
			,	b.BetCheck AS BetId
			,	b.Odds
			,	NULL AS MalayOdds
			,	b.Hdp1
			,	b.Hdp2
			,	ABS(CASE WHEN sb.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
			,	b.LiveHomeScore
			,	b.LiveAwayScore
			,	b.LiveIndicator
			,	b.StatusID AS TicketStatus
			,	m.Matchid
			,	m.EventDate
			,	m.EventStatus
			,	m.GlobalShowTime
			,	m.HomeId
			,	m.AwayId
			,	m.LeagueId
			,	m.SportType
		FROM	#tmpRefno AS rn WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettransm AS b WITH(NOLOCK) ON rn.Refno = b.Refno	
			INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
			LEFT JOIN #tmpBetType AS sb WITH(NOLOCK) ON sb.BetTypeID = b.BetType AND ISNULL(sb.BetID,b.betcheck) = b.betcheck
		WHERE m.eventdate > @MoveBetsDay

		DELETE rn
		FROM #tmpRefno AS rn 
			INNER JOIN #tmpTicketDetails AS td WITH(NOLOCK) ON td.Refno = rn.Refno;
		
	
		INSERT INTO #tmpTicketDetails(Refno,DBSource,TransID,CustID,TicketOrder,BetType,BetTeamGroup,BetTeam,BetTeamFullname,ChoiceOrder,BetId,Odds,MalayOdds,Hdp1,Hdp2,HDP,LiveHomeScore,LiveAwayScore,LiveIndicator,TicketStatus,Matchid,EventDate,EventStatus,GlobalShowTime,HomeId,AwayId,LeagueId,SportType)
		SELECT 	b.refno
			,	@DBSource_14 AS DBSource
			,	b.TransID
			,	b.CustID
			,	(CASE WHEN b.Matchid = @Matchid THEN @Order_SubMainMatch 
					 ELSE @Order_SubOtherMatch	END) AS TicketOrder
			,	b.BetType
			,	(CASE WHEN sb.BetChoiceType = 2 THEN b.BetTeam ELSE '1' END) AS BetTeamGroup
			,	b.BetTeam
			,	(CASE WHEN sb.BetTypeID IS NULL THEN b.Betteam 
					ELSE CASE WHEN b.Betteam = sb.BetChoiceHome THEN sb.BetChoiceHomeFullName
							WHEN b.Betteam = sb.BetChoiceAway THEN sb.BetChoiceAwayFullName 
						 END
					END) AS BetTeamFullname
			,	(CASE WHEN b.BetTeam = sb.BetChoiceHome THEN 10
						 WHEN b.BetTeam = sb.BetChoiceAway THEN 20
						 ELSE NULL END) AS ChoiceOrder
			,	b.BetCheck AS BetId
			,	b.Odds
			,	NULL AS MalayOdds
			,	b.Hdp1
			,	b.Hdp2
			,	ABS(CASE WHEN sb.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
			,	b.LiveHomeScore
			,	b.LiveAwayScore
			,	b.LiveIndicator
			,	b.StatusID AS TicketStatus
			,	m.Matchid
			,	m.EventDate
			,	m.EventStatus
			,	m.GlobalShowTime
			,	m.HomeId
			,	m.AwayId
			,	m.LeagueId
			,	m.SportType
		FROM	#tmpRefno AS rn WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettransm14 b WITH(NOLOCK) ON rn.Refno = b.Refno	
			INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
			LEFT JOIN #tmpBetType AS sb WITH(NOLOCK) ON sb.BetTypeID = b.BetType AND ISNULL(sb.BetID,b.betcheck) = b.betcheck
		WHERE m.eventdate BETWEEN @BalanceUpDay AND @MoveBetsDay

		DELETE rn
		FROM #tmpRefno AS rn 
			INNER JOIN #tmpTicketDetails AS td WITH(NOLOCK) ON td.Refno = rn.Refno;

		INSERT INTO #tmpTicketDetails(Refno,DBSource,TransID,CustID,TicketOrder,BetType,BetTeamGroup,BetTeam,BetTeamFullname,ChoiceOrder,BetId,Odds,MalayOdds,Hdp1,Hdp2,HDP,LiveHomeScore,LiveAwayScore,LiveIndicator,TicketStatus,Matchid,EventDate,EventStatus,GlobalShowTime,HomeId,AwayId,LeagueId,SportType)
		SELECT 	b.refno
			,	@DBSource_bk AS DBSource
			,	b.TransID
			,	b.CustID
			,	(CASE WHEN b.Matchid = @Matchid THEN @Order_SubMainMatch 
					 ELSE @Order_SubOtherMatch	END) AS TicketOrder
			,	b.BetType
			,	(CASE WHEN sb.BetChoiceType = 2 THEN b.BetTeam ELSE '1' END) AS BetTeamGroup
			,	b.BetTeam
			,	(CASE WHEN sb.BetTypeID IS NULL THEN b.Betteam 
					ELSE CASE WHEN b.Betteam = sb.BetChoiceHome THEN sb.BetChoiceHomeFullName
							WHEN b.Betteam = sb.BetChoiceAway THEN sb.BetChoiceAwayFullName 
						 END
					END) AS BetTeamFullname
			,	(CASE WHEN b.BetTeam = sb.BetChoiceHome THEN 10
						 WHEN b.BetTeam = sb.BetChoiceAway THEN 20
						 ELSE NULL END) AS ChoiceOrder
			,	b.BetCheck AS BetId
			,	b.Odds
			,	NULL AS MalayOdds
			,	b.Hdp1
			,	b.Hdp2
			,	ABS(CASE WHEN sb.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
			,	b.LiveHomeScore
			,	b.LiveAwayScore
			,	b.LiveIndicator
			,	b.StatusID AS TicketStatus
			,	m.Matchid
			,	m.EventDate
			,	m.EventStatus
			,	m.GlobalShowTime
			,	m.HomeId
			,	m.AwayId
			,	m.LeagueId
			,	m.SportType
		FROM	#tmpRefno AS rn WITH(NOLOCK)
			INNER JOIN bodb_Archive.dbo.bettransm b WITH(NOLOCK) ON rn.Refno = b.Refno	
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
			LEFT JOIN #tmpBetType AS sb WITH(NOLOCK) ON sb.BetTypeID = b.BetType AND ISNULL(sb.BetID,b.betcheck) = b.betcheck
		WHERE m.eventdate < @BalanceUpDay

		DELETE rn
		FROM #tmpRefno AS rn 
		
		--===============================GET MAIN PARLAY TICKET - ORIGINAL===========================================

		INSERT INTO #tmpMainTicket(Refno,TransID,TransDate,Combinition,TicketType,Stake,OrgStake,BetFrom,Reason,ListReason,AGroup,MGroup,CustID,CurrencyName,CurrencyID)
		SELECT	bt.Refno
			,	bt.TransID
			,	bt.TransDate
			,	CASE WHEN CAST(bt.BetCheck AS INT) & 2 = 2 THEN 2 -- Combo 2 bit 2
					 WHEN CAST(bt.BetCheck AS INT) & 4 = 4 THEN 3 -- Combo 3 bit 3 
				END AS Combinition
			,	2 AS TicketType
			,	bt.Stake * bt.ActualRate AS Stake
			,	bt.Stake AS OrgStake
			,	bt.BetFrom
			,	ISNULL(rn.Reason,'0')
			,	rn.Reason AS ListReason
			,	ISNULL(rn.AGroup,0)
			,	ISNULL(rn.MGroup,0)
			,	bt.CustID
			,	e.Currency AS CurrencyName
			,	e.ExchangeId AS CurrencyID
		FROM	#tmpRefnoInfo AS rn WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettrans AS bt WITH(NOLOCK) ON rn.Refno = bt.Refno
			INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) ON e.ExchangeId = bt.currency
		WHERE (@FromTransDate IS NULL OR (bt.TransDate >= @FromTransDate AND bt.TransDate < @ToTransDate));

		DELETE rn
		FROM #tmpRefnoInfo AS rn 
			INNER JOIN #tmpMainTicket AS td WITH(NOLOCK) ON td.Refno = rn.Refno;

		INSERT INTO #tmpMainTicket(Refno,TransID,TransDate,Combinition,TicketType,Stake,OrgStake,BetFrom,Reason,ListReason,AGroup,MGroup,CustID,CurrencyName,CurrencyID)
		SELECT	bt.Refno
			,	bt.TransID
			,	bt.TransDate
			,	CASE WHEN CAST(bt.BetCheck AS INT) & 2 = 2 THEN 2 -- Combo 2 bit 2
					 WHEN CAST(bt.BetCheck AS INT) & 4 = 4 THEN 3 -- Combo 3 bit 3 
				END AS Combinition
			,	2 AS TicketType
			,	bt.Stake * bt.ActualRate AS Stake
			,	bt.Stake AS OrgStake
			,	bt.BetFrom
			,	ISNULL(rn.Reason,'0')
			,	rn.Reason AS ListReason
			,	ISNULL(rn.AGroup,0)
			,	ISNULL(rn.MGroup,0)
			,	bt.CustID
			,	e.Currency AS CurrencyName
			,	e.ExchangeId AS CurrencyID
		FROM #tmpRefnoInfo AS rn WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettrans14 bt WITH(NOLOCK) ON rn.Refno = bt.Refno
			INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) ON e.ExchangeId = bt.currency
		WHERE (@FromTransDate IS NULL OR (bt.TransDate >= @FromTransDate AND bt.TransDate < @ToTransDate));
		
		DELETE rn
		FROM #tmpRefnoInfo AS rn 
			INNER JOIN #tmpMainTicket AS td WITH(NOLOCK) ON td.Refno = rn.Refno;

		INSERT INTO #tmpCustRefno(CustID, Refno)
		SELECT DISTINCT td.CustID, td.Refno 
		FROM #tmpRefnoInfo AS rn WITH(NOLOCK)
			INNER JOIN #tmpTicketDetails AS td WITH(NOLOCK) ON td.Refno = rn.Refno;	

		INSERT INTO #tmpMainTicket(Refno,TransID,TransDate,Combinition,TicketType,Stake,OrgStake,BetFrom,Reason,ListReason,AGroup,MGroup,CustID,CurrencyName,CurrencyID)
		SELECT	bt.Refno
			,	bt.TransID
			,	bt.TransDate
			,	CASE WHEN CAST(bt.BetCheck AS INT) & 2 = 2 THEN 2 -- Combo 2 bit 2
					 WHEN CAST(bt.BetCheck AS INT) & 4 = 4 THEN 3 -- Combo 3 bit 3 
				END AS Combinition
			,	2 AS TicketType
			,	bt.Stake * bt.ActualRate AS Stake
			,	bt.Stake AS OrgStake
			,	bt.BetFrom
			,	ISNULL(rn.Reason,'0')
			,	rn.Reason AS ListReason
			,	ISNULL(rn.AGroup,0)
			,	ISNULL(rn.MGroup,0)
			,	bt.CustID
			,	e.Currency AS CurrencyName
			,	e.ExchangeId AS CurrencyID
		FROM #tmpCustRefno AS cr
			INNER JOIN #tmpRefnoInfo AS rn WITH(NOLOCK) ON rn.Refno = cr.Refno
			INNER JOIN bodb_Archive.dbo.bettrans_bk AS bt WITH(NOLOCK) ON bt.CustID = cr.CustID AND bt.refno = cr.Refno
			INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) ON e.ExchangeId = bt.currency
			LEFT JOIN #tmpMainTicket AS mt WITH(NOLOCK) ON mt.Refno = rn.Refno
		WHERE (@FromTransDate IS NULL OR (bt.TransDate >= @FromTransDate AND bt.TransDate < @ToTransDate))
			AND mt.Refno IS NULL;
	END;

	IF @ViewMode = 0 --Get ALL Ticket from orig
	BEGIN		
		IF @BatchSize <= 0 
		BEGIN -- Get total Trans
			INSERT INTO #tmpRefno(Refno)
			SELECT DISTINCT b.Refno
			FROM bodb02.dbo.bettransm AS b WITH(NOLOCK)
				INNER JOIN bodb02.dbo.Bettrans bt WITH(NOLOCK) ON b.Refno = bt.Refno
				INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
			WHERE m.EventDate > @MoveBetsDay	
				AND bt.SequenceID < @LastScannedSequenceID
				AND b.Matchid = @Matchid
				AND (CAST(bt.BetCheck AS INT) & 2 = 2 -- Combo 2 bit 2
					OR CAST(bt.BetCheck AS INT) & 4 = 4) -- Combo 3 bit 3
				AND bt.BetTeam = 1						-- 1:Mix Parlay
				AND bt.BetType = 29
				AND bt.Matchid = 29	
				AND b.liveindicator = @IsLive
				AND b.bettype = @Bettype
				AND b.Betcheck = @BetID
		END
		ELSE IF @BatchSize > 0 -- GET Ticket Details Info By Batch Size
		BEGIN 
			INSERT INTO #tmpRefno(Refno, SequenceID)
			SELECT DISTINCT TOP(@BatchSize) bt.Refno, bt.sequenceid
			FROM bodb02.dbo.bettransm AS b WITH(NOLOCK)
				INNER JOIN bodb02.dbo.Bettrans bt WITH(NOLOCK) ON b.Refno = bt.Refno
				INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
			WHERE m.EventDate > @MoveBetsDay
				AND b.Matchid = @Matchid
				AND (CAST(bt.BetCheck AS INT) & 2 = 2 -- Combo 2 bit 2
					OR CAST(bt.BetCheck AS INT) & 4 = 4) -- Combo 3 bit 3
				AND bt.BetTeam = 1						-- 1:Mix Parlay
				AND bt.BetType = 29
				AND bt.Matchid = 29
				AND b.liveindicator = @IsLive
				AND b.bettype = @Bettype
				AND b.Betcheck = @BetID
				AND bt.SequenceID < @LastScannedSequenceID				
			ORDER BY bt.SequenceID DESC

			SET @MinSequenceID = (SELECT MIN(SequenceID) FROM #tmpRefno WITH(NOLOCK));
		END

		INSERT INTO #tmpTicketDetails(Refno,DBSource,TransID,CustID,TicketOrder,BetType,BetTeamGroup,BetTeam,BetTeamFullname,ChoiceOrder,BetId,Odds,MalayOdds, Hdp1,Hdp2,HDP,LiveHomeScore,LiveAwayScore,LiveIndicator,TicketStatus,Matchid,EventDate,EventStatus,GlobalShowTime,HomeId,AwayId,LeagueId,SportType)
		SELECT 	b.refno
			,	@DBSource_Orig AS DBSource
			,	b.TransID
			,	b.CustID
			,	(CASE WHEN b.Matchid = @Matchid THEN @Order_SubMainMatch 
					 ELSE @Order_SubOtherMatch	END) AS TicketOrder
			,	b.BetType
			,	(CASE WHEN sb.BetChoiceType = 2 THEN b.BetTeam ELSE '1' END) AS BetTeamGroup
			,	b.BetTeam
			,	(CASE WHEN sb.BetTypeID IS NULL THEN b.Betteam 
					ELSE CASE WHEN b.Betteam = sb.BetChoiceHome THEN sb.BetChoiceHomeFullName
							WHEN b.Betteam = sb.BetChoiceAway THEN sb.BetChoiceAwayFullName 
						 END
					END) AS BetTeamFullname
			,	(CASE WHEN b.BetTeam = sb.BetChoiceHome THEN 10
						 WHEN b.BetTeam = sb.BetChoiceAway THEN 20
						 ELSE NULL END) AS ChoiceOrder
			,	b.BetCheck AS BetId
			,	b.Odds
			,	NULL AS MalayOdds
			,	b.Hdp1
			,	b.Hdp2
			,	ABS(CASE WHEN sb.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
			,	b.LiveHomeScore
			,	b.LiveAwayScore
			,	b.LiveIndicator
			,	b.StatusID AS TicketStatus
			,	m.Matchid
			,	m.EventDate
			,	m.EventStatus
			,	m.GlobalShowTime
			,	m.HomeId
			,	m.AwayId
			,	m.LeagueId
			,	m.SportType
		FROM	#tmpRefno AS rn WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettransm AS b WITH(NOLOCK) ON rn.Refno = b.Refno	
			INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
			LEFT JOIN #tmpBetType AS sb WITH(NOLOCK) ON sb.BetTypeID = b.BetType AND ISNULL(sb.BetID,b.betcheck) = b.betcheck
		WHERE m.eventdate > @MoveBetsDay;

		DELETE rn
		FROM #tmpRefno AS rn 
			INNER JOIN #tmpTicketDetails AS td WITH(NOLOCK) ON td.Refno = rn.Refno;

		INSERT INTO #tmpTicketDetails(Refno,DBSource,TransID,CustID,TicketOrder,BetType,BetTeamGroup,BetTeam,BetTeamFullname,ChoiceOrder,BetId,Odds,MalayOdds,Hdp1,Hdp2,HDP,LiveHomeScore,LiveAwayScore,LiveIndicator,TicketStatus,Matchid,EventDate,EventStatus,GlobalShowTime,HomeId,AwayId,LeagueId,SportType)
		SELECT 	b.refno
			,	@DBSource_14 AS DBSource
			,	b.TransID
			,	b.CustID
			,	(CASE WHEN b.Matchid = @Matchid THEN @Order_SubMainMatch 
					 ELSE @Order_SubOtherMatch	END) AS TicketOrder
			,	b.BetType
			,	(CASE WHEN sb.BetChoiceType = 2 THEN b.BetTeam ELSE '1' END) AS BetTeamGroup
			,	b.BetTeam
			,	(CASE WHEN sb.BetTypeID IS NULL THEN b.Betteam 
					ELSE CASE WHEN b.Betteam = sb.BetChoiceHome THEN sb.BetChoiceHomeFullName
							WHEN b.Betteam = sb.BetChoiceAway THEN sb.BetChoiceAwayFullName 
						 END
					END) AS BetTeamFullname
			,	(CASE WHEN b.BetTeam = sb.BetChoiceHome THEN 10
						 WHEN b.BetTeam = sb.BetChoiceAway THEN 20
						 ELSE NULL END) AS ChoiceOrder
			,	b.BetCheck AS BetId
			,	b.Odds
			,	NULL AS MalayOdds
			,	b.Hdp1
			,	b.Hdp2
			,	ABS(CASE WHEN sb.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
			,	b.LiveHomeScore
			,	b.LiveAwayScore
			,	b.LiveIndicator
			,	b.StatusID AS TicketStatus
			,	m.Matchid
			,	m.EventDate
			,	m.EventStatus
			,	m.GlobalShowTime
			,	m.HomeId
			,	m.AwayId
			,	m.LeagueId
			,	m.SportType
		FROM	#tmpRefno AS rn WITH(NOLOCK)
			INNER JOIN bodb02.dbo.bettransm14 b WITH(NOLOCK) ON rn.Refno = b.Refno	
			INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
			LEFT JOIN #tmpBetType AS sb WITH(NOLOCK) ON sb.BetTypeID = b.BetType AND ISNULL(sb.BetID,b.betcheck) = b.betcheck
		WHERE m.eventdate BETWEEN @BalanceUpDay AND @MoveBetsDay;

		DELETE rn
		FROM #tmpRefno AS rn 
			INNER JOIN #tmpTicketDetails AS td WITH(NOLOCK) ON td.Refno = rn.Refno;

		INSERT INTO #tmpTicketDetails(Refno,DBSource,TransID,CustID,TicketOrder,BetType,BetTeamGroup,BetTeam,BetTeamFullname,ChoiceOrder,BetId,Odds,MalayOdds,Hdp1,Hdp2,HDP,LiveHomeScore,LiveAwayScore,LiveIndicator,TicketStatus,Matchid,EventDate,EventStatus,GlobalShowTime,HomeId,AwayId,LeagueId,SportType)
		SELECT 	b.refno
			,	@DBSource_bk AS DBSource
			,	b.TransID
			,	b.CustID
			,	(CASE WHEN b.Matchid = @Matchid THEN @Order_SubMainMatch 
					 ELSE @Order_SubOtherMatch	END) AS TicketOrder
			,	b.BetType
			,	(CASE WHEN sb.BetChoiceType = 2 THEN b.BetTeam ELSE '1' END) AS BetTeamGroup
			,	b.BetTeam
			,	(CASE WHEN sb.BetTypeID IS NULL THEN b.Betteam 
					ELSE CASE WHEN b.Betteam = sb.BetChoiceHome THEN sb.BetChoiceHomeFullName
							WHEN b.Betteam = sb.BetChoiceAway THEN sb.BetChoiceAwayFullName 
						 END
					END) AS BetTeamFullname
			,	(CASE WHEN b.BetTeam = sb.BetChoiceHome THEN 10
						 WHEN b.BetTeam = sb.BetChoiceAway THEN 20
						 ELSE NULL END) AS ChoiceOrder
			,	b.BetCheck AS BetId
			,	b.Odds
			,	NULL AS MalayOdds
			,	b.Hdp1
			,	b.Hdp2
			,	ABS(CASE WHEN sb.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
			,	b.LiveHomeScore
			,	b.LiveAwayScore
			,	b.LiveIndicator
			,	b.StatusID AS TicketStatus
			,	m.Matchid
			,	m.EventDate
			,	m.EventStatus
			,	m.GlobalShowTime
			,	m.HomeId
			,	m.AwayId
			,	m.LeagueId
			,	m.SportType
		FROM	#tmpRefno AS rn WITH(NOLOCK)
			INNER JOIN bodb_Archive.dbo.bettransm b WITH(NOLOCK) ON rn.Refno = b.Refno	
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON b.Matchid = m.Matchid
			LEFT JOIN #tmpBetType AS sb WITH(NOLOCK) ON sb.BetTypeID = b.BetType AND ISNULL(sb.BetID,b.betcheck) = b.betcheck
		WHERE m.eventdate < @BalanceUpDay;

		DELETE rn
		FROM #tmpRefno AS rn 

		--===============================GET MAIN PARLAY TICKET - ORIGINAL===========================================
		INSERT INTO #tmpRefno(Refno)
		SELECT DISTINCT rn.Refno 
		FROM #tmpTicketDetails AS rn WITH(NOLOCK);

		INSERT INTO #tmpMainTicket(Refno,TransID,TransDate,Combinition,TicketType,Stake,OrgStake,BetFrom,Reason,ListReason,AGroup,MGroup,CustID,CurrencyName,CurrencyID)
		SELECT	bt.Refno
			,	bt.TransID
			,	bt.TransDate
			,	CASE WHEN CAST(bt.BetCheck AS INT) & 2 = 2 THEN 2 -- Combo 2 bit 2
					 WHEN CAST(bt.BetCheck AS INT) & 4 = 4 THEN 3 -- Combo 3 bit 3 
				END AS Combinition
			,	2 AS TicketType
			,	bt.Stake * bt.ActualRate AS Stake
			,	bt.Stake AS Stake
			,	bt.BetFrom
			,	ISNULL(rn.Reason,'0')
			,	rn.Reason AS ListReason
			,	ISNULL(rn.AGroup,0)
			,	ISNULL(rn.MGroup,0)
			,	bt.CustID
			,	e.Currency AS CurrencyName
			,	e.ExchangeId AS CurrencyID
		FROM #tmpRefno AS rf WITH(NOLOCK) 			
			INNER JOIN bodb02.dbo.bettrans AS bt WITH(NOLOCK) ON rf.Refno = bt.Refno
			INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) ON e.ExchangeId = bt.currency
			LEFT JOIN #tmpRefnoInfo AS rn WITH(NOLOCK) ON rn.Refno = rf.Refno
		WHERE (@FromTransDate IS NULL OR (bt.TransDate >= @FromTransDate AND bt.TransDate < @ToTransDate));

		DELETE rn
		FROM #tmpRefnoInfo AS rn 
			INNER JOIN #tmpMainTicket AS td WITH(NOLOCK) ON td.Refno = rn.Refno;

		INSERT INTO #tmpMainTicket(Refno,TransID,TransDate,Combinition,TicketType,Stake,OrgStake,BetFrom,Reason,ListReason,AGroup,MGroup,CustID,CurrencyName,CurrencyID)
		SELECT	bt.Refno
			,	bt.TransID
			,	bt.TransDate
			,	CASE WHEN CAST(bt.BetCheck AS INT) & 2 = 2 THEN 2 -- Combo 2 bit 2
					 WHEN CAST(bt.BetCheck AS INT) & 4 = 4 THEN 3 -- Combo 3 bit 3 
				END AS Combinition
			,	2 AS TicketType
			,	bt.Stake * bt.ActualRate AS Stake
			,	bt.Stake AS OrgStake
			,	bt.BetFrom
			,	ISNULL(rn.Reason,'0')
			,	rn.Reason AS ListReason
			,	ISNULL(rn.AGroup,0)
			,	ISNULL(rn.MGroup,0)
			,	bt.CustID
			,	e.Currency AS CurrencyName
			,	e.ExchangeId AS CurrencyID
		FROM #tmpRefno AS rf WITH(NOLOCK) 			
			INNER JOIN bodb02.dbo.bettrans14 AS bt WITH(NOLOCK) ON rf.Refno = bt.Refno
			INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) ON e.ExchangeId = bt.currency
			LEFT JOIN #tmpRefnoInfo AS rn WITH(NOLOCK) ON rn.Refno = rf.Refno
		WHERE (@FromTransDate IS NULL OR (bt.TransDate >= @FromTransDate AND bt.TransDate < @ToTransDate));
		
		DELETE rn
		FROM #tmpRefno AS rn 
			INNER JOIN #tmpMainTicket AS td WITH(NOLOCK) ON td.Refno = rn.Refno;

		INSERT INTO #tmpCustRefno(CustID, Refno)
		SELECT DISTINCT td.CustID, td.Refno 
		FROM #tmpRefno AS rn WITH(NOLOCK)
			INNER JOIN #tmpTicketDetails AS td WITH(NOLOCK) ON td.Refno = rn.Refno;	

		INSERT INTO #tmpMainTicket(Refno,TransID,TransDate,Combinition,TicketType,Stake,OrgStake,BetFrom,Reason,ListReason,AGroup,MGroup,CustID,CurrencyName,CurrencyID)
		SELECT	bt.Refno
			,	bt.TransID
			,	bt.TransDate
			,	CASE WHEN CAST(bt.BetCheck AS INT) & 2 = 2 THEN 2 -- Combo 2 bit 2
					 WHEN CAST(bt.BetCheck AS INT) & 4 = 4 THEN 3 -- Combo 3 bit 3 
				END AS Combinition
			,	2 AS TicketType
			,	bt.Stake * bt.ActualRate AS Stake
			,	bt.Stake AS OrgStake
			,	bt.BetFrom
			,	ISNULL(rn.Reason,'0')
			,	rn.Reason AS ListReason
			,	ISNULL(rn.AGroup,0)
			,	ISNULL(rn.MGroup,0)
			,	bt.CustID
			,	e.Currency AS CurrencyName
			,	e.ExchangeId AS CurrencyID
		FROM #tmpCustRefno AS cr
			INNER JOIN #tmpRefnoInfo AS rn WITH(NOLOCK) ON rn.Refno = cr.Refno
			INNER JOIN bodb_Archive.dbo.bettrans_bk AS bt WITH(NOLOCK) ON bt.CustID = cr.CustID AND bt.refno = cr.Refno
			INNER JOIN bodb02.dbo.Exchange AS e WITH(NOLOCK) ON e.ExchangeId = bt.currency
			LEFT JOIN #tmpMainTicket AS mt WITH(NOLOCK) ON mt.Refno = rn.Refno
		WHERE (@FromTransDate IS NULL OR (bt.TransDate >= @FromTransDate AND bt.TransDate < @ToTransDate))
			AND mt.Refno IS NULL;

	END;
	
	----==================UPDATE Malay Odds==================
	UPDATE t WITH(ROWLOCK, UPDLOCK)
	SET t.MalayOdds = ( CASE WHEN ot.OddsType IS NOT NULL THEN (CASE WHEN t.odds <= 2 THEN (t.odds - 1)
																		WHEN t.odds > 2 THEN -(1/NULLIF((t.odds - 1),0)) 
																END)
							ELSE(	CASE WHEN t.odds <= 1 THEN t.odds
											WHEN t.odds > 1 THEN -(1/NULLIF(t.odds,0)) 
									END) 
						END)
	FROM #tmpTicketDetails AS t
		LEFT JOIN bodb02.dbo.f_Set_OddsTypeBetTypes() AS ot ON ot.BetType = t.BetType;

	INSERT INTO #tmpMainTicketFormat(Refno, Odds, MalayOdds, BetTeam, ChoiceOrder, TicketStatus)
	SELECT	st.Refno
		,	EXP(SUM(LOG(st.Odds))) AS Odds
		,	NULL MalayOdds
		,	MIN(CASE WHEN st.TicketOrder = 1 THEN st.Betteam ELSE NULL END)
		,	MIN(CASE WHEN st.TicketOrder = 1 THEN st.ChoiceOrder ELSE NULL END)
		,	MIN(CASE WHEN st.TicketOrder = 1 THEN st.TicketStatus  ELSE NULL END)
	FROM #tmpTicketDetails AS st WITH(NOLOCK)
	GROUP BY st.Refno

	INSERT INTO #tmpTicketDetails(Refno,CustID, DBSource,TransId,TicketOrder,Odds, MalayOdds, Betteam, ChoiceOrder, TicketStatus)
	SELECT 	mt.refno
		,	mt.CustID
		,	0 AS DBSource
		,	mt.TransID AS TransIdm
		,	@Order_MainTicket AS TicketOrder
		,	mf.Odds
		,	mf.MalayOdds
		,	mf.Betteam
		,	mf.ChoiceOrder
		,	mf.TicketStatus
	FROM #tmpMainTicket AS mt WITH(NOLOCK)
		INNER JOIN #tmpMainTicketFormat AS mf WITH(NOLOCK) ON mt.Refno = mf.Refno		
	
	----==================UPDATE Trans Info==================
	UPDATE t WITH(ROWLOCK, UPDLOCK)
	SET t.IsLicensee	= 1
	,	t.Danger1		= c.danger
	,	t.Danger2		= c.danger2
	,	t.Danger3		= c.danger3
	,	t.Danger4		= c.Danger4
	,	t.Danger5		= c.Danger5
	,	t.CustomerClass	= c.CustomerClass
	,	t.UserName		= c.UserName
	FROM #tmpMainTicket AS t
		INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON t.CustId = c.custid
		INNER JOIN bodb02.dbo.Dep_CustSuper AS cs WITH(NOLOCK) ON cs.custid = c.srecommend;

	UPDATE t WITH(ROWLOCK, UPDLOCK)
	SET t.IsLicensee	= 0
	,	t.Danger1		= c.danger
	,	t.Danger2		= c.danger2
	,	t.Danger3		= c.danger3
	,	t.Danger4		= c.Danger4
	,	t.Danger5		= c.Danger5
	,	t.CustomerClass	= c.CustomerClass
	,	t.UserName		= c.UserName
	FROM #tmpMainTicket AS t
		INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON t.CustId = c.custid
		INNER JOIN bodb02.dbo.CustProductStatus AS s WITH(NOLOCK) ON s.custid = c.custid
	WHERE t.IsLicensee IS NULL;

	----==================FILTERS=========================	

	IF (@ListScore IS NOT NULL) OR (@IsLicensee IS NOT NULL) OR (@ListCustomerClass <> '') OR (@ListDanger IS NOT NULL)
		OR (@ListCurrency IS NOT NULL) OR (@ListReason <> '') OR (@ListAGroup <> '') OR (@ListMGroup <> '') OR (@ListHDPBetTeam IS NOT NULL)
		OR (@ListStatus IS NOT NULL) OR (@CustAmountRM > 0) OR (@CustAmountRM > 0)
	BEGIN
		SET @IsFilter = 1;
	END;
	
	IF (@IsFilter = 1)
	BEGIN
		GOTO CHECK_FILTER;
	END;
	
	CHECK_FILTER:
		IF (@IsFilter = 1)
		BEGIN	
			--====================Fitler By Score==================				
			IF (@ListScore IS NOT NULL)
			BEGIN

				;WITH CTE_Score AS (
					SELECT LTRIM(LEFT(ssk.Value,CHARINDEX('-',ssk.Value)-1)) AS LiveHomeScore
						, RTRIM(RIGHT(ssk.Value,LEN(ssk.Value) - CHARINDEX('-',ssk.Value))) AS LiveAwayScore
					FROM STRING_SPLIT(@ListScore, ',') ssk
				)			
				DELETE td
				FROM #tmpTicketDetails AS td WITH(NOLOCK)
					LEFT JOIN CTE_Score AS s ON s.LiveHomeScore = td.LiveHomeScore AND s.LiveAwayScore = td.LiveAwayScore
				WHERE s.LiveHomeScore IS NULL
					AND td.TicketOrder = 1;

				DELETE t
				FROM #tmpMainTicket AS t WITH(NOLOCK)
					LEFT JOIN #tmpTicketDetails AS td WITH(NOLOCK) ON t.Refno = td.Refno AND td.TicketOrder = 1
				WHERE td.Refno IS NULL;

				DELETE td
				FROM #tmpTicketDetails AS td WITH(NOLOCK)
				LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
				WHERE t.Refno IS NULL;
			END;

			--========================Fitler By Site(IsLicensee)==================
			IF (@IsLicensee IS NOT NULL)
			BEGIN
				
				DELETE t
				FROM #tmpMainTicket AS t WITH(NOLOCK)
				WHERE t.IsLicensee != @IsLicensee;

				DELETE td
				FROM #tmpTicketDetails AS td WITH(NOLOCK)
					LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
				WHERE t.Refno IS NULL;

			END;

			--========================Fitler By CustomerClass==================
			IF (@ListCustomerClass <> '')
			BEGIN
				WITH CTE_CC AS (
					SELECT ssk.value AS CustomerClass FROM STRING_SPLIT(@ListCustomerClass, ',') AS ssk
				)
				DELETE t
				FROM #tmpMainTicket AS t
					LEFT JOIN CTE_CC AS c ON c.CustomerClass = ISNULL(t.CustomerClass,0)
				WHERE c.CustomerClass IS NULL;

				DELETE td
				FROM #tmpTicketDetails AS td WITH(NOLOCK)
					LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
				WHERE t.Refno IS NULL;
			END;

			--========================Fitler By Danger==================		
			IF (@ListDanger IS NOT NULL)
			BEGIN
				DECLARE @tmpSupportedDanger AS TABLE (Danger1 TINYINT, Danger2 TINYINT, Danger3 TINYINT, Danger4 TINYINT, Danger5 TINYINT);
			
				INSERT INTO @tmpSupportedDanger (Danger1,Danger2,Danger3,Danger4,Danger5)
				SELECT	ISNULL(JSON_VALUE(ssk.value, '$.Danger1'),0) AS Danger1
					,	ISNULL(JSON_VALUE(ssk.value, '$.Danger2'),0) AS Danger2
					,	ISNULL(JSON_VALUE(ssk.value, '$.Danger3'),0) AS Danger3
					,	ISNULL(JSON_VALUE(ssk.value, '$.Danger4'),0) AS Danger4
					,	ISNULL(JSON_VALUE(ssk.value, '$.Danger5'),0) AS Danger5
				FROM OPENJSON (@ListDanger) AS ssk;
				
				IF NOT EXISTS (SELECT 1 FROM @tmpSupportedDanger AS t WHERE t.Danger1 = 0 AND t.Danger2 = 0 AND t.Danger3 = 0 AND t.Danger4 = 0 AND t.Danger5 = 0)
				BEGIN
					DELETE t
					FROM #tmpMainTicket AS t
						LEFT JOIN @tmpSupportedDanger AS d1 ON d1.Danger1 = t.Danger1 AND t.Danger1 > 0
						LEFT JOIN @tmpSupportedDanger AS d2 ON d2.Danger2 = t.Danger2 AND t.Danger2 > 0
						LEFT JOIN @tmpSupportedDanger AS d3 ON d3.Danger3 = t.Danger3 AND t.Danger3 > 0
						LEFT JOIN @tmpSupportedDanger AS d4 ON d4.Danger4 = t.Danger4 AND t.Danger4 > 0
						LEFT JOIN @tmpSupportedDanger AS d5 ON d5.Danger5 = t.Danger5 AND t.Danger5 > 0
					WHERE d1.Danger1 IS NULL 
						AND d2.Danger2 IS NULL 
						AND d3.Danger3 IS NULL
						AND d4.Danger4 IS NULL
						AND d5.Danger5 IS NULL

					DELETE td
					FROM #tmpTicketDetails AS td WITH(NOLOCK)
						LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
					WHERE t.Refno IS NULL;
				END
				ELSE
				BEGIN
					DELETE t
					FROM #tmpMainTicket AS t
						LEFT JOIN @tmpSupportedDanger AS d1 ON d1.Danger1 = t.Danger1 AND t.Danger1 > 0
						LEFT JOIN @tmpSupportedDanger AS d2 ON d2.Danger2 = t.Danger2 AND t.Danger2 > 0
						LEFT JOIN @tmpSupportedDanger AS d3 ON d3.Danger3 = t.Danger3 AND t.Danger3 > 0
						LEFT JOIN @tmpSupportedDanger AS d4 ON d4.Danger4 = t.Danger4 AND t.Danger4 > 0
						LEFT JOIN @tmpSupportedDanger AS d5 ON d5.Danger5 = t.Danger5 AND t.Danger5 > 0	
					WHERE NOT (t.Danger1 = 0 AND t.Danger2 = 0 AND t.Danger3 = 0 AND t.Danger4 = 0 AND t.Danger5 = 0)
						AND d1.Danger1 IS NULL 
						AND d2.Danger2 IS NULL 
						AND d3.Danger3 IS NULL
						AND d4.Danger4 IS NULL
						AND d5.Danger5 IS NULL

					DELETE td
					FROM #tmpTicketDetails AS td WITH(NOLOCK)
						LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
					WHERE t.Refno IS NULL;
				END;

			END;

			--========================Filter By Currency==================	
			IF (@ListCurrency IS NOT NULL)
			BEGIN
				WITH CTE_Currency AS (
					SELECT ssk.value AS CurrencyId FROM STRING_SPLIT(@ListCurrency, ',') AS ssk
				)
				DELETE t
				FROM #tmpMainTicket AS t
					LEFT JOIN CTE_Currency AS curr ON curr.CurrencyId = t.CurrencyId	
				WHERE curr.CurrencyId IS NULL

				DELETE td
				FROM #tmpTicketDetails AS td WITH(NOLOCK)
					LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
				WHERE t.Refno IS NULL;
			END;

			--========================Fitler By Reason==================
			IF (@ListReason <> '') AND @ListRefno <> ''
			BEGIN
				DECLARE @tmpSupportedReason AS TABLE (Reason VARCHAR(50) DEFAULT '0' PRIMARY KEY);
				
				IF	OBJECT_ID('tempdb..#tmpTransIdReason') IS NOT NULL
				BEGIN
					DROP TABLE #tmpTransIdReason;
				END;

				CREATE TABLE #tmpTransIdReason(
						TransId			BIGINT NOT NULL PRIMARY KEY
					,	ListReason		VARCHAR(MAX)
					,	MinReason		VARCHAR(50) DEFAULT '0'	
				);
			
				INSERT INTO @tmpSupportedReason (Reason)
				SELECT ssk.value FROM STRING_SPLIT(@ListReason, ',') ssk;	

				--Delete Dup ticket 
				INSERT INTO #tmpTransIdReason(TransID, ListReason, MinReason)
				SELECT	tmpTr.TransID
					,	STRING_AGG(tmpRs.Reason, ',') WITHIN GROUP (ORDER BY tmpRs.Reason) AS Reason
					,	MIN(tmpRs.Reason)
				FROM #tmpMainTicket AS tmpTr WITH(NOLOCK)
					LEFT JOIN @tmpSupportedReason AS tmpRs ON tmpRs.Reason = tmpTr.Reason
				GROUP BY TransID;

				UPDATE tmpTk
				SET	tmpTk.ListReason = tmpTr.ListReason
				,	tmpTk.Reason = CASE WHEN tmpTr.MinReason = tmpTk.Reason THEN tmpTr.MinReason ELSE '-1' END
				FROM #tmpMainTicket AS tmpTk
					INNER JOIN #tmpTransIdReason AS tmpTr ON tmpTk.TransId = tmpTr.TransID
				
				--Delete ticket is not in Reason Filter
				DELETE t
				FROM #tmpMainTicket AS t
					LEFT JOIN @tmpSupportedReason AS c ON c.Reason = ISNULL(t.Reason,'0')
				WHERE c.Reason IS NULL

				DELETE td
				FROM #tmpTicketDetails AS td WITH(NOLOCK)
					LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
				WHERE t.Refno IS NULL;

			END;
		
			--========================Fitler By AGroup==================
			IF @ListAGroup <> ''
			BEGIN
				WITH CTE_AGroup AS (
					SELECT ssk.value AS AGroup FROM STRING_SPLIT(@ListAGroup, ',') AS ssk
				)
				DELETE t
				FROM #tmpMainTicket AS t
					LEFT JOIN CTE_AGroup AS c ON c.AGroup = ISNULL(t.AGroup,0)
				WHERE c.AGroup IS NULL

				DELETE td
				FROM #tmpTicketDetails AS td WITH(NOLOCK)
					LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
				WHERE t.Refno IS NULL;
			END;

			--========================Fitler By MGroup==================
			IF @ListMGroup <> ''
			BEGIN
				WITH CTE_MGroup AS (
					SELECT ssk.value AS MGroup FROM STRING_SPLIT(@ListMGroup, ',') AS ssk
				)
				DELETE t
				FROM #tmpMainTicket AS t	
					LEFT JOIN CTE_MGroup AS c ON c.MGroup = ISNULL(t.MGroup,0)
				WHERE c.MGroup IS NULL;

				DELETE td
				FROM #tmpTicketDetails AS td WITH(NOLOCK)
					LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
				WHERE t.Refno IS NULL;
			END;

			--========================Fitler By HDP(BetTeam)==================	
			IF (@ListHDPBetTeam IS NOT NULL)
			BEGIN

				IF EXISTS (	SELECT 1 
							FROM #tmpBetType bt 
							WHERE bt.BetTypeID = @Bettype AND bt.BetChoiceType = 1) --Filter BetTeam
				BEGIN
					WITH CTE_BetTeam AS (
						SELECT ssk.value AS BetTeam FROM STRING_SPLIT(@ListHDPBetTeam, ',') AS ssk
					)
					DELETE t
					FROM #tmpTicketDetails AS t
						INNER JOIN #tmpBetType AS st ON t.BetType = st.BettypeID AND st.BetChoiceType = 1
						LEFT JOIN CTE_BetTeam AS bt ON bt.BetTeam = t.BetTeam
					WHERE bt.BetTeam IS NULL
						AND t.TicketOrder = 1;		

					DELETE t
					FROM #tmpMainTicket AS t WITH(NOLOCK)
						LEFT JOIN #tmpTicketDetails AS td WITH(NOLOCK) ON t.Refno = td.Refno AND td.TicketOrder = 1
					WHERE td.Refno IS NULL;

					DELETE td
					FROM #tmpTicketDetails AS td WITH(NOLOCK)
						LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
					WHERE t.Refno IS NULL;
				END
			
				ELSE IF EXISTS (SELECT 1
								FROM #tmpBetType bt 
								WHERE bt.BetTypeID = @Bettype AND bt.BetChoiceType = 2) --Filter Hdp
				BEGIN
					;WITH CTE_Hdp AS (
						SELECT ssk.value AS Hdp FROM STRING_SPLIT(@ListHDPBetTeam, ',') AS ssk
					)
					DELETE t
					FROM #tmpTicketDetails AS t
						INNER JOIN #tmpBetType AS st ON t.BetType = st.BettypeID AND st.BetChoiceType = 2
						LEFT JOIN CTE_Hdp AS h ON h.Hdp = t.Hdp
					WHERE h.Hdp IS NULL
						AND t.hdp IS NOT NULL
						AND t.TicketOrder = 1;
					
					DELETE t
					FROM #tmpMainTicket AS t WITH(NOLOCK)
						LEFT JOIN #tmpTicketDetails AS td WITH(NOLOCK) ON t.Refno = td.Refno AND td.TicketOrder = 1
					WHERE td.Refno IS NULL;

					DELETE td
					FROM #tmpTicketDetails AS td WITH(NOLOCK)
						LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
					WHERE t.Refno IS NULL
					
				END;
			END;	

			--========================Fitler By Status==================	
			IF (@ListStatus IS NOT NULL) 
			BEGIN
				WITH CTE_Status AS (
					SELECT ssk.value AS StatusID FROM STRING_SPLIT(@ListStatus, ',') AS ssk
				)
				DELETE t
				FROM #tmpTicketDetails AS t
					LEFT JOIN CTE_Status AS s ON s.StatusID = t.TicketStatus
				WHERE s.StatusID IS NULL
					AND t.TicketOrder = 1 --Sub Ticket of View Match							
				
				DELETE t
				FROM #tmpMainTicket AS t WITH(NOLOCK)
					LEFT JOIN #tmpTicketDetails AS td WITH(NOLOCK) ON t.Refno = td.Refno AND td.TicketOrder = 1
				WHERE td.Refno IS NULL;

				DELETE td
				FROM #tmpTicketDetails AS td WITH(NOLOCK)
					LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
				WHERE t.Refno IS NULL;	

			END;		

			--========================Cust Amount(RM)==================	
			IF (@CustAmountRM > 0)
			BEGIN
				IF	OBJECT_ID('tempdb..#tmpCustAmount') IS NOT NULL
				BEGIN
					DROP TABLE	#tmpCustAmount;
				END;

				CREATE TABLE	#tmpCustAmount(
						CustId			INT
					,	BetTeamGroup	NVARCHAR(10)
				);

				INSERT INTO #tmpCustAmount(CustId, BetTeamGroup)
				SELECT	mt.CustId
					,	st.BetTeamGroup
					--,	SUM(mt.Stake)
				FROM #tmpMainTicket AS mt WITH(NOLOCK)
					INNER JOIN #tmpTicketDetails AS st WITH(NOLOCK) ON st.Refno = mt.Refno AND TicketOrder = 1
				GROUP BY mt.CustId, st.BetTeamGroup
				HAVING SUM(mt.Stake) >= @CustAmountRM;

				CREATE CLUSTERED INDEX CIX_tmpCustAmount_Group ON #tmpCustAmount (CustID, BetTeamGroup);

				DELETE tmpTk
				FROM #tmpTicketDetails AS tmpTk WITH(NOLOCK)
					LEFT JOIN #tmpCustAmount AS tmpCa WITH(NOLOCK) ON tmpCa.CustId = tmpTk.CustId and tmpCa.BetTeamGroup = tmpTk.BetTeamGroup
				WHERE tmpTk.TicketOrder = 1
					AND tmpCa.CustId IS NULL

				DELETE t
				FROM #tmpMainTicket AS t WITH(NOLOCK)
					LEFT JOIN #tmpTicketDetails AS td WITH(NOLOCK) ON t.Refno = td.Refno AND td.TicketOrder = 1
				WHERE td.Refno IS NULL;

				DELETE td
				FROM #tmpTicketDetails AS td WITH(NOLOCK)
					LEFT JOIN #tmpMainTicket AS t WITH(NOLOCK) ON t.Refno = td.Refno
				WHERE t.Refno IS NULL;
			END;		
		END;	

	--=========================--RETURN DATA============================--
	IF (@BatchSize = 0)
	BEGIN		
		SET @TotalTicket = (SELECT COUNT(DISTINCT Refno) FROM #tmpTicketDetails AS td WITH(NOLOCK));
	END
	ELSE 
	BEGIN		
		SELECT	st.CustId
			,	mt.CustomerClass
			,	mt.Danger1
			,	mt.Danger2
			,	mt.Danger3
			,	mt.Danger4
			,	mt.Danger5
			--	CHOICE------------
			,	st.ChoiceOrder
			,	st.TicketOrder
			,	st.Refno
			,	mt.Combinition
			,	st.TransId AS TransID			
			,	st.Matchid
			,	h.TeamName AS HomeName
			,	a.TeamName AS AwayName
			,	bt.typenamee AS BetTypeName
			,	st.BetTeam
			,	st.BetTeamFullName
			,	s.SportName AS SportType
			,	l.LeagueName
			,	st.GlobalShowTime AS KickOffTime
			------------------------------
			,	st.TicketStatus
			,	st.Odds
			,	st.MalayOdds
			,	mt.CurrencyName
			,	(CASE WHEN st.TicketOrder = 0 THEN mt.Stake ELSE NULL END) AS Stake
			,	(CASE WHEN st.TicketOrder = 0 THEN mt.OrgStake ELSE NULL END) AS OrgStake
			,	(CASE WHEN TicketOrder > 0 AND st.Hdp IS NULL THEN st.BetTeam ELSE CONVERT(VARCHAR(10),st.Hdp) END) AS Choice
			,	st.LiveHomeScore
			,	st.LiveAwayScore
			,	st.LiveIndicator
			,	mt.TransDate
			,	mt.BetFrom
			,	mt.AGroup
			,	mt.MGroup
			,	mt.Reason			
			,	ISNULL(mt.ListReason,mt.Reason) AS ListReason			
		FROM #tmpMainTicket AS mt WITH(NOLOCK)
			INNER JOIN #tmpTicketDetails AS st WITH(NOLOCK) ON st.Refno = mt.Refno
			LEFT JOIN bodb02.dbo.Team AS h WITH(NOLOCK) ON h.TeamID = st.HomeID
			LEFT JOIN bodb02.dbo.Team AS a WITH(NOLOCK) ON a.TeamID = st.AwayID
			LEFT JOIN bodb02.dbo.League AS l WITH(NOLOCK) ON l.LeagueID = st.LeagueID
			LEFT JOIN bodb02.dbo.Sports AS s WITH(NOLOCK) ON s.SportType = st.SportType
			LEFT JOIN bodb02.dbo.BetType AS bt WITH(NOLOCK) ON st.BetType = bt.typeID
		ORDER BY mt.Refno ASC, TicketOrder ASC, Matchid DESC;
	END;

END