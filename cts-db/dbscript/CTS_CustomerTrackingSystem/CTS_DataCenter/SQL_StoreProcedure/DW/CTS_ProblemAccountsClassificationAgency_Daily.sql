/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[CTS_ProblemAccountsClassificationAgency_Daily]
	@ListCustIds			VARCHAR(MAX)
AS
/*
	Created: 20250303@Thomas.Nguyen
	Task : Classify Problem Account -  Daily
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20250303@Thomas.Nguyen: Created [Redmine ID: #218588]

	Param's Explanation:
*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @PROBLEMACCOUNT_LOSING		INT = 0
		,	@PROBLEMACCOUNT_WINNING		INT = 2;

	DECLARE	@LASTXDAYS					VARCHAR(5) = '60';
	DECLARE	@LASTYDAYS					VARCHAR(5) = '365';
	DECLARE @RANGDAYS					VARCHAR(10) = CONCAT_WS(',', @LASTXDAYS, @LASTYDAYS);

	IF	OBJECT_ID('tempdb..#tmpRawData') IS NOT NULL
		DROP TABLE	#tmpRawData;

	CREATE TABLE #tmpRawData(
		CustId				 INT			NOT NULL,
		SportGroup			 INT			NOT NULL,
		TurnoverRM			 DECIMAL(19, 4)	NOT NULL,
		WinlossRM			 DECIMAL(19, 4)	NOT NULL,
		TurnoverORG			 DECIMAL(19, 4)	NOT NULL,
		WinlossORG			 DECIMAL(19, 4)	NOT NULL,
		BetCount			 BIGINT			NOT NULL,
		FirstBetDate		 DATETIME		NOT NULL,
        LastXDaysTurnoverRM  DECIMAL(19, 4)	NOT NULL,
        LastXDaysWinlossRM	 DECIMAL(19, 4)	NOT NULL,
        LastXDaysBetCount	 INT			NOT NULL,
		LastYDaysTurnoverRM  DECIMAL(19, 4)	NOT NULL,
        LastYDaysWinlossRM	 DECIMAL(19, 4)	NOT NULL,
        LastYDaysBetCount	 INT			NOT NULL,
		ProcessedTime        DATETIME		NOT NULL,
		PRIMARY KEY CLUSTERED (CustId, SportGroup)
	);

	IF	OBJECT_ID('tempdb..#tmpCustomerAccummulatedInfo') IS NOT NULL
		DROP TABLE	#tmpCustomerAccummulatedInfo;

	CREATE TABLE #tmpCustomerAccummulatedInfo(
		CustId			    INT             NOT NULL,
		TurnoverRM		    DECIMAL(19, 4)  NOT NULL,
		WinlossRM			DECIMAL(19, 4)  NOT NULL,
		Margin				DECIMAL(19, 4)  NOT NULL,
		BetCount			BIGINT          NOT NULL
	);

	IF OBJECT_ID('tempdb..#tmpCustomers') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpCustomers;
	END
	
	CREATE TABLE #tmpCustomers(
			CustId			INT
	);

	CREATE CLUSTERED INDEX IX_#mpCustomers_CustId ON #tmpCustomers(
		[CustId]			ASC
	);

	-- #0: Distinct custid
	INSERT INTO #tmpCustomers(CustId)
	SELECT [value] FROM STRING_SPLIT(@ListCustIds, ',');

	SELECT @ListCustIds = STUFF((SELECT ',', CONVERT(VARCHAR(15), t.CustId) 
								FROM (SELECT DISTINCT CustId FROM #tmpCustomers WITH (NOLOCK)) AS t
								FOR XML PATH('')), 1, 1, '');

	-- #1: GetCustomer Accummulated data
	INSERT INTO #tmpRawData(CustId, SportGroup, TurnoverRM, WinlossRM, TurnoverORG, WinlossORG, BetCount, FirstBetDate, LastXDaysTurnoverRM, LastXDaysWinlossRM, LastXDaysBetCount, LastYDaysTurnoverRM, LastYDaysWinlossRM, LastYDaysBetCount, ProcessedTime)
	EXEC bodb_dwrs.dbo.Acc_Rpt_CTS_GetSMAAccumulatedInfo @ListCustID = @ListCustIds, @RangeDays = @RANGDAYS, @IsAccumulated = 1;

	-- #2: Sum data by custid
	INSERT INTO #tmpCustomerAccummulatedInfo(CustId, TurnoverRM, WinlossRM, Margin, BetCount)
	SELECT	a.CustId
		,	SUM(a.TurnoverRM)
		,	SUM(a.WinlossRM)
		,	CASE WHEN SUM(a.TurnoverRM) = 0 THEN 0 ELSE SUM(a.WinlossRM) / SUM(a.TurnoverRM) * 100 END
		,	SUM(a.BetCount)
	FROM #tmpRawData AS a WITH(NOLOCK)
	GROUP BY a.CustId;

	-- #3: Classify new members
	SELECT	r.CustId
		,	CASE
				WHEN (r.Margin < 0) THEN @PROBLEMACCOUNT_LOSING
				WHEN (r.Margin >= 0) THEN @PROBLEMACCOUNT_WINNING
			END AS WinlossStatus
		,	r.TurnoverRM
		,	r.WinlossRM
		,	r.BetCount
	FROM #tmpCustomerAccummulatedInfo AS r WITH(NOLOCK)
END;
