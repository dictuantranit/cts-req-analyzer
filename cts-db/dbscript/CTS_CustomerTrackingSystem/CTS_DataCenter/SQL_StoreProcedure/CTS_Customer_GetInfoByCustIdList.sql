/*<info serverAlias="DBCTS-WASAVerse" executers="wsv_cts" viewers="" isFunction="0" isNested="1"></info>*/

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
ALTER PROCEDURE	CTS_Customer_GetInfoByCustIdList
		@custIdList			VARCHAR(MAX) = ''
	,	@sourceType			TINYINT	= 0
AS
/*
	Creator:	20191128@Harvey
	Task:		Get customer - [Redmine: #124592]
	Database:	DBCTS.bodb02
	
	Revisions:
		- 20181121@Harvey:		Initial - [Redmine: #124592]
		- 20200423@Harvey:		New way to get siteId, siteName - [Redmine: #132705]
		- 20202005@Harvey:		only get SMAP (roleid 4321) 	- [Redmine: #133934]
		- 20200623@Long.Luu:	Sync more Customer Info [Redmine: #136046]
		- 20200827@Long.Luu:	Fix CN88 account status checking condition [Redmine: #137647]
		- 20210112@Long.Luu:	Fix Customer Status Issue & Remove Robot checking [Redmine: #148541]
		- 20191128@Casey.Huynh:	Enhance CTSCustomerFlow [Redmine ID: 148849]
		- 20210205@Casey.Huynh:	Return  Customer Info [Redmine ID: 149941]
		- 20210423@Casey.Huynh:	Enhance Get Closed and Suspended Status of Credit Customer from table bodb02.dbo.CustProductStatus [Redmine ID: #152259]		
		- 20211214@Long.Luu:	Return more data (danger from 1 to 5) [Redmine: #165105]
		- 20220616@Long.Luu:	Get Licensee Info [Redmine ID: 174136]
		- 20220621@Long.Luu:	Enhance way to get licensee info [Redmine ID: 174136]
		- 20220707@Long.Luu:	Get Lic VIP & BA Info [Redmine ID: 174219]
		- 20220822@Long.Luu:	Return more data [Redmine ID: 175698]
		- 20221205@Victoria.Le:	Return more data: DangerSabaSc (Saba Soccer) and DangerSabaBkb (Saba Baseketball) [Redmine ID: #181208]
		- 20240318@Casey.Huynh: Return empty if not existing CustInfo, CustProductStatus , CustInfo, Dep_CustSuper [Redmine ID: #198000]
		- 20241216@Tony.Nguyen: Change the process so that it retrieves SiteID/Site for the member directly (Redmine ID: #214585)
		- 20250416@Thomas.Nguyen: Return more Customer missing info [Redmine ID: #223443]
		- 20250428@Thomas.Nguyen: Upgrade CurrencyID datatype [Redmine ID: #225335]
		- 20250611@Thomas.Nguyen: Return more reactivated cust missed info [Redmine ID: #230204]

	Param's Explanation (filtered by):
		- @sourceType: 0- GET New Customer Info
		, 1- Get Info Customer table
		, 2- Get CustInfo table
		, 3- GET Info CustProductStatus table

	EXEC CTS_Customer_GetInfoByCustIdList '1,2,3,95396080', 0	

*/
BEGIN;
	SET NOCOUNT ON;

	DECLARE @MBC_ACCOUNTSTATUS_OPEN			INT = 1
		,	@MBC_ACCOUNTSTATUS_DISABLED		INT = 2
		,	@MBC_ACCOUNTSTATUS_CLOSED		INT = 3
		,	@MBC_ACCOUNTSTATUS_SUSPENDED	INT = 4;

	--=============CHECK EXISTING==============================
	DECLARE @CheckExisting BIT = 1;

	IF OBJECT_ID('tempdb..#tmpCustomers') IS NOT NULL
	BEGIN
		DROP TABLE	#tmpCustomers;
	END;

	CREATE TABLE #tmpCustomers (
			CustId			INT NOT NULL PRIMARY KEY		
		,	CustStatusID	TINYINT NULL
		,	Danger1			TINYINT NULL
		,	Danger2			TINYINT NULL
		,	Danger3			TINYINT NULL		
		,	Danger4			TINYINT NULL
		,	Danger5			TINYINT NULL
		,	DangerSabaSc	TINYINT NULL	
		,	DangerSabaBkb	TINYINT NULL
		,	Username		VARCHAR(30)
		,	Username2		VARCHAR(50)
		,	SiteId			INT
		,	[Site]			VARCHAR(10)
		,	RoleId			TINYINT
		,	CurrencyId		SMALLINT
		,	Currency		VARCHAR(50)
		,	Srecommend		INT
		,	Mrecommend		INT
		,	Recommend		INT
		,	CreatedDate		DATETIME	
		,	IsLicensee		BIT		
		,	IsLicenseeVIP	BIT DEFAULT 0		
		,	IsLicenseeBA	BIT DEFAULT 0

		,	CustInfoRepUpdateTime			DATETIME2
		,	SiteRepUpdateTime				DATETIME2
		,	DepCustSuperRepUpdateTime		DATETIME2
		,	CustProductStatusRepUpdateTime	DATETIME2
	);

	INSERT INTO #tmpCustomers (CustId)
	SELECT ssk.value FROM STRING_SPLIT (@custIdList, ',') ssk;

	CREATE TABLE #Tmp_CustMissingInfo(
		CustID			INT NOT NULL PRIMARY KEY
	);

	--=========================================================

	IF (@sourceType IN (0,1,2))
	BEGIN
		UPDATE	tmpCust 
		SET		Username = 	cust.username
			,	Username2 = cust.username2	
			,	SiteId = st2.siteid
			,	[Site] = cust.[site]
			,	RoleId = cust.roleid		
			,	CurrencyId = cust.currency
			,	Currency = ex.currency
			,	Srecommend = cust.srecommend
			,	Mrecommend = cust.mrecommend 
			,	Recommend = cust.recommend	
			,	CreatedDate = cust.creatdate
			,	SiteRepUpdateTime = st2.RepUpdateTime
		FROM bodb02.dbo.Customer AS cust WITH (NOLOCK)
			INNER JOIN #tmpCustomers AS tmpCust WITH (NOLOCK) ON cust.custid = tmpCust.CustId
			INNER JOIN bodb02.dbo.Exchange AS ex WITH (NOLOCK) ON cust.currency = ex.exchangeid
			LEFT JOIN bodb02.dbo.[Site] AS st2 WITH (NOLOCK) ON cust.[site] = st2.[site];

		UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET a.CustStatusID = (CASE 
								WHEN c.[Enabled] <> 1 THEN @MBC_ACCOUNTSTATUS_DISABLED
								WHEN c.closed = 1 THEN @MBC_ACCOUNTSTATUS_CLOSED
								WHEN c.reject = 1 THEN @MBC_ACCOUNTSTATUS_SUSPENDED
								ELSE @MBC_ACCOUNTSTATUS_OPEN END)
			,	a.Danger1 = c.danger
			,	a.Danger2 = c.danger2
			,	a.Danger3 = c.danger3
			,	a.Danger4 = c.Danger4
			,	a.Danger5 = c.Danger5
			,	a.DangerSabaSc = (CASE 
									WHEN DangerLevel IS NOT NULL THEN DangerLevel&15
									ELSE 0 END)
			,	a.DangerSabaBkb = (CASE 
									WHEN DangerLevel IS NOT NULL THEN (DangerLevel&240)/16
									ELSE 0 END)
			,	a.IsLicensee = 1
			,	a.CustInfoRepUpdateTime = c.RepUpdateTime
			,	a.DepCustSuperRepUpdateTime = cs.RepUpdateTime
		FROM #tmpCustomers AS a
			INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON a.custid = c.custid
			INNER JOIN bodb02.dbo.Dep_CustSuper AS cs WITH(NOLOCK) ON a.Srecommend = cs.custid;

		UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET a.CustStatusID = (CASE 
								WHEN c.[Enabled] <> 1 THEN @MBC_ACCOUNTSTATUS_DISABLED
								WHEN s.CloseInfo <> 0 THEN @MBC_ACCOUNTSTATUS_CLOSED
								WHEN s.SuspendInfo <> 0 THEN @MBC_ACCOUNTSTATUS_SUSPENDED
								ELSE @MBC_ACCOUNTSTATUS_OPEN END)
			,	a.Danger1 = c.danger
			,	a.Danger2 = c.danger2
			,	a.Danger3 = c.danger3
			,	a.Danger4 = c.Danger4
			,	a.Danger5 = c.Danger5
			,	a.DangerSabaSc = (CASE 
									WHEN DangerLevel IS NOT NULL THEN DangerLevel&15
									ELSE 0 END)
			,	a.DangerSabaBkb = (CASE 
									WHEN DangerLevel IS NOT NULL THEN (DangerLevel&240)/16
									ELSE 0 END)
			,	a.IsLicensee = 0
			,	a.CustInfoRepUpdateTime = ISNULL(a.CustInfoRepUpdateTime,c.RepUpdateTime)
			,	a.CustProductStatusRepUpdateTime = s.RepUpdateTime
		FROM #tmpCustomers AS a
			INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON a.custid = c.custid
			INNER JOIN bodb02.dbo.CustProductStatus AS s WITH(NOLOCK) ON a.custid = s.custid
		WHERE	a.CustStatusID IS NULL;

		UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET a.IsLicenseeVIP = 1
		FROM #tmpCustomers AS a
			INNER JOIN DBCUST.custDB.dbo.Dep_CustVIP AS c WITH(NOLOCK) ON a.custid = c.CustID
		WHERE	a.IsLicensee = 1;

		UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET a.IsLicenseeBA = 1
		FROM #tmpCustomers AS a
			INNER JOIN DBCUST.custDB.dbo.Dep_CustBAActive AS s WITH(NOLOCK) ON a.custid = s.custid
		WHERE	a.IsLicensee = 1;
	END;

	IF (@sourceType = 3)
	BEGIN
		UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET a.CustStatusID = (CASE 
								WHEN c.[Enabled] <> 1 THEN @MBC_ACCOUNTSTATUS_DISABLED
								WHEN s.CloseInfo <> 0 THEN @MBC_ACCOUNTSTATUS_CLOSED
								WHEN s.SuspendInfo <> 0 THEN @MBC_ACCOUNTSTATUS_SUSPENDED
								ELSE @MBC_ACCOUNTSTATUS_OPEN END)
		FROM #tmpCustomers AS a
			INNER JOIN bodb02.dbo.custInfo AS c WITH(NOLOCK) ON a.custid = c.custid
			INNER JOIN bodb02.dbo.CustProductStatus AS s WITH(NOLOCK) ON a.custid = s.custid;
	END;

	--============================================
	IF (@sourceType = 0)
	BEGIN
		INSERT INTO #Tmp_CustMissingInfo(CustID)
		SELECT tmp.CustId
		FROM #tmpCustomers AS tmp WITH(NOLOCK)
		WHERE ((tmp.IsLicensee IS NULL OR tmp.SiteId IS NULL) AND tmp.CurrencyId NOT IN (20,27,28)) OR tmp.UserName IS NULL;

		SELECT	a.CustId		AS CustID
			,	a.Username		AS UserName
			,	a.Username2		AS UserName2
			,	a.SiteId		AS SiteID
			,	a.[Site]		AS 'Site'
			,	a.RoleId		AS RoleID
			,	a.CurrencyId	AS CurrencyID
			,	a.Currency		AS Currency
			,	a.Srecommend	AS SRecommend
			,	a.Mrecommend	AS MRecommend
			,	a.Recommend		AS Recommend
			,	a.CreatedDate	AS CreatedDate
			,	a.CustStatusID	AS CustStatusID
			,	a.Danger1		AS Danger1
			,	a.Danger2		AS Danger2
			,	a.Danger3		AS Danger3			
			,	a.Danger4		AS Danger4
			,	a.Danger5		AS Danger5
			,	a.DangerSabaSc	AS DangerSabaSc
			,	a.DangerSabaBkb	AS DangerSabaBkb
			,	a.IsLicensee	AS IsLicensee
			,	a.IsLicenseeVIP	AS IsLicenseeVIP
			,	a.IsLicenseeBA	AS IsLicenseeBA

			,	a.CustInfoRepUpdateTime				AS CustInfoRepUpdateTime
			,	a.DepCustSuperRepUpdateTime			AS DepCustSuperRepUpdateTime
			,	a.SiteRepUpdateTime					AS SiteRepUpdateTime
			,	a.CustProductStatusRepUpdateTime	AS CustProductStatusRepUpdateTime
		FROM #tmpCustomers AS a WITH(NOLOCK)
		WHERE NOT EXISTS (SELECT TOP(1) 1 FROM #Tmp_CustMissingInfo AS tmp WITH(NOLOCK) WHERE a.CustId = tmp.CustID);

		--==============RETURN CUST MISSING INFO====================
		SELECT CustID
		FROM #Tmp_CustMissingInfo WITH(NOLOCK);
	END;

	IF (@sourceType = 1)
	BEGIN
		SELECT	a.CustId		AS CustID
			,	a.Username		AS UserName
			,	a.Username2		AS UserName2
			,	a.SiteId		AS SiteID
			,	a.[Site]		AS 'Site'
			,	a.RoleId		AS RoleID
			,	a.CurrencyId	AS CurrencyID
			,	a.Currency		AS Currency
			,	a.Srecommend	AS SRecommend
			,	a.Mrecommend	AS MRecommend
			,	a.Recommend		AS Recommend
			,	a.CreatedDate	AS CreatedDate
			,	a.IsLicensee	AS IsLicensee
			,	a.IsLicenseeVIP	AS IsLicenseeVIP
			,	a.IsLicenseeBA	AS IsLicenseeBA
		FROM #tmpCustomers AS a WITH(NOLOCK)
	END;

	IF (@sourceType = 2)
	BEGIN
		SELECT	a.CustID		AS CustID
			,	a.CustStatusID	AS CustStatusID
			,	a.Danger1		AS Danger1
			,	a.Danger2		AS Danger2
			,	a.Danger3		AS Danger3		
			,	a.Danger4		AS Danger4
			,	a.Danger5		AS Danger5
			,	a.DangerSabaSc	AS DangerSabaSc
			,	a.DangerSabaBkb	AS DangerSabaBkb
		FROM #tmpCustomers AS a WITH(NOLOCK);
	END;

	IF (@sourceType = 3)
	BEGIN
		SELECT	a.CustID		AS CustID
			,	a.CustStatusID	AS CustStatusID
		FROM #tmpCustomers AS a WITH(NOLOCK);
	END;

END;

