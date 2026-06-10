/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[CTS_TWGroupBetting_SyncDataGroupBettingTicket]
			@GBTicketString		VARCHAR(MAX)
		,	@RunningSequenceId	BIGINT
AS
/*
	Created: 20220314@Harvey.Nguyen
	Task : Insert group betting ticket from DB061 -> DB062 %
	DB	 : DBCTS.WASAVerse

	Revisions:
		- 20220314@Harvey.Nguyen: Init sp 											[Redmine ID: #170160]
		- 20220505@Harvey.Nguyen: Insert GroupBetting ticket into history table		[Redmine ID: #169671]
		- 20220711@Harvey.Nguyen: Change solution to scan on each ticket			[Redmine ID: #169671]
		- 20220831@Harvey.Nguyen: Update for Scale out DB Trans						[Redmine ID: #176472]
		- 20230417@Casey.Huynh: Ignore Duplicate TransID 							[Redmine ID: #187030]
		- 20230626@Victoria.Le: Add new columns	RulesType,IsRule1[tag by %RFM],IsRule2[tag by %CC],IsRule3[tag by %Betfrom]
																			[Redmine ID: #189505]
		- 20230818@Victoria.Le: Add ROWLOCK with the delete statement [Redmine ID: #191955]
		- 20231011@Victoria.Le: Keep data 14 days instead of 7 days [Redmine ID: #195298]
		- 20231024@John.Ngo:	[CTS] - Customer Classification - TW GB - Resolve Deadlock Problems [Redmine ID: #195866]
		- 20240130@Victoria.Le:	Change tables - TWGB Migrate data from bodb02 to WASAVerse [Redmine ID: #191955]
		- 20240509@Victoria.Le: Incorrect logic to clean up data yesterday of table TWGroupBettingTicket [Redmine ID: #204731]
		- 20240405@Victoria.Le:	Edit SP to improve performance [Redmine ID: #200842]
		
	Params Explaination:
		EXECUTE [dbo].[CTS_TWGroupBetting_SyncDataGroupBettingTicket] 
*/
BEGIN
	SET NOCOUNT ON;

DECLARE 	@DailyMidnightFrom				DATETIME
		,	@DailyMidnightTo				DATETIME
		,	@RunningDate					DATETIME
		,	@Today							DATETIME = GETDATE()
		,	@CleanTicketFlag_ParameterID	SMALLINT = 7
		,	@CleanTicketFlag_READY			SMALLINT = 0
		,	@CleanTicketFlag_WAITING		SMALLINT = -1
		;

	IF OBJECT_ID('tempdb..#TmpGroupBettingTicket') IS NOT NULL
		DROP TABLE #TmpGroupBettingTicket;

	CREATE TABLE #TmpGroupBettingTicket (
			TransId				BIGINT	
		,	CustId				INT
		,	TransDate			DATE
		,	RuleId				TINYINT
		,	RulesType			VARCHAR(100)
		,	IsViolateRFM		BIT
		,	IsViolateCC			BIT
		,	IsViolateBetFrom	BIT
	);

	INSERT INTO #TmpGroupBettingTicket (TransId, Custid, TransDate, RuleId, RulesType, IsViolateRFM, IsViolateCC, IsViolateBetFrom)
	SELECT j.TransId, j.Custid, j.TransDate, j.RuleId, gbr.RuleName, j.IsViolateRFM, j.IsViolateCC, j.IsViolateBetFrom
	FROM OPENJSON(@GBTicketString) WITH (		
			TransId				BIGINT		'$.TransId' 
		,	CustId				INT			'$.CustId' 
		,	TransDate			DATE		'$.TransDate' 
		,	RuleId				TINYINT		'$.RuleId' 
		,	IsViolateRFM		BIT			'$.IsViolateRFM' 
		,	IsViolateCC			BIT			'$.IsViolateCC' 
		,	IsViolateBetFrom	BIT			'$.IsViolateBetFrom' 
	) AS j
		INNER JOIN dbo.TWGroupBettingRule AS gbr WITH(NOLOCK) ON j.RuleId = gbr.RuleId;
		
	CREATE CLUSTERED INDEX #CIX_TmpGroupBettingTicket_TransId ON #TmpGroupBettingTicket (TransId);
	
	INSERT INTO dbo.TWGroupBettingTicket_History (
			TransId
		,	TransDate
		,	RulesType
		,	IsRule1
		,	IsRule2
		,	IsRule3
		)
	SELECT 	tmp.TransId
		,	tmp.TransDate
		,	tmp.RulesType
		,	tmp.IsViolateRFM
		,	tmp.IsViolateCC
		,	tmp.IsViolateBetFrom
	FROM #TmpGroupBettingTicket AS tmp
		LEFT JOIN dbo.TWGroupBettingTicket_History AS his WITH(NOLOCK) ON tmp.TransID = his.TransID
	WHERE his.TransID IS NULL;
	
	INSERT INTO dbo.TWGroupBettingTicket (
			CustId
		,	TransId
		,	TransDate
		)
	SELECT 	tmp.Custid
		,	tmp.TransId
		,	tmp.TransDate
	FROM #TmpGroupBettingTicket AS tmp
		LEFT JOIN dbo.TWGroupBettingTicket AS t WITH(NOLOCK) ON tmp.TransID = t.TransID
	WHERE t.TransID IS NULL;
	
	SELECT @DailyMidnightFrom 	= DATEADD(MINUTE, 30, CONVERT(SMALLDATETIME, CONVERT(DATE, @Today)));
	SELECT @DailyMidnightTo 	= DATEADD(MINUTE, 60, CONVERT(SMALLDATETIME, CONVERT(DATE, @Today)));
	
	IF (@Today > @DailyMidnightFrom AND @Today < @DailyMidnightTo)
	BEGIN 
		SELECT @RunningDate = transdate
		FROM bodb02.dbo.bettrans WITH (NOLOCK)
		WHERE sequenceid = @RunningSequenceId; -- '2024-05-07 23:05:05'
		
		SELECT @DailyMidnightFrom 	= DATEADD(MINUTE, 30, CONVERT(SMALLDATETIME, CONVERT(DATE, @RunningDate))); -- '2024-05-07 00:30:00'
		SELECT @DailyMidnightTo 	= DATEADD(MINUTE, 60, CONVERT(SMALLDATETIME, CONVERT(DATE, @RunningDate))); -- '2024-05-07 01:00:00'
		
		IF (@RunningDate > @DailyMidnightFrom 
				AND @RunningDate < @DailyMidnightTo 
				AND CONVERT(DATE, @RunningDate) =  CONVERT(DATE, @Today)) 
		BEGIN
			UPDATE 	dbo.SystemParameter WITH(UPDLOCK, ROWLOCK)
			SET 	ParameterValue 	= @CleanTicketFlag_WAITING
			WHERE 	ParameterID 	= @CleanTicketFlag_ParameterID
				AND ParameterValue 	= @CleanTicketFlag_READY;
		END;
	END;
	
	DROP TABLE IF EXISTS #TmpGroupBettingTicket;
	
END;

