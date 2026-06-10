/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" viewers="" isFunction="0" isNested="0"></info>*/

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
ALTER PROCEDURE	CTS_Customer_GetNewCustomerInfo
		@LastCustId INT = 0
	,	@rowSize INT = 500
AS
/*
	Creator:	20200118@Casey.Huynh
	Task:		Get New customer - [Redmine ID: 148849]
	Database:	DBCTS.bodb02
	
	Revisions:
		-2020018@Casey.Huynh:Created [Redmine ID: 148849]
        -20210427@Casey.Huynh: Add RoleID Condition [Redmine ID: 153283]
		-20210506@Casey.Huynh: Add condition By CreatedTime and UserName2 [Redmine ID: 154633]
		-20210514@Casey.Huynh: Remove Hardcode TraceTime [Redmine ID: 154633]
		-20232209@Casey.Huynh: Remove Logic Keep Cust With NULL UserName2 [Redmine 193050]
		-20231222@Casey.Huynh: Enhance Get new Cust If Existing in CustInfo [Redmine 198667]
		-20240318@Casey.Huynh: Move logic check existing CustInfo to sp get CustInfo by CustList([Redmine ID: 198000]
		-20241024@Victoria.Le: Missing new customer due to replication inhouse ([Redmine ID: #212655]
		-20241111@John.Ngo:    Missing new customer due to replication inhouse ([Redmine ID: #212655]
		-20250416@Thomas.Nguyen: Remove logic for MaxRepUpdateTime [Redmine ID: #223443]

	Developer's Notes:
		

	exec CTS_Customer_GetNewCustomerInfo 10, 10
		
*/
BEGIN;
	SET NOCOUNT ON;

	DECLARE @custIDList	VARCHAR(MAX);

	IF	OBJECT_ID('tempdb..#tmpNewCust') IS NOT NULL
		DROP TABLE	#tmpNewCust;

	CREATE TABLE #tmpNewCust(
		CustId			INT NOT NULL
	,	CreatedDate		SMALLDATETIME
	,	RoleID			TINYINT
	,	UserName2		VARCHAR(50)
	,	RepUpdateTime	DATETIME2
	,	PRIMARY KEY (CustId)
	);

	INSERT INTO #tmpNewCust(CustId, CreatedDate, RoleId, UserName2, RepUpdateTime)
	SELECT	TOP (@rowSize) 
			c.CustId
		,	c.CreatDate
		,	c.RoleId
		,	c.UserName2
		,	c.RepUpdateTime
	FROM	bodb02.dbo.Customer AS c WITH(NOLOCK)
	WHERE	c.CustId > @LastCustId
	ORDER BY c.CustId ASC;	

	SELECT  @custIDList = COALESCE(@custIDList + ',', '') +  CONVERT(VARCHAR(10),tmpCus.CustID)
	FROM	#tmpNewCust AS tmpCus WITH(NOLOCK)
	WHERE	tmpCus.RoleID BETWEEN 1 AND 4;

	EXEC CTS_Customer_GetInfoByCustIdList @custIDList;

	SELECT	MAX(CustID) AS LastInsertCustID
	FROM	#tmpNewCust AS tmpCus WITH(NOLOCK);	

END;
GO

