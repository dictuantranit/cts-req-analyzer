/*<info serverAlias="DBCTSC-bodb_CustHistory" executers="wsv_cts" viewers="" isFunction="0" isNested="0"></info>*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
ALTER PROCEDURE	CTS_CustProductStatusHistory_GetUpdatedCustID
		@lastUpdateTime		DATETIME
	,	@lastCustId			INT
	,	@rowSize			INT = 500
	,	@waitTime			SMALLINT = 0
AS
/*
	Creator:	20210423@CaseyHuynh
	Task:		Get updated Credit Customer Status [Redmine ID: #152259]
	Database:	bodb_CustHistory
	
	Revisions:
		- 20210423@CaseyHuynh: Created [Redmine ID: #152259]
		- 20250121@Jonas.Huynh: Fix customer info missing due to latency [Redmine ID: 214157]

	Developer's Notes:
		- @Example:			NULL		- Explaination [DEFAULT]

	exec CTS_CustProductStatus_GetUpdatedCustID '2020-09-11 06:18:51.743',44757634,500,60
		

*/
BEGIN;
	SET NOCOUNT ON;

	DECLARE	@rowCount				INT;
	DECLARE	@maxUpdateTime			DATETIME;
	DECLARE @nextUpdateTime			DATETIME;
	DECLARE @nextValidUpdateTime	DATETIME;
	DECLARE @custIdList				VARCHAR(MAX);

	IF	OBJECT_ID('tempdb..#tmpUpdatedCustProductStatus') IS NOT NULL
		DROP TABLE	#tmpUpdatedCustProductStatus;
	
	CREATE TABLE #tmpUpdatedCustProductStatus (
			UpdateTime	DATETIME
		,	CustId		INT
	);

	INSERT INTO #tmpUpdatedCustProductStatus(UpdateTime, CustID)
	SELECT		TOP(@rowSize) cih.UpdateTime
				, cih.CustID
	FROM		bodb_CustHistory.dbo.CustProductStatus_History AS cih WITH(NOLOCK)
	WHERE		cih.UpdateTime = @lastUpdateTime
				AND cih.CustId > @lastCustId
	ORDER BY	cih.UpdateTime ASC, cih.CustID ASC;

	SET @rowCount = (SELECT COUNT(1) FROM #tmpUpdatedCustProductStatus AS tmpCus)

	IF(@rowCount < @rowSize)
	BEGIN
     	SET @nextUpdateTime = (SELECT MAX(cih.UpdateTime) FROM bodb_CustHistory.dbo.CustProductStatus_History AS cih WITH(NOLOCK));
		SET @nextValidUpdateTime = DATEADD(SECOND, -@waitTime, @nextUpdateTime);

		IF (@nextValidUpdateTime > @lastUpdateTime)
		BEGIN 
			INSERT INTO #tmpUpdatedCustProductStatus(UpdateTime, CustID)
			SELECT		TOP(@rowSize - @rowCount) cih.UpdateTime
					,	cih.CustID
			FROM		bodb_CustHistory.dbo.CustProductStatus_History AS cih WITH(NOLOCK)
			WHERE		cih.UpdateTime > @lastUpdateTime
						AND cih.UpdateTime <= @nextValidUpdateTime
			ORDER BY	cih.UpdateTime, cih.CustID;
		END;
	END;

	SET  @maxUpdateTime = (SELECT MAX(tmpCus1.UpdateTime) FROM #tmpUpdatedCustProductStatus AS tmpCus1)

	SELECT	@maxUpdateTime AS LastUpdatedTime
			, MAX(tmpCus.CustId) AS LastCustId
	FROM	#tmpUpdatedCustProductStatus AS tmpCus
	WHERE	tmpCus.UpdateTime = @maxUpdateTime;

	SELECT	@custIdList = COALESCE(@custIdList + ',', '') +  CONVERT(VARCHAR(12), tmp.CustId)
	FROM	(	SELECT DISTINCT tmpCus.CustId
				FROM  #tmpUpdatedCustProductStatus AS tmpCus) AS tmp;

	SELECT	@custIdList AS CustIdList;
END;
GO