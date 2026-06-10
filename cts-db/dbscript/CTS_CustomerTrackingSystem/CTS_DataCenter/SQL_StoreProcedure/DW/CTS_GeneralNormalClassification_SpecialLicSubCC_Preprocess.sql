/*<info serverAlias="DBVR2-bodb_VR2Model" executers="wsv_cts" isFunction="0" isNested="0"></info>*/
USE [bodb_VR2Model]
GO
/****** Object:  StoredProcedure [dbo].[CTS_GeneralNormalClassification_SpecialLicSubCC_Preprocess]    Script Date: 06/01/2023 2:56:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CTS_GeneralNormalClassification_SpecialLicSubCC_Preprocess]
	@ListCustId		VARCHAR(MAX)
AS
/*
	Created: 20250515@Casey.Huynh
	Task :  Insert custIds to Normal Classification pool
	DB: bodb_VR2Model
	Original:

	Revisions:
		- 20250515@Casey.Huynh: Created [Redmine ID: #226847]

		Param's Explanation:

    Script:
        EXEC bodb_VR2Model.dbo.[CTS_GeneralNormalClassification_SpecialLicSubCC_Preprocess]  @ListCustId = '1,2,3';
*/
BEGIN
	
	SET NOCOUNT ON;

	DECLARE	@FunctionId				TINYINT = 10;

	DECLARE	@Priority				SMALLINT,
			@Priority_GroupId		TINYINT  = 1,
			@Priority_ActionUnknown SMALLINT = 9999;
	
	IF OBJECT_ID('tempdb..#tmpCustomers') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpCustomers;
	END

	CREATE TABLE #tmpCustomers (CustId INT PRIMARY KEY);

	-- #1: Get Customers
    INSERT INTO  #tmpCustomers (CustId) 
	SELECT DISTINCT CAST(value AS INT) CustId 
	FROM STRING_SPLIT(@ListCustId, ',');

	-- #2: Remove disable account
	DELETE r WITH(ROWLOCK)
	FROM #tmpCustomers AS r
		INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON r.CustId = c.custid
	WHERE c.[Enabled] = 0

	-- #3: Get priority
	SELECT @Priority = ISNULL(p.[Priority], @Priority_ActionUnknown)  
	FROM dbo.CustomerClassification_Priority AS p WITH(NOLOCK)
	WHERE p.GroupId = @Priority_GroupId AND p.FunctionId = @FunctionId;

	-- #4: Insert Normal Classification Pool
	EXEC dbo.CTS_GeneralNormalClassification_NormalPool_Insert @FunctionId = @FunctionId, @Priority = @Priority;

END;
GO
