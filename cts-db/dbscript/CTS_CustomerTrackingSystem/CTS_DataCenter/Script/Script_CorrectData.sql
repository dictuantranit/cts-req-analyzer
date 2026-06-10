/****=====Step****/
#===1: 
UPDATE CTS_Admin.Subscriber
SET		SubscriberName = 'haifa'
WHERE	SubscriberID = 104;

DELETE 	
FROM CTS_Admin.Subscriber 
WHERE	SubscriberID = 4431;

UPDATE CTS_DataCenter.MappingSubscriberSite
SET 	SubscriberName = 'haifa'
		, SiteID = 44
        , SiteName = 'haifa'
        , SubscriberType = 1
WHERE	SubscriberID = 104;

DELETE 	
FROM 	CTS_DataCenter.MappingSubscriberSite	
WHERE	SubscriberID = 4431;

/*====Update Customer*======================*/
/*STEP 1: DELETE Haifa and  BBIN from CTSCustomer*/
   CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSCustomer_DELETE_HAIFA4431 (
		CTSCustID			BIGINT	UNSIGNED	AUTO_INCREMENT
		, SubscriberID		INT		UNSIGNED
		, CustID			INT		UNSIGNED
		, CustSubID			INT		UNSIGNED
		, UserName			VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		, UserName2			VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        , SiteID			INT
		, Site				VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		, RoleID			TINYINT
		, Currency			VARCHAR(10)
		, CurrencyID		INT		
		, SRecommend		INT		UNSIGNED
		, MRecommend		INT		UNSIGNED	
		, Recommend			INT		UNSIGNED
        , LastLoginTime		TIMESTAMP(4)
        , CreatedDate		DATETIME
		, PRIMARY KEY	PK_CTSCustomer_CTSCustID(CTSCustID)    
		, UNIQUE KEY	UK_CTSCustomer_SubscriberID_UserName2(SubscriberID, UserName2)
	) ENGINE=INNODB AUTO_INCREMENT=1;


	CALL CTS_DataCenter.CTS_DC_CTSCustomer_DELETEHaifaCustomer;


	INSERT INTO CTS_DataCenter.CTSCustomer(CTSCustID, SubscriberID, UserName, UserName2,  LastLoginTime)
	SELECT 		ctsAcc.CTSCustID
				, 104 AS SubscriberID
				, '' AS UserName
				, CONCAT('haifa$',dcsAcc.LoginName) AS UserName2
				, dcsAcc.LastLoginTime
	FROM 		CTS_DataCenter.CustDCSAccount AS ctsAcc
	INNER JOIN	DCS_DataCenter.Account AS dcsAcc
				ON ctsAcc.AccountID = dcsAcc.AccountID
	WHERE 	ctsAcc.SubscriberID = 104;

/*============================================*/

