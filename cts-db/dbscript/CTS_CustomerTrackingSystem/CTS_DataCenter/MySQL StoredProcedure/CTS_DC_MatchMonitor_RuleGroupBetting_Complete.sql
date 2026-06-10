/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_RuleGroupBetting_Complete`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_RuleGroupBetting_Complete`(
		IN ip_LiveIndicator BOOLEAN
	,	IN ip_MaxSequenceID	BIGINT UNSIGNED
	, 	IN ip_MatchID		INT
    , 	IN ip_ScoreDiff		INT 
    , 	IN ip_BettypeID		INT
    ,	IN ip_BetID			BIGINT
    ,	IN ip_Betteam		VARCHAR(10)
    , 	IN ip_TransGroup	JSON
)
 
  SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210526@Casey.Huynh
		Task :		Match Monitor Insert trans ticket to Staging table
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20210526@Casey.Huynh: Created [Redmine ID: 152883]
            -	20210719@Casey.Huynh: Fix Issue Rule Trans.StepTime and AssGroup [Redmine ID: 158946]
            -	20210830@Casey.Huynh: Update Rule seperate Live and NonLive and move to Slave [Redmine ID: 159195]
            -	20211213@Casey.Huynh: Enhance MM, Add column LeagueName [Redmine ID: 165606]
			-	20220110@Casey.Huynh: Enhance MM, Add SportType, Betteam, BetID [Redmine ID: 166986]
            -	20220815@Casey.Huynh: Scale Out DB [Redmine ID: #176472]
            - 	20220830@Casey.Huynh: New Category for Classify Group Betting [Redmine ID: #176976]
            -	202200929@Casey.Huynh: Seperate By Sport [Redmine ID: #178310]
            - 	202201021@Casey.Huynh: Group By Betteam [Redmine ID: #179439]
            -	20221205@Casey.Huynh: Rename Table [Redmine ID: #179502]
            -	20230202@Casey.Huynh: HF Missing Insert HighStakeLicCustList [Redmine ID: #183324]
            -	20230221@Casey.Huynh: Update Rule, The same Choice [Redmine ID: #184041]
            - 	20240417@Casey.Huynh: Renovate GroupBetting Rule [Redmine ID: #203319]
            
		Param's Explanation (filtered by):	

		Example:
			CALL CTS_DC_MatchMonitor_RuleGroupBetting_Complete(@ip_LiveIndicator:=1,@ip_MaxSequenceID:=119780351005,@ip_MatchID:=4
			,@ip_ScoreDiff:=0,@ip_BettypeID:=1,@ip_BetID:=0,@ip_Betteam:='a'
			,'[{"GroupID":1,"Reason":0,"TransIDList":"254608225414938624,254608225414938626","CustIDList":"1319,1320", "HighStakeLicCustList":"1319,1320"}]');
 
	*/
        
	DECLARE CONS_LOG 				TINYINT DEFAULT 0; #0:LogOff, 1:LogOn
    DECLARE CONS_MMREASON_GROUPBETTING	INT	DEFAULT	0;
    
	DECLARE lv_LogTime			DATETIME(4) DEFAULT current_timestamp(4);
    DECLARE lv_GroupID 					INT;
    DECLARE lv_TransIDList 				LONGTEXT;
    DECLARE lv_OldTransList 			LONGTEXT;    
    DECLARE lv_CustIDList				LONGTEXT;
    DECLARE lv_HighStakeLicCustList		LONGTEXT;
    
    DECLARE lv_NoOfOldGroupID	INT;
    DECLARE lv_EventDate 		DATE;
    DECLARE lv_LiveHomeScore	SMALLINT UNSIGNED;
    DECLARE lv_LiveAwayScore	SMALLINT UNSIGNED;
    DECLARE lv_TargetGroupID 	INT;
    DECLARE	lv_KickOffTime 		DATETIME;
    DECLARE	lv_EventStatus 		VARCHAR(50);
    DECLARE lv_HomeID 			INT UNSIGNED;
    DECLARE lv_AwayID 			INT UNSIGNED;
    DECLARE lv_LeagueID			INT UNSIGNED;
    DECLARE lv_LeagueName		VARCHAR(500);
    DECLARE	lv_Sporttype		INT;
	
    #==================LOG=======================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_RuleGroupBetting_Complete';
    IF CONS_LOG = 1 THEN     
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText, JsonString1)
		SELECT lv_SPName, CURRENT_TIMESTAMP(4), CONCAT('lv_LogTime_Start:=',lv_LogTime,',@ip_LiveIndicator:=',ip_LiveIndicator,',@ip_MaxSequenceID:=',ip_MaxSequenceID,',@ip_MatchID:=',ip_MatchID
		,',@ip_ScoreDiff:=',ip_ScoreDiff,',@ip_BettypeID:=',ip_BettypeID,',@ip_BetID:=',ip_BetID,',@ip_Betteam:=',ip_Betteam), ip_TransGroup;
    END IF;
    #==================LOG=======================================================  
    
    DROP TEMPORARY TABLE IF EXISTS Temp_TransGroup;
    CREATE TEMPORARY TABLE Temp_TransGroup
    (
			GroupID 				INT PRIMARY KEY
        ,	CustIDList 				LONGTEXT
        ,	TransIDList				LONGTEXT 
        ,	HighStakeLicCustList	LONGTEXT
    );    
    
	DROP TEMPORARY TABLE IF EXISTS Temp_GroupBettingGroup;
    CREATE TEMPORARY TABLE Temp_GroupBettingGroup
    (
			GroupID 				INT PRIMARY KEY
        ,	CustIDList 				LONGTEXT
        ,	TransIDList				LONGTEXT
        ,	HighStakeLicCustList	LONGTEXT
    );   
	
	DROP TEMPORARY TABLE IF EXISTS Temp_GroupBettingOldGroup;
    CREATE TEMPORARY TABLE Temp_GroupBettingOldGroup(
			GroupID INT PRIMARY KEY
    ); 
	
	DROP TEMPORARY TABLE IF EXISTS Temp_GroupBettingTrans;
    CREATE TEMPORARY TABLE Temp_GroupBettingTrans(
			TransID	BIGINT PRIMARY KEY
    ); 
    
    INSERT IGNORE INTO Temp_TransGroup(GroupID, CustIDList, TransIDList,HighStakeLicCustList)
	SELECT  js.GroupID
		,	js.CustIDList
        ,	js.TransIDList
        ,	js.HighStakeLicCustList
	FROM JSON_TABLE(ip_TransGroup,
					 "$[*]" COLUMNS(
								GroupID					INT PATH "$.GroupID" 
							,	CustIDList				LONGTEXT PATH "$.CustIDList" 
                            ,	TransIDList				LONGTEXT PATH "$.TransIDList"
                            ,	HighStakeLicCustList	LONGTEXT PATH "$.HighStakeLicCustList" 
						)
				) AS js;     

    INSERT INTO Temp_GroupBettingGroup(GroupID, CustIDList, TransIDList, HighStakeLicCustList)
    SELECT  tmpTg.GroupID
		,	tmpTg.CustIDList
        ,	tmpTg.TransIDList
        ,	tmpTg.HighStakeLicCustList
	FROM Temp_TransGroup AS tmpTg;

    #======Update MatchMonitorDetails====================================  

    IF (ip_LiveIndicator = 1) THEN
		SELECT mms.EventDate, mms.LiveHomeScore, mms.LiveAwayScore, mms.EventDate, mms.KickOffTime, mms.EventStatus, mms.HomeID, mms.AwayID, mms.LeagueID, mms.LeagueName, mms.Sporttype
		INTO lv_EventDate, lv_LiveHomeScore, lv_LiveAwayScore, lv_EventDate, lv_KickOffTime, lv_EventStatus, lv_HomeID, lv_AwayID, lv_LeagueID, lv_LeagueName, lv_Sporttype
		FROM CTS_DataCenter.MatchMonitorStagingGroupBettingLive AS mms
		WHERE mms.SequenceID <= ip_MaxSequenceID AND mms.MatchID = ip_MatchID AND mms.BettypeID = ip_BettypeID AND mms.BetID = ip_BetID AND mms.Betteam = ip_Betteam AND mms.ScoreDiff = ip_ScoreDiff
		LIMIT 1;
	END IF;

	IF (ip_LiveIndicator = 0) THEN
		SELECT mms.EventDate, mms.LiveHomeScore, mms.LiveAwayScore, mms.EventDate, mms.KickOffTime, mms.EventStatus, mms.HomeID, mms.AwayID, mms.LeagueID, mms.LeagueName, mms.Sporttype
		INTO lv_EventDate, lv_LiveHomeScore, lv_LiveAwayScore, lv_EventDate, lv_KickOffTime, lv_EventStatus, lv_HomeID, lv_AwayID, lv_LeagueID, lv_LeagueName, lv_Sporttype
		FROM CTS_DataCenter.MatchMonitorStagingGroupBettingNonLive AS mms
		WHERE mms.SequenceID <= ip_MaxSequenceID AND mms.MatchID = ip_MatchID AND mms.BettypeID = ip_BettypeID AND mms.BetID = ip_BetID  AND mms.Betteam = ip_Betteam AND mms.ScoreDiff = ip_ScoreDiff
		LIMIT 1;	 
	END IF;
    #========GroupBetting Group========================
    IF EXISTS (SELECT 1 FROM Temp_GroupBettingGroup AS tmpTg) THEN
		hg: LOOP 
			TRUNCATE TABLE Temp_GroupBettingOldGroup;
			TRUNCATE TABLE Temp_GroupBettingTrans;         

			SET lv_GroupID = 0;

			SELECT tmpTg.GroupID, tmpTg.TransIDList, tmpTg.CustIDList, tmpTg.HighStakeLicCustList
			INTO lv_GroupID,  lv_TransIDList, lv_CustIDList, lv_HighStakeLicCustList
			FROM Temp_GroupBettingGroup AS tmpTg
			ORDER BY tmpTg.GroupID ASC 
            LIMIT 1;        
			  
			IF lv_GroupID =0 
			THEN			
				LEAVE hg; 
			END IF;
                        
            CALL CTS_DC_Sys_SplitStringToTempItemTable(lv_TransIDList,',','BIGINT');
            
			INSERT IGNORE INTO Temp_GroupBettingTrans (TransID) SELECT * FROM TempItemTable;   

            IF (ip_LiveIndicator = 1) THEN
            
				INSERT IGNORE INTO Temp_GroupBettingOldGroup
				SELECT DISTINCT(mms.GroupID)
				FROM Temp_GroupBettingTrans AS tmpTs
					INNER JOIN MatchMonitorStagingGroupBettingLive AS mms ON mms.TransID = tmpTs.TransID;     
                 
			ELSEIF (ip_LiveIndicator = 0) THEN
    
				INSERT IGNORE INTO Temp_GroupBettingOldGroup
				SELECT DISTINCT(mms.GroupID)
				FROM Temp_GroupBettingTrans AS tmpTs
					INNER JOIN MatchMonitorStagingGroupBettingNonLive AS mms ON mms.TransID = tmpTs.TransID;
                
           END IF;        
            
            SELECT MIN(GroupID)
            INTO lv_TargetGroupID
            FROM Temp_GroupBettingOldGroup
            WHERE GroupID <> 0;			
            
			SELECT COUNT(1)
            INTO lv_NoOfOldGroupID
            FROM Temp_GroupBettingOldGroup
            WHERE GroupID <> 0;			

			IF(lv_NoOfOldGroupID = 0) THEN # INSERT NEW GROUP
				SELECT 	IFNULL(MAX(mmd.GroupID),0)
				INTO 	lv_TargetGroupID
				FROM 	CTS_DataCenter.MatchMonitorDetails AS mmd
				WHERE 	mmd.LiveIndicator = ip_LiveIndicator AND mmd.MatchID = ip_MatchID AND mmd.BettypeID = ip_BettypeID AND mmd.BetID = ip_BetID  AND mmd.Betteam = ip_Betteam AND mmd.ScoreDiff = ip_ScoreDiff AND mmd.Reason = CONS_MMREASON_GROUPBETTING; 

				SET lv_TargetGroupID =  lv_TargetGroupID + 1;
                
				INSERT IGNORE INTO CTS_DataCenter.MatchMonitorDetails(MatchID, LiveIndicator, ScoreDiff, BettypeID, BetID, Betteam, EventDate, GroupID, LiveHomeScore, LiveAwayScore, ListCustID, ListTransID, HighStakeLicCustList, Reason)##LOG185793
				VALUES(ip_MatchID, ip_LiveIndicator, ip_ScoreDiff, ip_BettypeID, ip_BetID, ip_Betteam, lv_EventDate, lv_TargetGroupID, lv_LiveHomeScore, lv_LiveAwayScore
				, lv_CustIDList, lv_TransIDList, lv_HighStakeLicCustList, CONS_MMREASON_GROUPBETTING);      

			END IF; 
	
			IF (lv_NoOfOldGroupID = 1) THEN # UPDATE OLD GROUP  
				SELECT mmd.ListTransID
                INTO lv_OldTransList
                FROM CTS_DataCenter.MatchMonitorDetails AS mmd 
                WHERE  mmd.LiveIndicator = ip_LiveIndicator AND mmd.MatchID = ip_MatchID
					AND mmd.BettypeID = ip_BettypeID AND mmd.BetID = ip_BetID 
					AND mmd.Betteam = ip_Betteam AND mmd.ScoreDiff = ip_ScoreDiff 
                    AND mmd.GroupID = lv_TargetGroupID  AND mmd.Reason = CONS_MMREASON_GROUPBETTING;
                
                IF LENGTH(lv_OldTransList) < LENGTH(lv_TransIDList) THEN					
					UPDATE IGNORE CTS_DataCenter.MatchMonitorDetails AS mmd 
					SET mmd.GroupID = lv_TargetGroupID, mmd.ListCustID = lv_CustIDList, mmd.ListTransID = lv_TransIDList, mmd.Reason = CONS_MMREASON_GROUPBETTING
					WHERE  mmd.LiveIndicator = ip_LiveIndicator AND mmd.MatchID = ip_MatchID 
						AND mmd.BettypeID = ip_BettypeID AND mmd.BetID = ip_BetID 
						AND mmd.Betteam = ip_Betteam AND mmd.ScoreDiff = ip_ScoreDiff 
                        AND mmd.GroupID = lv_TargetGroupID AND mmd.Reason = CONS_MMREASON_GROUPBETTING;
				END IF;
				
			END IF;        
			
			IF (lv_NoOfOldGroupID > 1) THEN # MERGE GROUP        
				DELETE mmd
				FROM CTS_DataCenter.MatchMonitorDetails AS mmd
					INNER JOIN Temp_GroupBettingOldGroup AS tmpIt ON mmd.GroupID = tmpIt.GroupID
				WHERE mmd.LiveIndicator = ip_LiveIndicator AND mmd.MatchID = ip_MatchID 
					AND mmd.BettypeID = ip_BettypeID AND mmd.BetID = ip_BetID 
					AND mmd.Betteam = ip_Betteam AND mmd.ScoreDiff = ip_ScoreDiff 
					AND mmd.GroupID <> lv_TargetGroupID AND mmd.Reason = CONS_MMREASON_GROUPBETTING;
						
				UPDATE IGNORE CTS_DataCenter.MatchMonitorDetails AS mmd
				SET mmd.GroupID = lv_TargetGroupID, mmd.ListCustID = lv_CustIDList, mmd.ListTransID = lv_TransIDList
				WHERE mmd.LiveIndicator = ip_LiveIndicator AND mmd.MatchID = ip_MatchID 
					AND mmd.BettypeID = ip_BettypeID AND mmd.BetID = ip_BetID 
					AND mmd.Betteam = ip_Betteam AND mmd.ScoreDiff = ip_ScoreDiff 
					AND mmd.GroupID = lv_TargetGroupID  AND mmd.Reason = CONS_MMREASON_GROUPBETTING;   
 
			END IF;		
			#==============UPDATE Staging GroupID ===========================================================
			IF(ip_LiveIndicator = 1) THEN
					SET @sql = 	CONCAT("UPDATE CTS_DataCenter.MatchMonitorStagingGroupBettingLive
										SET GroupID = ",lv_TargetGroupID,"
										WHERE TransID IN (",lv_TransIDList,")");    
					
					PREPARE 	stmt1 FROM @sql;
					EXECUTE 	stmt1;
			END IF;	
            
			IF(ip_LiveIndicator = 0) THEN			
					SET @sql = 	CONCAT("UPDATE CTS_DataCenter.MatchMonitorStagingGroupBettingNonLive
										SET	GroupID = ",lv_TargetGroupID,"
										WHERE TransID IN (",lv_TransIDList,")");
					
					PREPARE 	stmt1 FROM @sql;
					EXECUTE 	stmt1;
			END IF;  
			
			DELETE tmptg
			FROM Temp_GroupBettingGroup AS tmptg WHERE GroupID = lv_GroupID;

		END LOOP;
		
		#========UPDATE MatchMonitor===================================    
		INSERT IGNORE INTO CTS_DataCenter.MatchMonitor(MatchID, BettypeID, BetID, LiveIndicator, EventDate, KickOffTime, EventStatus, HomeID, AwayID, LeagueID, LeagueName, Sporttype, Reason)
		SELECT	ip_MatchID, ip_BettypeID, ip_BetID, ip_LiveIndicator, lv_EventDate, lv_KickOffTime, lv_EventStatus, lv_HomeID, lv_AwayID, lv_LeagueID, lv_LeagueName, lv_Sporttype,	mmd.Reason
		FROM CTS_DataCenter.MatchMonitorDetails AS mmd
		WHERE mmd.LiveIndicator = ip_LiveIndicator AND mmd.MatchID = ip_MatchID 
			AND mmd.BettypeID = ip_BettypeID AND mmd.BetID = ip_BetID 
			AND mmd.Betteam = ip_Betteam AND mmd.Reason = CONS_MMREASON_GROUPBETTING;
	END IF;	
    
    
	IF CONS_LOG = 1 THEN     
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, current_timestamp(4), CONCAT('lv_LogTime_end:=',lv_LogTime);
    END IF;
END$$
DELIMITER ;
