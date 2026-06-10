/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_UserComment_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_UserComment_Insert`(
		IN ip_UserID			INT
    ,	IN ip_MatchID 			BIGINT UNSIGNED
	,	IN ip_SportType			INT
	,	IN ip_LiveIndicator		BOOLEAN   
    ,	IN ip_BettypeID			INT UNSIGNED
    ,	IN ip_BetIDList			TEXT    
    ,	IN ip_UserComment		VARCHAR(1000)
    ,	IN ip_CorrectReason		INT #-1: Others, Else MM Reason
    ,	IN ip_IncorrectReason	JSON       
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20231023@Casey.Huynh
		Task :		User Comment Insert
		DB:			CTS_DataCenter
		Original:

		Revisions:
			-	20231023@Casey.Huynh: Created [Redmine ID: #195043]
            - 	20240205@Casey.Huynh: Exclude Lopsided Bet [Redmine ID: #197706]
            -	20250318@Casey.Huynh: Match Monitor Badminton [Redmine ID: #219681]
            
		Param's Explanation (filtered by):
		
		Example:
			CALL CTS_DC_MatchMonitor_UserComment_Insert(@ip_UserID:=1
            , @ip_MatchID:=1, @ip_SportType:=2, @ip_LiveIndicator:=0, @ip_BettypeID:=1, @ip_BetID:=0, @ip_UserID:=862400
            , @ip_UserComment:='CaseyTest', @ip_CorrectReason:= 2
            , @ip_IncorrectReason:='[{"Reason":1, "FromTransInfo":"1", "ToTransInfo":"2"}
									,	{"Reason":2, "FromTransInfo":"2023-10-18 04:11:42.042", "ToTransInfo":"2023-10-19 04:11:42.042"}]'
						);

	*/
    DECLARE CONST_COMMENTTYPE_INCORRECT	TINYINT DEFAULT 0;
    DECLARE CONST_COMMENTTYPE_CORRECT	TINYINT DEFAULT 1;
    DECLARE CONST_SPNAME				VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_UserComment_Insert';
    DECLARE CONST_USERLOG_LOGTYPE		SMALLINT DEFAULT 35;
    
    DECLARE lv_CurrentDateTime		DATETIME(3) DEFAULT CURRENT_TIMESTAMP(3);
    DECLARE lv_MaxMMUserCommentID	BIGINT UNSIGNED;
    DECLARE lv_NewMMUserCommentID	BIGINT UNSIGNED;
    DECLARE lv_LogInfo				TEXT;
    
    #========INSERT MatchMonitor UserComment=============================== 
	DROP TEMPORARY TABLE IF EXISTS Temp_BetID;    
	CREATE TEMPORARY TABLE Temp_BetID( 	  
		BetID		BIGINT PRIMARY KEY
	);

    SET @sql = CONCAT("INSERT INTO Temp_BetID (BetID) VALUES ('", REPLACE(ip_BetIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
	SELECT IFNULL(MAX(mm.MMUserCommentID),0)
    INTO lv_MaxMMUserCommentID
    FROM CTS_DataCenter.MatchMonitorUserComment AS mm;
    
    INSERT INTO CTS_DataCenter.MatchMonitorUserComment(MatchID, SportType, LiveIndicator, BettypeID, BetID, UserComment, CreatedDate, CreatedBy, ModifiedDate, ModifiedBy)
    SELECT	ip_MatchID
		,	ip_SportType
        ,	ip_LiveIndicator
		,	ip_BettypeID
        ,	tmpBet.BetID
		,	ip_UserComment
		,	lv_CurrentDateTime AS CreatedDate
		,	ip_UserId AS CreatedBy
		,	lv_CurrentDateTime AS ModifiedDate
		,	ip_UserId AS ModifiedBy
	FROM Temp_BetID AS tmpBet;

    #========INSERT MatchMonitor UserComment Details - Incorrect Reason=======================
   
    SELECT MAX(mm.MMUserCommentID)
    INTO lv_NewMMUserCommentID
    FROM CTS_DataCenter.MatchMonitorUserComment AS mm
		INNER JOIN Temp_BetID AS tmpBet ON tmpBet.BetID = mm.BetID
    WHERE	mm.MatchID	= ip_MatchID
		AND	mm.SportType = ip_SportType
        AND	mm.LiveIndicator = ip_LiveIndicator
        AND	mm.BettypeID = ip_BettypeID
        AND	mm.BetID = tmpBet.BetID
        AND	mm.CreatedBy = ip_UserID
		AND	mm.MMUserCommentID > lv_MaxMMUserCommentID;

    INSERT INTO CTS_DataCenter.MatchMonitorUserCommentDetails(MMUserCommentID, CommentType, Reason, FromTransInfo, ToTransInfo)
    SELECT	lv_NewMMUserCommentID AS MMUserCommentID
		,	CONST_COMMENTTYPE_INCORRECT AS CommentType
		,	js.Reason
		,	js.FromTransInfo
        ,	js.ToTransInfo
    FROM JSON_TABLE(ip_IncorrectReason,
					"$[*]" COLUMNS	(	Reason 			INT		PATH "$.Reason"                
									,	FromTransInfo	VARCHAR(30) PATH "$.FromTransInfo"
									,	ToTransInfo		VARCHAR(30)	PATH "$.ToTransInfo"
									)
					) AS js;  
                    
    #======#========INSERT MatchMonitor UserComment Details - correct Reason=======================
	INSERT INTO CTS_DataCenter.MatchMonitorUserCommentDetails(MMUserCommentID, CommentType, Reason)
    SELECT	lv_NewMMUserCommentID AS MMUserCommentID
		,	CONST_COMMENTTYPE_CORRECT AS CommentType
		,	ip_CorrectReason
	;
    #========INSERT User Log=======================
	SET lv_LogInfo = CONCAT('ip_MatchID:',ip_MatchID,',ip_SportType:',ip_SportType,',ip_LiveIndicator:',ip_LiveIndicator,',ip_BettypeID:',ip_BettypeID,',ip_BetIDList:',ip_BetIDList
							,',ip_UserComment:',ip_UserComment,',ip_CorrectReason:',ip_CorrectReason,',ip_IncorrectReason:',ip_IncorrectReason);
                                    
    INSERT IGNORE INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	SELECT	CONST_USERLOG_LOGTYPE AS LogTypeID
		,	CONST_SPNAME AS SPName
		,	lv_LogInfo AS LogInfo
		,	lv_CurrentDateTime AS CreatedDate
		,	ip_UserID AS CreatedBy;
    
END$$
DELIMITER ;
