/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
/****** Object:  StoredProcedure [dbo].[CTS_BySportNormalClassification_NormalPool_Get]    ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CTS_BySportNormalClassification_NormalPool_Get]
	@ScannedMaxId BIGINT OUTPUT
AS
/*
	Created: 20230630@Jonas.Huynh
	Task : Insert customers to normal pool for classification by sport
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20230630@Jonas.Huynh: Created [Redmine ID: #189875]
		- 20240327@Jonas.Huynh: EC2024 - Resolve Locking [Redmine ID: #200842]

	Param's Explanation:
		@ScannedMaxId: This parameter is used to output scanned MaxID

    Script:
		DECLARE @output BIGINT
        EXEC bodb_VR2Model.dbo.CTS_BySportNormalClassification_NormalPool_Get @ScannedMaxId = @output;
*/
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE	@BATCHSIZE					INT		= 20000;
	DECLARE @BYSPORT_LASTSCANNEDROW		TINYINT = 2;
	DECLARE @LastScannedRow				ROWVERSION;

	IF	OBJECT_ID('tempdb..#tmpCustomers') IS NOT NULL
	DROP TABLE	#tmpCustomers;

	CREATE TABLE #tmpCustomers(
		Id				BIGINT PRIMARY KEY IDENTITY(1,1),
		CustId			INT NOT NULL,
		SportGroup		SMALLINT NOT NULL,
		IsCheckBetCount BIT DEFAULT(0)
	);

	-- #1: Get Scanned MaxID
	SELECT @ScannedMaxId = MAX(c.ID)
	FROM dbo.CustomerClassification_BySport_NormalPool AS c WITH(NOLOCK);

	SELECT @LastScannedRow = CAST(CAST([Value] AS BIGINT) AS ROWVERSION) 
	FROM dbo.CustomerClassification_Parameter WITH(NOLOCK) 
	WHERE [DataId] = @BYSPORT_LASTSCANNEDROW;

	-- #2: Get top customers by priority
	IF(@ScannedMaxId IS NOT NULL)
	BEGIN
		INSERT INTO #tmpCustomers(CustId, SportGroup, IsCheckBetCount)
		SELECT TOP(@BATCHSIZE) np.CustId, np.SportGroup,
			   CASE WHEN (COUNT(np.CustId) = COUNT(np.FunctionId)) AND (COUNT(np.FunctionId) = SUM(np.FunctionId)) THEN 1 ELSE 0 END
		FROM dbo.CustomerClassification_BySport_NormalPool AS np WITH(NOLOCK)
		WHERE np.ID <= @ScannedMaxId 
			AND NOT EXISTS (SELECT 1 FROM dbo.CustomerClassification_BySport AS cc WITH (NOLOCK) 
							WHERE cc.CustId = np.CustId
								AND cc.SportId = np.SportGroup
								AND cc.[RowVersion] > @LastScannedRow)
		GROUP BY np.CustId, np.SportGroup
		ORDER BY Min(np.Priority) ASC, Min(np.ID) ASC
	END

	-- #3: Return dataset
	SELECT CustId		   AS CustId, 
		   SportGroup	   AS SportGroup,
		   IsCheckBetCount AS IsCheckBetCount
	FROM #tmpCustomers
	ORDER BY CustId;
	
	DROP TABLE #tmpCustomers;
END;
GO

GRANT EXECUTE ON [dbo].[CTS_BySportNormalClassification_NormalPool_Get] TO [wsv_cts]
GO
GRANT VIEW DEFINITION ON [dbo].[CTS_BySportNormalClassification_NormalPool_Get] TO [wsv_cts]
GO