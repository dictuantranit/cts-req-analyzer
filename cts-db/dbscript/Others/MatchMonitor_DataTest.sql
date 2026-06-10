
BEGIN -------CREATE MATCH-------

	if object_id ( 'tempdb..#TempMatch', 'U') is not null begin drop table #TempMatch end;
	CREATE TABLE #TempMatch(Id int identity(1,1), SportType int, LeagueId int, LeagueGroupId int, HomeId INT, AwayId INT, Code nVARCHAR(50));--Code =SporttypeLeagueidLegueGroupid
	INSERT INTO #TempMatch(SportType, LeagueId, LeagueGroupId, HomeId, AwayId)
	VALUES(1,3,1,6,9),(1,3,1,8,5)
		, (1,20,2,189,810),(1,20,2,513,522)
		, (1,22,3,419,1803),(1,22,3,828,5369)
		, (1,51,7,16164,1186),(1,51,7,732,1193)
		, (1,63,8,2236,2816),(1,63,8,1023,1009) 
		, (1,78,9,818,2133),(1,78,9,155,6138) 
		, (2,245,0,2582,49157),(2,245,0,281716,281722)
		, (2,410,0,744549,757051),(2,410,0,541161,757051)
		, (2,503,0,19383,19386),(2,503,0,316392,275024)
		, (43,103,20,18956,18955),(43,103,20,12055,217)
	
	UPDATE #TempMatch
	SET Code = 10000000 * (CASE WHEN LeagueGroupId IN (1,2,3) THEN 1 ELSE 2 END) + ((Sporttype/10)*10 + (SportType%10))*100000 + ((LeagueId/100)*100 + (LeagueId%100)*100 + (LeagueId%10)*10)*100+ Id
	
	
	SELECT * from #TempMatch
	SELECT 'CTSMatchS' + CONVERT(Varchar,SportType) + 'L' + CONVERT(Varchar,LeagueId) + 'Lg' +  CONVERT(Varchar,LeagueGroupId) from #TempMatch

	SELECT 10000000 * (CASE WHEN LeagueGroupId IN (1,2,3) THEN 1 ELSE 2 END) + ((Sporttype/10)*10 + (SportType%10))*100000 + ((LeagueId/100)*100 + (LeagueId%100)*100 + (LeagueId%10)*10)*100+ Id, *  from #TempMatch with(nolock) 

	DECLARE @lv_CurrentTime DATETIME;
	DECLARE @lv_Time DATETIME;
	DECLARE @lv_Date DATE;

	SET @lv_CurrentTime = CONVERT( VARCHAR(24), GETDATE(), 113);
	SET @lv_Time = CONVERT( VARCHAR(24), GETDATE(), 120);
	SET @lv_Date = @lv_Time;

	SELECT 413%10;

	SET IDENTITY_INSERT Match ON;

		INSERT INTO Match (Matchid,leagueid,homeid,awayid,eventdate,eventstatus,creator,matchcode,kickofftime,showtime,sporttype,GlobalShowTime,HasLive,changetime,
			livehomescore,liveawayscore,ruben,multiple,yenbet,exrisk,homeid2,awayid2,DisplayMode,LeaguePatternID,HomeDisplayPatternID,AwayDisplayPatternID,IsNeutral,AutoSetting,SettlementStatus,IsDeleted,isTestMatch)
		SELECT tmp.Code, tmp.leagueid, tmp.homeid, tmp.awayid,@lv_Date,'running',8,'CTSMatch' + CONVERT(Varchar, Code),@lv_Time AS kickofftime,@lv_Time AS showtime,tmp.sporttype,@lv_Time AS GlobalShowTime, 1 AS HasLive,@lv_Time AS changetime

			,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		FROM #TempMatch as tmp
		LEFT JOIN Match as m with(nolock)  on tmp.code = m.matchid
		where m.matchid is null;

	SET IDENTITY_INSERT Match  OFF;

	select top (100) * FROm Match with(nolock);

	
End;


BEGIN -------CREATE TICKET RANDOM-------
	
	if object_id ( 'tempdb..#TempBettypeBetteam', 'U') is not null begin drop table #TempBettypeBetteam end;
	CREATE TABLE #TempBettypeBetteam(Id int identity(1,1), Bettype int, betteam varchar(20))
	insert into  #TempBettypeBetteam(Bettype, betteam)
	values(1,'a')
		, (1,'h')
		, (3,'a')
		, (3,'h')
		, (7,'a')
		, (7,'h')
		, (8,'a')
		, (8,'h')

	if object_id ( 'tempdb..#TempOdds', 'U') is not null begin drop table #TempOdds end;
	CREATE TABLE #TempOdds(Id int identity(1,1), GroupOdds int, LiveIndicator bit, LiveHomeScore int, LiveAwayScore int, bettype int, hdp1 decimal(10,4), hdp2 decimal(10,4), OddsValue decimal(5,2));
	insert into #TempOdds ( LiveIndicator, GroupOdds, LiveHomeScore, LiveAwayScore, bettype, hdp1, hdp2, OddsValue)
	VALUES(0,1,0,0,1,0.0,0.25,0.2)
		,(0,1,0,0,3,0.5,0.0,0.2)
		,(0,1,0,0,7,0.75,0.0,0.2)
		,(0,1,0,0,8,1,0.0,0.2)
		,(0,2,0,0,1,0.0,0.25,0.5)
		,(0,2,0,0,3,0.5,0.0,0.5)
		,(0,2,0,0,7,0.75,0.0,0.5)
		,(0,2,0,0,8,1,0.0,0.5)
		,(0,3,0,0,1,0.0,0.25,0.8)
		,(0,3,0,0,3,0.5,0.0,0.8)
		,(0,3,0,0,7,0.75,0.0,0.8)
		,(0,3,0,0,8,1,0.0,0.8)
		,(0,4,0,0,1,0.0,0.25,0.95)
		,(0,4,0,0,3,0.5,0.0,0.95)
		,(0,4,0,0,7,0.75,0.0,0.95)
		,(0,4,0,0,8,1,0.0,0.95) --===================================
		,(1,1,1,0,1,0.0,0.25,0.2)
		,(1,1,1,0,3,0.5,0.0,0.2)
		,(1,1,1,0,7,0.75,0.0,0.2)
		,(1,1,1,0,8,1,0.0,0.2)
		,(1,2,1,0,1,0.0,0.25,0.5)
		,(1,2,1,0,3,0.5,0.0,0.5)
		,(1,2,1,0,7,0.75,0.0,0.5)
		,(1,2,1,0,8,1,0.0,0.5)
		,(1,3,1,0,1,0.0,0.25,0.8)
		,(1,3,1,0,3,0.5,0.0,0.8)
		,(1,3,1,0,7,0.75,0.0,0.8)
		,(1,3,1,0,8,1,0.0,0.8)
		,(1,4,1,0,1,0.0,0.25,0.95)
		,(1,4,1,0,3,0.5,0.0,0.95)
		,(1,4,1,0,7,0.75,0.0,0.95)
		,(1,4,1,0,8,1,0.0,0.95) --===================================
		,(1,1,0,1,1,0.0,0.25,0.2)
		,(1,1,0,1,3,0.5,0.0,0.2)
		,(1,1,0,1,7,0.75,0.0,0.2)
		,(1,1,0,1,8,1,0.0,0.2)
		,(1,2,0,1,1,0.0,0.25,0.5)
		,(1,2,0,1,3,0.5,0.0,0.5)
		,(1,2,0,1,7,0.75,0.0,0.5)
		,(1,2,0,1,8,1,0.0,0.5)
		,(1,3,0,1,1,0.0,0.25,0.8)
		,(1,3,0,1,3,0.5,0.0,0.8)
		,(1,3,0,1,7,0.75,0.0,0.8)
		,(1,3,0,1,8,1,0.0,0.8)
		,(1,4,0,1,1,0.0,0.25,0.95)
		,(1,4,0,1,3,0.5,0.0,0.95)
		,(1,4,0,1,7,0.75,0.0,0.95)
		,(1,4,0,1,8,1,0.0,0.95) --===================================
		,(1,1,0,2,1,0.0,0.25,0.2)
		,(1,1,0,2,3,0.5,0.0,0.2)
		,(1,1,0,2,7,0.75,0.0,0.2)
		,(1,1,0,2,8,1,0.0,0.2)
		,(1,2,0,2,1,0.0,0.25,0.5)
		,(1,2,0,2,3,0.5,0.0,0.5)
		,(1,2,0,2,7,0.75,0.0,0.5)
		,(1,2,0,2,8,1,0.0,0.5)
		,(1,3,0,2,1,0.0,0.25,0.8)
		,(1,3,0,2,3,0.5,0.0,0.8)
		,(1,3,0,2,7,0.75,0.0,0.8)
		,(1,3,0,2,8,1,0.0,0.8)
		,(1,4,0,2,1,0.0,0.25,0.95)
		,(1,4,0,2,3,0.5,0.0,0.95)
		,(1,4,0,2,7,0.75,0.0,0.95)
		,(1,4,0,2,8,1,0.0,0.95) --===================================

		SELECT * FROM #TempOdds;

		If object_id ( 'tempdb..#TempCust', 'U') is not null begin drop table #TempCust end;	
 		CREATE TABLE #TempCust(CustId int primary key, IsLicensee int ,recommend int , mrecommend int , srecommend int , currency int, Username nvarchar(50), CurrencyName nVARCHAR(100) );

		insert into #TempCust(CustID, recommend, mrecommend, srecommend, currency, IsLicensee, Username, CurrencyName)
		SELECT  top(5) c.custid ,  recommend, mrecommend, srecommend, c.currency, 0, c.Username, e.currency
		from custdb.dbo.Customer c
			inner join custdb.dbo.site s with(nolock)  on c.site = s.site and s.SiteDBGroupID = 0 and s.isLicensee = 0 and c.roleid = 1 and c.currency <> 20 
			inner join dbo.exchange e on c.currency = e.exchangeid
		Group by c.CustID, recommend, mrecommend, srecommend, c.currency, Username, e.currency;
		
		insert into #TempCust(CustID, recommend, mrecommend, srecommend, currency, IsLicensee, Username, CurrencyName)
		SELECT  top(5) c.custid ,  recommend, mrecommend, srecommend, c.currency, 0, c.Username, e.currency
		from custdb.dbo.Customer c
			inner join custdb.dbo.site s with(nolock)  on c.site = s.site and s.SiteDBGroupID = 0 and s.isLicensee = 1 and c.roleid = 1 and c.currency <> 20 
			inner join dbo.exchange e on c.currency = e.exchangeid
		Group by c.CustID, recommend, mrecommend, srecommend, c.currency, Username, e.currency;
		

		If object_id ( 'tempdb..#TempStake', 'U') is not null begin drop table #TempStake end;	
 		CREATE TABLE #TempStake(Stake int ,ActualRate Decimal(10,4) );

		Insert into #TempStake(Stake,ActualRate)
		Values(100,1.2)
		,(1010,0.5)
		,(300,1.5)
		,(400,0.8)

		If object_id ( 'tempdb..#TempBettrans', 'U') is not null begin drop table #TempBettrans end;
		CREATE TABLE [dbo].[#TempBettrans](
			[custid] [int] NOT NULL,
			[transdate] [datetime] NOT NULL,
			[oddsid] [int] NOT NULL,
			[hdp1] [smallmoney] NULL,
			[hdp2] [smallmoney] NULL,
			[odds] [smallmoney] NULL,
			[stake] [money] NOT NULL,
			[status] [nvarchar](10) NULL,
			[winlost] [money] NULL,
			[awinlost] [money] NULL,
			[mwinlost] [money] NULL,
			[playercomm] [money] NULL,
			[comm] [money] NULL,
			[acomm] [money] NULL,
			[apositiontaking] [smallmoney] NULL,
			[mpositiontaking] [smallmoney] NULL,
			[tpositiontaking] [smallmoney] NULL,
			[playerdiscount] [decimal](9, 8) NULL,
			[discount] [decimal](9, 8) NULL,
			[adiscount] [decimal](9, 8) NULL,
			[livehomescore] [smallint] NULL,
			[liveawayscore] [smallint] NULL,
			[liveindicator] [bit] NULL,
			[betteam] [nvarchar](10) NULL,
			[creator] [int] NOT NULL,
			[refno] [bigint] NOT NULL,
			[comstatus] [nvarchar](20) NULL,
			[winlostdate] [smalldatetime] NULL,
			[betfrom] [nvarchar](3) NULL,
			[betcheck] [nvarchar](50) NULL,
			[checktime] [datetime] NULL,
			[oddsspread] [money] NULL,
			[actualrate] [float] NULL,
			[matchid] [int] NULL,
			[recommend] [int] NOT NULL,
			[mrecommend] [int] NOT NULL,
			[ruben] [tinyint] NULL,
			[betid] [bigint] NULL,
			[statuswinlost] [tinyint] NULL,
			[modds] [smallmoney] NULL,
			[bettype] [smallint] NULL,
			[betdaqid] [bigint] NULL,
			[tstamp] [timestamp] NULL,
			[actual_stake] [money] NULL,
			[currency] [tinyint] NULL,
			[ip] [varchar](45) NULL,
			[transdesc] [nvarchar](1000) NULL,
			[sdiscount] [decimal](9, 8) NULL,
			[scomm] [money] NULL,
			[spositiontaking] [smallmoney] NULL,
			[swinlost] [money] NULL,
			[srecommend] [int] NOT NULL,
			[Username] [nvarchar](50) NULL,
			[CurrencyName] [nvarchar](50) NULL,
			[virtualrate] [float] NOT NULL,
			[oddstype] [tinyint] NULL,
			[statusID] [tinyint] NULL,
			[currency2] [tinyint] NULL,
			[balance] [money] NULL,
			[SecAcceptFlag] [bit] NULL,
			[transid2] [bigint] NULL,
			[RecommDate] [datetime] NULL,
			[ExtraInfo] [varchar](1000) NULL,
			[WalletType] [tinyint] NULL,
			[BonusID] [int] NULL,
			[RefCode] [bigint] NULL,
			[SettlementTime] [datetime] NULL,
			[epositiontaking] [smallmoney] NULL,
			[ReasonID] [smallint] NULL,
			[sort] [smallint] NULL,
			[BetSiteID] [int] NULL,
			[RepUpdateTime] [datetime2](7) NULL,
			[BRID] [bigint] NULL,
			[RepDestUpdateTime] [datetime2](7) NULL,
			[SiteDBGroupID] [smallint] NULL,
			[TransId] [bigint]  NULL,
			[sequenceid] [bigint] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
			[FcUpdateTime] [datetime2](7) NULL);

	insert into bodb02.dbo.Odds (Matchid,Bettype,livehomescore, liveawayscore, liveindicator, hdp1, hdp2, odds1a, TBRepKey)

	SELECT DISTINCT Code, Bettype,livehomescore, liveawayscore, liveindicator, hdp1, hdp2, OddsValue, id
	FROM #TempOdds AS odd
		, (SELECT  DISTINCT Code From #TempMatch t where t.sporttype = 1) AS tm;

	--DELETE o from  bodb02.dbo.Odds o where matchid in (select distinct code from #TempMatch);

	DELETE tb from [#TempBettrans] tb;
	Insert into [#TempBettrans](custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount,adiscount,livehomescore,liveawayscore,liveindicator,betteam,creator,refno,comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread,actualrate,matchid,recommend,mrecommend,ruben,betid,statuswinlost,modds,bettype,betdaqid,actual_stake,currency,ip,transdesc,sdiscount,scomm,spositiontaking,swinlost,srecommend,Username,CurrencyName,virtualrate,oddstype,statusID,currency2,balance,SecAcceptFlag,transid2,RecommDate,ExtraInfo,WalletType,BonusID,RefCode,SettlementTime,epositiontaking,ReasonID,sort,BetSiteID,RepUpdateTime,BRID,RepDestUpdateTime,SiteDBGroupID,TransId,FcUpdateTime)
	SELECT tc.custid
	,transdate
	,tbt.oddsid
	,tbt.hdp1
	,tbt.hdp2
	,tbt.odds1a AS Odds
	,ts.stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount
	,adiscount
	,tbt.livehomescore
	,tbt.liveawayscore
	,tbt.liveindicator
	,tbt.betteam
	,8 AS creator,refno,b.comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread
	,ts.ActualRate
	,tbt.matchid
	,tc.recommend
	,tc.mrecommend,ruben,betid,statuswinlost,modds
	,tbt.bettype,betdaqid,actual_stake
	,tc.currency,ip,transdesc,sdiscount,scomm,spositiontaking,swinlost
	,tc.srecommend
	,tc.Username
	,tc.CurrencyName,virtualrate,oddstype,statusID,currency2,balance,b.SecAcceptFlag,transid2,RecommDate,ExtraInfo,WalletType,BonusID,RefCode,SettlementTime,epositiontaking
	,ReasonID,b.sort,BetSiteID,RepUpdateTime,BRID,RepDestUpdateTime,SiteDBGroupID,TransId,FcUpdateTime
	From (SELECT Top(1) * FROM bodb02.dbo.bettrans where bettype=1 and status = 'running' ) b
	, (SELECT o.*, tb.betteam From #TempMatch t 
		inner join Odds as o with(nolock)   on o.Matchid = t.Code
		inner join #TempBettypeBetteam as tb  on o.Bettype = tb.bettype
		where t.sporttype = 1) tbt
	, #TempCust AS tc
	, #TempStake AS ts
	ORder by tbt.liveawayscore , tbt.livehomescore , tbt.bettype , tbt.oddsid ;

	SELECT sequenceid s, matchid,  * FROM [#TempBettrans] AS tm Order by  s;
		SELECT max(sequenceid) FROM [#TempBettrans] 
	DECLARE @i int;
	DECLARE @transid BIGINT;
	DECLARE @TransDate DATETIME2;

	set @i=1;
	SET @TransDate = GETDATE();


		EXEC Get_Bettrans_Transid @transid OUTPUT
		SELECT min(oddsid) from [#TempBettrans];
		Insert into dbo.Bettrans(custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount,adiscount,livehomescore,liveawayscore,liveindicator,betteam,creator,refno,comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread,actualrate,matchid,recommend,mrecommend,ruben,betid,statuswinlost,modds,bettype,betdaqid,actual_stake,currency,ip,transdesc,sdiscount,scomm,spositiontaking,swinlost,srecommend,Username,CurrencyName,virtualrate,oddstype,statusID,currency2,balance,SecAcceptFlag,transid2,RecommDate,ExtraInfo,WalletType,BonusID,RefCode,SettlementTime,epositiontaking,ReasonID,sort,BetSiteID,RepUpdateTime,BRID,RepDestUpdateTime,SiteDBGroupID,TransId,FcUpdateTime)
		SELECT  tbt.custid
		, DATEADD(SECOND,Sequenceid*10,GETDATE()) AS transdate
		,tbt.oddsid
		,tbt.hdp1
		,tbt.hdp2
		,tbt.Odds
		,tbt.stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount
		,adiscount
		,tbt.livehomescore
		,tbt.liveawayscore
		,tbt.liveindicator
		,tbt.betteam
		,8 AS creator,refno,tbt.comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread
		,tbt.ActualRate
		,tbt.matchid
		,tbt.recommend
		,tbt.mrecommend,ruben,betid,statuswinlost,modds
		,tbt.bettype,betdaqid,actual_stake
		,tbt.currency,ip,transdesc,sdiscount,scomm,spositiontaking,swinlost
		,tbt.srecommend,Username
		,CurrencyName,virtualrate,oddstype,statusID,currency2,balance,tbt.SecAcceptFlag,transid2,RecommDate,ExtraInfo,WalletType,BonusID,RefCode,SettlementTime,epositiontaking
		,ReasonID,tbt.sort,BetSiteID,RepUpdateTime,BRID,RepDestUpdateTime,SiteDBGroupID
		,@TransId+sequenceid
		,FcUpdateTime
		From [#TempBettrans] tbt
		where tbt.oddsid = 443848668;
		Where Sequenceid between 1 and 1000;






	While @i <= 420
	begin
		

		EXEC Get_Bettrans_Transid @transid OUTPUT

		Insert into dbo.Bettrans(custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount,adiscount,livehomescore,liveawayscore,liveindicator,betteam,creator,refno,comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread,actualrate,matchid,recommend,mrecommend,ruben,betid,statuswinlost,modds,bettype,betdaqid,actual_stake,currency,ip,transdesc,sdiscount,scomm,spositiontaking,swinlost,srecommend,Username,CurrencyName,virtualrate,oddstype,statusID,currency2,balance,SecAcceptFlag,transid2,RecommDate,ExtraInfo,WalletType,BonusID,RefCode,SettlementTime,epositiontaking,ReasonID,sort,BetSiteID,RepUpdateTime,BRID,RepDestUpdateTime,SiteDBGroupID,TransId,FcUpdateTime)
		SELECT tbt.custid
		, DATEADD(SECOND,10,GETDATE()) AS transdate 
		, ROW_NUMBER() OVER(ORDER BY SequenceId ASC) AS Row
		,tbt.oddsid
		,tbt.hdp1
		,tbt.hdp2
		,tbt.Odds
		,tbt.stake,status,winlost,awinlost,mwinlost,playercomm,comm,acomm,apositiontaking,mpositiontaking,tpositiontaking,playerdiscount,discount
		,adiscount
		,tbt.livehomescore
		,tbt.liveawayscore
		,tbt.liveindicator
		,tbt.betteam
		,8 AS creator,refno,tbt.comstatus,winlostdate,betfrom,betcheck,checktime,oddsspread
		,tbt.ActualRate
		,tbt.matchid
		,tbt.recommend
		,tbt.mrecommend,ruben,betid,statuswinlost,modds
		,tbt.bettype,betdaqid,actual_stake
		,tbt.currency,ip,transdesc,sdiscount,scomm,spositiontaking,swinlost
		,tbt.srecommend,Username
		,CurrencyName,virtualrate,oddstype,statusID,currency2,balance,tbt.SecAcceptFlag,transid2,RecommDate,ExtraInfo,WalletType,BonusID,RefCode,SettlementTime,epositiontaking
		,ReasonID,tbt.sort,BetSiteID,RepUpdateTime,BRID,RepDestUpdateTime,SiteDBGroupID
		,@TransId+sequenceid
		,FcUpdateTime
		From [#TempBettrans] tbt
		WHERE sequenceid = @i
		set @i = @i+1
		WAITFOR Delay '00:00:01'
	end;

END;
/*
DELETE b
--SELECT COUNT(1)
FROM bettrans b with(nolock)
inner join #TempMatch m on m.code = b.matchid  where b.sequenceid > 1011566007625802796 */