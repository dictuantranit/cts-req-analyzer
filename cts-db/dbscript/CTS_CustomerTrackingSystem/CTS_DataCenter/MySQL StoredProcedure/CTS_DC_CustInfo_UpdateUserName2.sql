/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_UpdateUserName2`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_UpdateUserName2`(
		IN ip_Customer JSON
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200118@CaseyHuynh
		Task:		Update UserName2 [Redmine ID: 148849]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20210115@Casey.Huynh: Created [Redmine ID: #148849]
			- 202101295@Casey.Huynh: Add Ignore to Update statement [Redmine ID: #149639]
            - 20210208@Casey.Huynh: Created [Redmine ID: #149941]
			- 20210622@Aries.Nguyen: Update coding convention and improve locking  [Redmine ID: #157203]

		Param's Explanation (filtered by):         
        
        Example:
       
	*/	  
	DECLARE     lv_No    INT    DEFAULT 1;
    DECLARE     lv_ErrorMessage2 VARCHAR(200) DEFAULT '';
    DECLARE		lv_ErrorMessage	VARCHAR(200) DEFAULT '';
 
	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN   
		GET DIAGNOSTICS lv_No = NUMBER;
		GET DIAGNOSTICS CONDITION lv_No 
            lv_ErrorMessage = MESSAGE_TEXT;	
		
		IF(lv_No > 1) THEN
			SET lv_No = lv_No - 1;
			GET STACKED  DIAGNOSTICS CONDITION lv_No
				lv_ErrorMessage2 = MESSAGE_TEXT;	
        END IF;
			
		SET lv_ErrorMessage = CONCAT(lv_ErrorMessage,'; ',lv_ErrorMessage2);

		CALL CTS_Log.CTS_Log_ErrorLog_Insert('CTS_DC_CTSCustomer_UpdateUserName2',lv_ErrorMessage, JSON_OBJECT('parameter', ip_Customer));
    
		SIGNAL SQLSTATE '99999' SET MESSAGE_TEXT = lv_ErrorMessage;
    END;

	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomer;
	CREATE TEMPORARY TABLE Temp_CTSCustomer( 		
			CustID			INT UNSIGNED NOT NULL
		,	CustSubID		INT
        ,	CTSCustID		BIGINT
		,	UserName2		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	RegisterName	VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	SubscriberID	INT
        
        ,	INDEX Temp_CTSCustomer_CTSCustID(CTSCustID)
    );

	DROP TEMPORARY TABLE IF EXISTS Temp_CustInfo;
	CREATE TEMPORARY TABLE Temp_CustInfo( 		
        	CTSCustID		BIGINT
        ,	RegisterName	VARCHAR(50) 
        ,	SubscriberID	INT
    );
    
    INSERT INTO Temp_CTSCustomer(CustID, CustSubID, UserName2, CTSCustID)
	SELECT	js.CustID	
		,	js.CustSubID            
		,	(CASE WHEN js.UserName2 = 'null' THEN NULL ELSE js.UserName2 END) AS UserName2
		,	js.CTSCustID
	FROM JSON_TABLE(ip_Customer,
		 "$[*]" COLUMNS(
					CustID			INT	 UNSIGNED	PATH "$.CustID" 
				,	CustSubID		BIGINT			PATH "$.CustSubID"
				,	UserName2		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	PATH "$.UserName2" 
				,	CTSCustID		BIGINT			PATH "$.CTSCustID"
			)
	) AS js;    
   
    INSERT INTO Temp_CustInfo(CTSCustID, SubscriberID, RegisterName)
	SELECT  tmpCus.CTSCustID
		,	cus.SubscriberID
		,	SUBSTRING(tmpCus.UserName2, LOCATE('$',tmpCus.UserName2) + 1)
	FROM Temp_CTSCustomer AS tmpCus
		INNER JOIN 	CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = tmpCus.CTSCustID 
		INNER JOIN	CTS_DataCenter.MappingSubscriberSite mss ON cus.SiteID = mss.SiteID 
																AND ((mss.RoleMapping = 1 AND cus.RoleID = 1)
																	OR (mss.RoleMapping = 2 AND cus.RoleID > 1)
																	OR (mss.RoleMapping = 0));
    UPDATE Temp_CTSCustomer AS tmpCus
		INNER JOIN Temp_CustInfo AS cus ON cus.CTSCustID = tmpCus.CTSCustID 
	SET   tmpCus.SubscriberID = cus.SubscriberID
		, tmpCus.RegisterName = cus.RegisterName;       
   
	UPDATE IGNORE CTS_DataCenter.CTSCustomer AS cus
		INNER JOIN	CTS_DataCenter.Temp_CTSCustomer AS tmpCus ON cus.CTSCustID = tmpCus.CTSCustID 
    SET	  cus.UserName2 = tmpCus.UserName2
		, cus.RegisterName = tmpCus.RegisterName
        , cus.ModifiedTime = CURRENT_TIMESTAMP(4);

   #=====ReTransform==============================
    INSERT INTO DCS_DataCenter.AccountTransformStatus(AccountID, IsCTSTransformed)
	SELECT	acc.AccountID
			,	0
	FROM  DCS_DataCenter.Account AS acc
		INNER JOIN	Temp_CTSCustomer AS tmpCus ON acc.LoginName = tmpCus.RegisterName AND	acc.SubscriberID = tmpCus.SubscriberID
	WHERE acc.IsCTSTransformed = -1; 
 

END$$
DELIMITER ;
