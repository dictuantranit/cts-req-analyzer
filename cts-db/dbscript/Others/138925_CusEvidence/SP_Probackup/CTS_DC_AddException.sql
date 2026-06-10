CREATE DEFINER=`fps`@`%` PROCEDURE `CTS_DC_AddException`(IN ip_UserID INT, IN ip_FromCTSCustID BIGINT, IN ip_ToUserName VARCHAR(50), IN ip_Comment VARCHAR(200), OUT op_Error INT)
BEGIN
	/*
		Created:	20200123@Casey.Huynh	
		Task :		Add Exception
		DB:			CTS_DataCenter
		Original: 
		Revisions:
		Param's Explanation (filtered by):
			OutPut: vr_Error (1: User Is not Existing, 0: Add Successfully)
	*/ 
 
    DECLARE		vr_ToCTSCustID 	BIGINT;
    DECLARE		vr_CreatedDate	DATETIME;
    DECLARE		vr_SPName 	VARCHAR(100) 	DEFAULT 'CTS_DC_AddException';
    DECLARE		vr_Error	INT DEFAULT 0;
    
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;     
    SET SESSION default_collation_for_utf8mb4 = utf8mb4_0900_ai_ci;
    
    SET vr_ToCTSCustID = (	SELECT	CTSCustID 
							FROM	CTS_DataCenter.CTSCustomer AS ct 
                            WHERE	ct.UserName 	= ip_ToUserName 
									OR ct.UserName2 = ip_ToUserName);    
                                    
	SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    
    IF(vr_ToCTSCustID IS NULL) THEN
		 SET	vr_Error = 1;
	ELSE
		SET	vr_CreatedDate = CURRENT_TIME();
        
        #======INSERT EXCEPTION=================================
		INSERT INTO CTS_DataCenter.CustException(FromCTSCustID, ToCTSCustID, CreatedDate, CreatedBy, Comment)
        VALUES(ip_FromCTSCustID, vr_ToCTSCustID, vr_CreatedDate , ip_UserID, ip_Comment);
 
		INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		VALUES(1,vr_SPName, CONCAT('Insert Exception: ip_FromCTSCustID_', ip_FromCTSCustID, ';ip_ToUserName_', ip_ToUserName,'(',vr_ToCTSCustID,')'), vr_CreatedDate, ip_UserID);
        
        #=====REMOVE AFFECTED EVIDENCE==========================
		
		DELETE 	ce
		FROM 	CTS_DataCenter.CustEvidence AS ce
		WHERE	(	(ce.CTSCustID 	= ip_FromCTSCustID 	AND ce.FromCustID = vr_ToCTSCustID)
				OR 	(ce.CTSCustID	= vr_ToCTSCustID 	AND ce.FromCustID = ip_FromCTSCustID))
                AND ce.Level = 2;
		
		INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		VALUES(4,vr_SPName, CONCAT('Remove Affected Evidence: ip_FromCTSCustID_', ip_FromCTSCustID, ';ip_ToUserName_', ip_ToUserName,'(',vr_ToCTSCustID,')'), vr_CreatedDate, ip_UserID);        
            
		SET	vr_Error = 0;        
    END IF;
    
    SET op_Error = vr_Error;
    SET SESSION default_collation_for_utf8mb4 = utf8mb4_general_ci;
END