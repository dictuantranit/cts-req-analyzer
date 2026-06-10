/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_RuleHedging_Process`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_RuleHedging_Process`(
		IN ip_LiveIndicator		BOOLEAN
	,	IN ip_MatchID			INT UNSIGNED
    ,	IN ip_ScoreDiff			INT 
    ,	IN ip_BettypeID			INT UNSIGNED
    ,	IN ip_BetID				BIGINT
    ,	IN ip_Betteam			VARCHAR(10)
    ,	IN ip_SportType			INT
    ,	IN ip_SequenceIDList	LONGTEXT		# SequenceID List from SP CTS_DC_MatchMonitor_RuleHedging_Get
    ,	IN ip_CustGroup			JSON 		# Group Return from DC_Association_DetectGroup    
)
      
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20210526@Casey.Huynh
		Task :		Match Monitor Rule Soccer - Hedging Process
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20210526@Casey.Huynh: 	Created [Redmine ID: 152883]
			-	20221021@Casey.Huynh: 	Fixed Clean Data Staging [Redmine ID: #179427]
			- 	202201021@Casey.Huynh: 	Group By Betteam [Redmine ID: #179439]
			-   20221107@Aries.Nguyen: 	Tuning performance of Hedging Detection  [Redmine ID: #180185]
			-	20221205@Casey.Huynh: 	Rename Table [Redmine ID: #179502]
			-	20230310@Victoria.Le:	Credit Scale Out - Split 789y Site [Redmine ID: #183140]
            -	20230612@Casey.Huynh: 	LogInfo [Redmine ID: #185793]
            -	20240109@Casey.Huynh:	Enhance Hedging Rule [Redmine ID: #192172]
            -	20240223@Casey.Huynh:	Fix Issue Return [Redmine ID: #201271]
            -	20240509@Casey.Huynh: 	HF Hedging StepTime [Redmine ID: #204338]
            -	20240617@Casey.Huynh:	Update Data Type [Redmine ID: #206564]
            -	20240724@Casey.Huynh:	Enhance Rule [Redmine ID: #207523]
	    - 	20240703@Victoria.Le	Renovate CC Phase2 [Redmine ID: #205317]
			
		Param's Explanation (filtered by):	
		Example:
			- CALL CTS_DC_MatchMonitor_RuleHedging_Process(@ip_LiveIndicator:=1,@ip_MaxSequenceID:=113171940189,@ip_MatchID:=22081995,@ip_ScoreDiff:=1,@ip_BettypeID:=1,@ip_BetID:=0,@ip_Betteam:='a');
			
	*/
	DECLARE CONST_LOG 					TINYINT DEFAULT 0;
	DECLARE CONST_SUBSCRIBERID_ALPHA	INT DEFAULT 168;
	DECLARE CONST_SUBSCRIBERID_MAXBET	INT DEFAULT 169;
    DECLARE CONST_MMRULEGROUP_HEDGING	INT DEFAULT 3;
    DECLARE CONST_MMREASON_HEDGING		INT DEFAULT 1;
	DECLARE CONST_PARENTID_PA 			INT;

	DECLARE lv_RuleTimeStep 				SMALLINT;
	DECLARE lv_RuleTotalStake 			DECIMAL(20,4);
	DECLARE lv_CustIDList 				LONGTEXT;
	DECLARE lv_IsHedging 				BOOLEAN;
	DECLARE lv_GroupID 					INT; 
	
	SET CONST_PARENTID_PA 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');

    #==================LOG=======================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_RuleHedging_Process';
    IF CONST_LOG = 1 THEN     
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, CURRENT_TIMESTAMP(), CONCAT('@ip_LiveIndicator:=',ip_LiveIndicator,',@ip_MatchID:=',ip_MatchID
		,',@ip_ScoreDiff:=',ip_ScoreDiff,',@ip_BettypeID:=',ip_BettypeID,',@ip_BetID:=',ip_Betteam,',@ip_HDP:=',ip_Betteam);
    END IF;
    
    #==================LOG=======================================================   
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans;
    CREATE TEMPORARY TABLE Temp_Trans(
			GroupID			INT
		,	OrderNum		INT
        ,	SequenceID		BIGINT
        ,	TransDateToSecond BIGINT
        ,	TransID			BIGINT
        ,	CustID			BIGINT
        ,	CTSCustID		BIGINT
        ,	SubscriberID	INT
        ,	Stake			DECIMAL(20,4)
		,	IsHedging		BOOLEAN
        ,	OldGroupID		INT
        ,	TimeGroupID		INT
		
        ,	PRIMARY KEY PK_Temp_Trans_GroupID_OrderNum(GroupID, OrderNum)
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans2;
    CREATE TEMPORARY TABLE Temp_Trans2(
			GroupID			INT
		,	OrderNum		INT
        ,	SequenceID		BIGINT
        ,	TransDateToSecond BIGINT
        ,	TransID			BIGINT
        ,	CustID			BIGINT
        ,	CTSCustID		BIGINT
        ,	SubscriberID	INT
        ,	Stake			DECIMAL(20,4)
		,	IsHedging		BOOLEAN
        ,	OldGroupID		INT
        
        ,	PRIMARY KEY PK_Temp_Trans_GroupID_OrderNum(GroupID, OrderNum)
    );

    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE 		Temp_Cust (
		 	CustID 	BIGINT UNSIGNED PRIMARY KEY
	); 
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Group;
	CREATE TEMPORARY TABLE Temp_Group(
			GroupID 		INT
		,	TimeGroupID		BIGINT PRIMARY KEY
		,	TransIDList		LONGTEXT
        ,	OldGroupIDList	VARCHAR(500)
		,	CustIDList		LONGTEXT
		,	CTSCustIDList	LONGTEXT
        ,	IsHedging		BOOLEAN
		,	AgentDetect_CTSCustIDList LONGTEXT
		,	SequenceIDList	LONGTEXT
        ,	IsValidGroup	BOOLEAN
	);
    #=======================================================================
	SELECT 	st.TotalStake, st.TimeStep
	INTO 	lv_RuleTotalStake, lv_RuleTimeStep
	FROM CTS_DataCenter.MatchMonitorRuleSetting AS st 
	WHERE 	st.RuleGroupID = CONST_MMRULEGROUP_HEDGING AND st.SportType = ip_SportType 
			AND st.Reason = CONST_MMREASON_HEDGING AND st.RuleStatus = 1
	LIMIT 1;

    DROP TEMPORARY TABLE IF EXISTS Temp_CustGroup;
    CREATE TEMPORARY TABLE Temp_CustGroup(
			CustID		BIGINT
        ,	GroupID		INT
	);
    
    INSERT INTO Temp_CustGroup(CustID, GroupID)
    SELECT  js.CustID
		,	js.GroupID
	FROM JSON_TABLE(ip_CustGroup,
					 "$[*]" COLUMNS(
								CustID		BIGINT UNSIGNED PATH "$.CustID" 	
							,	GroupID		INT PATH "$.GroupID"
						)
					) AS js;  
    
	DROP TEMPORARY TABLE IF EXISTS Temp_SequenceID;
    CREATE TEMPORARY TABLE Temp_SequenceID (
			SequenceID	BIGINT UNSIGNED PRIMARY KEY
    );
    
	SET @sql = CONCAT("INSERT INTO Temp_SequenceID (SequenceID) VALUES ('", REPLACE(ip_SequenceIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    IF (ip_LiveIndicator = 1) THEN
    
		INSERT INTO Temp_Trans(GroupID, OrderNum ,SequenceID,TransDateToSecond,TransID,CustID,CTSCustID, SubscriberID, Stake,IsHedging, OldGroupID)
        SELECT	tmpCg.GroupID
			,	ROW_NUMBER() OVER (PARTITION BY tmpCg.GroupID ORDER BY SequenceID ) AS OrderNum			
			,	mms.SequenceID
			,	mms.TransDateToSecond
			,	mms.TransID
			,	mms.CustID
			,	mms.CTSCustID
            ,	mms.SubscriberID
			,	mms.Stake
			,	mms.IsHedging
            ,	mms.GroupID
        FROM	CTS_DataCenter.MatchMonitorStagingHedgingLive AS mms
			INNER JOIN Temp_SequenceID AS tmpSq ON tmpSq.SequenceID = mms.SequenceID
			INNER JOIN Temp_CustGroup AS tmpCg ON tmpCg.CustID = mms.CustID;
            
		INSERT INTO Temp_Trans2(GroupID, OrderNum, TransDateToSecond)
		SELECT tmpTs.GroupID
			,	tmpTs.OrderNum
            ,	tmpTs.SequenceID
            ,	tmpTs.TransDateToSecond
            ,	tmpTs.TransID
            ,	tmpTs.CustID
            ,	tmpTs.CTSCustID
            ,	tmpTs.SubscriberID
            ,	tmpTs.Stake
            ,	tmpTs.IsHedging
            ,	tmpTs.OldGroupID
		FROM Temp_Trans AS tmpTs;

        SET @n=0;
        UPDATE Temp_Trans AS t
			LEFT JOIN Temp_Trans2 AS t2 ON t.GroupID = t2.GroupID AND t.OrderNum = t2.OrderNum  +1 AND t.TransDateToSecond - t2.TransDateToSecond <= 180
		SET t.TimeGroupID = (CASE WHEN t2.OrderNum IS NOT NULL THEN @n ELSE @n:=@n+1  END);
		
        INSERT INTO Temp_Group(GroupID, TimeGroupID, IsHedging, TransIDList, OldGroupIDList, CustIDList
								, CTSCustIDList, AgentDetect_CTSCustIDList, SequenceIDList, IsValidGroup)        
        SELECT	MIN(tmp.GroupID) AS GroupID
			,	tmp.TimeGroupID
            ,	MAX(tmp.IsHedging) AS IsHedging
            ,	GROUP_CONCAT(tmp.TransID ORDER BY tmp.TransID) AS TransIDList
			,	GROUP_CONCAT(DISTINCT tmp.OldGroupID) AS OldGroupIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CustID) AS CustIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CTSCustID) AS CTSCustIDList
			,	CASE WHEN COUNT(DISTINCT CASE WHEN tmp.SubscriberID IN (CONST_SUBSCRIBERID_ALPHA,CONST_SUBSCRIBERID_MAXBET) THEN tmp.CTSCustID ELSE NULL END) > 1 
												THEN GROUP_CONCAT(DISTINCT CASE WHEN tmp.SubscriberID IN (CONST_SUBSCRIBERID_ALPHA,CONST_SUBSCRIBERID_MAXBET) THEN tmp.CTSCustID ELSE NULL END)
								ELSE NULL END AS AgentDetect_CTSCustIDList
			,	GROUP_CONCAT(tmp.SequenceID)
            ,	(CASE WHEN COUNT(DISTINCT CustID) > 1 AND SUM(Stake) >= lv_RuleTotalStake THEN 1 ELSE 0 END) AS IsValidGroup
        FROM Temp_Trans AS tmp
        GROUP BY TimeGroupID;

	ELSE #(ip_LiveIndicator = 0)
		
		INSERT INTO Temp_Trans(GroupID, OrderNum ,SequenceID,TransDateToSecond,TransID,CustID,CTSCustID, SubscriberID, Stake,IsHedging, OldGroupID)
        SELECT	tmpCg.GroupID
			,	ROW_NUMBER() OVER (PARTITION BY tmpCg.GroupID ORDER BY SequenceID ) AS OrderNum			
			,	mms.SequenceID
			,	mms.TransDateToSecond
			,	mms.TransID
			,	mms.CustID
			,	mms.CTSCustID
            ,	mms.SubscriberID
			,	mms.Stake
			,	mms.IsHedging
            ,	mms.GroupID
        FROM	CTS_DataCenter.MatchMonitorStagingHedgingNonLive AS mms
			INNER JOIN Temp_SequenceID AS tmpSq ON tmpSq.SequenceID = mms.SequenceID
			INNER JOIN Temp_CustGroup AS tmpCg ON tmpCg.CustID = mms.CustID;
            
		INSERT INTO Temp_Trans2(GroupID, OrderNum, SequenceID,TransDateToSecond,TransID,CustID,CTSCustID,SubscriberID,Stake,IsHedging,OldGroupID)
		SELECT tmpTs.GroupID
			,	tmpTs.OrderNum
            ,	tmpTs.SequenceID
            ,	tmpTs.TransDateToSecond
            ,	tmpTs.TransID
            ,	tmpTs.CustID
            ,	tmpTs.CTSCustID
            ,	tmpTs.SubscriberID
            ,	tmpTs.Stake
            ,	tmpTs.IsHedging
            ,	tmpTs.OldGroupID
		FROM Temp_Trans AS tmpTs;

        SET @n=0;
        
        UPDATE Temp_Trans AS t
			LEFT JOIN Temp_Trans2 AS t2 ON t.GroupID = t2.GroupID AND t.OrderNum = t2.OrderNum  +1 AND t.TransDateToSecond - t2.TransDateToSecond <= 180
		SET t.TimeGroupID = (CASE WHEN t2.OrderNum IS NOT NULL THEN @n ELSE @n:=@n+1  END);
		
        INSERT INTO Temp_Group(GroupID, TimeGroupID, IsHedging, TransIDList, OldGroupIDList, CustIDList
								, CTSCustIDList, AgentDetect_CTSCustIDList, SequenceIDList, IsValidGroup)        
        SELECT	MIN(tmp.GroupID) AS GroupID
			,	tmp.TimeGroupID
            ,	MAX(tmp.IsHedging) AS IsHedging
            ,	GROUP_CONCAT(tmp.TransID ORDER BY tmp.TransID) AS TransIDList
			,	GROUP_CONCAT(DISTINCT tmp.OldGroupID) AS OldGroupIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CustID) AS CustIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CTSCustID) AS CTSCustIDList
			,	CASE WHEN COUNT(DISTINCT CASE WHEN tmp.SubscriberID IN (CONST_SUBSCRIBERID_ALPHA,CONST_SUBSCRIBERID_MAXBET) THEN tmp.CTSCustID ELSE NULL END) > 1 
												THEN GROUP_CONCAT(DISTINCT CASE WHEN tmp.SubscriberID IN (CONST_SUBSCRIBERID_ALPHA,CONST_SUBSCRIBERID_MAXBET) THEN tmp.CTSCustID ELSE NULL END)
								ELSE NULL END AS AgentDetect_CTSCustIDList
			,	GROUP_CONCAT(tmp.SequenceID)
            ,	(CASE WHEN COUNT(DISTINCT CustID) > 1 AND SUM(Stake) >= lv_RuleTotalStake THEN 1 ELSE 0 END) AS IsValidGroup
        FROM Temp_Trans AS tmp
        GROUP BY TimeGroupID;
    END IF;
    #===============CHECK Is Hedging Group====================
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Completed;
	CREATE TEMPORARY TABLE Temp_Completed(GroupID INT PRIMARY KEY, IsHedging BOOLEAN);
	
	INSERT INTO Temp_Completed(GroupID, IsHedging)
	SELECT tmpGp.GroupID
		, MAX(tmpGp.IsHedging) AS IsHedging
	FROM Temp_Group AS tmpGp
	GROUP BY tmpGp.GroupID
	HAVING COUNT(DISTINCT tmpGp.TimeGroupID) = 1 AND MAX(IsValidGroup) = 1;

    SET lv_GroupID = 0;
    SET lv_GroupID = (	SELECT tmp.GroupID
						FROM Temp_Completed AS tmp
						WHERE tmp.IsHedging = 0 AND tmp.GroupID > lv_GroupID 
						ORDER BY tmp.GroupID
						LIMIT 1);    

    WHILE lv_GroupID IS NOT NULL DO    
    
		TRUNCATE TABLE Temp_Cust;
        
        SET lv_IsHedging = 0;
        
		SELECT tmpRg.CustIDList
		INTO lv_CustIDList
		FROM Temp_Group AS tmpRg
		WHERE tmpRg.GroupID = lv_GroupID;
		
        SET @sql = CONCAT("INSERT IGNORE INTO Temp_Cust(CustID) VALUES ('", REPLACE(lv_CustIDList, ",", "'),('"),"');");
		PREPARE stmt1 FROM @sql;
		EXECUTE stmt1;

		SELECT 1 
		INTO lv_IsHedging
		FROM Temp_Cust AS tmpCus 
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cla ON cla.CustID = tmpCus.CustID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
		WHERE cla.ParentID = CONST_PARENTID_PA
		AND cc.IsHedgingReasonMM = 1
		LIMIT 1;
   
        IF lv_IsHedging <> 1 THEN
			CALL CTS_DataCenter.CTS_DC_Association_IsAssociatedHedgingCustByCustIDList(lv_CustIDList, lv_IsHedging);
        END IF;
        
        IF lv_IsHedging = 1 THEN    
			UPDATE Temp_Group AS tmpRg
			SET tmpRg.IsHedging = 1
            WHERE tmpRg.GroupID = lv_GroupID;            
        END IF;
        
		SET lv_GroupID = (	SELECT tmp.GroupID
							FROM Temp_Completed AS tmp
							WHERE tmp.IsHedging = 0 AND tmp.GroupID > lv_GroupID 
							ORDER BY tmp.GroupID
							LIMIT 1);   
    END WHILE;
    
	SELECT	tmpGr.GroupID
		,	tmpGr.IsHedging
		,	tmpGr.OldGroupIDList		
        ,	tmpGr.CustIDList
        ,	tmpGr.TransIDList        
    FROM Temp_Group AS tmpGr
		INNER JOIN Temp_Completed AS tmpCp ON tmpGr.GroupID = tmpCp.GroupID
    WHERE tmpGr.IsHedging = 1 AND tmpGr.IsValidGroup = 1;

    SELECT	tmpGr.CTSCustIDList
		,	tmpGr.AgentDetect_CTSCustIDList
        ,	tmpGr.SequenceIDList
    FROM Temp_Group AS tmpGr
		LEFT JOIN Temp_Completed AS tmpCp ON tmpGr.GroupID = tmpCp.GroupID
	WHERE tmpCp.GroupID IS NULL AND tmpGr.IsValidGroup = 1;

END$$
DELIMITER ;
