/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_UserComment_Delete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_UserComment_Delete`(
    	IN ip_UserID			INT
    ,   IN ip_MMUserCommentID	BIGINT UNSIGNED 
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20231023@Casey.Huynh
		Task :		User Comment Delete
		DB:			CTS_DataCenter
		Original:

		Revisions:
			-	20231023@Casey.Huynh: Created [Redmine ID: #195043]
            
		Param's Explanation (filtered by):
		
		Example:
			CALL CTS_DC_MatchMonitor_UserComment_Delete(@ip_UserID:=17001301, @ip_MMUserCommentID:=10);
	*/

    DECLARE CONST_SPNAME				VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_UserComment_Delete';
    DECLARE CONST_USERLOG_LOGTYPE		SMALLINT DEFAULT 37;
    
    DECLARE lv_CurrentDateTime		DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3);
	DECLARE lv_LogInfo				TEXT;
    
	#===========REMOVE MatchMonitorUserCommentDetails if incorect reason not exist in Temp_IncorrectReason======================================================
    DELETE mmd
    FROM MatchMonitorUserCommentDetails AS mmd
    WHERE	mmd.MMUserCommentID = ip_MMUserCommentID;    
        
    #===========DELETE MatchMonitorUserComment===================================================================================
    DELETE mm
    FROM MatchMonitorUserComment AS mm
    WHERE mm.MMUserCommentID = ip_MMUserCommentID;  
    
    #========INSERT User Log=======================
	SET lv_LogInfo = CONCAT('ip_MMUserCommentID:',ip_MMUserCommentID);
                                    
    INSERT IGNORE INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	SELECT	CONST_USERLOG_LOGTYPE AS LogTypeID
		,	CONST_SPNAME AS SPName
		,	lv_LogInfo AS LogInfo
		,	lv_CurrentDateTime AS CreatedDate
		,	ip_UserID AS CreatedBy;
    
END$$
DELIMITER ;
