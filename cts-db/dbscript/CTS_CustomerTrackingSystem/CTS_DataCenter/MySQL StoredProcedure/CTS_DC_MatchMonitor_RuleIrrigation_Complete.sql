/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_RuleIrrigation_Complete`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_RuleIrrigation_Complete`(
		IN ip_LiveIndicator BOOLEAN    
	,	IN ip_MaxSequenceID BIGINT UNSIGNED
    ,	IN ip_SportType     INT
	, 	IN ip_MatchID		INT
    , 	IN ip_ScoreDiff		INT 
    , 	IN ip_BettypeID		INT
    ,	IN ip_BetID			BIGINT
	,	IN ip_HDP			DECIMAL(8,4)
    ,	IN ip_Betteam		VARCHAR(10)
    , 	IN ip_TransGroup	JSON
    
)
  SQL SECURITY INVOKER
	BEGIN
	/*
		Created:	20211122@Casey.Huynh
		Task :		Match Monitor Rule Irrigation complete
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20221122@Casey.Huynh: Created [Redmine ID: #179499]
			- 20221228@Victoria.Le:	Add HDP for Irrigation rule [Redmine ID: #181990]
            
		Param's Explanation (filtered by):	
			
		Example:
			CALL CTS_DC_MatchMonitor_RuleIrrigation_Complete(@ip_LiveIndicator:=0,@ip_MaxSequenceID:=0,@ip_SportType:=1,@ip_MatchID:=1
            ,@ip_ScoreDiff:=1,@ip_BettypeID:=1,@ip_BetID:=0,@ip_Betteam:='a',
            @ip_TransGroup:='[{"CustID":3,"TransIDList":"1,2,3","OldGroupID":1}]');
	*/
    DECLARE	CONST_GROUPID	TINYINT DEFAULT 4;
    
    DECLARE lv_Rule_Reason	INT;  
    DECLARE lv_MaxGroupID	INT;    
	DECLARE lv_KickOffTime  DATETIME;
	DECLARE lv_EventStatus  VARCHAR(50);
	DECLARE lv_HomeID   INT UNSIGNED;
	DECLARE lv_AwayID    INT UNSIGNED;
	DECLARE lv_LeagueID   INT UNSIGNED;
	DECLARE lv_LeagueName  VARCHAR(500);
	DECLARE lv_EventDate   DATE;
	DECLARE lv_LiveHomeScore  SMALLINT UNSIGNED;
	DECLARE lv_LiveAwayScore  SMALLINT UNSIGNED;
    
	/*===================LOG=======================================
	INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText, JsonString1 )
    SELECT'CTS_DC_MatchMonitor_RuleIrrigation_Complete1', current_timestamp(), 
    CONCAT('ip_LiveIndicator:',ip_LiveIndicator,' ip_MaxSequenceID:',ip_MaxSequenceID,' ip_SportType:',ip_SportType,' ip_MatchID:',ip_MatchID
    ,' ip_ScoreDiff:',ip_ScoreDiff,' ip_BettypeID:',ip_BettypeID,' ip_BetID:',ip_BetID,' ip_Betteam:',ip_Betteam), ip_TransGroup;
	===================LOG=======================================*/
    DROP TEMPORARY TABLE IF EXISTS Temp_InputTransGroup;
    CREATE TEMPORARY TABLE Temp_InputTransGroup
    (
			CustID 			BIGINT UNSIGNED PRIMARY KEY
        ,	TransIDList 	LONGTEXT
        ,	OldGroupID		INT 
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_NewGroup;
    CREATE TEMPORARY TABLE Temp_NewGroup
    (		ID				INT PRIMARY KEY AUTO_INCREMENT
		,	CustID 			BIGINT UNSIGNED
        ,	TransIDList		TEXT
        ,	GroupID			INT 
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_TransGroup;
    CREATE TEMPORARY TABLE Temp_TransGroup
    (
			TransID 	BIGINT UNSIGNED PRIMARY KEY
        ,	GroupID 	INT
    );
    
    #===========GET RULE SETTING==================================================
    SELECT mst.Reason
    INTO lv_Rule_Reason
    FROM CTS_DataCenter.MatchMonitorRuleSetting AS mst
    WHERE mst.RuleGroupID = 4 AND mst.SportType = ip_SportType AND mst.RuleStatus = 1;
    
    #=============================================================================
    INSERT IGNORE INTO Temp_InputTransGroup(CustID, TransIDList, OldGroupID)
	SELECT 	js.CustID
		,	js.TransIDList
		,	js.OldGroupID
	FROM JSON_TABLE(ip_TransGroup,
					 "$[*]" COLUMNS(
								CustID			BIGINT UNSIGNED PATH "$.CustID"
							,	TransIDList		LONGTEXT PATH "$.TransIDList"
							,	OldGroupID		INT PATH "$.OldGroupID" 
						)
				) AS js;               
	
    #=======UPDATE OLD GROUP====================================	
	UPDATE CTS_DataCenter.MatchMonitorDetails AS mmd
		INNER JOIN Temp_InputTransGroup AS tmp ON mmd.GroupID = tmp.OldGroupID 
    SET ListTransID = CONCAT(ListTransID,',',TransIDList)
	WHERE mmd.MatchID = ip_MatchID 
		AND mmd.ScoreDiff = ip_ScoreDiff 
		AND mmd.BettypeID = ip_BettypeID 
		AND mmd.BetID = ip_BetID 
		AND mmd.HDP = ip_HDP
		AND mmd.Betteam = ip_Betteam
		AND mmd.Reason = lv_Rule_Reason;
	
    #=======INSERT NEW GROUP===================================
    SELECT IFNULL(MAX(mmd.GroupID),0)
    INTO lv_MaxGroupID
    FROM CTS_DataCenter.MatchMonitorDetails AS mmd
    WHERE mmd.MatchID = ip_MatchID 
		AND mmd.ScoreDiff = ip_ScoreDiff 
		AND mmd.BettypeID = ip_BettypeID 
		AND mmd.BetID = ip_BetID
		AND mmd.HDP = ip_HDP
		AND mmd.Betteam = ip_Betteam 
		AND mmd.Reason = lv_Rule_Reason;

    INSERT INTO Temp_NewGroup(CustID, TransIDList)
    SELECT	tmpTg.CustID
		,	tmpTg.TransIDList
    FROM Temp_InputTransGroup AS tmpTg
    WHERE tmpTg.OldGroupID = 0;
	
    UPDATE Temp_NewGroup AS tmpNg
    SET tmpNg.GroupID = tmpNg.ID + lv_MaxGroupID;
    
    IF (ip_LiveIndicator = 0) THEN
		SELECT mms.EventDate, mms.LiveHomeScore, mms.LiveAwayScore, mms.EventDate, mms.KickOffTime, mms.EventStatus, mms.HomeID, mms.AwayID, mms.LeagueID, mms.LeagueName
		INTO lv_EventDate, lv_LiveHomeScore, lv_LiveAwayScore, lv_EventDate, lv_KickOffTime, lv_EventStatus, lv_HomeID, lv_AwayID, lv_LeagueID, lv_LeagueName
		FROM CTS_DataCenter.MatchMonitorStagingIrrigationNonLive AS mms
		WHERE mms.SequenceID <= ip_MaxSequenceID 
			AND mms.MatchID = ip_MatchID 
			AND mms.BettypeID = ip_BettypeID 
			AND mms.BetID = ip_BetID 
			AND mms.Hdp = ip_HDP
			AND mms.Betteam = ip_Betteam
		LIMIT 1;
	END IF;

    INSERT IGNORE INTO CTS_DataCenter.MatchMonitorDetails(MatchID, LiveIndicator, ScoreDiff, BettypeID, BetID, HDP, Betteam, EventDate, LiveHomeScore, LiveAwayScore, ListCustID, ListTransID, GroupID, Reason)
	SELECT	ip_MatchID, ip_LiveIndicator, ip_ScoreDiff, ip_BettypeID, ip_BetID, ip_HDP, ip_Betteam, lv_EventDate, lv_LiveHomeScore, lv_LiveAwayScore, tmpNg.CustID, tmpNg.TransIDList, tmpNg.GroupID, lv_Rule_Reason
	FROM 	Temp_NewGroup AS tmpNg;
    
    INSERT IGNORE INTO CTS_DataCenter.MatchMonitor(MatchID, BettypeID, BetID, LiveIndicator, EventDate, KickOffTime, EventStatus, HomeID, AwayID, LeagueID, LeagueName, Sporttype, Reason)
	SELECT	ip_MatchID, ip_BettypeID, ip_BetID, ip_LiveIndicator, lv_EventDate, lv_KickOffTime, lv_EventStatus, lv_HomeID, lv_AwayID, lv_LeagueID, lv_LeagueName, ip_SportType,	lv_Rule_Reason
	FROM Temp_NewGroup AS tmpTg
    WHERE tmpTg.GroupID = 1;
    
	#=======Existing Group==========
	INSERT INTO Temp_TransGroup(TransID, GroupID)
	SELECT js.TransID
		,  tmpTg.OldGroupID
	FROM Temp_InputTransGroup AS tmpTg
	JOIN JSON_TABLE(REPLACE(JSON_ARRAY(tmpTg.TransIDList), ',', '","'), 
					'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
					) js
	WHERE tmpTg.OldGroupID > 0;
	
	#=======NEW GROUP===============================================================
	INSERT INTO Temp_TransGroup(TransID, GroupID)
	SELECT js.TransID
		,  tmpNg.GroupID
	FROM Temp_NewGroup AS tmpNg
	JOIN JSON_TABLE(REPLACE(JSON_ARRAY(tmpNg.TransIDList), ',', '","'), 
					'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
					) js;    


	IF (ip_LiveIndicator = 0) THEN
		#=======UPDATE GROUPID TO STAGING TABLE===================
		UPDATE CTS_DataCenter.MatchMonitorStagingIrrigationNonLive AS mms
			INNER JOIN Temp_TransGroup as tmpTg ON mms.TransID = tmpTg.TransID
		SET mms.GroupID = tmpTg.GroupID;     
	END IF;	
    
END$$
DELIMITER ;
