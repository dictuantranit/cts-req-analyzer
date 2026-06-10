/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" viewers="" isFunction="0" isNested="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[CTS_CustomerClassification_CheckGroupBettingAndReject]
	@custIdList			VARCHAR(MAX) = ''
AS
/*
	Created: 20210722@Harvey.Nguyen
	Task : New categories/CC for TW group betting detection
	DB: WASAVerse
	Original:

	Revisions:
		- 20210722@Harvey.Nguyen: Created [Redmine ID: #155956]
		- 20230626@Victoria.Le:		Get Group Betting, Reject, Desktop percent within 60 days & and current date [Redmine ID: #189505]
		- 20240130@Victoria.Le:	  	Change tables - TWGB Migrate data from bodb02 to WASAVerse [Redmine ID: #191955]
		- 20240923@Jonas.Huynh: 	Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]	

	Param's Explanation:
*/
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE @Today DATE;

	IF OBJECT_ID('tempdb..#tmpCustomerClassification') IS NOT NULL
	BEGIN
		DROP TABLE #tmpCustomerClassification;
	END;

	CREATE TABLE #tmpCustomerClassification (
			CustId				INT NOT NULL PRIMARY KEY		
		,	CateId				TINYINT NULL
		,	TWBetCount			INT		NULL
		,	TWGroupBettingRate	MONEY	NULL
		,	TWTicketRejectRate	MONEY	NULL
		,	TWDesktopUsageRate	MONEY	NULL
	);	
	
	IF OBJECT_ID('tempdb..#tmpCustomerGroupPercentage') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpCustomerGroupPercentage;
	END;

	CREATE TABLE #tmpCustomerGroupPercentage (
			CustId				INT NOT NULL PRIMARY KEY	
		,	TWBetCount			INT NULL
		,	TWGroupBettingRate	MONEY NULL	
		,	TWTicketRejectRate	MONEY NULL
		,	TWDesktopUsageRate	MONEY NULL
		,	TWTicketParlayCount	INT NULL	
	);
	
	SET @Today = GETDATE();

	INSERT INTO #tmpCustomerClassification(CustId)
	SELECT	ssk.value
	FROM 	STRING_SPLIT(@custIdList, ',') AS ssk;
	
	INSERT INTO #tmpCustomerGroupPercentage (CustId, TWBetCount, TWGroupBettingRate, TWTicketRejectRate, TWDesktopUsageRate, TWTicketParlayCount)
	SELECT 	gbc.CustId
		,	SUM(gbc.TicketCount) AS 'TotalBetCount'
		,  	CASE WHEN SUM(gbc.TicketCount) <> 0 THEN SUM(CONVERT(MONEY, gbc.GBTicketCount)) * 100 / SUM(CONVERT(MONEY, gbc.TicketCount)) ELSE NULL END AS 'GBPercent'
		,  	CASE WHEN SUM(gbc.TicketCount) <> 0 THEN SUM(CONVERT(MONEY, gbc.RejectTicketCount)) * 100 / SUM(CONVERT(MONEY, gbc.TicketCount)) ELSE NULL END AS 'RejectPercent'
		,  	CASE WHEN SUM(gbc.TicketCount) <> 0 THEN SUM(CONVERT(MONEY, gbc.DesktopTicketCount)) * 100 / SUM(CONVERT(MONEY, gbc.TicketCount)) ELSE NULL END AS 'DesktopPercent'
		,	SUM(gbc.ParlayTicketCount) AS 'ParlayTicketCount'
	FROM #tmpCustomerClassification AS cust WITH (NOLOCK)
		INNER JOIN dbo.TWGroupBettingCustomer AS gbc WITH (NOLOCK) ON gbc.CustId = cust.CustId
	WHERE gbc.ScanDate >= DATEADD(DAY,-60,@Today) AND gbc.ScanDate < DATEADD(DAY,1,@Today)
	GROUP BY gbc.CustId;
	
	UPDATE cc
	SET cc.CateId = 7
		, cc.TWBetCount = r.TWBetCount
		, cc.TWGroupBettingRate = r.TWGroupBettingRate
	FROM #tmpCustomerClassification cc
		INNER JOIN #tmpCustomerGroupPercentage AS r ON cc.CustId = r.CustId
	WHERE r.TWTicketParlayCount = 0
		AND ((r.TWBetCount <= 30 AND r.TWGroupBettingRate >= 6)
				OR (r.TWBetCount > 30 AND r.TWGroupBettingRate >= 2)
			);

	UPDATE cc
	SET cc.CateId = 8
	, 	cc.TWDesktopUsageRate = r.TWDesktopUsageRate
	, 	cc.TWTicketRejectRate = r.TWTicketRejectRate
	FROM #tmpCustomerClassification cc
		INNER JOIN #tmpCustomerGroupPercentage AS r ON cc.CustId = r.CustId
	WHERE  cc.CateId IS NULL
		AND r.TWTicketParlayCount = 0
		AND r.TWDesktopUsageRate > 90
		AND r.TWTicketRejectRate >= 30;

	SELECT 	CustId AS 'CustID'
		,	CateId AS 'TaggingID'
		,	2 AS 'TaggingType'
		,	TWBetCount			
		,	TWGroupBettingRate	
		,	TWTicketRejectRate	
		,	TWDesktopUsageRate
	FROM #tmpCustomerClassification;
	
	DROP TABLE IF EXISTS #tmpCustomerClassification;
	DROP TABLE IF EXISTS #tmpCustomerGroupPercentage;


END;

