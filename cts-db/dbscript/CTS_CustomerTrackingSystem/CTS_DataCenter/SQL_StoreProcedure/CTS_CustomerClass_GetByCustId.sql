/*<info serverAlias="DBCTS-bodb02" executers="bodbSPUNet" isFunction="0" isNested="0"></info>*/

GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[CTS_CustomerClass_GetByCustId] 
		 @custIds				VARCHAR(MAX)
AS
/*
	Created: 20190826@Harvey
	Task : Get fraud information for Customer
	DB: bodb02
	Original:

	Revisions:
		-	20190826@Harvey: init SPs											[Redmine: #140971]
		 

	Param's Explanation:

	EXEC [CTS_CustomerClass_GetByCustId] '888234,40751882'
*/
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #tmpCustomers (CustId INT)

	INSERT INTO #tmpCustomers(CustId)
	SELECT val FROM dbo.f_SplitString(@custIds,',')
	OPTION (maxrecursion 0);

	SELECT	ci.custid
		,	ci.CustomerClass
	FROM dbo.custInfo ci WITH (NOLOCK)
		INNER JOIN #tmpCustomers tcust WITH (NOLOCK) ON ci.custid = tcust.CustId;

	DROP TABLE #tmpCustomers;
END;
