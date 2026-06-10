/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_InsertException`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_InsertException`(
		IN ip_UserID		INT
	,	IN ip_FromCTSCustID BIGINT UNSIGNED
	,	IN ip_ToUserName	VARCHAR(50)
	,	IN ip_Comment		VARCHAR(500)

	,	OUT op_Error		INT
	,	OUT op_ToCTSCustID	BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200123@Casey.Huynh	
		Task :		Add Exception
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20200807@Casey.Huynh:[138925]: Change ip_Comment VARCHAR(200) To ip_Comment VARCHAR(500)
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: #148723]
			- 20210527@Aries.Nguyen: Cannot insert Exception Customers [Redmine ID: #155916]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
			- 20210909@Aries.Nguyen: Update bet limit [Redmine ID: #160711]
			
		Param's Explanation (filtered by):
			- OutPut: lv_Error (1: User Is not Existing, 0: Add Successfully)
	*/ 
 
    DECLARE		lv_ToCTSCustID 	BIGINT UNSIGNED;
    DECLARE		lv_CreatedDate	DATETIME;
    DECLARE		lv_SPName 		VARCHAR(100) 	DEFAULT 'CTS_DC_Association_InsertException';
    DECLARE		lv_Error		INT DEFAULT 0;
    
	SELECT	CTSCustID 
	INTO	lv_ToCTSCustID
	FROM	CTS_DataCenter.CTSCustomer AS ct 
    WHERE	ct.UserName  = ip_ToUserName 
		OR  ct.UserName2 = ip_ToUserName;
   
    
    IF(lv_ToCTSCustID IS NULL) THEN
		 SET	lv_Error = 1;
	ELSE
		SET	lv_CreatedDate = CURRENT_TIMESTAMP();
        
        #======INSERT EXCEPTION=================================
		INSERT INTO CTS_DataCenter.CustException(FromCTSCustID, ToCTSCustID, CreatedDate, CreatedBy, Comment)
        VALUES(ip_FromCTSCustID, lv_ToCTSCustID, lv_CreatedDate , ip_UserID, ip_Comment);
 
		INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		VALUES(1,lv_SPName, CONCAT('Insert Exception: ip_FromCTSCustID_', ip_FromCTSCustID, ';ip_ToUserName_', ip_ToUserName,'(',lv_ToCTSCustID,')'), lv_CreatedDate, ip_UserID);
        
        #=====REMOVE AFFECTED EVIDENCE==========================
		
		DELETE 	ce
		FROM 	CTS_DataCenter.CustEvidence AS ce
		WHERE	(	(ce.CTSCustID 	= ip_FromCTSCustID 	AND ce.FromCustID = lv_ToCTSCustID)
				OR 	(ce.CTSCustID	= lv_ToCTSCustID 	AND ce.FromCustID = ip_FromCTSCustID))
                AND ce.Level = 2;
		
		INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		VALUES(4,lv_SPName, CONCAT('Remove Affected Evidence: ip_FromCTSCustID_', ip_FromCTSCustID, ';ip_ToUserName_', ip_ToUserName,'(',lv_ToCTSCustID,')'), lv_CreatedDate, ip_UserID);        
            
		SET	lv_Error = 0;        
    END IF;
    
    SET op_Error = lv_Error;
	SET op_ToCTSCustID = lv_ToCTSCustID;
	
END$$

DELIMITER ;