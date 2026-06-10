/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[CTS_ProblemAccountsClassification_Daily]
	@ListCustInfo			VARCHAR(MAX),
	@FunctionId				SMALLINT = 12
AS
/*
	Created: 20220328@Long.Luu
	Task : Classify Problem Account -  Daily
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20220328@Long.Luu: Created [Redmine ID: #170468]
		- 20221118@Jonas.Huynh: Update parameter of DW SP GetCustAccumulatedInfo [Redmine ID: #179500]
		- 20230601@Jonas.Huynh: Update SP get accumulated performance (Renovate Phase2) [Redmine ID: #186684]
		- 20230627@Jonas.Huynh: Reset Balance for Credit with Inactive Normal with new place-bet [Redmine ID: #189876]
		- 20230807@Jonas.Huynh: HF exclude Non-sport for General [Redmine ID: #192388]
		- 20230726@Jonas.Huynh: Saba Classification [Redmine ID: #185320]
		- 20250908@Thomas.Nguyen: CC 2900/2901 - Add logic for SportGroup [Redmine ID: #237405]
		- 20250918@Thomas.Nguyen: HF data with STRING_AGG is truncated [Redmine ID: #239260]

	Param's Explanation:

	Example:
		EXEC CTS_ProblemAccountsClassification_Daily @ListCustInfo = '[{"CustID":1096006, "SportGroup":0},{"CustID":1096006, "SportGroup":2},{"CustID":1277, "SportGroup":0},{"CustID":249550995, "SportGroup":1},{"CustID":43290047, "SportGroup":1},{"CustID":43290027, "SportGroup":1}]';

*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @PROBLEMACCOUNT_LOSING		INT = 0
		,	@PROBLEMACCOUNT_KEEPSTATE	INT = 1
		,	@PROBLEMACCOUNT_WINNING		INT = 2;

	DECLARE @CurrentDateTime			DATETIME = GETDATE();
	DECLARE @CurrentDate				DATE	 = GETDATE();

	DECLARE @SportGroup_SabaVRSoccer	 SMALLINT = 145,
			@SportGroup_SabaVRBasketball SMALLINT = 912,
			@SportGroup_NonSport		 SMALLINT = 229,
			@SportGroup_General			 SMALLINT = 0;

	DECLARE @ListCustIds				VARCHAR(MAX);

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
		ActiveDaysCustID	 INT			NOT NULL,
        ActiveDaysSportGroup INT			NOT NULL,
        WindaysCustID		 INT			NOT NULL,
        WinDaysSportGroup	 INT			NOT NULL,
		ProcessedTime        DATETIME       NOT NULL
		PRIMARY KEY CLUSTERED (CustId, SportGroup)
	);

	IF	OBJECT_ID('tempdb..#tmpCustomerAccummulatedInfo') IS NOT NULL
		DROP TABLE	#tmpCustomerAccummulatedInfo;

	CREATE TABLE #tmpCustomerAccummulatedInfo(
		[CustId]			INT NOT NULL,
		[SportGroup]		INT NOT NULL,
		[TurnoverRM]		MONEY NULL,
		[WinlossRM]			MONEY NULL,
		[BetCount]			BIGINT NULL,
		[ActiveDays]		INT NULL
	);

	IF OBJECT_ID('tempdb..#tmpCustInfo') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpCustInfo;
	END
	
	CREATE TABLE #tmpCustInfo(
			CustId			INT
		,	SportGroup		INT
	);

	CREATE CLUSTERED INDEX IX_#tmpCustInfo_CustId_SportGroup ON #tmpCustInfo(
		[CustId]			ASC,
		[SportGroup]		ASC
	);

	-- #0: Distinct custid
	INSERT INTO #tmpCustInfo (CustId, SportGroup)
	SELECT DISTINCT	js.CustID
				,	js.SportGroup
	FROM	OPENJSON(@ListCustInfo) WITH (
					CustID			INT			'$.CustID'
				,	SportGroup		INT			'$.SportGroup'
	) AS js;

	WITH CTE_CustIds AS (
		SELECT DISTINCT CustId FROM #tmpCustInfo
	)
	SELECT @ListCustIds = STRING_AGG(CAST(CustId AS VARCHAR(MAX)), ',') FROM CTE_CustIds;

	-- #1: GetCustomer Accummulated data
	INSERT INTO #tmpRawData(CustId, SportGroup, TurnoverRM, WinlossRM, TurnoverORG, WinlossORG, BetCount, ActiveDaysCustID, ActiveDaysSportGroup, WindaysCustID, WinDaysSportGroup, ProcessedTime)
	EXEC bodb_dwrs.dbo.Acc_Rpt_CTS_GetCustAccumulatedInfo @ListCustID = @ListCustIds, @isResetBalance = 1;

	DELETE a WITH (ROWLOCK)
	FROM #tmpRawData AS a
	WHERE a.SportGroup IN (@SportGroup_NonSport, @SportGroup_SabaVRSoccer, @SportGroup_SabaVRBasketball);

	-- #2: Sum data by custid
	INSERT INTO #tmpCustomerAccummulatedInfo(CustId, SportGroup, TurnoverRM, WinlossRM, BetCount, ActiveDays)
	SELECT	a.CustId
		,	@SportGroup_General AS SportGroup
		,	SUM(a.TurnoverRM)
		,	SUM(a.WinlossRM)
		,	SUM(a.BetCount)
		,	MAX(a.ActiveDaysCustID)
	FROM #tmpRawData AS a WITH(NOLOCK)
		INNER JOIN #tmpCustInfo AS cus ON a.CustId = cus.CustId
	WHERE cus.SportGroup = @SportGroup_General
	GROUP BY a.CustId;

	INSERT INTO #tmpCustomerAccummulatedInfo(CustId, SportGroup, TurnoverRM, WinlossRM, BetCount, ActiveDays)
	SELECT	a.CustId
		,	a.SportGroup
		,	SUM(a.TurnoverRM)
		,	SUM(a.WinlossRM)
		,	SUM(a.BetCount)
		,	MAX(a.ActiveDaysCustID)
	FROM #tmpRawData AS a WITH(NOLOCK)
		INNER JOIN #tmpCustInfo AS cus ON a.CustId = cus.CustId AND a.SportGroup = cus.SportGroup
	WHERE cus.SportGroup <> @SportGroup_General
	GROUP BY a.CustId, a.SportGroup;

	-- #3: Classify new members
	SELECT	r.CustId
		,	r.SportGroup
		,	CASE
				WHEN (r.WinlossRM < -10000) THEN @PROBLEMACCOUNT_LOSING
				WHEN (r.WinlossRM >= -5000) THEN @PROBLEMACCOUNT_WINNING
				ELSE @PROBLEMACCOUNT_KEEPSTATE
			END AS WinlossStatus
		,	r.TurnoverRM
		,	r.WinlossRM
		,	r.BetCount
		,	r.ActiveDays
	FROM #tmpCustomerAccummulatedInfo AS r WITH(NOLOCK);
END;
