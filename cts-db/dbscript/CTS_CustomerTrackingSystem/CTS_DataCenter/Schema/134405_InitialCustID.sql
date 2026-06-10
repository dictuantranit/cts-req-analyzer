DELIMITER $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.AutoTagInitial_CTSCustomerClassification_New$$
CREATE DEFINER=`fps`@`%` PROCEDURE CTS_Adhoc.AutoTagInitial_CTSCustomerClassification_New()
BEGIN
/*
Creator: 	20200603@Casey.Huynh
Task:	 	CTS_Schema
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 

        - [20200603@Casey.Huynh][135324]: 
			+ Alter Table CTSCustomerClassification, add column LastScannedDate
            + Alter table CTS_DataCenter.CustomerCategory: Add ScanIntervalInSecond
Reviewer:
*/

	DECLARE	fromCTSCustID BIGINT UNSIGNED DEFAULT 0;
	DECLARE	toCTSCustID BIGINT UNSIGNED  DEFAULT 0;
/*
	CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSCustomerClassification_New (
			CustID				BIGINT UNSIGNED
		,	CTSCustID			BIGINT UNSIGNED
		, 	SubscriberID		INT	UNSIGNED
		,	SportGroupID		SMALLINT UNSIGNED
		, 	CategoryID			SMALLINT UNSIGNED    
		, 	Remark				VARCHAR(500) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		, 	CreatedDate			DATETIME
		,	CreatedBy			INT
		, 	LastModifiedDate	DATETIME
		,	LastModifiedBy		INT UNSIGNED
		,	LastScannedDate		DATETIME
		, 	PRIMARY KEY			PK_CTSCustomerClassification_CustIDSportGroupIDCategoryID(CustID, SportGroupID, CategoryID)
		, 	INDEX				IX_CTSCustomerClassification_SubscriberID(SubscriberID)
		,	INDEX				IX_CTSCustomerClassification_LastScannedDate(LastScannedDate)
		,   INDEX				IX_CTSCustomerClassification_CategoryID(CategoryID, SportGroupID)
		, 	INDEX 				IX_CTSCustomerClassification_CustID(CustID)
	) ENGINE=INNODB;
    
*/
	
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SELECT 		MIN(CTSCustID), MAX(CTSCustID)
	INTO 		fromCTSCustID, toCTSCustID
	FROM		(SELECT 	CTSCustID
				FROM		CTS_DataCenter.CTSCustomerClassification
				WHERE		CTSCustID > toCTSCustID
               # WHERE		CTSCustID < toCTSCustID
				ORDER BY	CTSCustID ASC
				LIMIT		10000) AS a;
    
	WHILE (fromCTSCustID IS NOT NULL)
	DO
			INSERT INTO CTS_DataCenter.CTSCustomerClassification_New(CustID, CTSCustID, SubscriberID, SportGroupID
						, CategoryID, Remark, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy, LastScannedDate)            
            SELECT 		cus.CustID
						, ccl.CTSCustID
                        , ccl.SubscriberID
                        , ccl.SportGroupID
                        , ccl.CategoryID
                        , ccl.Remark
                        , ccl.CreatedDate
                        , ccl.CreatedBy
                        , ccl.LastModifiedDate
                        , ccl.LastModifiedBy
                        , ccl.LastScannedDate
			FROM		CTS_DataCenter.CTSCustomerClassification AS ccl
            INNER JOIN	CTS_DataCenter.CTSCustomer AS cus
						ON ccl.CTSCustID = cus.CTSCustID
			WHERE ccl.CTSCustID BETWEEN fromCTSCustID AND toCTSCustID;
            
            SELECT 		MIN(CTSCustID), MAX(CTSCustID)
			INTO 		fromCTSCustID, toCTSCustID
			FROM		(SELECT 	CTSCustID
						FROM		CTS_DataCenter.CTSCustomerClassification
						WHERE		CTSCustID > toCTSCustID
						ORDER BY	CTSCustID ASC
						LIMIT		10000) AS a;            
	END WHILE;



END$$
DELIMITER ;
