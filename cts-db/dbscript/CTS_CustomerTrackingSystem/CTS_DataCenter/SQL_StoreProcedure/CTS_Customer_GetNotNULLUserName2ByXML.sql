/*<info serverAlias="DBCTS-bodb02" executers="bodbSPUNet" viewers="" isFunction="0" isNested="0"></info>*/

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
ALTER PROCEDURE	CTS_Customer_GetNotNULLUserName2ByXML
		@custXML	XML
	,	@Is_CustSub	BIT
AS
/*
	Creator:	20210115@CaseyHuynh
	Task:		Get customer - [Redmine: #148849]
	Database:	DBCTS.bodb02
	
	Revisions:
		-20210115@Casey.Huynh: Created [Redmine ID: 148849]
        -20210222@Casey.Huynh: Remove Get UserName2 Info from Customer [149941]
		-20231003@Casey.Huynh: Add Get UserName2 Info from Customer [193050]

	Developer's Notes:
		- @Example:			NULL		- Explaination [DEFAULT]

	exec EXEC  @return_value = [dbo].[CTS_Customer_GetNotNULLUserName2ByXML]
			@custXML = N'<Root>
            <Customer CustID="47087783" CustSubID="1441102" CTSCustID = "222294242"/>      
          </Root>'

		
*/
BEGIN;
	SET NOCOUNT ON;
	IF OBJECT_ID('tempdb..#tmpInputCust') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpInputCust;
	END;

	CREATE TABLE #tmpInputCust (
			CustID		INT
		,	CustSubID	INT
		,	CTSCustID	BIGINT
	);

	INSERT INTO #tmpInputCust(CustID, CustSubID, CTSCustID)
	SELECT	T.C.value('./@CustID', 'INT') AS CustId
			, T.C.value('./@CustSubID', 'INT') AS CustSubID
			, T.C.value('./@CTSCustID', 'BIGINT') AS CTSCustID
	FROM @custXML.nodes('//Customer') AS T(C)
	OPTION (OPTIMIZE FOR (@custXML = NULL));
	
	IF @Is_CustSub = 1
	BEGIN
		SELECT	tmpCus.CustID
			,	tmpCus.CustSubID
			,	cusSub.UserName2
			,	tmpCus.CTSCustID
		FROM	dbo.CustSub AS cusSub WITH (NOLOCK)
		INNER JOIN #tmpInputCust AS tmpCus WITH(NOLOCK) ON cusSub.subaccid = tmpCus.CustSubID
		WHERE	cusSub.username2 IS NOT NULL AND tmpCus.CustSubID > 0
		;
	END;

		
	IF @Is_CustSub = 0
	BEGIN
		SELECT	cus.CustID
			,	0 AS CustSubID
			,	cus.UserName2
			,	tmpCus.CTSCustID
		FROM	dbo.Customer AS cus WITH (NOLOCK)
		INNER JOIN #tmpInputCust AS tmpCus WITH(NOLOCK) ON cus.CustID = tmpCus.CustID
		WHERE	cus.username2 IS NOT NULL;
		;
	END;
END;
GO