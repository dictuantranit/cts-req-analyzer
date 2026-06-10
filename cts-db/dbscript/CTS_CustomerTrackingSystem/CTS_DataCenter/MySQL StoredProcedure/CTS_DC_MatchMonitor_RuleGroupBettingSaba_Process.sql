/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitor_RuleGroupBettingSaba_Process`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitor_RuleGroupBettingSaba_Process`(
		IN ip_LiveIndicator		BOOLEAN
	,	IN ip_MatchID			INT UNSIGNED
    ,	IN ip_SportType			INT
    ,	IN ip_ScoreDiff			INT 
    ,	IN ip_BettypeID			INT UNSIGNED
    ,	IN ip_BetID				BIGINT
    ,	IN ip_Betteam			VARCHAR(10)
    ,	IN ip_SequenceIDList	LONGTEXT	# SequenceID List from SP CTS_DC_MatchMonitor_RuleGroupBettingSaba_Process
    ,	IN ip_CustGroup			JSON 		# Group Return from DC_Association_DetectGroup    
)
      
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20240603@Casey.Huynh
		Task :		Match Monitor - Group Betting Saba - Process
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20240603@Casey.Huynh: Created [Redmine ID: #191972]
            - 20240704@Casey.Huynh: Saba Group Betting - Add Basketball and enhance Soccer [Redmine ID: #207523]
			- 20250717@Logan.Nguyen: Saba Group Betting - Classify Saba Soccer Group Betting into CC3101-3201 [Redmine ID: #227848]
            
		Param's Explanation (filtered by):
			
		Example:
			CALL CTS_DC_MatchMonitor_RuleGroupBettingSaba_Process(
            @ip_LiveIndicator:=1
            ,@ip_MatchID:=22081995
            ,@ip_ScoreDiff:=1
            ,@ip_BettypeID:=1
            ,@ip_BetID:=0
            ,@ip_Betteam:='a'
            ,@ip_SequenceIDList:='1,2'
            ,@ip_CustGroup:='[{"CustID":1,"GroupID":1},{"CustID":2,"GroupID":1}]');
						
	*/
	
	DECLARE CONST_LOG 							TINYINT DEFAULT 0;
    DECLARE CONST_MMRULEGROUP_GROUPBETTINGSABA	INT DEFAULT 6;
	DECLARE CONST_CLASSIFYTOTALSTAKE_SOCCERSABA	DECIMAL(20,4) DEFAULT 150;
	DECLARE CONST_CLASSIFYTOTALCUSTSABA			INT DEFAULT 3;
    DECLARE CONST_MMREASON_GROUPBETTINGSABA		INT DEFAULT 0;
	DECLARE CONST_SPORTTYPE_SOCCER				INT DEFAULT 1;
	DECLARE lv_RuleTimeStep 					SMALLINT;
    DECLARE lv_RuleCustStake 					DECIMAL(20,4);
	DECLARE lv_RuleTotalStake 					DECIMAL(20,4);
	DECLARE lv_CustIDList 						LONGTEXT;
	DECLARE lv_GroupID 							INT; 

    #==================LOG=======================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitor_RuleGroupBettingSaba_Process';
    IF CONST_LOG = 1 THEN     
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, CURRENT_TIMESTAMP(), CONCAT('@ip_LiveIndicator:=',ip_LiveIndicator,',@ip_MatchID:=',ip_MatchID
		,',@ip_ScoreDiff:=',ip_ScoreDiff,',@ip_BettypeID:=',ip_BettypeID,',@ip_BetID:=',ip_Betteam,',@ip_HDP:=',ip_Betteam);
    END IF;
    
    #==================LOG=======================================================   
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans;
    CREATE TEMPORARY TABLE Temp_Trans(
			GroupID				INT
		,	OrderNum			INT
        ,	SequenceID			BIGINT
        ,	TransDateToSecond	BIGINT
        ,	TransID				BIGINT
        ,	CustID				BIGINT
        ,	CTSCustID			BIGINT
        ,	Stake				DECIMAL(20,4)
        ,	OldGroupID			INT
        ,	TimeGroupID			INT
		,	IsLicensee			BOOLEAN
		
        ,	PRIMARY KEY PK_Temp_Trans_GroupID_OrderNum(GroupID, OrderNum)
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans2;
    CREATE TEMPORARY TABLE Temp_Trans2(
			GroupID				INT
		,	OrderNum			INT
        ,	TransDateToSecond	BIGINT
        
        ,	PRIMARY KEY PK_Temp_Trans_GroupID_OrderNum(GroupID, OrderNum)
    );
       
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE 		Temp_Cust (
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
		,	SequenceIDList		LONGTEXT
		,	LicCustList 		LONGTEXT
        ,	LicCustTotalStake	INT
		,	LicCustTotal		INT
        ,	IsValidGroup		BOOLEAN
	);
    #=======================================================================
	SELECT 	st.CustStake, st.TotalStake, st.TimeStep
	INTO 	lv_RuleCustStake, lv_RuleTotalStake, lv_RuleTimeStep
	FROM CTS_DataCenter.MatchMonitorRuleSetting AS st 
	WHERE 	st.RuleGroupID = CONST_MMRULEGROUP_GROUPBETTINGSABA
		AND st.RuleStatus = 1
        AND st.SportType = ip_SportType
	LIMIT 1;

    DROP TEMPORARY TABLE IF EXISTS Temp_CustGroup;
    CREATE TEMPORARY TABLE Temp_CustGroup(
			CustID		BIGINT PRIMARY KEY
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
    
		INSERT INTO Temp_Trans(GroupID, OrderNum ,SequenceID,TransDateToSecond,TransID,CustID,CTSCustID, Stake, OldGroupID, IsLicensee)
        SELECT	tmpCg.GroupID
			,	ROW_NUMBER() OVER (PARTITION BY tmpCg.GroupID ORDER BY SequenceID ) AS OrderNum			
			,	mms.SequenceID
			,	mms.TransDateToSecond
			,	mms.TransID
			,	mms.CustID
			,	mms.CTSCustID
			,	mms.Stake
            ,	mms.GroupID
			,	mms.IsLicensee
        FROM	CTS_DataCenter.MatchMonitorStagingGroupBettingSabaLive AS mms
			INNER JOIN Temp_SequenceID AS tmpSq ON tmpSq.SequenceID = mms.SequenceID
			INNER JOIN Temp_CustGroup AS tmpCg ON tmpCg.CustID = mms.CustID;
            
		INSERT INTO Temp_Trans2(GroupID, OrderNum, TransDateToSecond)
		SELECT	tmpTs.GroupID
			,	tmpTs.OrderNum
            ,	tmpTs.TransDateToSecond
		FROM Temp_Trans AS tmpTs;

        SET @n=0;
        UPDATE Temp_Trans AS t
			LEFT JOIN Temp_Trans2 AS t2 ON t.GroupID = t2.GroupID AND t.OrderNum = t2.OrderNum  +1 AND t.TransDateToSecond - t2.TransDateToSecond <= lv_RuleTimeStep
		SET t.TimeGroupID = (CASE WHEN t2.OrderNum IS NOT NULL THEN @n ELSE @n:=@n+1  END);
		
        INSERT INTO Temp_Group(GroupID, TimeGroupID, TransIDList, OldGroupIDList, CustIDList, CTSCustIDList, SequenceIDList, LicCustList, LicCustTotalStake, LicCustTotal,IsValidGroup)        
        SELECT	MIN(tmp.GroupID) AS GroupID
			,	tmp.TimeGroupID
            ,	GROUP_CONCAT(tmp.TransID ORDER BY tmp.TransID) AS TransIDList
			,	GROUP_CONCAT(DISTINCT tmp.OldGroupID) AS OldGroupIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CustID) AS CustIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CTSCustID) AS CTSCustIDList
			,	GROUP_CONCAT(tmp.SequenceID)
			,	GROUP_CONCAT(DISTINCT (CASE WHEN tmp.IsLicensee = 1 THEN tmp.CustID ELSE NULL END)) AS LicCustList
			,	SUM((CASE WHEN tmp.IsLicensee = 1 THEN tmp.Stake ELSE 0 END)) AS LicCustTotalStake
			,	COUNT(DISTINCT (CASE WHEN tmp.IsLicensee = 1 THEN tmp.CustID ELSE NULL END)) AS LicCustTotal
            ,	(CASE WHEN COUNT(DISTINCT CustID) > 1 AND SUM(Stake) >= lv_RuleTotalStake THEN 1 ELSE 0 END) AS IsValidGroup
        FROM Temp_Trans AS tmp
        GROUP BY tmp.TimeGroupID;
        
        #===============CHECK IS THE COMPLETED GROUP====================   
		DROP TEMPORARY TABLE IF EXISTS Temp_Completed;
		CREATE TEMPORARY TABLE Temp_Completed(GroupID INT PRIMARY KEY);
		
		INSERT INTO Temp_Completed(GroupID)
		SELECT tmpGp.GroupID
		FROM Temp_Group AS tmpGp
		GROUP BY tmpGp.GroupID
		HAVING COUNT(DISTINCT tmpGp.TimeGroupID) = 1
			AND MAX(IsValidGroup) = 1;
        
		#=====================RETURN COMPLETE GROUP================================
		SELECT	tmpGr.GroupID	
			,	tmpGr.CustIDList
			,	tmpGr.TransIDList  
			,	(CASE WHEN (ip_SportType = CONST_SPORTTYPE_SOCCER AND tmpGr.LicCustTotalStake >= CONST_CLASSIFYTOTALSTAKE_SOCCERSABA) 
						AND tmpGr.LicCustTotal >= CONST_CLASSIFYTOTALCUSTSABA THEN tmpGr.LicCustList ELSE NULL END) AS HighStakeLicCustList      
		FROM Temp_Group AS tmpGr
			INNER JOIN Temp_Completed AS tmpCp ON tmpGr.GroupID = tmpCp.GroupID
		WHERE tmpCp.GroupID IS NOT NULL
			AND tmpGr.IsValidGroup = 1;
        
		#=====================RETURN NOT COMPLETE GROUP================================
		
		SELECT	GROUP_CONCAT(tmp.CustID) AS CustIDList
			,	GROUP_CONCAT(tmp.CTSCustID) AS CTSCustIDList
			,	GROUP_CONCAT(tmp.CustSequenceIDList) AS SequenceIDList
			,	tmp.LicCustList
		FROM (	SELECT	tmpGr.TimeGroupID
					,	mms.CustID
					,	mms.CTSCustID
                    ,	SUM(mms.Stake) AS CustStake
					,	GROUP_CONCAT(mms.SequenceID) AS CustSequenceIDList
					,	tmpGr.LicCustList
				FROM Temp_Group AS tmpGr
				JOIN JSON_TABLE(REPLACE(JSON_ARRAY(tmpGr.SequenceIDList), ',', '","'), 
								'$[*]' COLUMNS (SequenceID BIGINT UNSIGNED PATH '$')
								) js
				INNER JOIN CTS_DataCenter.MatchMonitorStagingGroupBettingSabaLive AS mms ON js.SequenceID = mms.SequenceID	
				LEFT JOIN Temp_Completed AS tmpCp ON tmpGr.GroupID = tmpCp.GroupID
				WHERE tmpCp.GroupID IS NULL
					AND tmpGr.IsValidGroup = 1
				GROUP BY tmpGr.TimeGroupID, mms.CustID, mms.CTSCustID
				HAVING SUM(mms.Stake) >= lv_RuleCustStake
			  ) AS tmp
		GROUP BY tmp.TimeGroupID
		HAVING COUNT(DISTINCT tmp.CTSCustID) > 1
			AND SUM(tmp.CustStake) >= lv_RuleTotalStake;
        
	ELSE #(ip_LiveIndicator = 0)
		
		INSERT INTO Temp_Trans(GroupID, OrderNum ,SequenceID,TransDateToSecond,TransID,CustID,CTSCustID, Stake, OldGroupID,IsLicensee)
        SELECT	tmpCg.GroupID
			,	ROW_NUMBER() OVER (PARTITION BY tmpCg.GroupID ORDER BY SequenceID ) AS OrderNum			
			,	mms.SequenceID
			,	mms.TransDateToSecond
			,	mms.TransID
			,	mms.CustID
			,	mms.CTSCustID
			,	mms.Stake
            ,	mms.GroupID
			,	mms.IsLicensee
        FROM	CTS_DataCenter.MatchMonitorStagingGroupBettingSabaNonLive AS mms
			INNER JOIN Temp_SequenceID AS tmpSq ON tmpSq.SequenceID = mms.SequenceID
			INNER JOIN Temp_CustGroup AS tmpCg ON tmpCg.CustID = mms.CustID;
            
		INSERT INTO Temp_Trans2(GroupID, OrderNum, TransDateToSecond)
		SELECT	tmpTs.GroupID
			,	tmpTs.OrderNum
            ,	tmpTs.TransDateToSecond
		FROM Temp_Trans AS tmpTs;

        SET @n=0;
        
        UPDATE Temp_Trans AS t
			LEFT JOIN Temp_Trans2 AS t2 ON t.GroupID = t2.GroupID AND t.OrderNum = t2.OrderNum + 1 AND t.TransDateToSecond - t2.TransDateToSecond <= lv_RuleTimeStep
		SET t.TimeGroupID = (CASE WHEN t2.OrderNum IS NOT NULL THEN @n ELSE @n:=@n+1  END);
		
        INSERT INTO Temp_Group(GroupID, TimeGroupID, TransIDList, OldGroupIDList, CustIDList, CTSCustIDList, SequenceIDList, LicCustList, LicCustTotalStake, LicCustTotal, IsValidGroup)        
        SELECT	MIN(tmp.GroupID) AS GroupID
			,	tmp.TimeGroupID
            ,	GROUP_CONCAT(tmp.TransID ORDER BY tmp.TransID) AS TransIDList
			,	GROUP_CONCAT(DISTINCT tmp.OldGroupID) AS OldGroupIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CustID) AS CustIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CTSCustID) AS CTSCustIDList
			,	GROUP_CONCAT(tmp.SequenceID)
			,	GROUP_CONCAT(DISTINCT (CASE WHEN tmp.IsLicensee = 1 THEN tmp.CustID ELSE NULL END)) AS LicCustList
			,	SUM((CASE WHEN tmp.IsLicensee = 1 THEN tmp.Stake ELSE 0 END)) AS LicCustTotalStake
			,	COUNT(DISTINCT (CASE WHEN tmp.IsLicensee = 1 THEN tmp.CustID ELSE NULL END)) AS LicCustTotal
            ,	(CASE WHEN COUNT(DISTINCT CustID) > 1 AND SUM(Stake) >= lv_RuleTotalStake THEN 1 ELSE 0 END) AS IsValidGroup
        FROM Temp_Trans AS tmp
        GROUP BY tmp.TimeGroupID;
        
        #===============CHECK IS THE COMPLETED GROUP====================    
		DROP TEMPORARY TABLE IF EXISTS Temp_Completed;
		CREATE TEMPORARY TABLE Temp_Completed(GroupID INT PRIMARY KEY);

		INSERT INTO Temp_Completed(GroupID)
		SELECT tmpGp.GroupID
		FROM Temp_Group AS tmpGp
		GROUP BY tmpGp.GroupID
		HAVING COUNT(DISTINCT tmpGp.TimeGroupID) = 1
			AND MAX(IsValidGroup) = 1;
        
		#=====================RETURN COMPLETE GROUP================================
		SELECT	tmpGr.GroupID	
			,	tmpGr.CustIDList
			,	tmpGr.TransIDList  
			,	(CASE WHEN (ip_SportType = CONST_SPORTTYPE_SOCCER AND tmpGr.LicCustTotalStake >= CONST_CLASSIFYTOTALSTAKE_SOCCERSABA) 
						AND tmpGr.LicCustTotal >= CONST_CLASSIFYTOTALCUSTSABA THEN tmpGr.LicCustList ELSE NULL END) AS HighStakeLicCustList      
		FROM Temp_Group AS tmpGr
			INNER JOIN Temp_Completed AS tmpCp ON tmpGr.GroupID = tmpCp.GroupID
		WHERE tmpCp.GroupID IS NOT NULL
			AND tmpGr.IsValidGroup = 1;

		#=====================RETURN NOT COMPLETE GROUP================================
		
		SELECT	GROUP_CONCAT(tmp.CustID) AS CustIDList
			,	GROUP_CONCAT(tmp.CTSCustID) AS CTSCustIDList
			,	GROUP_CONCAT(tmp.CustSequenceIDList) AS SequenceIDList
			,	tmp.LicCustList
		FROM (	SELECT	tmpGr.TimeGroupID
					,	mms.CustID
					,	mms.CTSCustID
                    ,	SUM(mms.Stake) AS CustStake
					,	GROUP_CONCAT(mms.SequenceID) AS CustSequenceIDList
					,	tmpGr.LicCustList
				FROM Temp_Group AS tmpGr
				JOIN JSON_TABLE(REPLACE(JSON_ARRAY(tmpGr.SequenceIDList), ',', '","'), 
								'$[*]' COLUMNS (SequenceID BIGINT UNSIGNED PATH '$')
								) js
				INNER JOIN CTS_DataCenter.MatchMonitorStagingGroupBettingSabaNonLive AS mms ON js.SequenceID = mms.SequenceID	
				LEFT JOIN Temp_Completed AS tmpCp ON tmpGr.GroupID = tmpCp.GroupID
				WHERE tmpCp.GroupID IS NULL
					AND tmpGr.IsValidGroup = 1
				GROUP BY tmpGr.TimeGroupID, mms.CustID, mms.CTSCustID
				HAVING SUM(mms.Stake) >= lv_RuleCustStake
			  ) AS tmp
		GROUP BY tmp.TimeGroupID
		HAVING COUNT(DISTINCT tmp.CTSCustID) > 1
			AND SUM(tmp.CustStake) >= lv_RuleTotalStake;
            
    END IF;

END$$
DELIMITER ;

