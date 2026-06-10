/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_RuleHedging_StagingClean`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_RuleHedging_StagingClean`(
		IN ip_LiveIndicator	BOOLEAN
	,	IN ip_MaxSequenceID	BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210526@Casey.Huynh
		Task :		Match Monitor Insert trans ticket to Staging table
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20210526@Casey.Huynh: Created [Redmine ID: 159195]
            -	20220110@Casey.Huynh: Enhance MM, Add SportType, Betteam, BetID [Redmine ID: 166986]
            -	20220815@Casey.Huynh: Scale Out DB [Redmine ID: #176472]
            -	202200929@Casey.Huynh: Seperate By Sport [Redmine ID: #178310]
            -	20221021@Casey.Huynh: Fixed Clean Data Staging [Redmine ID: #179427]
            -	20221027@Casey.Huynh: Seperate pool Staging [RedmineID: 179439]
            -	20221205@Casey.Huynh: Rename Table [Redmine ID: #179502]
            -	20230109@Casey.Huynh: UpdateSoreDiff [Redmine ID: #182637]
            -	20240509@Casey.Huynh: HF Hedging StepTime, Keep Cust if existing Last 3 miniutes [Redmine ID: #204338]
            
		Param's Explanation (filtered by):
			CALL CTS_DC_MatchMonitor_RuleHedging_StagingClean(@ip_LiveIndicator:=1,@ip_MaxSequenceID:=2);
            
		Example:
			
	*/
    DECLARE CONS_LOG 			TINYINT DEFAULT 0; #0:LogOff, 1:LogOn
    DECLARE CONST_RULE_GROUPID  TINYINT DEFAULT 3; # Hedging
 
	DECLARE	lv_LastTransID 		BIGINT; 
	DECLARE	lv_FromTime 		BIGINT;
    DECLARE	lv_ToTime 			BIGINT; 
    DECLARE lv_Rule_TimeStep	SMALLINT;
    
    #==================LOG=======================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_RuleHedging_StagingClean';
    IF CONS_LOG = 1 THEN     
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, CURRENT_TIMESTAMP(), CONCAT('@ip_LiveIndicator:=',ip_LiveIndicator,',@ip_MaxSequenceID:=',ip_MaxSequenceID);
    END IF;
    #==================LOG=======================================================   
    
    DROP TEMPORARY TABLE IF EXISTS Temp_LastGroupIDGroup;
    CREATE TEMPORARY TABLE Temp_LastGroupIDGroup
    (
			MatchID INT
        ,	ScoreDiff INT
        ,	BettypeID INT
        ,	BetID BIGINT
        ,	Betteam VARCHAR(10)
        ,   GroupID INT
        
        ,	PRIMARY KEY (MatchID,ScoreDiff,BettypeID, BetID, Betteam, GroupID)
    );

	DROP TEMPORARY TABLE IF EXISTS Temp_LastCustIDGroup;
	CREATE TEMPORARY TABLE Temp_LastCustIDGroup(
			MatchID		INT
        ,	ScoreDiff	INT
        ,	BettypeID	INT
        ,	BetID		BIGINT
        ,	Betteam		VARCHAR(10)
        ,   CustID 		INT
        
        ,	PRIMARY KEY (MatchID,ScoreDiff,BettypeID, BetID, Betteam, CustID)
	);
    #======Get Setting Info=====================================================
    SELECT TimeStep
    INTO lv_Rule_TimeStep
    FROM CTS_DataCenter.MatchMonitorRuleSetting AS st
    WHERE st.RuleGroupID = CONST_RULE_GROUPID AND st.RuleStatus = 1
    LIMIT 1;
    
    #======Clean Staging=================================================
    IF (ip_LiveIndicator = 1) THEN 		
    
		SELECT 	MAX(mms.TransDateToSecond), MAX(mms.TransID)
		INTO 	lv_ToTime, lv_LastTransID
		FROM	CTS_DataCenter.MatchMonitorStagingHedgingLive AS mms
        WHERE	mms.SequenceID <= ip_MaxSequenceID;      
		
        SELECT  mms.TransDateToSecond
        INTO 	lv_FromTime
		FROM	CTS_DataCenter.MatchMonitorStagingHedgingLive AS mms
        WHERE	mms.SequenceID <= ip_MaxSequenceID
			AND mms.TransDateToSecond >= lv_ToTime - lv_Rule_TimeStep
		ORDER BY mms.TransDateToSecond ASC
        LIMIT 1;  
		
		INSERT INTO Temp_LastGroupIDGroup(MatchID, ScoreDiff, BettypeID, BetID, Betteam, GroupID)
		SELECT 	DISTINCT mms.MatchID,  mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, mms.GroupID
		FROM 	CTS_DataCenter.MatchMonitorStagingHedgingLive mms
		WHERE	mms.SequenceID <= ip_MaxSequenceID
			AND mms.GroupID <> 0
			AND	mms.TransDateToSecond BETWEEN lv_FromTime AND lv_ToTime; 
        
		#=====Remove GroupID > 0 AND NOT IN Last Step Time Group===================
		DELETE mms
		FROM CTS_DataCenter.MatchMonitorStagingHedgingLive AS mms            
			LEFT JOIN Temp_LastGroupIDGroup AS tmpTg ON mms.MatchID = tmpTg.MatchID AND mms.ScoreDiff = tmpTg.ScoreDiff AND mms.BettypeID = tmpTg.BettypeID
				AND mms.BetID = tmpTg.BetID AND mms.Betteam = tmpTg.Betteam AND mms.GroupID = tmpTg.GroupID
		WHERE	mms.SequenceID <= ip_MaxSequenceID
			AND mms.GroupID > 0 
			AND mms.TransDateToSecond < lv_FromTime 
			AND tmpTg.GroupID IS NULL;
		
        #=====Remove GroupID > 0 AND NOT IN Last Step Time Group===================
        WHILE EXISTS (	SELECT 1 
						FROM CTS_DataCenter.MatchMonitorStagingHedgingLive AS mms 
						WHERE mms.SequenceID <= ip_MaxSequenceID
							AND mms.GroupID = 0 
                            AND mms.TransDateToSecond < lv_FromTime
                        LIMIT 1)
		DO	
            
			TRUNCATE TABLE Temp_LastCustIDGroup;
			INSERT INTO Temp_LastCustIDGroup(MatchID, ScoreDiff, BettypeID, BetID, Betteam, CustID)
			SELECT	DISTINCT mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, mms.CustID
			FROM 	CTS_DataCenter.MatchMonitorStagingHedgingLive AS mms
			WHERE	mms.SequenceID <= ip_MaxSequenceID
				AND mms.GroupID = 0
				AND	mms.TransDateToSecond BETWEEN lv_FromTime AND lv_ToTime;
       
            DELETE mms
			FROM CTS_DataCenter.MatchMonitorStagingHedgingLive AS mms            
				LEFT JOIN Temp_LastCustIDGroup AS tmpCus ON mms.MatchID = tmpCus.MatchID AND mms.ScoreDiff = tmpCus.ScoreDiff AND mms.BettypeID = tmpCus.BettypeID
							AND mms.BetID = tmpCus.BetID AND mms.Betteam = tmpCus.Betteam AND tmpCus.CustID = mms.CustID 
			WHERE	mms.SequenceID <= ip_MaxSequenceID
				AND mms.GroupID = 0 
				AND mms.TransDateToSecond < lv_FromTime 
				AND tmpCus.CustID IS NULL;    

            #===Get Previous Time Group===============    
			SELECT 	MAX(mms.TransDateToSecond)
			INTO 	lv_ToTime
			FROM	CTS_DataCenter.MatchMonitorStagingHedgingLive AS mms
			WHERE	mms.SequenceID <= ip_MaxSequenceID
				AND mms.TransDateToSecond < lv_FromTime
				AND mms.GroupID = 0; 
            
            SELECT  mms.TransDateToSecond
			INTO 	lv_FromTime
			FROM	CTS_DataCenter.MatchMonitorStagingHedgingLive AS mms
			WHERE	mms.SequenceID <= ip_MaxSequenceID
				AND mms.TransDateToSecond >= lv_ToTime - lv_Rule_TimeStep
                AND mms.GroupID = 0 
			ORDER BY mms.TransDateToSecond ASC
			LIMIT 1;  
            
		END WHILE;
        
		IF lv_LastTransID > 0 THEN	
			UPDATE 	CTS_DataCenter.SystemParameter AS sys
			SET 	sys.ParameterValue = ip_MaxSequenceID
			WHERE 	sys.ParameterID = 120;
		END IF;        
	END IF;
    
IF (ip_LiveIndicator = 0) THEN     
    
		SELECT 	MAX(mms.TransDateToSecond), MAX(mms.TransID)
		INTO 	lv_ToTime, lv_LastTransID
		FROM	CTS_DataCenter.MatchMonitorStagingHedgingNonLive AS mms
        WHERE	mms.SequenceID <= ip_MaxSequenceID;      
		
        SELECT  mms.TransDateToSecond
        INTO 	lv_FromTime
		FROM	CTS_DataCenter.MatchMonitorStagingHedgingNonLive AS mms
        WHERE	mms.SequenceID <= ip_MaxSequenceID
			AND mms.TransDateToSecond >= lv_ToTime - lv_Rule_TimeStep
		ORDER BY mms.TransDateToSecond ASC
        LIMIT 1;  
		
		INSERT INTO Temp_LastGroupIDGroup(MatchID, ScoreDiff, BettypeID, BetID, Betteam, GroupID)
		SELECT 	DISTINCT mms.MatchID,  mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, mms.GroupID
		FROM 	CTS_DataCenter.MatchMonitorStagingHedgingNonLive mms
		WHERE	mms.SequenceID <= ip_MaxSequenceID
			AND mms.GroupID <> 0
			AND	mms.TransDateToSecond BETWEEN lv_FromTime AND lv_ToTime; 
        
		#=====Remove GroupID > 0 AND NOT IN Last Step Time Group===================
		DELETE mms
		FROM CTS_DataCenter.MatchMonitorStagingHedgingNonLive AS mms            
			LEFT JOIN Temp_LastGroupIDGroup AS tmpTg ON mms.MatchID = tmpTg.MatchID AND mms.ScoreDiff = tmpTg.ScoreDiff AND mms.BettypeID = tmpTg.BettypeID
				AND mms.BetID = tmpTg.BetID AND mms.Betteam = tmpTg.Betteam AND mms.GroupID = tmpTg.GroupID
		WHERE	mms.SequenceID <= ip_MaxSequenceID
			AND mms.GroupID > 0 
			AND mms.TransDateToSecond < lv_FromTime 
			AND tmpTg.GroupID IS NULL;
		
        #=====Remove GroupID > 0 AND NOT IN Last Step Time Group===================
        WHILE EXISTS (	SELECT 1 
						FROM CTS_DataCenter.MatchMonitorStagingHedgingNonLive AS mms 
						WHERE mms.SequenceID <= ip_MaxSequenceID
							AND mms.GroupID = 0 
                            AND mms.TransDateToSecond < lv_FromTime
                        LIMIT 1)
		DO	
            
			TRUNCATE TABLE Temp_LastCustIDGroup;
			INSERT INTO Temp_LastCustIDGroup(MatchID, ScoreDiff, BettypeID, BetID, Betteam, CustID)
			SELECT	DISTINCT mms.MatchID, mms.ScoreDiff, mms.BettypeID, mms.BetID, mms.Betteam, mms.CustID
			FROM 	CTS_DataCenter.MatchMonitorStagingHedgingNonLive AS mms
			WHERE	mms.SequenceID <= ip_MaxSequenceID
				AND mms.GroupID = 0
				AND	mms.TransDateToSecond BETWEEN lv_FromTime AND lv_ToTime;
       
            DELETE mms
			FROM CTS_DataCenter.MatchMonitorStagingHedgingNonLive AS mms            
				LEFT JOIN Temp_LastCustIDGroup AS tmpCus ON mms.MatchID = tmpCus.MatchID AND mms.ScoreDiff = tmpCus.ScoreDiff AND mms.BettypeID = tmpCus.BettypeID
							AND mms.BetID = tmpCus.BetID AND mms.Betteam = tmpCus.Betteam AND tmpCus.CustID = mms.CustID 
			WHERE	mms.SequenceID <= ip_MaxSequenceID
				AND mms.GroupID = 0 
				AND mms.TransDateToSecond < lv_FromTime 
				AND tmpCus.CustID IS NULL;    

            #===Get Previous Time Group===============    
			SELECT 	MAX(mms.TransDateToSecond)
			INTO 	lv_ToTime
			FROM	CTS_DataCenter.MatchMonitorStagingHedgingNonLive AS mms
			WHERE	mms.SequenceID <= ip_MaxSequenceID
				AND mms.TransDateToSecond < lv_FromTime
				AND mms.GroupID = 0; 
            
            SELECT  mms.TransDateToSecond
			INTO 	lv_FromTime
			FROM	CTS_DataCenter.MatchMonitorStagingHedgingNonLive AS mms
			WHERE	mms.SequenceID <= ip_MaxSequenceID
				AND mms.TransDateToSecond >= lv_ToTime - lv_Rule_TimeStep
                AND mms.GroupID = 0 
			ORDER BY mms.TransDateToSecond ASC
			LIMIT 1;  
            
		END WHILE;
        
        
		IF lv_LastTransID > 0 THEN
        
			UPDATE 	CTS_DataCenter.SystemParameter AS sys
			SET 	sys.ParameterValue = ip_MaxSequenceID
			WHERE 	sys.ParameterID = 121;
            
		END IF;
		
	END IF;
    
END$$
DELIMITER ;
