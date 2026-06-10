/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CTSCustomer_UpdateSubscriberIDBySiteID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CTSCustomer_UpdateSubscriberIDBySiteID`(
		IN ip_SubsSiteJson JSON
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200111@Casey.Huynh
		Task:		Update CTSCustomer for SubscriberID NULL
		DB:			CTS_DataCenter
		Original:

		Revisions:
			-	20210115@Casey.Huynh: Created [Redmine ID: 148849]
            -	20211029@Casey.Huynh: Update CTSClassification, CTSClassification_History [Redmine ID: 163899]
			-	20240628@Thomas.Nguyen: Renovate CC phase 2 - Remove unused table ProbationAccountMonitor
            -	20241016@Casey.Huynh: Agency CC, Seperate Member and Agency [Redmine ID: #185799]
            
		Param's Explanation (filtered by):
		
		Exampele: CALL CTS_DC_CTSCustomer_UpdateSubscriberIDBySiteID ('[{"SubscriberID":898294,"SiteID":43534235,"RoleMapping":1}]');
	*/
	DECLARE CONST_ROLEID_MEMBER					TINYINT DEFAULT 1;
    DECLARE CONST_ROLEID_AGENT            		TINYINT DEFAULT 2;
    DECLARE CONST_ROLEID_MASTER            		TINYINT DEFAULT 3;
    DECLARE CONST_ROLEID_SUPER            		TINYINT DEFAULT 4;
    
    DECLARE lv_size			BIGINT DEFAULT 200;
    DECLARE lv_PreCTSCustID BIGINT DEFAULT 0;
	DECLARE lv_No    		INT DEFAULT 1;
     
    DROP TEMPORARY TABLE IF EXISTS TempSubSite;
    
    CREATE TEMPORARY TABLE TempSubSite
    (
			SubscriberID	INT
        ,	SiteID			INT
        ,	RoleMapping		TINYINT
    );
    
    DROP TEMPORARY TABLE IF EXISTS TempCTSCustomer;
    
    CREATE TEMPORARY TABLE TempCTSCustomer
    (
			CTSCustID		BIGINT UNSIGNED
        ,	CustID			INT UNSIGNED
        ,	CustSubID		INT UNSIGNED
        ,	RoleID			INT UNSIGNED
        ,	UserName		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	RegisterName	VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	SubscriberID	INT        
        ,	PRIMARY KEY TempCTSCustomer(CTSCustID)
        ,	INDEX TempCTSCustomer_CustSubIDCustID(CustSubID,CustID)
    );
      
	INSERT INTO TempSubSite(SubscriberID, SiteID, RoleMapping)
	SELECT		js.SubscriberID	
			,	js.SiteID
			,	js.RoleMapping
	FROM JSON_TABLE(ip_SubsSiteJson,
		 "$[*]" COLUMNS(
				SubscriberID	INT	 PATH "$.SubscriberID"
			,	SiteID			INT	 PATH "$.SiteID" 
            ,	RoleMapping		TINYINT	 PATH "$.RoleMapping" 
			)
	) AS js;

	WHILE (lv_PreCTSCustID IS NOT NULL)
    DO      
		
        TRUNCATE TABLE TempCTSCustomer;
        
		INSERT INTO TempCTSCustomer(CTSCustID, CustID, CustSubID, RoleID, RegisterName, SubscriberID, UserName)
        SELECT 	cus.CTSCustID
			,	cus.CustID
            ,	cus.CustSubID
            ,	cus.RoleID
			,	SUBSTRING(cus.UserName2, LOCATE('$',cus.UserName2) + 1) AS RegisterName
            ,	mss.SubscriberID
            ,	cus.UserName
		FROM CTS_DataCenter.CTSCustomer AS cus 
			INNER JOIN TempSubSite AS mss ON cus.SiteID = mss.SiteID AND ((mss.RoleMapping = 1 AND cus.RoleID = CONST_ROLEID_MEMBER) OR (mss.RoleMapping = 2 AND cus.RoleID > CONST_ROLEID_MEMBER) OR (mss.RoleMapping = 0))
		WHERE cus.SubscriberID IS NULL AND cus.SiteID = mss.SiteID
		LIMIT lv_size;
        
        UPDATE CTS_DataCenter.CTSCustomer AS cus 
			INNER JOIN TempCTSCustomer AS tmpCus ON cus.CTSCustID = tmpCus.CTSCustID
        SET		cus.SubscriberID = tmpCus.SubscriberID
			,	cus.RegisterName = tmpCus.RegisterName
			,	cus.ModifiedTime = CURRENT_TIMESTAMP(4);
		
        #=====ReTransform==============================
		UPDATE DCS_DataCenter.Account AS acc	
			INNER JOIN TempCTSCustomer AS tmpCus ON acc.LoginName = tmpCus.RegisterName AND	acc.SubscriberID = tmpCus.SubscriberID
		SET	acc.IsCTSTransformed = 0
		WHERE acc.IsCTSTransformed = -1;    
		
		UPDATE DCS_DataCenter.Account AS acc	
			INNER JOIN TempCTSCustomer AS tmpCus ON acc.LoginName = tmpCus.UserName AND acc.SubscriberID = tmpCus.SubscriberID
		SET acc.IsCTSTransformed = 0
		WHERE acc.IsCTSTransformed = -1;    
		
        #=====UPDATE CTSCustomerClassification FOR MEMBER=========================================================
        UPDATE CTS_DataCenter.CTSCustomerClassification AS cc
			INNER JOIN TempCTSCustomer AS tmpCus ON tmpCus.CustSubID = 0 AND tmpCus.CustID= cc.CustID AND tmpCus.RoleID = CONST_ROLEID_MEMBER
        SET		cc.CTSCustID = tmpCus.CTSCustID
			,	cc.SubscriberID = tmpCus.SubscriberID
            ,	cc.RoleID = tmpCus.RoleID;
            
		#=====UPDATE CTSCustomerClassification_History FOR MEMBER=================================================
        UPDATE CTS_DataCenter.CTSCustomerClassification_History AS ch
			INNER JOIN TempCTSCustomer AS tmpCus ON tmpCus.CustSubID = 0 AND tmpCus.CustID= ch.CustID AND tmpCus.RoleID = CONST_ROLEID_MEMBER
        SET	ch.CTSCustID = tmpCus.CTSCustID;        
        
        #=====UPDATE CTSCustomerClassificationAgency FOR AGENCY===================================================
        UPDATE CTS_DataCenter.CTSCustomerClassificationAgency AS cc
			INNER JOIN TempCTSCustomer AS tmpCus ON tmpCus.CustSubID = 0 AND tmpCus.CustID= cc.CustID AND tmpCus.RoleID IN (CONST_ROLEID_AGENT,CONST_ROLEID_MASTER,CONST_ROLEID_SUPER)
        SET		cc.CTSCustID = tmpCus.CTSCustID
			,	cc.SubscriberID = tmpCus.SubscriberID
            ,	cc.RoleID = tmpCus.RoleID;
            
		#=====UPDATE CTSCustomerClassificationAgency_History FOR AGENCY============================================
        UPDATE CTS_DataCenter.CTSCustomerClassificationAgency_History AS ch
			INNER JOIN TempCTSCustomer AS tmpCus ON tmpCus.CustSubID = 0 AND tmpCus.CustID= ch.CustID AND tmpCus.RoleID IN (CONST_ROLEID_AGENT,CONST_ROLEID_MASTER,CONST_ROLEID_SUPER)
        SET		ch.CTSCustID = tmpCus.CTSCustID
            ,	ch.RoleID = tmpCus.RoleID;
        
        #=========================================================================================================
        
        SET lv_PreCTSCustID = (SELECT 1 FROM TempCTSCustomer AS tmpCus LIMIT 1);
        
    END WHILE;
END$$
DELIMITER ;