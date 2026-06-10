/*<info serverAlias="DBARCCUST-bodb_Customer" executers="wsv_cts" viewers="" isFunction="0" isNested="0"></info>*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
ALTER PROCEDURE	CTS_ArchivedCustomerMissing_Get
		@lastArchiveDate	DATETIME
	,	@maxArchiveDate		DATETIME
	,	@lastCustId			INT
	,	@rowSize			INT = 500
    ,	@custType			TINYINT
AS
/*
	Creator:	20240510@Jonas.Huynh
	Task:		Get Achived Customer Missing [Redmine ID: 204368]
	Database:	bodb_Customer
	
	Revisions:
		- 20240510@Jonas.Huynh: Created [Redmine ID: 204368]

	Developer's Notes:
    
	EXEC CTS_ArchivedCustomerMissing_Get '2021-02-03 03:35:51.810','2021-02-03 03:35:51.810',100,150,1	

*/
BEGIN;
	SET NOCOUNT ON;

	DECLARE	@toDate			DATETIME = GETDATE();
	DECLARE	@rowCount		INT;

	IF	OBJECT_ID('tempdb..#tmpArchivedCustomers') IS NOT NULL
		DROP TABLE	#tmpArchivedCustomers;
	
	CREATE TABLE #tmpArchivedCustomers (
			ArchivedDate DATETIME
		,	CustId		 INT
	);
	
	CREATE CLUSTERED INDEX IX_tmpArchivedCustomers_ArchivedDateCustId ON #tmpArchivedCustomers(
			ArchivedDate	ASC
		,	CustId			ASC
	);

	IF(@custType = 0) --Credit
	BEGIN
		INSERT INTO #tmpArchivedCustomers(ArchivedDate, CustID)
		SELECT		TOP(@rowSize) arc.ArchiveDate
					, arc.CustID
		FROM		bodb_Customer.dbo.CustInfo_Old AS arc WITH(NOLOCK)
		WHERE		arc.ArchiveDate = @lastArchiveDate
					AND arc.CustId > @lastCustId
					AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.Customer AS cust WITH(NOLOCK) WHERE cust.CustID = arc.CustID)
		ORDER BY	arc.CustID ASC;

		SET @rowCount = (SELECT COUNT(1) FROM #tmpArchivedCustomers AS tmpCus)

		IF(@rowCount < @rowSize)
		BEGIN
			INSERT INTO #tmpArchivedCustomers(ArchivedDate, CustID)
			SELECT		TOP(@rowSize - @rowCount) arc.ArchiveDate
					,	arc.CustID
			FROM		bodb_Customer.dbo.CustInfo_Old AS arc WITH(NOLOCK)
			WHERE		arc.ArchiveDate > @lastArchiveDate
						AND arc.ArchiveDate <= @maxArchiveDate
						AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.Customer AS cust WITH(NOLOCK) WHERE cust.CustID = arc.CustID)
			ORDER BY	arc.ArchiveDate ASC, arc.CustID ASC;
		END;
	END;
	IF (@custType = 1) --Licencee
	BEGIN
		INSERT INTO #tmpArchivedCustomers(ArchivedDate, CustID)
		SELECT		TOP(@rowSize) arc.ArchivedDate
					, arc.CustID
		FROM		bodb02.dbo.Dep_Customer_Archived AS arc WITH(NOLOCK)
		WHERE		arc.ArchivedDate = @lastArchiveDate
					AND arc.CustId > @lastCustId
					AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.Customer AS cust WITH(NOLOCK) WHERE cust.CustID = arc.CustID)
		ORDER BY	arc.CustID ASC;

		SET @rowCount = (SELECT COUNT(1) FROM #tmpArchivedCustomers AS tmpCus)

		IF(@rowCount < @rowSize)
		BEGIN
			INSERT INTO #tmpArchivedCustomers(ArchivedDate, CustID)
			SELECT		TOP(@rowSize - @rowCount) arc.ArchivedDate
					,	arc.CustID
			FROM		bodb02.dbo.Dep_Customer_Archived AS arc WITH(NOLOCK)
			WHERE		arc.ArchivedDate > @lastArchiveDate
						AND arc.ArchivedDate <= @maxArchiveDate
						AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.Customer AS cust WITH(NOLOCK) WHERE cust.CustID = arc.CustID)
			ORDER BY	arc.ArchivedDate ASC, arc.CustID ASC;
		END;
	END;

	SELECT ArchivedDate, CustID FROM #tmpArchivedCustomers;
END;
GO

GRANT EXECUTE ON [dbo].[CTS_ArchivedCustomerMissing_Get] TO [wsv_cts]
GO
GRANT VIEW DEFINITION ON [dbo].[CTS_ArchivedCustomerMissing_Get] TO [wsv_cts]
GO