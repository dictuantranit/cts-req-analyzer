/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_UserComment_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_UserComment_Update`(
    	IN ip_UserID			INT
    ,   IN ip_MMUserCommentID	BIGINT UNSIGNED    
    ,	IN ip_UserComment		VARCHAR(1000)
    ,	IN ip_CorrectReason		TINYINT				#-1: Others, Else MM Reason
    ,	IN ip_IncorrectReason	JSON       
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20231023@Casey.Huynh
		Task :		User Comment Update
		DB:			CTS_DataCenter
		Original:

		Revisions:
			-	20231023@Casey.Huynh: Created [Redmine ID: #195043]
            
		Param's Explanation (filtered by):
		
		Example:
			CALL CTS_DC_MatchMonitor_UserComment_Update(@ip_UserID:=862400
            , @ip_MMUserCommentID:=10, @ip_UserComment:='Dev Test update', @ip_CorrectReason:= 1
            , @ip_IncorrectReason:='[{"Reason":1, "FromTransInfo":"1", "ToTransInfo":"2"}
									]'
			);

	*/
    DECLARE CONST_COMMENTTYPE_INCORRECT	TINYINT DEFAULT 0;
    DECLARE CONST_COMMENTTYPE_CORRECT	TINYINT DEFAULT 1;
    DECLARE CONST_SPNAME				VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_UserComment_Update';
    DECLARE CONST_USERLOG_LOGTYPE		SMALLINT DEFAULT 36;
    
    DECLARE lv_CurrentDateTime		DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3);
	DECLARE lv_LogInfo				TEXT;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_IncorrectReason;
    CREATE TEMPORARY TABLE Temp_IncorrectReason(
			Reason			SMALLINT PRIMARY KEY COMMENT '-1: Others, Else MM Reason' 
		,	FromTransInfo	VARCHAR(30)
		,	ToTransInfo		VARCHAR(30)
    );
    
    #===========GET	Incorrect Reason=================================================================================================
    INSERT INTO Temp_IncorrectReason(Reason, FromTransInfo, ToTransInfo)
    SELECT	js.Reason
		,	js.FromTransInfo
        ,	js.ToTransInfo
    FROM JSON_TABLE(ip_IncorrectReason,
					"$[*]" COLUMNS	(	Reason 			TINYINT 	PATH "$.Reason"                
									,	FromTransInfo	VARCHAR(30) PATH "$.FromTransInfo"
									,	ToTransInfo		VARCHAR(30)	PATH "$.ToTransInfo"
									)
					) AS js;
                    
	#===========REMOVE MatchMonitorUserCommentDetails if incorect reason not exist in Temp_IncorrectReason======================================================
    DELETE mmd
    FROM MatchMonitorUserCommentDetails AS mmd
		LEFT JOIN Temp_IncorrectReason AS tmpIr ON tmpIr.Reason = mmd.Reason 
    WHERE	mmd.MMUserCommentID = ip_MMUserCommentID
		AND mmd.CommentType = CONST_COMMENTTYPE_INCORRECT
		AND tmpIr.Reason IS NULL;
        
    #===========UPDATE MatchMonitorUserCommentDetails if incorect reason not exist in Temp_IncorrectReason=======================================================
    UPDATE MatchMonitorUserCommentDetails AS mmd
		INNER JOIN Temp_IncorrectReason AS tmpIr ON tmpIr.Reason = mmd.Reason
	SET	mmd.FromTransInfo = tmpIr.FromTransInfo
	,	mmd.ToTransInfo = tmpIr.ToTransInfo
    WHERE mmd.MMUserCommentID = ip_MMUserCommentID
		AND mmd.CommentType = CONST_COMMENTTYPE_INCORRECT;
    
    #===========INSERT MatchMonitorUserCommentDetails if Temp_IncorrectReason.Reason not exists=================================================================
	INSERT INTO CTS_DataCenter.MatchMonitorUserCommentDetails(MMUserCommentID, CommentType, Reason, FromTransInfo, ToTransInfo)
    SELECT	ip_MMUserCommentID AS MMUserCommentID
		,	CONST_COMMENTTYPE_INCORRECT AS CommentType
		,	tmpIr.Reason
		,	tmpIr.FromTransInfo
        ,	tmpIr.ToTransInfo
    FROM Temp_IncorrectReason AS tmpIr
		LEFT JOIN MatchMonitorUserCommentDetails AS mmd ON  mmd.MMUserCommentID = ip_MMUserCommentID AND mmd.CommentType = CONST_COMMENTTYPE_INCORRECT AND tmpIr.Reason = mmd.Reason
	WHERE mmd.MMUserCommentID IS NULL;  
    
    #===========UPDATE MatchMonitorUserCommentDetails Correct Reason=====================================================================================
    UPDATE MatchMonitorUserCommentDetails AS mmd
    SET mmd.Reason = ip_CorrectReason
    WHERE mmd.MMUserCommentID = ip_MMUserCommentID
		AND mmd.CommentType = CONST_COMMENTTYPE_CORRECT
        AND mmd.Reason <> ip_CorrectReason;
        
    #===========UPDATE MatchMonitorUserComment===================================================================================
    UPDATE MatchMonitorUserComment AS mm
	SET mm.UserComment = ip_UserComment
	,	mm.ModifiedBy = ip_UserID
    ,	mm.ModifiedDate = lv_CurrentDateTime
    WHERE mm.MMUserCommentID = ip_MMUserCommentID;    
    
    #========INSERT User Log=======================
	SET lv_LogInfo = CONCAT('ip_MMUserCommentID:',ip_MMUserCommentID,',ip_UserComment:',ip_UserComment,',ip_CorrectReason:',ip_CorrectReason,',ip_IncorrectReason:',ip_IncorrectReason);
                                    
    INSERT IGNORE INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	SELECT	CONST_USERLOG_LOGTYPE AS LogTypeID
		,	CONST_SPNAME AS SPName
		,	lv_LogInfo AS LogInfo
		,	lv_CurrentDateTime AS CreatedDate
		,	ip_UserID AS CreatedBy;
    
END$$
DELIMITER ;
