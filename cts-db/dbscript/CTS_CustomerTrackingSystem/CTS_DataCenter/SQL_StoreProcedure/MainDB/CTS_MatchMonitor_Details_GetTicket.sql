/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CTS_MatchMonitor_Details_GetTicket]
		@QueryType					TINYINT = 1
	,	@LastScannedSequenceID		BIGINT = 0
	,	@LastTransDate				DATETIME = NULL
	,	@IsLive						BIT = 1
	,	@BatchSize					INT = 500
	,	@ListTransId				VARCHAR(MAX) = ''
	,	@EventDate					DATETIME = '1900-09-22'
	,	@MatchID					INT = 0
	,	@ListSportBetType			VARCHAR(MAX)
	,	@ViewMode				TINYINT = 1	
	,	@IsLicensee					BIT = NULL
	,	@IsExclTestCurr				BIT = 0
	,	@ListCurrency				VARCHAR(MAX) = NULL
	,	@ListHDPBetTeam				VARCHAR(MAX) = NULL
	,	@ListScore					VARCHAR(MAX) = NULL
	,	@CustAmountRM				MONEY = 0
	,	@ListDanger					VARCHAR(MAX) = NULL
	,	@ListStatus					VARCHAR(50) = NULL
	,	@ListCustomerClass			VARCHAR(MAX) = NULL	
	,	@ListReason					VARCHAR(MAX) = NULL
	,	@ListAGroup					VARCHAR(MAX) = NULL
	,	@ListMGroup					VARCHAR(MAX) = NULL
	,	@FromTransDate				DATETIME = NULL
	,	@ToTransDate				DATETIME = NULL
	,	@IsCashout					BIT = NULL
	,	@UserNameList				VARCHAR(MAX) = ''

	,	@MinSequenceId				BIGINT = NULL OUTPUT
	,	@MinTransDate				DATETIME = NULL OUTPUT
	,	@TotalTicket				INT = NULL OUTPUT

AS
/*
	Created: 20210526@Long.Luu
	Task : CTS - Match Monitor Details - Get Fraud Tickets
	DB	 : bodb02

	Revisions:
		- 20210526@Long.Luu:	Created [Redmine ID: #152883]
		- 20210728@Long.Luu:	Exclude SABA's leaguegroup [Redmine ID: #159187]		
		- 20210820@Long.Luu:	Separate Live/Nonlive ticket selection [Redmine ID: #159195]
		- 20210928@Long.Luu:	Remove useless filter [Redmine ID: #159195]		
		- 20211214@Long.Luu:	Return danger info [Redmine ID: #165606]
		- 20220110@Long.Luu:	Return BetId and support data for Basketbal & Esports [Redmine ID: #166986]
		- 20220728@Long.Luu:	Convert stake to RM [Redmine ID: #175913]
		- 20220725@Long.Luu:	Return More Ticket's Info [Redmine ID: #175700]
		- 20230203@Victoria.Le	Various Odds will be converted to a unique one - Malaysian Odds [Redmine ID: #183277]
		- 20230220@Victoria.Le	Modify Formula to calculate Odds - For Decimal Odds [Redmine ID: #184080]
		- 202302220@Victoria.Le	Modify Formula to calculate Odds - For US Odds [Redmine ID: #184041]
		- 20230105@Victoria.Le	Get GlobalShowTime instead of KickOffTime
								Return StakeRM [Redmine ID: #181995]
		- 20230602@Long.Luu:	Add new agent as internal account [Redmine ID: #188554]
		- 20230607@Long.Luu:	Exclude more Saba's LeagueGroupID [Redmine ID: #189439]
		- 20230601@Victoria.Le	Show all tickets [Redmine ID: #185793]
		- 20230721@Victoria.Le	Get CurrencyName from table Exchange [Redmine ID: #191422]
		- 20230724@Victoria.Le	Add condition BetID with BetType = Quarter X HDP/OU/MoneyLine [Redmine ID: #191703]
		- 20230724@Victoria.Le	Using STRING_SPLIT instead of dbo.f_SplitString
								Show all tickets - Add Filter by Danger and Status [Redmine ID: #191401]
		- 20230911@Casey.Huynh:	Filter by CustomerClass, TotalAmount, Reason, AGroup, MGroup [Redmine ID: #193029]
		- 20231009@Casey.Huynh: Fixed Sum CustAmount [Redmine ID: #195204]
		- 20231010@Casey.Huynh: Fixed Filter Trans With Multi Reason [Redmine ID: #195204]
		- 20231017@Victoria.Le: Modify Formula to calculate Odds - For Decimal Odds [Redmine ID: #195562]
        - 20231024@Long.Luu: 	Add Agent HITRM & WINRM as internal account [Redmine ID: #195355]
        - 20231106@Long.Luu: 	Exclude Reject Tickets [Redmine ID: #196399]
		- 20231116@Long.Luu: 	Support filter by FromTransDate-ToTransDate [Redmine ID: 195042]
        - 20231207@Long.Luu: 	Add Agent M999RM00 as internal account [Redmine ID: #197915]
		- 20231120@Casey.Huynh:	Enhance Rule for Esport. Adjust Group Stake to 300, Add AssociationByIP, ShareMatch(3 Match(last 7 day) [Redmine ID: #196396]
		- 20240129@Casey.Huynh: Support Danger Monitor Details In 7 days [Redmine ID: #196361]
		- 20240129@Thomas.Nguyen: Return more column MalayOdds and add filter by Cashout [Redmine ID: #199634]
		- 20240322@Vitoria.Le: 	Optimize query by considering to remove temporarily table  
									And Separate between QueryType = 1 and QueryType in (2,3) [Redmine ID: #201380]
		- 20240521@Thomas.Nguyen: Remove hardcode 2 Agent WINRM and M999RM00 as internal accounts for Danger Monitor [Redmine ID: #205239]
		- 20240802@Casey.Huynh:	Enhance Filter Amount Sum by all Selected BetChoice  [Redmine ID: #207528]
		- 20240904@Casey.Huynh: Rename @ViewMode To @ViewMode [Redmine ID: #207397]
		- 20241226@Thomas.Nguyen: Add Username Filter [Redmine ID: #210128]
		- 20241217@Victoria.Le: Super/Master Direct Member [Redmine ID: #214585]
		- 20250225@Casey.Huynh: Handle @ListSportBetType (Criket BetID IS NULL) [Redmine ID: #218383]
		- 20250318@Casey.Huynh: Match Monitor Badminton, Rename From CTS_Rpt_MatchMonitor_TicketDetails [Redmine ID: #219681]
		- 20250428@Thomas.Nguyen: Upgrade CurrencyID datatype [Redmine ID: #225335]
        - 20250923@Long.Luu: 	Add Agents ORI6RM & ORI20RM  as internal account [Redmine ID: #239117]

	Params Explaination:
		- @QueryType: 1 - to run service (get tickets by @LastScannedTransID, @IsLive & @BatchSize) >> refer to new SP CTS_Rpt_MatchMonitor_GetTicketInfo
					 
					  2 - to show on report (get tickets by @EventDate & @ListTransId). Support the Last 3 Days
					  3	- to Show Support the Last 7 days
		- @ListDanger: format JSON
			SET @ListDanger = '[{"Danger1":10},{"Danger1":17},{"Danger1":28},{"Danger2":28},{"Danger2":6},{"Danger2":12},{"Danger3":48}]'

		- @ListStatus: List StatusID
			SET @ListStatus = '111,113,103,101,0,102,112,1,131' --Draw: 111;Lose: 113;Refund: 103;Reject: 101;Running: 0;Void: 102;Won:112;Waiting: 1;Completed: 131
		- @ListSportBetType: JSON
			,@ListSportBetType='[	{"SportTypeID":1, "BetTypeID":1, "BetChoiceType":2}
								,	{"SportTypeID":2, "BetTypeID":3, "BetChoiceType":2}
								,	{"SportTypeID":43, "BetTypeID":9001, "BetChoiceType":2}]'	
		- @ListHDPBetTeam: 
			+ ABS(hdp1 - hdp2): IF BetChoiceType = 2 (2 choices)
			+ Betteam: IF BetChoiceType = 1

		- @ListCustomerClass: format VARCHAR(MAX)
		     SET = '200,201,2201'
			
	Example:
		DECLARE @MinSequenceId BIGINT
		DECLARE @TotalTicket INT;

		exec CTS_MatchMonitor_Details_GetTicket 
			@QueryType=3
		,	@LastScannedSequenceID=119785603800
		,	@IsLive=1
		,	@BatchSize=-1
		,	@ListTransId=''
		,	@EventDate='2024-08-17 00:00:00'
		,	@ListSportBetType='[{"SportTypeID":1,"BetTypeID":6,"BetChoiceType":1,"BetChoiceHome":null,"BetChoiceAway":null,"BetIDPattern":null,"BetID":0}]'
		,	@MatchID=83674467
		,	@ViewMode=0
		,	@ListCurrency='2,13,9'
		,	@ListHDPBetTeam='7&over'
		,	@ListScore='0 - 0'
		,	@CustAmountRM=1.0000
		,	@ListDanger='[{"Danger1":0,"Danger2":0,"Danger3":0,"Danger4":33,"Danger5":0}]'
		,	@ListStatus='0'
		,	@ListCustomerClass='302,303,3001,400,0'
		,	@ListReason='0'
		,	@ListAGroup='0'
		,	@ListMGroup='0'
		,	@IsExclTestCurr=1
		 ,@MinSequenceId=@MinSequenceId OUTPUT,@TotalTicket=@TotalTicket OUTPUT;
		SELECT @MinSequenceId,@TotalTicket ;
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
	
	--==================================================================
	IF	OBJECT_ID('tempdb..#tmpTickets') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpTickets;
	END;

	CREATE TABLE	#tmpTickets(
			SequenceId			BIGINT
		,	TransId				BIGINT
		,	TransDate			DATETIME
		,	MatchId				INT
		,	EventDate			DATETIME
		,	EventStatus			NVARCHAR(50)
		,	KickOffTime			DATETIME
		,	HomeId				INT
		,	AwayId				INT
		,	LeagueId			INT
		,	LeagueName			NVARCHAR(500)
		,	IsMajorLeague		BIT
		,	SportType			SMALLINT
		,	BetType				SMALLINT
		,	CustId				INT
		,	BetteamGroup		NVARCHAR(10)
		,	BetTeam				NVARCHAR(10)
		,	BetChoiceHome		NVARCHAR(10)
		,	BetChoiceAway		NVARCHAR(10)
		,	BetId				BIGINT
		,	Stake				MONEY
		,	OrgStake			MONEY
		,	Odds				SMALLMONEY
		,	Hdp1				SMALLMONEY
		,	Hdp2				SMALLMONEY
		,	LiveHomeScore		SMALLINT
		,	LiveAwayScore		SMALLINT
		,	LiveIndicator		BIT
		,	TicketStatus		SMALLINT
		,	Danger1				TINYINT
		,	Danger2				TINYINT
		,	Danger3				TINYINT
		,	Danger4				TINYINT
		,	Danger5				TINYINT
		,	CustomerClass		SMALLINT
		,	CurrencyName		NVARCHAR(100)
		,	CurrencyId			SMALLINT
		,	Hdp					SMALLMONEY
		,	IsLicensee			BIT
		,	BetFrom				NVARCHAR(4)
		,	Reason				VARCHAR(50) DEFAULT '0'
		,	ListReason			VARCHAR(MAX)
		,	AGroup				INT  DEFAULT 0
		,	MGroup				INT  DEFAULT 0
		,	OddsType			TINYINT
		,	MalayOdds			SMALLMONEY
		,	IsCashout			BIT
		
	);	
	
	CREATE CLUSTERED INDEX #CIX_tmpTickets_CustId ON #tmpTickets (CustId,CurrencyId,BetTeam);
	
	CREATE NONCLUSTERED INDEX #CIX_tmpTickets_Group ON #tmpTickets (TransId) 
		INCLUDE (LiveHomeScore,LiveAwayScore,IsLicensee,CustomerClass,Danger1,Danger2,Danger3,Danger4,Danger5,Reason,AGroup,MGroup,Hdp,TicketStatus,IsCashout);
	
	IF	OBJECT_ID('tempdb..#tmpTransIds') IS NOT NULL
	BEGIN
		DROP TABLE #tmpTransIds;
	END;

	CREATE TABLE #tmpTransIds(
			TransId		BIGINT NOT NULL 
		,	Reason		VARCHAR(50) DEFAULT '0'
		,	AGroup		INT
		,	MGroup		INT
	);

	IF	OBJECT_ID('tempdb..#tmpSportBetType') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpSportBetType;
	END;

	CREATE TABLE	#tmpSportBetType(
			SportTypeID				SMALLINT
		,	BetTypeID				INT
		,	BetChoiceType			TINYINT
		,	BetChoiceHome			NVARCHAR(10)
		,	BetChoiceAway			NVARCHAR(10)
		,	BetIDPattern			NVARCHAR(20)
		,	BetID					BIGINT
	);
	
	DROP TABLE IF EXISTS #tmpUsername;
	CREATE TABLE	#tmpUsername(
			UserName	VARCHAR(50)  PRIMARY KEY	
	);

	DROP TABLE IF EXISTS #tmpCustomer;
	CREATE TABLE	#tmpCustomer(
			CustId		INT PRIMARY KEY	
	);

	IF ISNULL(@UserNameList,'') <> ''
	BEGIN
		INSERT INTO #tmpUsername(UserName)
		SELECT DISTINCT ssk.value FROM STRING_SPLIT (@UserNameList, ',') AS ssk;

		INSERT INTO #tmpCustomer(CustId)
		SELECT cs.custid
		FROM bodb02.dbo.Customer AS cs WITH (NOLOCK) 
			INNER JOIN #tmpUsername AS un WITH(NOLOCK) ON un.username = cs.username;
	END;

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

	--==================================================================
	IF @ListSportBetType <> ''
		BEGIN
			INSERT INTO #tmpSportBetType(SportTypeID,BetTypeID,BetChoiceType,BetChoiceHome,BetChoiceAway,BetIDPattern,BetID)
			SELECT	j.SportTypeID
				,	j.BetTypeID
				,	j.BetChoiceType
				,	j.BetChoiceHome
				,	j.BetChoiceAway
				,	j.BetIDPattern
				,	j.BetID
			FROM OPENJSON (@ListSportBetType) WITH (
					SportTypeID			SMALLINT		'$.SportTypeID'
				,	BetTypeID			INT				'$.BetTypeID'
				,	BetChoiceType		TINYINT			'$.BetChoiceType'
				,	BetChoiceHome		NVARCHAR(10)	'$.BetChoiceHome'
				,	BetChoiceAway		NVARCHAR(10)	'$.BetChoiceAway'
				,	BetIDPattern		NVARCHAR(20)	'$.BetIDPattern'
				,	BetID				BIGINT			'$.BetID'
				) AS j;
				
			CREATE NONCLUSTERED INDEX IX_tmpSportBetType_Group ON #tmpSportBetType(SportTypeID, BetTypeID);

		END;
	
	IF @ListTransId <> ''
		BEGIN
			INSERT INTO #tmpTransIds (TransID,Reason,AGroup,MGroup)
			SELECT	j.TransID
				,	j.Reason
				,	j.AGroup
				,	j.MGroup
			FROM OPENJSON (@ListTransId) WITH (
					TransID		BIGINT '$.TransID'
				,	Reason		VARCHAR(50) '$.Reason'
				,	AGroup		INT '$.AGroup'
				,	MGroup		INT '$.MGroup'
				) AS j;
				
			CREATE CLUSTERED INDEX CIX_tmpTransIds_Group ON #tmpTransIds (TransId, Reason);
		END;

	IF (@QueryType = 2) --Get Date for MM Monitor
		BEGIN --Get Ticket for MM Details Report 
			----==================GET Trans==================
			IF @IsGetDataFromBK = 1
			BEGIN
				IF (@ListTransId <> '' AND @ViewMode = 1) 
				BEGIN
					INSERT INTO #tmpTickets(TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
						,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup, OddsType, IsCashout)
					SELECT 
							b.transid
						,	b.transdate
						,	b.matchid
						,	m.eventdate
						,	m.Eventstatus
						,	m.GlobalShowTime
						,	m.homeid
						,	m.awayid
						,	m.leagueid
						,	m.SportType
						,	b.BetType
						,	b.custid
						,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
						,	b.betteam
						,	st.BetChoiceHome
						,	st.BetChoiceAway
						,	b.betid
						,	b.stake * b.actualrate 
						,	b.stake
						,	b.odds
						,	b.hdp1
						,	b.hdp2
						,	b.livehomescore
						,	b.liveawayscore
						,	b.statusID
						,	b.liveindicator
						,	e.currency
						,	e.ExchangeId
						,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
						,	b.BetFrom
						,	ISNULL(tmpTs.Reason,'0')
						,	ISNULL(tmpTs.AGroup,0)
						,	ISNULL(tmpTs.MGroup,0)
						,	b.oddstype
						,	CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashout
					FROM #tmpTransIds AS tmpTs WITH(NOLOCK)
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS b WITH(NOLOCK) ON b.TransId = tmpTs.TransId
						INNER JOIN bodb_Archive.dbo.match_bk AS m WITH(NOLOCK) ON b.matchid = m.matchid
						INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
										AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.betID)
						INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
					WHERE (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
					;
				END;
			END;

			IF	@IsGetDataFrom14 = 1
			BEGIN
				IF (@ListTransId <> '' AND @ViewMode = 1) 
				BEGIN
					INSERT INTO #tmpTickets(TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
						,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup, OddsType, IsCashout)
					SELECT 
							b.transid
						,	b.transdate
						,	b.matchid
						,	m.eventdate
						,	m.Eventstatus
						,	m.GlobalShowTime
						,	m.homeid
						,	m.awayid
						,	m.leagueid
						,	m.SportType
						,	b.BetType
						,	b.custid
						,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
						,	b.betteam
						,	st.BetChoiceHome
						,	st.BetChoiceAway
						,	b.betid
						,	b.stake * b.actualrate 
						,	b.stake
						,	b.odds
						,	b.hdp1
						,	b.hdp2
						,	b.livehomescore
						,	b.liveawayscore
						,	b.statusID
						,	b.liveindicator
						,	e.currency
						,	e.ExchangeId
						,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
						,	b.BetFrom
						,	ISNULL(tmpTs.Reason,'0')
						,	ISNULL(tmpTs.AGroup,0)
						,	ISNULL(tmpTs.MGroup,0)
						,	b.oddstype
						,	CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashout
					FROM #tmpTransIds AS tmpTs WITH(NOLOCK)
						INNER JOIN bodb02.dbo.bettrans14 AS b WITH(NOLOCK) ON b.TransId = tmpTs.TransId
						INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON b.matchid = m.matchid
						INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
										AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.betID)
						INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
					WHERE (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
					;
				END;
			END;

			IF	@IsGetDataFromOrigin = 1
			BEGIN
				IF (@ListTransId <> '' AND @ViewMode = 1) 
				BEGIN
					INSERT INTO #tmpTickets(SequenceId,TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
						,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup, OddsType, IsCashout)
					SELECT b.sequenceid
						,	b.transid
						,	b.transdate
						,	b.matchid
						,	m.eventdate
						,	m.Eventstatus
						,	m.GlobalShowTime
						,	m.homeid
						,	m.awayid
						,	m.leagueid
						,	m.SportType
						,	b.BetType
						,	b.custid
						,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
						,	b.betteam
						,	st.BetChoiceHome
						,	st.BetChoiceAway
						,	b.betid
						,	b.stake * b.actualrate 
						,	b.stake
						,	b.odds
						,	b.hdp1
						,	b.hdp2
						,	b.livehomescore
						,	b.liveawayscore
						,	b.statusID
						,	b.liveindicator
						,	e.currency
						,	e.ExchangeId
						,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
						,	b.BetFrom
						,	ISNULL(tmpTs.Reason,'0')
						,	ISNULL(tmpTs.AGroup,0)
						,	ISNULL(tmpTs.MGroup,0)
						,	b.oddstype
						,	CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashout
					FROM #tmpTransIds AS tmpTs WITH(NOLOCK)
						INNER JOIN bodb02.dbo.bettrans AS b WITH(NOLOCK) ON b.TransId = tmpTs.TransId
						INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
						INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
												AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.betID)
						INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
					WHERE (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate));
				END
				ELSE IF (@ViewMode = 0)
				BEGIN	
					IF (@CustAmountRM > 0) 
					BEGIN	

						INSERT INTO #tmpTickets(SequenceId,TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
							,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup, OddsType, IsCashout)
							SELECT b.sequenceid
								,	b.transid
								,	b.transdate
								,	b.matchid
								,	m.eventdate
								,	m.Eventstatus
								,	m.GlobalShowTime
								,	m.homeid
								,	m.awayid
								,	m.leagueid
								,	m.SportType
								,	b.BetType
								,	b.custid
								,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
								,	b.betteam
								,	st.BetChoiceHome
								,	st.BetChoiceAway
								,	b.betid
								,	b.stake * b.actualrate 
								,	b.stake
								,	b.odds
								,	b.hdp1
								,	b.hdp2
								,	b.livehomescore
								,	b.liveawayscore
								,	b.statusID
								,	b.liveindicator
								,	e.currency
								,	e.ExchangeId
								,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
								,	b.BetFrom
							,	ISNULL(tmpTs.Reason,'0')
							,	ISNULL(tmpTs.AGroup,0)
							,	ISNULL(tmpTs.MGroup,0)
								,	b.oddstype
								,	CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashout
							FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
								INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
								INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
													AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
								INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency	
								LEFT JOIN #tmpTransIds AS tmpTs WITH(NOLOCK) ON b.TransId = tmpTs.TransId
							WHERE	b.sequenceid < @LastScannedSequenceID								
								AND b.matchid = @MatchID
								AND b.liveindicator = @IsLive
								AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND b.Currency NOT IN (20,27,28)))
								AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate));
					END;

					IF (@CustAmountRM <= 0) 
					BEGIN
						IF (@BatchSize = 0) ---GET TotalTicket
						BEGIN
							INSERT INTO #tmpTickets(SequenceId,TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
								,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup, OddsType, IsCashout)
							SELECT b.sequenceid
								,	b.transid
								,	b.transdate
								,	b.matchid
								,	m.eventdate
								,	m.Eventstatus
								,	m.GlobalShowTime
								,	m.homeid
								,	m.awayid
								,	m.leagueid
								,	m.SportType
								,	b.BetType
								,	b.custid
								,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
								,	b.betteam
								,	st.BetChoiceHome
								,	st.BetChoiceAway
								,	b.betid
								,	b.stake * b.actualrate 
								,	b.stake
								,	b.odds
								,	b.hdp1
								,	b.hdp2
								,	b.livehomescore
								,	b.liveawayscore
								,	b.statusID
								,	b.liveindicator
								,	e.currency
								,	e.ExchangeId
								,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
								,	b.BetFrom
							,	ISNULL(tmpTs.Reason,'0')
							,	ISNULL(tmpTs.AGroup,0)
							,	ISNULL(tmpTs.MGroup,0)
								,	b.oddstype
								,	CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashout
							FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
								INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
								INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
															AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
								INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
								LEFT JOIN #tmpTransIds AS tmpTs WITH(NOLOCK) ON b.TransId = tmpTs.TransId
							WHERE	b.sequenceid < @LastScannedSequenceID							
								AND b.matchid = @MatchID	
								AND b.liveindicator = @IsLive
								AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND b.Currency NOT IN (20,27,28)))
								AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate));
						END
						ELSE IF (@BatchSize > 0) --- GET Ticket Details 
						BEGIN
							INSERT INTO #tmpTickets(SequenceId,TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
								,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup, OddsType, IsCashout)
							SELECT TOP (@BatchSize) b.sequenceid
								,	b.transid
								,	b.transdate
								,	b.matchid
								,	m.eventdate
								,	m.Eventstatus
								,	m.GlobalShowTime
								,	m.homeid
								,	m.awayid
								,	m.leagueid
								,	m.SportType
								,	b.BetType
								,	b.custid
								,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
								,	b.betteam
								,	st.BetChoiceHome
								,	st.BetChoiceAway
								,	b.betid
								,	b.stake * b.actualrate 
								,	b.stake
								,	b.odds
								,	b.hdp1
								,	b.hdp2
								,	b.livehomescore
								,	b.liveawayscore
								,	b.statusID
								,	b.liveindicator
								,	e.currency
								,	e.ExchangeId
								,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
								,	b.BetFrom							
							,	ISNULL(tmpTs.Reason,'0')
							,	ISNULL(tmpTs.AGroup,0)
							,	ISNULL(tmpTs.MGroup,0)
								,	b.oddstype
								,	CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashout
							FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
								INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
								INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON l.leagueid = m.leagueid
								INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
																AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID) 
								INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
								LEFT JOIN #tmpTransIds AS tmpTs WITH(NOLOCK) ON b.TransId = tmpTs.TransId
							WHERE	b.sequenceid < @LastScannedSequenceID
								AND b.matchid = @MatchID
								AND b.liveindicator = @IsLive
								AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND b.Currency NOT IN (20,27,28)))
								AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
							ORDER BY b.sequenceid DESC;

							SET @MinSequenceId = (SELECT MIN(SequenceId) FROM #tmpTickets);
						END 
					END;
					
				END;
			END;
			
			----==================UPDATE Malay Odds==================
			UPDATE t WITH(ROWLOCK, UPDLOCK)
			SET t.MalayOdds = CASE 
								-- Decimal
								WHEN t.oddstype = 1 THEN (CASE
															WHEN ot.OddsType IS NOT NULL THEN (CASE 
																								WHEN t.odds <= 2 THEN (t.odds - 1)
																								WHEN t.odds > 2 THEN -(1/NULLIF((t.odds - 1),0)) END)
															ELSE (CASE 
																	WHEN t.odds <= 1 THEN t.odds
																	WHEN t.odds > 1 THEN -(1/NULLIF(t.odds,0)) END) END)
								-- Hong Kong
								WHEN t.oddstype = 2 THEN (CASE	
															WHEN t.odds <= 1 THEN t.odds
															WHEN t.odds > 1 THEN -(1/NULLIF(t.odds,0)) END)
								-- Indonesia
								WHEN t.oddstype = 3 THEN -(1/NULLIF(t.odds,0))
								-- Malaysian & Myanmar
								WHEN t.oddstype IN (4,6) THEN t.odds
								-- US
								WHEN t.oddstype = 5 THEN -(1/NULLIF(t.odds,0))
							END
			FROM #tmpTickets AS t
				LEFT JOIN bodb02.dbo.f_Set_OddsTypeBetTypes() AS ot ON ot.BetType = t.BetType;
		END;	
	
	IF (@QueryType = 3) --Get Date for Danger Monitor
		BEGIN --Get Ticket for MM Details Report 
			----==================GET Trans==================
			IF	@IsGetDataFrom14 = 1
			BEGIN
				IF (@ListTransId <> '' AND @ViewMode = 1) 
				BEGIN
					INSERT INTO #tmpTickets(TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
						,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup)
					SELECT 
							b.transid
						,	b.transdate
						,	b.matchid
						,	m.eventdate
						,	m.Eventstatus
						,	m.GlobalShowTime
						,	m.homeid
						,	m.awayid
						,	m.leagueid
						,	m.SportType
						,	b.BetType
						,	b.custid
						,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
						,	b.betteam
						,	st.BetChoiceHome
						,	st.BetChoiceAway
						,	b.betid
						,	b.stake * b.actualrate 
						,	b.stake
						,	b.odds
						,	b.hdp1
						,	b.hdp2
						,	b.livehomescore
						,	b.liveawayscore
						,	b.statusID
						,	b.liveindicator
						,	e.currency
						,	e.ExchangeId
						,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
						,	b.BetFrom
						,	ISNULL(tmpTs.Reason,'0')
						,	ISNULL(tmpTs.AGroup,0)
						,	ISNULL(tmpTs.MGroup,0)
					FROM #tmpTransIds AS tmpTs WITH(NOLOCK)
						INNER JOIN bodb02.dbo.bettrans14 AS b WITH(NOLOCK) ON b.TransId = tmpTs.TransId
						INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON b.matchid = m.matchid
						INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
											AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.betID)
						INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
					WHERE (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
						 AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)));

				END;
				ELSE IF (@ViewMode = 0)
				BEGIN	
					IF (@CustAmountRM > 0) 
					BEGIN	

						INSERT INTO #tmpTickets(TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
							,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup)
							SELECT b.transid
								,	b.transdate
								,	b.matchid
								,	m.eventdate
								,	m.Eventstatus
								,	m.GlobalShowTime
								,	m.homeid
								,	m.awayid
								,	m.leagueid
								,	m.SportType
								,	b.BetType
								,	b.custid
								,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
								,	b.betteam
								,	st.BetChoiceHome
								,	st.BetChoiceAway
								,	b.betid
								,	b.stake * b.actualrate 
								,	b.stake
								,	b.odds
								,	b.hdp1
								,	b.hdp2
								,	b.livehomescore
								,	b.liveawayscore
								,	b.statusID
								,	b.liveindicator
								,	e.currency
								,	e.ExchangeId
								,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
								,	b.BetFrom
							,	ISNULL(tmpTs.Reason,'0')
							,	ISNULL(tmpTs.AGroup,0)
							,	ISNULL(tmpTs.MGroup,0)
							FROM bodb02.dbo.bettrans14 AS b WITH(NOLOCK)
								INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON b.matchid = m.matchid
								INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) ON b.custid = c.custid
								INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
													AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
								INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency	
								LEFT JOIN #tmpTransIds AS tmpTs WITH(NOLOCK) ON b.TransId = tmpTs.TransId
							WHERE	b.matchid = @MatchID								
								AND b.liveindicator = @IsLive
								AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND b.Currency NOT IN (20,27,28)))
								AND c.site NOT IN ('Nextbet','9wickets','9wsports')
								AND c.username NOT LIKE '%Cashout%'
								AND b.mrecommend NOT IN (27899314,11656504,12146012) 
								AND b.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
								AND b.srecommend NOT IN (41430709)
								AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
								AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)));
				
					END;

					IF (@CustAmountRM <= 0) 
					BEGIN
						--- GET Ticket Details 
						INSERT INTO #tmpTickets(TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
							,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup)
						SELECT TOP (@BatchSize) b.transid
							,	b.transdate
							,	b.matchid
							,	m.eventdate
							,	m.Eventstatus
							,	m.GlobalShowTime
							,	m.homeid
							,	m.awayid
							,	m.leagueid
							,	m.SportType
							,	b.BetType
							,	b.custid
							,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
							,	b.betteam							
							,	st.BetChoiceHome
							,	st.BetChoiceAway
							,	b.betid
							,	b.stake * b.actualrate 
							,	b.stake
							,	b.odds
							,	b.hdp1
							,	b.hdp2
							,	b.livehomescore
							,	b.liveawayscore
							,	b.statusID
							,	b.liveindicator
							,	e.currency
							,	e.ExchangeId
							,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
							,	b.BetFrom							
						,	ISNULL(tmpTs.Reason,'0')
						,	ISNULL(tmpTs.AGroup,0)
						,	ISNULL(tmpTs.MGroup,0)
						FROM bodb02.dbo.bettrans14 AS b WITH(NOLOCK)
							INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON b.matchid = m.matchid
							INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) ON b.custid = c.custid
							INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON l.leagueid = m.leagueid
							INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
											AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
							INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
							LEFT JOIN #tmpTransIds AS tmpTs WITH(NOLOCK) ON b.TransId = tmpTs.TransId
						WHERE	b.matchid = @MatchID
							AND b.liveindicator = @IsLive
							AND (@IsExclTestCurr = 0 OR (@IsExclTestCurr = 1 AND b.Currency NOT IN (20,27,28)))
							AND c.site NOT IN ('Nextbet','9wickets','9wsports')
							AND c.username NOT LIKE '%Cashout%'
							AND b.mrecommend NOT IN (27899314,11656504,12146012) 
							AND b.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
							AND b.srecommend NOT IN (41430709)
							AND b.TransDate < @LastTransDate
							AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
							AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)))
						ORDER BY b.TransDate DESC;

						SET @MinTransDate= (SELECT MIN(TransDate) FROM #tmpTickets WITH(NOLOCK));

						INSERT INTO #tmpTickets(TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
							,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup)
						SELECT b.transid
							,	b.transdate
							,	b.matchid
							,	m.eventdate
							,	m.Eventstatus
							,	m.GlobalShowTime
							,	m.homeid
							,	m.awayid
							,	m.leagueid
							,	m.SportType
							,	b.BetType
							,	b.custid
							,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
							,	b.betteam
							,	st.BetChoiceHome
							,	st.BetChoiceAway
							,	b.betid
							,	b.stake * b.actualrate 
							,	b.stake
							,	b.odds
							,	b.hdp1
							,	b.hdp2
							,	b.livehomescore
							,	b.liveawayscore
							,	b.statusID
							,	b.liveindicator
							,	e.currency
							,	e.ExchangeId
							,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
							,	b.BetFrom							
						,	ISNULL(tmpTs.Reason,'0')
						,	ISNULL(tmpTs.AGroup,0)
						,	ISNULL(tmpTs.MGroup,0)
						FROM bodb02.dbo.bettrans14 AS b WITH(NOLOCK)
							INNER JOIN bodb02.dbo.match14 AS m WITH(NOLOCK) ON b.matchid = m.matchid
							INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) ON b.custid = c.custid
							INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
											AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
							INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
							LEFT JOIN #tmpTransIds AS tmpTs WITH(NOLOCK) ON b.TransId = tmpTs.TransId
							LEFT JOIN #tmpTickets AS tmpTk WITH(NOLOCK) ON tmpTk.TransID = b.TransID
						WHERE	b.matchid = @MatchID
							AND b.liveindicator = @IsLive
							AND c.site NOT IN ('Nextbet','9wickets','9wsports')
							AND c.username NOT LIKE '%Cashout%'
							AND b.mrecommend NOT IN (27899314,11656504,12146012) 
							AND b.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
							AND b.srecommend NOT IN (41430709)
							AND b.TransDate = @MinTransDate
							AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
							AND tmpTk.TransID IS NULL
							AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)));
					END;
					
				END;
			END;

			IF	@IsGetDataFromOrigin = 1
			BEGIN
				IF (@ListTransId <> '' AND @ViewMode = 1) 
				BEGIN
					INSERT INTO #tmpTickets(SequenceId,TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
						,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup)
					SELECT b.sequenceid
						,	b.transid
						,	b.transdate
						,	b.matchid
						,	m.eventdate
						,	m.Eventstatus
						,	m.GlobalShowTime
						,	m.homeid
						,	m.awayid
						,	m.leagueid
						,	m.SportType
						,	b.BetType
						,	b.custid
						,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
						,	b.betteam
						,	st.BetChoiceHome
						,	st.BetChoiceAway
						,	b.betid
						,	b.stake * b.actualrate 
						,	b.stake
						,	b.odds
						,	b.hdp1
						,	b.hdp2
						,	b.livehomescore
						,	b.liveawayscore
						,	b.statusID
						,	b.liveindicator
						,	e.currency
						,	e.ExchangeId
						,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
						,	b.BetFrom
						,	ISNULL(tmpTs.Reason,'0')
						,	ISNULL(tmpTs.AGroup,0)
						,	ISNULL(tmpTs.MGroup,0)
					FROM #tmpTransIds AS tmpTs WITH(NOLOCK)
						INNER JOIN bodb02.dbo.bettrans AS b WITH(NOLOCK) ON b.TransId = tmpTs.TransId
						INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
						INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
											AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.betID)
						INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
					WHERE (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
						AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)));
					
				END
				ELSE IF (@ViewMode = 0)
				BEGIN	
					IF (@CustAmountRM > 0) 
					BEGIN
						INSERT INTO #tmpTickets(SequenceId,TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
							,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup)
						SELECT b.sequenceid
							,	b.transid
							,	b.transdate
							,	b.matchid
							,	m.eventdate
							,	m.Eventstatus
							,	m.GlobalShowTime
							,	m.homeid
							,	m.awayid
							,	m.leagueid
							,	m.SportType
							,	b.BetType
							,	b.custid
							,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
							,	b.betteam
							,	st.BetChoiceHome
							,	st.BetChoiceAway
							,	b.betid
							,	b.stake * b.actualrate 
							,	b.stake
							,	b.odds
							,	b.hdp1
							,	b.hdp2
							,	b.livehomescore
							,	b.liveawayscore
							,	b.statusID
							,	b.liveindicator
							,	e.currency
							,	e.ExchangeId
							,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
							,	b.BetFrom
						,	ISNULL(tmpTs.Reason,'0')
						,	ISNULL(tmpTs.AGroup,0)
						,	ISNULL(tmpTs.MGroup,0)
						FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
							INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
							INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) ON b.custid = c.custid
							INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
										AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID)
							INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency	
							LEFT JOIN #tmpTransIds AS tmpTs WITH(NOLOCK) ON b.TransId = tmpTs.TransId
						WHERE	b.sequenceid < @LastScannedSequenceID							
							AND b.matchid = @MatchID	
							AND b.liveindicator = @IsLive
							AND c.site NOT IN ('Nextbet','9wickets','9wsports')
							AND c.username NOT LIKE '%Cashout%'
							AND b.mrecommend NOT IN (27899314,11656504,12146012) 
							AND b.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
							AND b.srecommend NOT IN (41430709)
							AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
							AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)));
				
					END;

					IF (@CustAmountRM <= 0) 
					BEGIN
						--- GET Ticket Details 
						INSERT INTO #tmpTickets(SequenceId,TransId,TransDate,MatchId,EventDate,EventStatus,KickOffTime,HomeId,AwayId,LeagueId,SportType,BetType,CustId,BetteamGroup,BetTeam,BetChoiceHome,BetChoiceAway
							,BetId,Stake,OrgStake,Odds,Hdp1,Hdp2,LiveHomeScore,LiveAwayScore,TicketStatus, LiveIndicator, CurrencyName,CurrencyId,Hdp,BetFrom, Reason, AGroup, MGroup)
						SELECT TOP (@BatchSize) b.sequenceid
							,	b.transid
							,	b.transdate
							,	b.matchid
							,	m.eventdate
							,	m.Eventstatus
							,	m.GlobalShowTime
							,	m.homeid
							,	m.awayid
							,	m.leagueid
							,	m.SportType
							,	b.BetType
							,	b.custid
							,	(CASE WHEN st.BetChoiceType = 2 THEN b.Betteam ELSE '1' END) AS BetteamGroup
							,	b.betteam
							,	st.BetChoiceHome
							,	st.BetChoiceAway
							,	b.betid
							,	b.stake * b.actualrate 
							,	b.stake
							,	b.odds
							,	b.hdp1
							,	b.hdp2
							,	b.livehomescore
							,	b.liveawayscore
							,	b.statusID
							,	b.liveindicator
							,	e.currency
							,	e.ExchangeId
							,	ABS(CASE WHEN st.BetChoiceType = 2 THEN b.Hdp1 - b.Hdp2 END) AS HDP
							,	b.BetFrom							
						,	ISNULL(tmpTs.Reason,'0')
						,	ISNULL(tmpTs.AGroup,0)
						,	ISNULL(tmpTs.MGroup,0)
						FROM bodb02.dbo.bettrans AS b WITH(NOLOCK)
							INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON b.matchid = m.matchid
							INNER JOIN bodb02.dbo.Customer AS c WITH(NOLOCK) ON b.custid = c.custid
							INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON l.leagueid = m.leagueid
							INNER JOIN #tmpSportBetType AS st WITH(NOLOCK) ON m.SportType = st.SportTypeID 
									AND b.BetType = st.BetTypeID AND b.BetID = ISNULL(st.BetID,b.BetID) 
							INNER JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON e.ExchangeId = b.currency
							LEFT JOIN #tmpTransIds AS tmpTs WITH(NOLOCK) ON b.TransId = tmpTs.TransId
						WHERE	b.sequenceid < @LastScannedSequenceID
							AND b.matchid = @MatchID
							AND b.liveindicator = @IsLive
							AND c.site NOT IN ('Nextbet','9wickets','9wsports')
							AND c.username NOT LIKE '%Cashout%'
							AND b.mrecommend NOT IN (27899314,11656504,12146012) 
							AND b.recommend NOT IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)
							AND b.srecommend NOT IN (41430709)
							AND (@FromTransDate IS NULL OR (b.TransDate >= @FromTransDate AND b.TransDate < @ToTransDate))
							AND (ISNULL(@UserNameList,'') = '' OR (ISNULL(@UserNameList,'') <> '' AND EXISTS (SELECT TOP 1 1 FROM #tmpCustomer AS cus WITH(NOLOCK) WHERE b.custid = cus.CustId)))
						ORDER BY b.sequenceid DESC;

						SET @MinSequenceId = (SELECT MIN(SequenceId) FROM #tmpTickets);

					END;
					
				END;
			END;

		END;
	
	----==================UPDATE Trans Info==================
	UPDATE t WITH(ROWLOCK, UPDLOCK)
	SET t.IsLicensee	= 1
	,	t.Danger1		= c.danger
	,	t.Danger2		= c.danger2
	,	t.Danger3		= c.danger3
	,	t.Danger4		= c.Danger4
	,	t.Danger5		= c.Danger5
	,	t.CustomerClass	= c.CustomerClass
	FROM #tmpTickets AS t
		INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON t.CustId = c.custid
		INNER JOIN bodb02.dbo.Dep_CustSuper AS cs WITH (NOLOCK) ON cs.custid = c.srecommend;

	UPDATE t WITH(ROWLOCK, UPDLOCK)
	SET t.IsLicensee	= 0
	,	t.Danger1		= c.danger
	,	t.Danger2		= c.danger2
	,	t.Danger3		= c.danger3
	,	t.Danger4		= c.Danger4
	,	t.Danger5		= c.Danger5
	,	t.CustomerClass	= c.CustomerClass
	FROM #tmpTickets AS t
		INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON t.CustId = c.custid
		INNER JOIN bodb02.dbo.CustProductStatus AS s WITH (NOLOCK) ON s.custid = c.custid
	WHERE t.IsLicensee IS NULL;
	
	----==================FILTERS=========================		
	IF (@ListScore IS NOT NULL) OR (@IsLicensee IS NOT NULL) OR (@ListCustomerClass <> '') OR (@ListDanger IS NOT NULL)
		OR (@ListCurrency IS NOT NULL) OR (@ListReason <> '') OR (@ListAGroup <> '') OR (@ListMGroup <> '') OR (@ListHDPBetTeam IS NOT NULL)
		OR (@ListStatus IS NOT NULL) OR (@CustAmountRM > 0) OR (@CustAmountRM > 0) OR (@IsCashout IS NOT NULL)
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
				WITH CTE_Score AS (
					SELECT cas.LiveHomeScore, cas.LiveAwayScore
					FROM STRING_SPLIT(@ListScore, ',') ssk
						CROSS APPLY (SELECT	LiveHomeScore = xDim.value('/x[1]','varchar(max)')
										,	LiveAwayScore = xDim.value('/x[2]','varchar(max)')
									From (SELECT CAST('<x>' + REPLACE(REPLACE(ssk.value,'-',''),'  ','</x><x>')+'</x>' AS XML) AS xDim) AS s
									) AS cas
				)
				DELETE t
				FROM #tmpTickets AS t
					LEFT JOIN CTE_Score AS s ON s.LiveHomeScore = t.LiveHomeScore AND s.LiveAwayScore = t.LiveAwayScore
				WHERE s.LiveHomeScore IS NULL;

			END;

			--========================Fitler By Site(IsLicensee)==================
			IF (@IsLicensee IS NOT NULL)
			BEGIN
				DELETE t
				FROM #tmpTickets AS t
				WHERE t.IsLicensee != @IsLicensee;
			END;

			--========================Fitler By CustomerClass==================
			IF (@ListCustomerClass <> '')
			BEGIN
				WITH CTE_CC AS (
					SELECT ssk.value AS CustomerClass FROM STRING_SPLIT(@ListCustomerClass, ',') AS ssk
				)
				DELETE t
				FROM #tmpTickets AS t
					LEFT JOIN CTE_CC AS c ON c.CustomerClass = ISNULL(t.CustomerClass,0)
				WHERE c.CustomerClass IS NULL;
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
					FROM #tmpTickets AS t
						LEFT JOIN @tmpSupportedDanger AS d1 ON d1.Danger1 = t.Danger1 AND t.Danger1 > 0
						LEFT JOIN @tmpSupportedDanger AS d2 ON d2.Danger2 = t.Danger2 AND t.Danger2 > 0
						LEFT JOIN @tmpSupportedDanger AS d3 ON d3.Danger3 = t.Danger3 AND t.Danger3 > 0
						LEFT JOIN @tmpSupportedDanger AS d4 ON d4.Danger4 = t.Danger4 AND t.Danger4 > 0
						LEFT JOIN @tmpSupportedDanger AS d5 ON d5.Danger5 = t.Danger5 AND t.Danger5 > 0
					WHERE d1.Danger1 IS NULL 
						AND d2.Danger2 IS NULL 
						AND d3.Danger3 IS NULL
						AND d4.Danger4 IS NULL
						AND d5.Danger5 IS NULL;
				END
				ELSE
				BEGIN
					DELETE t
					FROM #tmpTickets AS t
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
						AND d5.Danger5 IS NULL;
				END;

			END;

			--========================Filter By Currency==================	
			IF (@ListCurrency IS NOT NULL)
			BEGIN
				WITH CTE_Currency AS (
					SELECT ssk.value AS CurrencyId FROM STRING_SPLIT(@ListCurrency, ',') AS ssk
				)
				DELETE t
				FROM #tmpTickets AS t
					LEFT JOIN CTE_Currency AS curr ON curr.CurrencyId = t.CurrencyId
				WHERE curr.CurrencyId IS NULL;
			END;

			--========================Fitler By Reason==================
			IF (@ListReason <> '')
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
				FROM #tmpTransIds AS tmpTr WITH(NOLOCK)
					LEFT JOIN @tmpSupportedReason AS tmpRs ON tmpRs.Reason = tmpTr.Reason
				GROUP BY TransID;

				UPDATE tmpTk
				SET	tmpTk.ListReason = tmpTr.ListReason
				,	tmpTk.Reason = CASE WHEN tmpTr.MinReason = tmpTk.Reason THEN tmpTr.MinReason ELSE '-1' END
				FROM #tmpTickets AS tmpTk
					INNER JOIN #tmpTransIdReason AS tmpTr ON tmpTk.TransId = tmpTr.TransID
				
				--Delete ticket is not in Reason Filter
				DELETE t
				FROM #tmpTickets AS t
					LEFT JOIN @tmpSupportedReason AS c ON c.Reason = ISNULL(t.Reason,'0')
				WHERE c.Reason IS NULL;				

			END;

			--========================Fitler By AGroup==================
			IF @ListAGroup <> ''
			BEGIN
				WITH CTE_AGroup AS (
					SELECT ssk.value AS AGroup FROM STRING_SPLIT(@ListAGroup, ',') AS ssk
				)
				DELETE t
				FROM #tmpTickets AS t
					LEFT JOIN CTE_AGroup AS c ON c.AGroup = ISNULL(t.AGroup,0)
				WHERE c.AGroup IS NULL;
			END;

			--========================Fitler By MGroup==================
			IF @ListMGroup <> ''
			BEGIN
				WITH CTE_MGroup AS (
					SELECT ssk.value AS MGroup FROM STRING_SPLIT(@ListMGroup, ',') AS ssk
				)
				DELETE t
				FROM #tmpTickets AS t
					LEFT JOIN CTE_MGroup AS c ON c.MGroup = ISNULL(t.MGroup,0)
				WHERE c.MGroup IS NULL;
			END;

			--========================Fitler By HDP(Betteam)==================	
			IF (@ListHDPBetTeam IS NOT NULL)
			BEGIN
				IF EXISTS (	SELECT 1 
							FROM #tmpSportBetType AS st WITH(NOLOCK) 
							WHERE st.BetChoiceType = 1) --Filter Betteam
				BEGIN
					WITH CTE_BetTeam AS (
						SELECT ssk.value AS BetTeam FROM STRING_SPLIT(@ListHDPBetTeam, ',') AS ssk
					)
					DELETE t
					FROM #tmpTickets AS t
						LEFT JOIN CTE_BetTeam AS bt ON bt.BetTeam = t.BetTeam
					WHERE bt.BetTeam IS NULL;
				
				END
				ELSE IF EXISTS (SELECT 1 
								FROM #tmpSportBetType AS st WITH(NOLOCK) 
								WHERE st.BetChoiceType = 2) --Filter Hdp
				BEGIN
					WITH CTE_Hdp AS (
						SELECT ssk.value AS Hdp FROM STRING_SPLIT(@ListHDPBetTeam, ',') AS ssk
					)
					DELETE t
					FROM #tmpTickets AS t
						LEFT JOIN CTE_Hdp AS h ON h.Hdp = t.Hdp
					WHERE h.Hdp IS NULL;
				END;
			END;	

			--========================Fitler By Status==================	
			IF (@ListStatus IS NOT NULL)
			BEGIN
				WITH CTE_Status AS (
					SELECT ssk.value AS StatusID FROM STRING_SPLIT(@ListStatus, ',') AS ssk
				)
				DELETE t
				FROM #tmpTickets AS t
					LEFT JOIN CTE_Status AS s ON s.StatusID = t.TicketStatus
				WHERE s.StatusID IS NULL;
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
					,	BetteamGroup	NVARCHAR(10)
				);
			
				INSERT INTO #tmpCustAmount(CustId, BetteamGroup)
				SELECT	tmpTk.CustId
					,	tmpTk.BetteamGroup
				FROM #tmpTickets AS tmpTk WITH(NOLOCK)
				GROUP BY tmpTk.CustId, tmpTk.BetteamGroup
				HAVING SUM(tmpTk.Stake) >= @CustAmountRM;

				CREATE CLUSTERED INDEX CIX_tmpCustAmount_Group ON #tmpCustAmount (CustID, BetteamGroup);

				DELETE tmpTk
				FROM #tmpTickets AS tmpTk WITH(NOLOCK)
					LEFT JOIN #tmpCustAmount AS tmpCa WITH(NOLOCK) ON tmpCa.CustId = tmpTk.CustId and tmpCa.BetteamGroup = tmpTk.BetteamGroup
				WHERE tmpCa.CustId IS NULL;
			END;

			--========================Fitler By Cashout==================	
			IF (@IsCashout IS NOT NULL)
			BEGIN
				DELETE t
				FROM #tmpTickets AS t
				WHERE t.IsCashout != @IsCashout;
			END;
		END;
		
	--====================RETURN DATA================================================
	IF (@QueryType = 2 AND @BatchSize = 0)
		BEGIN					
			SET @TotalTicket = (SELECT COUNT(1) FROM #tmpTickets);
		END
	ELSE --Return Ticket Details
		BEGIN
			SELECT	tmpTk.SequenceId
				,	tmpTk.TransId
				,	tmpTk.TransDate
				,	tmpTk.MatchId
				,	tmpTk.EventDate
				,	tmpTk.EventStatus
				,	tmpTk.KickOffTime
				,	tmpTk.HomeId
				,	tmpTk.AwayId
				,	tmpTk.LeagueId
				,	tmpTk.LeagueName
				,	tmpTk.IsMajorLeague
				,	tmpTk.SportType
				,	tmpTk.BetType
				,	tmpTk.CustId
				,	tmpTk.BetTeam
				,	(CASE WHEN tmpTk.BetTeam = tmpTk.BetChoiceHome THEN 10
						 WHEN tmpTk.BetTeam = tmpTk.BetChoiceAway THEN 20
						 ELSE NULL END) AS ChoiceOrder
				,	tmpTk.BetId
				,	tmpTk.Stake
				,	tmpTk.OrgStake
				,	tmpTk.Odds
				,	tmpTk.Hdp1
				,	tmpTk.Hdp2
				,	tmpTk.LiveHomeScore
				,	tmpTk.LiveAwayScore
				,	tmpTk.LiveIndicator
				,	tmpTk.TicketStatus
				,	tmpTk.Danger1
				,	tmpTk.Danger2
				,	tmpTk.Danger3
				,	tmpTk.Danger4
				,	tmpTk.Danger5
				,	tmpTk.CustomerClass
				,	tmpTk.CurrencyName
				,	tmpTk.CurrencyId
				,	tmpTk.Hdp
				,	tmpTk.IsLicensee
				,	tmpTk.BetFrom
				,	tmpTk.Reason
				,	ISNULL(tmpTk.ListReason,tmpTk.Reason) AS ListReason
				,	tmpTk.AGroup
				,	tmpTk.MGroup
				,	tmpTk.MalayOdds
			FROM #tmpTickets AS tmpTk WITH(NOLOCK);
		END;
	
	DROP TABLE IF EXISTS #tmpSportBetType;
	DROP TABLE IF EXISTS #tmpTickets;
	DROP TABLE IF EXISTS #tmpTransIds;
	DROP TABLE IF EXISTS #tmpTransIdReason;
	DROP TABLE IF EXISTS #tmpCustAmount;

END;

GO