/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CTS_GeneralNormalClassification_TWGroupBetting_GetChanges]
		@NextScannedDateTime DATETIME2 OUTPUT
	,	@NextScannedCustID BIGINT OUTPUT
AS
/*
	Created: 	20231030@Victoria.Le
	Task : 		Get List Custs to classify New Group Betting - CC2300
	DB: 		bodb_VR2Model
	Original:	
	Revisions:
		- 20231030@Victoria.Le: 	Initial Writing  [Redmine ID: #195060]
		- 20240417@Thomas.Nguyen: 	Add last scanned CustID and return DetectedDate, GBBetCount, SportType   [Redmine ID: #200854]
*/
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE @BatchSize INT = 20000;
	DECLARE	@LastJobScannedTime DATETIME2;
	DECLARE	@LastScannedCustID BIGINT;
	DECLARE	@MaxServiceScannedTime DATETIME2;
	DECLARE @LastJobScannedTime_ParamId TINYINT = 7;
	DECLARE @LastScannedCustID_ParamId TINYINT = 14;
	
	IF	OBJECT_ID('tempdb..#tmpCustScanned') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpCustScanned;
	END;

	CREATE TABLE #tmpCustScanned(
			CustId		  			INT PRIMARY KEY
		,	LastJobScannedTime		DATETIME2
		,	GBTicketCount			INT
		,	SportType				INT
	);
	
	-- Get Last Job Scanned Datetime
	SELECT @LastJobScannedTime = CONVERT(DATETIME2, [Value], 121)
	FROM dbo.CustomerClassification_Parameter WITH(NOLOCK)
	WHERE DataId = @LastJobScannedTime_ParamId;
	
	--Get Last Scanned CustID
	SELECT @LastScannedCustID = [Value]
	FROM dbo.CustomerClassification_Parameter WITH(NOLOCK)
	WHERE DataId = @LastScannedCustID_ParamId;

	INSERT INTO #tmpCustScanned (CustId, LastJobScannedTime, GBTicketCount, SportType)
	SELECT TOP(@BatchSize) cs.CustId, cs.LastJobScannedTime, cs.GBTicketCount, cs.SportType
	FROM dbo.CustomerClassification_ScannedNewCust AS cs WITH (NOLOCK)
	WHERE cs.JobScannedType = 2 
		AND ((cs.LastJobScannedTime >= @LastJobScannedTime AND CustID > @LastScannedCustID)
			OR (cs.LastJobScannedTime > @LastJobScannedTime))
		/*((cs.LastJobScannedTime >= @LastJobScannedTime AND cs.IsServiceScanned = 0)
		OR (cs.LastJobScannedTime >= @LastJobScannedTime AND cs.IsServiceScanned = 1 AND cs.LastServiceScannedTime < cs.LastJobScannedTime)) -- Number of GBTickets are updated */
	ORDER BY cs.LastJobScannedTime ASC, CustID ASC;
	
	SELECT @MaxServiceScannedTime = MAX(LastJobScannedTime) FROM #tmpCustScanned;

	SELECT @NextScannedCustID = (SELECT TOP 1 CustId FROM #tmpCustScanned ORDER BY LastJobScannedTime DESC, CustId DESC);
	
	SET @NextScannedCustID = ISNULL(@NextScannedCustID, @LastScannedCustID);

	SET @NextScannedDateTime = ISNULL(@MaxServiceScannedTime,@LastJobScannedTime);

	SELECT	CustId
		,	LastJobScannedTime AS DetectedDate
		,	GBTicketCount
		,	SportType
	FROM #tmpCustScanned;

	DROP TABLE IF EXISTS #tmpCustScanned;
	
END;