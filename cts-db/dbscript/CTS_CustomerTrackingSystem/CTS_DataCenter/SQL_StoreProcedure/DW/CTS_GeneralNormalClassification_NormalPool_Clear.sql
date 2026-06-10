/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
/****** Object:  StoredProcedure [dbo].[CTS_GeneralNormalClassification_NormalPool_Clear]    Script Date: 4/26/2023 2:12:54 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CTS_GeneralNormalClassification_NormalPool_Clear]
	@ListCustId		VARCHAR(MAX),
	@ScannedMaxId	BIGINT
AS
/*
	Created: 20230421@Jonas.Huynh
	Task : Insert customers to normal pool for classification
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20230420@Jonas.Huynh: Created [Redmine ID: #186678]
		- 20240327@Jonas.Huynh: EC2024 - Resolve Locking [Redmine ID: #200842]

	Param's Explanation:
		@ListCustId	 : This parameter is used to clear processed customer from normal pool
		@ScannedMaxId: This parameter is used to be as a scanned milestone to clear customer from normal pool

    Script:
        EXEC bodb_VR2Model.dbo.CTS_GeneralNormalClassification_NormalPool_Clear @ListCustId = '1,2,3',
																				@ScannedMaxId = 989347;
*/
BEGIN
	
	SET NOCOUNT ON;
	
	IF OBJECT_ID('tempdb..#tmpCustomers') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpCustomers;
	END

	CREATE TABLE #tmpCustomers (CustId INT PRIMARY KEY);

	IF OBJECT_ID('tempdb..#tmpIDs') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpIDs;
	END
	   
	CREATE TABLE #tmpIDs (ID BIGINT PRIMARY KEY);

	-- #1: Get Customers
    INSERT INTO  #tmpCustomers (CustID) 
	SELECT DISTINCT CAST(value AS INT) CustID 
	FROM STRING_SPLIT(@ListCustId, ',');

	-- #2: Clear normal pool
	IF(@ScannedMaxId IS NOT NULL)
	BEGIN
		INSERT INTO #tmpIDs (ID)
		SELECT p.ID
		FROM [dbo].[CustomerClassification_NormalPool] AS p WITH(NOLOCK)
			INNER JOIN #tmpCustomers AS t ON t.CustId = p.CustId
		WHERE p.ID <= @ScannedMaxId;

		DELETE c WITH (ROWLOCK)
		FROM #tmpIDs AS r 
			INNER LOOP JOIN [dbo].[CustomerClassification_NormalPool] AS c ON r.ID = c.ID;
	END;
	
	DROP TABLE #tmpCustomers;
	DROP TABLE #tmpIDs;
END;
GO

GRANT EXECUTE ON [dbo].[CTS_GeneralNormalClassification_NormalPool_Clear] TO [wsv_cts]
GO
GRANT VIEW DEFINITION ON [dbo].[CTS_GeneralNormalClassification_NormalPool_Clear] TO [wsv_cts]
GO