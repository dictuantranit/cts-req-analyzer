/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_RuleArbitrage_Process`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_RuleArbitrage_Process`(
		IN ip_LiveIndicator		BOOLEAN
	,	IN ip_MatchID			INT UNSIGNED
    ,	IN ip_IsMajorLeague 	BOOLEAN
    ,	IN ip_ScoreDiff			INT 
    ,	IN ip_BettypeID			INT UNSIGNED
    ,	IN ip_BetID				BIGINT
    ,	IN ip_HDP				DECIMAL(8,4)   
    ,	IN ip_SequenceIDList	LONGTEXT	# SequenceID List from SP CTS_DC_MatchMonitor_RuleArbitrage_Get
    ,	IN ip_CustGroup			JSON 		# Group Return from DC_Association_DetectGroup    
)
      
    SQL SECURITY INVOKER
sp: BEGIN
	/*
    
		Created:	202212216@Casey.Huynh
		Task :		Match Monitor Arbitrage Rule
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	202212216@Casey.Huynh: 	Created [Redmine ID: 179502]
			- 	20230109@Casey.Huynh: 	SumStake by CustID [Redmine ID: 182639]
			- 	20230111@Casey.Huynh: 	SumStake by CustID not group by Betteam [Redmine ID: 182639]
			-	20230310@Victoria.Le:	Credit Scale Out - Split 789y Site [Redmine ID: #183140]
			-	20230612@Casey.Huynh: 	LogInfo [Redmine ID: #185793]
            -	20230807@Casey.Huynh: 	Renovate Arbitrage [Redmine ID: #185791]
            -	20230821@Casey.Huynh: 	Fix Issue GroupID (Temp_ResultGroup.Primary) [Redmine ID: #192973]
            - 	20240417@Casey.Huynh: 	Renovate Arbitrage Rule [Redmine ID: #203319]
            
		Param's Explanation (filtered by):	
		Example:
		CALL CTS_DC_MatchMonitor_RuleArbitrage_Process(
		 @ip_LiveIndicator:=0
		,@ip_MatchID:=83540268
		,@SportType:=1
		,@ip_ScoreDiff:=0
		,@ip_BettypeID:=1
		,@ip_BetID:=0
		,@ip_Betteam:='h'
		,@ip_SequenceIDList:='119780925578,119780925587,119780925590,119780925602,119780925608,119780925617,119780925620,119780925626,119780925638,119780925659,119780925665,119780925677,119780925680,119780925689,119780925692,119780925695,119780925704,119780925713,119780925719,119780925725,119780925728,119780925734,119780925752,119780925758,119780925770'
		,@ip_CustGroup:='[	{"CustID":2707638,"GroupID":1}
						,	{"CustID":3945374,"GroupID":1}
						,	{"CustID":12362695,"GroupID":2}
						,	{"CustID":12362735,"GroupID":2}]'
			);
						
	*/
	
	DECLARE CONST_LOG 							TINYINT DEFAULT 0;
    DECLARE CONST_MMRULEGROUP_ARBITRAGE			INT DEFAULT 5;
	DECLARE CONST_SUBSCRIBERID_ALPHA	INT 	DEFAULT  	168;
	DECLARE CONST_SUBSCRIBERID_MAXBET	INT 	DEFAULT  	169;
	
	DECLARE lv_RuleTimeStep 				SMALLINT;
	DECLARE lv_RuleCustStake 				DECIMAL(20,4);
	DECLARE lv_CustIDList 					LONGTEXT;
	DECLARE lv_GroupID 						INT; 

    #==================LOG=======================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_RuleArbitrage_Process';
    IF CONST_LOG = 1 THEN     
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, CURRENT_TIMESTAMP(), CONCAT('@ip_LiveIndicator:=',ip_LiveIndicator,',@ip_MatchID:=',ip_MatchID
		,',@ip_ScoreDiff:=',ip_ScoreDiff,',@ip_BettypeID:=',ip_BettypeID,',@ip_BetID:=',ip_BetID,',@ip_HDP:=',ip_HDP);
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
        ,	SubscriberID	BIGINT
        ,	Stake			DECIMAL(20,4)
        ,	OldGroupID		INT
        ,	TimeGroupID		INT
        ,	Betteam			VARCHAR(10)
        
        ,	PRIMARY KEY PK_Temp_Trans_GroupID_OrderNum(GroupID, OrderNum)
        ,	INDEX IX_Temp_Trans_TimeGroupID(TimeGroupID)
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans2;
    CREATE TEMPORARY TABLE Temp_Trans2(
			GroupID			INT
		,	OrderNum		INT
        ,	TransDateToSecond BIGINT
        
        ,	PRIMARY KEY PK_Temp_Trans_GroupID_OrderNum(GroupID, OrderNum)
    );
       
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE Temp_Cust (
		 	CustID 	BIGINT UNSIGNED PRIMARY KEY
	); 
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Group;
	CREATE TEMPORARY TABLE Temp_Group(
			GroupID 			INT
		,	TimeGroupID			BIGINT PRIMARY KEY
		,	TransIDList			LONGTEXT
        ,	OldGroupIDList		VARCHAR(500)
		,	CustIDList			LONGTEXT
		,	CTSCustIDList		LONGTEXT        
		,	AgentDetect_CTSCustIDList LONGTEXT
		,	SequenceIDList		LONGTEXT
        ,	IsValidGroup		BOOLEAN
        
	);
    #=======================================================================
	SELECT 	st.CustStake, st.TimeStep
	INTO 	lv_RuleCustStake, lv_RuleTimeStep
	FROM	CTS_DataCenter.MatchMonitorRuleSetting AS st 
	WHERE 	st.RuleGroupID = CONST_MMRULEGROUP_ARBITRAGE
			AND (st.LeagueType = ip_IsMajorLeague OR st.LeagueType = 2)
            AND st.RuleStatus = 1
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
    
    IF (ip_LiveIndicator = 0) THEN
  
		INSERT INTO Temp_Trans(GroupID, OrderNum ,SequenceID,TransDateToSecond,TransID,CustID,CTSCustID, Stake, OldGroupID,Betteam)
        SELECT	tmpCg.GroupID
			,	ROW_NUMBER() OVER (PARTITION BY tmpCg.GroupID ORDER BY SequenceID ) AS OrderNum			
			,	mms.SequenceID
			,	mms.TransDateToSecond
			,	mms.TransID
			,	mms.CustID
			,	mms.CTSCustID
			,	mms.Stake
            ,	mms.GroupID
            ,	mms.Betteam
        FROM	CTS_DataCenter.MatchMonitorStagingArbitrageNonLive AS mms
			INNER JOIN Temp_SequenceID AS tmpSq ON tmpSq.SequenceID = mms.SequenceID
			INNER JOIN Temp_CustGroup AS tmpCg ON tmpCg.CustID = mms.CustID;
            
		INSERT INTO Temp_Trans2(GroupID, OrderNum, TransDateToSecond)
		SELECT tmpTs.GroupID
			,	tmpTs.OrderNum
            ,	tmpTs.TransDateToSecond
		FROM Temp_Trans AS tmpTs;

        SET @n=0;
        
        UPDATE Temp_Trans AS t
			LEFT JOIN Temp_Trans2 AS t2 ON t.GroupID = t2.GroupID AND t.OrderNum = t2.OrderNum + 1 AND t.TransDateToSecond - t2.TransDateToSecond <= 180
		SET t.TimeGroupID = (CASE WHEN t2.OrderNum IS NOT NULL THEN @n ELSE @n:=@n+1  END);
        
        INSERT INTO Temp_Group(GroupID, TimeGroupID, TransIDList, OldGroupIDList, CustIDList, CTSCustIDList, AgentDetect_CTSCustIDList, SequenceIDList, IsValidGroup)        
        SELECT	MIN(tmp.GroupID) AS GroupID
			,	tmp.TimeGroupID
            ,	GROUP_CONCAT(tmp.TransID ORDER BY tmp.TransID) AS TransIDList
			,	GROUP_CONCAT(DISTINCT tmp.OldGroupID) AS OldGroupIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CustID) AS CustIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CTSCustID) AS CTSCustIDList
            ,	CASE WHEN COUNT(DISTINCT CASE WHEN tmp.SubscriberID IN (CONST_SUBSCRIBERID_ALPHA,CONST_SUBSCRIBERID_MAXBET) THEN tmp.CTSCustID ELSE NULL END) > 1 
												THEN GROUP_CONCAT(DISTINCT CASE WHEN tmp.SubscriberID IN (CONST_SUBSCRIBERID_ALPHA,CONST_SUBSCRIBERID_MAXBET) THEN tmp.CTSCustID ELSE NULL END)
								ELSE NULL END AS AgentDetect_CTSCustIDList
			,	GROUP_CONCAT(tmp.SequenceID) AS SequenceIDList
            ,	(CASE WHEN COUNT(DISTINCT CustID) > 1 AND COUNT(DISTINCT tmp.Betteam) > 1 THEN 1 ELSE 0 END) AS IsValidGroup
        FROM Temp_Trans AS tmp
        GROUP BY TimeGroupID;
    END IF;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Completed;
	CREATE TEMPORARY TABLE Temp_Completed(GroupID INT PRIMARY KEY);
	
	INSERT INTO Temp_Completed(GroupID)
	SELECT tmpGp.GroupID
	FROM Temp_Group AS tmpGp
	GROUP BY tmpGp.GroupID
	HAVING COUNT(DISTINCT tmpGp.TimeGroupID) = 1 AND MAX(IsValidGroup) = 1;

	SELECT	tmpGr.GroupID	
        ,	tmpGr.CustIDList
        ,	tmpGr.TransIDList
    FROM Temp_Group AS tmpGr
		INNER JOIN Temp_Completed AS tmpCp ON tmpGr.GroupID = tmpCp.GroupID
    WHERE tmpCp.GroupID IS NOT NULL AND tmpGr.IsValidGroup = 1;
	
  
    
	SELECT	GROUP_CONCAT(tmp.CTSCustID) AS CTSCustIDList
		,	(CASE WHEN COUNT(DISTINCT Agent_CTSCustID ) > 1 THEN GROUP_CONCAT(DISTINCT Agent_CTSCustID) ELSE NULL END) AS AgentDetect_CTSCustIDList
		,	GROUP_CONCAT(tmp.SequenceIDList) AS SequenceIDList
	FROM (	SELECT	tmpGr.TimeGroupID
				,	mms.CTSCustID
				,	(CASE WHEN mms.SubscriberID IN (CONST_SUBSCRIBERID_ALPHA,CONST_SUBSCRIBERID_MAXBET) THEN mms.CTSCustID ELSE NULL END) AS Agent_CTSCustID
				,	GROUP_CONCAT(mms.SequenceID) AS SequenceIDList
				, 	MIN(Betteam) AS MinBetteam
				,	MAX(Betteam) AS MaxBetteam
			FROM Temp_Group AS tmpGr
			JOIN JSON_TABLE(REPLACE(JSON_ARRAY(tmpGr.SequenceIDList), ',', '","'), 
							'$[*]' COLUMNS (SequenceID BIGINT UNSIGNED PATH '$')
							) js
			INNER JOIN CTS_DataCenter.MatchMonitorStagingArbitrageNonLive AS mms ON js.SequenceID = mms.SequenceID	
			LEFT JOIN Temp_Completed AS tmpCp ON tmpGr.GroupID = tmpCp.GroupID
			WHERE tmpCp.GroupID IS NULL AND tmpGr.IsValidGroup = 1
			GROUP BY tmpGr.TimeGroupID, mms.CTSCustID, mms.SubscriberID
			HAVING SUM(mms.Stake) >= lv_RuleCustStake
		  ) AS tmp
	GROUP BY tmp.TimeGroupID
	HAVING COUNT(DISTINCT CTSCustID) > 1 AND Min(MinBetteam) <> MAX(MaxBetteam);    
    
END$$
DELIMITER ;