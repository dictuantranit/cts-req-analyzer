/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_Remove`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_Remove`(
		IN ip_GroupID 		BIGINT UNSIGNED
	,	IN ip_UserID 		INT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/* 
		Created:	20220705@Aries.Nguyen
		Task:		[CTS] Fraud Group Management [Redmine ID: #167748]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20220705@Aries.Nguyen: Created [Redmine ID: #167748]
            - 20220831@Aries.Nguyen: Associated Group Enhancement [Redmine ID: #176991]
            - 20221121@Casey.Huynh: Update UserLog [Redmine ID: #179389]
        
		Param's Explanation (filtered by):
        
        Example: 
			- CALL CTS_DC_AssociatedGroup_Remove(14,1);
	*/
	DECLARE lv_LogInfo JSON;
    DECLARE CONST_USERLOG_LOGTYPE SMALLINT DEFAULT 34;
    DECLARE CONST_SPNAME VARCHAR(100) DEFAULT 'CTS_DC_AssociatedGroup_Remove';
   
    #============USER LOG====================================
    SET lv_LogInfo = JSON_OBJECT('GroupID', ip_GroupID);
                      
     INSERT IGNORE INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	 SELECT CONST_USERLOG_LOGTYPE AS LogTypeID
			,	CONST_SPNAME AS SPName
			,	lv_LogInfo AS LogInfo
			,	NOW() AS CreatedDate
			,	ip_UserID AS CreatedBy;        
    
	UPDATE CTS_DataCenter.AssociatedGroup 
	SET		IsDisable = 1
		,	ModifiedBy = ip_UserID
    WHERE GroupID = ip_GroupID;
END$$
DELIMITER ;