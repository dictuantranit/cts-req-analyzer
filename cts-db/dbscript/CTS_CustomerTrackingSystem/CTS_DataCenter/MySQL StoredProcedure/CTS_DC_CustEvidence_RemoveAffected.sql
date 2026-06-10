DELIMITER $$
USE `CTS_DataCenter` $$
DROP PROCEDURE IF EXISTS CTS_DC_CustEvidence_RemoveAffected $$

CREATE PROCEDURE CTS_DC_CustEvidence_RemoveAffected (
	IN ip_CTSCustID 		BIGINT,        
    IN ip_EvidenceID 		SMALLINT,	
    IN ip_Remark 			VARCHAR(500), 
    IN ip_UserID 			INT)
BEGIN
	/*
		Created:	20200204@Thai
		Task:		Add an evidence that the customer will not be affected [Redmine ID: 127150]
		DB:			CTS_DataCenter
		Original:

		Revisions:
        
		Param's Explanation (filtered by):			
        
        CALL CTS_DC_RetractAffectedEvidence (127512, 5, 8)
	*/    
     
	DECLARE		vr_CreatedDate	DATETIME;	
    DECLARE		vr_SPName 	VARCHAR(100) 	DEFAULT 'CTS_DC_CustEvidence_RemoveAffected';    
    SET	vr_CreatedDate = CURRENT_TIME();
    	
	IF NOT EXISTS (SELECT 1 FROM CTS_DataCenter.CustRetractEvidence
					WHERE CTSCustID = ip_CTSCustID										
						AND EvidenceID = ip_EvidenceID) THEN
	INSERT INTO CTS_DataCenter.CustRetractEvidence( CTSCustID, EvidenceID, Remark, CreatedDate, CreatedBy)
	VALUES (ip_CTSCustID, ip_EvidenceID, ip_Remark, vr_CreatedDate, ip_UserID);				
                
	END IF;
       
    #=====LOG==========================
	INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	VALUES(5, vr_SPName, CONCAT('Retract Affected Evidence: ip_CTSCustID = ', ip_CTSCustID, ';ip_EvidenceID = ', ip_EvidenceID), vr_CreatedDate, ip_UserID);
    
END$$
DELIMITER ;