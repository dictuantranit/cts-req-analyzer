

DELIMITER $$

DROP PROCEDURE IF EXISTS CTS_Adhoc.CreateDataTest_CustomerClassification$$

CREATE PROCEDURE CTS_Adhoc.CreateDataTest_CustomerClassification_A()
BEGIN
	/*
		Created:	20200526@CaseyHuynh
	*/
   /*
   CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSCustomerClassification_CaseyIXA (
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

CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSCustomerClassification_CaseyIXB(
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

) ENGINE=INNODB;
*/
    DECLARE vrCTSCustID BIGINT UNSIGNED;
    SET 	@lastCTSCustID = -1;
     SELECT @lastCTSCustID;
    WHILE (@lastCTSCustID < 222078935)
    DO
		 SELECT @lastCTSCustID;
		INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassification_CaseyIXA(CustID, CTSCustID, SubscriberID, SportGroupID, CategoryID
        , Remark, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy, LastScannedDate)
		SELECT	cus.CustID
				, @lastCTSCustID := cus.CTSCustID
                , cus.SubscriberID
                , FLOOR(1+RAND()*6) AS SportGroupID
                , ELT(1+RAND()*20 , '51', '52', '53', '54', '55', '56', '57', '58', '59', '151'
									, '152', '153', '154', '155', '156', '157', '158', '159', '160') AS CategoryID
                , 'Casey test' AS Remark
                , '2020-07-24' AS CreatedDate
                , 10278938 AS CreatedBy
                , '2020-07-01' AS LastModifiedDate
                , 10278938 AS LastModifiedBy
                , DATE_SUB('2020-07-24', INTERVAL FLOOR(1+RAND()*14) DAY) AS LastScannedDate
        FROM		CTS_DataCenter.CTSCustomerClassification_CaseyIXA AS cus					
        WHERE	cus.CTSCustID > @lastCTSCustID
                   AND cus.CategoryID = ELT(1+RAND()*5, '4', '5', '6', '7', '10')                        
        ORDER BY cus.CTSCustID ASC
        LIMIT 20000
        ;
       	 SELECT @lastCTSCustID;
    END WHILE;
END$$

DELIMITER ;