/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `Adhoc_CTS_DC_Backup_MatchMonitorDetails_Data`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `Adhoc_CTS_DC_Backup_MatchMonitorDetails_Data`(
		IN ip_BatchSize			INT
)
    SQL SECURITY INVOKER
sp:BEGIN 
    /*
        Created: 20231129@Victoria.Le
        Task: Back Up Data with HighStakeLicCustList IS NOT NULL
        DB: CTS_DataCenter
      
        Revisions:
            - 20231129@Victoria.Le: Initial Writing  [Redmine ID: #188553]
            
		CALL Adhoc_CTS_DC_Backup_MatchMonitorDetails_Data (5);
    */

    DECLARE lv_rowcount 	INT DEFAULT 0;
    DECLARE lv_lastID	 	BIGINT DEFAULT 0;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_MatchMonitorDetails;
	CREATE TEMPORARY TABLE 		Temp_MatchMonitorDetails (
			ID 				BIGINT
		,	MatchID			INT		
		,	EventDate		DATE
		,	PRIMARY KEY (ID,EventDate) 	
	);
    
    WHILE (1=1) DO
		TRUNCATE TABLE Temp_MatchMonitorDetails;
		
		SET lv_rowcount = 0;

		INSERT INTO Temp_MatchMonitorDetails (ID,MatchID,EventDate)
		SELECT DISTINCT md.ID,md.MatchID,md.EventDate
		FROM CTS_DataCenter.MatchMonitorDetails AS md
			INNER JOIN CTS_DataCenter.MatchMonitor AS mm ON md.matchid = mm.matchid AND md.EventDate = mm.EventDate
		WHERE mm.SportType = 2
			AND md.HighStakeLicCustList IS NOT NULL
			AND md.ID > lv_lastID
		ORDER BY md.ID ASC
		LIMIT ip_BatchSize;
		
		SELECT COUNT(1) 
		INTO lv_rowcount
		FROM Temp_MatchMonitorDetails;
		
		SELECT MAX(ID) 
		INTO lv_lastID
		FROM Temp_MatchMonitorDetails;
        
        IF IFNULL(lv_rowcount,0) = 0 THEN
            LEAVE sp;
		ELSE
			INSERT IGNORE INTO CTS_DataCenter.MatchMonitorDetails_20231129_bk (ID,MatchID,LiveIndicator,BettypeID,HDP,GroupID,Reason,ListCustID,ListTransID,EventDate,LiveHomeScore,LiveAwayScore,BetID,ClassifyStatus,Betteam,HighStakeLicCustList,InsertTime,ScoreDiff)
			SELECT md.ID,md.MatchID,md.LiveIndicator,md.BettypeID,md.HDP,md.GroupID,md.Reason,md.ListCustID,md.ListTransID,md.EventDate,md.LiveHomeScore,md.LiveAwayScore,md.BetID,md.ClassifyStatus,md.Betteam,md.HighStakeLicCustList,md.InsertTime,md.ScoreDiff
			FROM Temp_MatchMonitorDetails AS tmp
				INNER JOIN CTS_DataCenter.MatchMonitorDetails as md ON md.ID = tmp.ID;
		END IF;

    END WHILE;

END$$
DELIMITER ;
