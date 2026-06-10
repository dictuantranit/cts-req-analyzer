/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustEvidence_RestoreAffected`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_RestoreAffected`(
		IN ip_CTSCustID		BIGINT UNSIGNED
	,	IN ip_EvidenceID	SMALLINT
	,	IN ip_UserID		INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200204@Thai
		Task:		The customer will be affected with this evidence [Redmine ID: 127150]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20210622@Aries.Nguyen: Update coding convention and inprove locking [Redmine ID: #157203]
        
		Param's Explanation (filtered by):			
        
		Example;
			- CALL CTS_DC_RestoreAffectedEvidence (11113, 5, 8)
	*/    
      
    DECLARE		vr_CreatedDate	DATETIME;	
    DECLARE		vr_SPName 	VARCHAR(100) 	DEFAULT 'CTS_DC_CustEvidence_RestoreAffected';        
    SET	vr_CreatedDate = CURRENT_TIME();
        	
	#=====REMOVE RETRACT EVIDENCE==========================
	DELETE FROM CTS_DataCenter.CustRetractEvidence
	WHERE CTSCustID = ip_CTSCustID										
		AND EvidenceID = ip_EvidenceID;	
    	
    #=====LOG==========================
	INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	VALUES(6, vr_SPName, CONCAT('Restore Affected Evidence: ip_CTSCustID = ', ip_CTSCustID, ';ip_EvidenceID = ', ip_EvidenceID), vr_CreatedDate, ip_UserID);
    
END$$
DELIMITER ;