/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `Adhoc_CTS_DC_Update_MatchMonitor_Data`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `Adhoc_CTS_DC_Update_MatchMonitor_Data`(
		IN ip_BatchSize			INT
)
    SQL SECURITY INVOKER
sp:BEGIN 
    /*
        Created: 20231129@Victoria.Le
        Task: Update/Clear Data Before Deploy SP Process GB
        DB: CTS_DataCenter
      
        Revisions:
            - 20231129@Victoria.Le: Initial Writing  [Redmine ID: #188553]
            
		CALL Adhoc_CTS_DC_Update_MatchMonitor_Data (5);
    */

    DECLARE lv_rowcount 	INT DEFAULT 0;
    DECLARE lv_lastID	 	BIGINT DEFAULT 0;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_MatchMonitor;
	CREATE TEMPORARY TABLE 		Temp_MatchMonitor (
			ID 					BIGINT
		,	MatchID				INT		
		,	EventDate			DATE
		,	ClassifyStatus		TINYINT
		,	PRIMARY KEY (ID,EventDate) 	
		,	INDEX IX_Temp_MatchMonitor (MatchID,EventDate,ClassifyStatus)
	);
    
    WHILE (1=1) DO
		TRUNCATE TABLE Temp_MatchMonitor;
		
		SET lv_rowcount = 0;

		INSERT INTO Temp_MatchMonitor (ID,MatchID,EventDate,ClassifyStatus)
		SELECT mm.ID,mm.MatchID,mm.EventDate,mm.ClassifyStatus
		FROM CTS_DataCenter.MatchMonitor AS mm 
		WHERE mm.SportType = 2
			AND mm.ID > lv_lastID
		ORDER BY mm.ID ASC
		LIMIT ip_BatchSize;
		
		SELECT COUNT(1) 
		INTO lv_rowcount
		FROM Temp_MatchMonitor;
		
		SELECT MAX(ID) 
		INTO lv_lastID
		FROM Temp_MatchMonitor;
        
        IF IFNULL(lv_rowcount,0) = 0 THEN
            LEAVE sp;
		ELSE
			UPDATE MatchMonitor AS mm
				INNER JOIN Temp_MatchMonitor AS tmp ON tmp.ID = mm.ID AND tmp.EventDate = mm.EventDate
			SET mm.ClassifyStatus = 1
			WHERE tmp.ClassifyStatus = 2;

            UPDATE MatchMonitorDetails AS md
				INNER JOIN Temp_MatchMonitor AS tmp ON tmp.MatchID = md.MatchID AND tmp.EventDate = md.EventDate
			SET md.HighStakeLicCustList = NULL;
          
			UPDATE MatchMonitorDetails AS md
				INNER JOIN Temp_MatchMonitor AS tmp ON tmp.MatchID = md.MatchID AND tmp.EventDate = md.EventDate
			SET 	md.ClassifyStatus = 1
			WHERE tmp.ClassifyStatus = 2;

			
		END IF;

    END WHILE;

END$$
DELIMITER ;
