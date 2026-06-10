/*<info serverAlias="DBARCCUST-bodb_Customer" executers="bodbSPUNet" viewers="" isFunction="0" isNested="0"></info>*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
ALTER PROCEDURE	CTS_ArchiveCustomer_Get
		@lastArchiveDate	DATETIME
	,	@lastCustId			INT
	,	@rowSize			INT = 500
    ,	@custType			TINYINT
AS
/*
	Creator:	20211008@CaseyHuynh
	Task:		Get Archive Customer [Redmine ID: 159611]
	Database:	bodb_Customer
	
	Revisions:
		- 20210205@CaseyHuynh: Created [Redmine ID: 159611]
		- 20240426@Jonas.Huynh: Enhance Archived Customers [Redmine ID: 203323]

	Developer's Notes:
    
	EXEC CTS_ArchiveCustomer_Get '2021-02-03 03:35:51.810',100,150,1	

*/
BEGIN;
	SET NOCOUNT ON;

	DECLARE	@toDate			DATETIME = GETDATE();
	DECLARE	@maxArchiveDate	DATETIME = DATEADD(MINUTE, -1, @toDate);
	DECLARE	@rowCount		INT;

	IF	OBJECT_ID('tempdb..#tmpArchivedCustomers') IS NOT NULL
		DROP TABLE	#tmpArchivedCustomers;
	
	CREATE TABLE #tmpArchivedCustomers (
			ArchivedDate DATETIME
		,	CustId		INT
	);
	
	CREATE CLUSTERED INDEX IX_tmpArchivedCustomers_ArchivedDateCustId ON #tmpArchivedCustomers(
			ArchivedDate	ASC
		,	CustId			ASC
	);

	IF(@custType = 0) --Credit
	BEGIN
		INSERT INTO #tmpArchivedCustomers(ArchivedDate, CustID)
		SELECT		TOP(@rowSize) cus.ArchiveDate
					, cus.CustID
		FROM		bodb_Customer.dbo.CustInfo_Old AS cus WITH(NOLOCK)
		WHERE		cus.ArchiveDate = @lastArchiveDate
					AND cus.CustId > @lastCustId
		ORDER BY	cus.CustID ASC;

		SET @rowCount = (SELECT COUNT(1) FROM #tmpArchivedCustomers AS tmpCus)

		IF(@rowCount < @rowSize)
		BEGIN
			INSERT INTO #tmpArchivedCustomers(ArchivedDate, CustID)
			SELECT		TOP(@rowSize - @rowCount) cus.ArchiveDate
					,	cus.CustID
			FROM		bodb_Customer.dbo.CustInfo_Old AS cus WITH(NOLOCK)
			WHERE		cus.ArchiveDate > @lastArchiveDate
						AND cus.ArchiveDate <= @maxArchiveDate
			ORDER BY	cus.ArchiveDate ASC, cus.CustID ASC;
		END;
	END;
	IF (@custType = 1) --Licencee
	BEGIN
		INSERT INTO #tmpArchivedCustomers(ArchivedDate, CustID)
		SELECT		TOP(@rowSize) cus.ArchivedDate
					, cus.CustID
		FROM		Bodb_Archive_Customer_Licensee.dbo.custInfo AS cus WITH(NOLOCK)
		WHERE		cus.ArchivedDate = @lastArchiveDate
					AND cus.CustId > @lastCustId
		ORDER BY	cus.CustID ASC;

		SET @rowCount = (SELECT COUNT(1) FROM #tmpArchivedCustomers AS tmpCus)

		IF(@rowCount < @rowSize)
		BEGIN
			INSERT INTO #tmpArchivedCustomers(ArchivedDate, CustID)
			SELECT		TOP(@rowSize - @rowCount) cus.ArchivedDate
					,	cus.CustID
			FROM		Bodb_Archive_Customer_Licensee.dbo.custInfo AS cus WITH(NOLOCK)
			WHERE		cus.ArchivedDate > @lastArchiveDate
						AND cus.ArchivedDate <= @maxArchiveDate
			ORDER BY	cus.ArchivedDate ASC, cus.CustID ASC;
		END;
	END;


	SELECT tmpCus.ArchivedDate, tmpCus.CustID FROM #tmpArchivedCustomers AS tmpCus;
END;
GO