/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[CTS_GeneralNormalClassificationAgency_NormalPool_Get]
	@ScannedMaxId BIGINT OUTPUT
AS
/*
	Created: 20241003@Jonas.Huynh
	Task : Insert customers to normal pool for classification
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20241003@Jonas.Huynh: Created [Redmine ID: #185799]

	Param's Explanation:
		@ScannedMaxId: This parameter is used to output scanned MaxID

    Script:
		DECLARE @output BIGINT
        EXEC bodb_VR2Model.dbo.CTS_GeneralNormalClassificationAgency_NormalPool_Get @ScannedMaxId = @output;
*/
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE	@BATCHSIZE						INT 	= 20000;
	DECLARE @FUNCTIONID_REALTIME			TINYINT = 1;
	DECLARE @GENERALAGENCY_LASTSCANNEDROW	SMALLINT = 1000;

	DECLARE @LastScannedRow					ROWVERSION;

	IF	OBJECT_ID('tempdb..#tmpCustomers') IS NOT NULL
	DROP TABLE	#tmpCustomers;

	CREATE TABLE #tmpCustomers(
		Id					BIGINT PRIMARY KEY IDENTITY(1,1),
		CustId				INT UNIQUE NOT NULL,
		IsRealtimeOnly		BIT DEFAULT(0)
	);

	-- #1: Get Scanned MaxID
	SELECT @ScannedMaxId = MAX(c.ID) 
	FROM dbo.CustomerClassificationAgency_NormalPool AS c WITH(NOLOCK);

	SELECT @LastScannedRow = CAST(CAST([Value] AS BIGINT) AS ROWVERSION) 
	FROM dbo.CustomerClassification_Parameter WITH(NOLOCK) 
	WHERE [DataId] = @GENERALAGENCY_LASTSCANNEDROW;

	-- #2: Get top customers by priority
	IF(@ScannedMaxId IS NOT NULL)
	BEGIN
		INSERT INTO #tmpCustomers(CustId, IsRealtimeOnly)
		SELECT TOP(@BATCHSIZE) c.CustId,
			   CASE WHEN SUM(FunctionId) = (COUNT(c.ID) * @FUNCTIONID_REALTIME) THEN 1 ELSE 0 END
		FROM dbo.CustomerClassificationAgency_NormalPool AS c WITH(NOLOCK)
		WHERE c.ID <= @ScannedMaxId
			AND NOT EXISTS (SELECT 1 FROM dbo.CustomerClassificationAgency AS cc WITH (NOLOCK) WHERE cc.[RowVersion] > @LastScannedRow AND cc.CustId = c.CustId)
		GROUP BY c.CustId
		ORDER BY Min(c.Priority) ASC, Min(c.ID) ASC;
	END

	-- #3: Return dataset
	SELECT CustId			 AS CustId, 
		   IsRealtimeOnly	 AS IsRealtimeOnly
	FROM #tmpCustomers;
	
	DROP TABLE #tmpCustomers;
END;
GO

GRANT EXECUTE ON [dbo].[CTS_GeneralNormalClassificationAgency_NormalPool_Get] TO [wsv_cts]
GO
GRANT VIEW DEFINITION ON [dbo].[CTS_GeneralNormalClassificationAgency_NormalPool_Get] TO [wsv_cts]
GO