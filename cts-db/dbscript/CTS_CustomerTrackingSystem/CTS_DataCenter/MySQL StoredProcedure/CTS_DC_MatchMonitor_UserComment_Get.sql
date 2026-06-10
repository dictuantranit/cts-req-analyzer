/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_UserComment_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_UserComment_Get`(
		IN ip_MatchID 			BIGINT UNSIGNED
	,	IN ip_LiveIndicator		BOOLEAN   
    ,	IN ip_BettypeID			INT UNSIGNED
    ,	IN ip_BetIDList			TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20231023@Casey.Huynh
		Task :		User Comment Get
		DB:			CTS_DataCenter
		Original:

		Revisions:
			-	20231023@Casey.Huynh: Created [Redmine ID: #195043]
            -	20240109@Casey.Huynh: Switch StaticList To Match Monitor Comment List  (ListID = 21) [Redmine ID: #197706]
            -	20250318@Casey.Huynh: 	Match Monitor Badminton [Redmine ID: #219681]
            
		Param's Explanation (filtered by):
		
		Example:
			CALL CTS_DC_MatchMonitor_UserComment_Get(@ip_MatchID:=1, @ip_LiveIndicator:=0, @ip_BettypeID:=8, @ip_BetID:=9922337203685477);
	*/
    DECLARE CONST_COMMENTTYPE_INCORRECT	TINYINT DEFAULT 0;
    DECLARE CONST_COMMENTTYPE_CORRECT	TINYINT DEFAULT 1;
    DECLARE CONST_STATICLIST_MMREASON	TINYINT DEFAULT 21;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_BetID;    
	CREATE TEMPORARY TABLE Temp_BetID( 	  
		BetID		BIGINT PRIMARY KEY
	);

    SET @sql = CONCAT("INSERT INTO Temp_BetID (BetID) VALUES ('", REPLACE(ip_BetIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    #========GET Match Monitor comment list=======================   
    SELECT	mm.MMUserCommentID
		,	mm.UserComment
		,	us.UserName		AS LastModifiedBy
        ,	mm.ModifiedDate	AS LastModifiedDate
        ,	CASE WHEN mmd.CommentType = CONST_COMMENTTYPE_CORRECT THEN  st.ItemName ELSE NULL END AS CorrectReason
        ,	CASE WHEN mmd.CommentType = CONST_COMMENTTYPE_INCORRECT THEN  st.ItemName ELSE NULL END AS IncorrectReason
        ,	mmd.FromTransInfo
        ,	mmd.ToTransInfo
    FROM CTS_DataCenter.MatchMonitorUserComment AS mm
		INNER JOIN CTS_DataCenter.MatchMonitorUserCommentDetails AS mmd ON mmd.MMUserCommentID = mm.MMUserCommentID
        INNER JOIN Temp_BetID AS tmpBet ON tmpBet.BetID = mm.BetID
        LEFT JOIN CTS_Admin.CTSUser AS us ON us.UserID = mm.ModifiedBy
        LEFT JOIN CTS_DataCenter.StaticList AS st ON st.ListID = CONST_STATICLIST_MMREASON AND st.ItemValue = mmd.Reason
    WHERE	mm.MatchID	= ip_MatchID
        AND	mm.LiveIndicator = ip_LiveIndicator
        AND	mm.BettypeID = ip_BettypeID;
        
END$$
DELIMITER ;
