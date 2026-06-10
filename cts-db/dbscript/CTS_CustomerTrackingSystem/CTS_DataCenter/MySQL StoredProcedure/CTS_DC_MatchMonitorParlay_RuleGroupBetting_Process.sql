/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_MatchMonitorParlay_RuleGroupBetting_Process`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_MatchMonitorParlay_RuleGroupBetting_Process`(
		IN ip_LiveIndicator		BOOLEAN
	,	IN ip_MatchID			INT UNSIGNED
    ,	IN ip_SportType			INT
    ,	IN ip_ScoreDiff			INT 
    ,	IN ip_BettypeID			INT UNSIGNED
    ,	IN ip_BetID				BIGINT
    ,	IN ip_Betteam			VARCHAR(10)    
    ,	IN ip_TransIDmList		LONGTEXT	# SequenceID List from SP CTS_DC_MatchMonitor_RuleGroupBetting_Get
    ,	IN ip_CustGroup			JSON 		# Group Return from DC_Association_DetectGroup    
)
      
    SQL SECURITY INVOKER
sp: BEGIN
	/*
    
		Created:	20240826@Casey.Huynh
		Task :		Match Monitor Rule - Process
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20240826@Casey.Huynh: Created [Redmine ID: 207397]
            
		Param's Explanation (filtered by):
        
		Example:
		CALL CTS_DC_MatchMonitorParlay_RuleGroupBetting_Process(
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
	
	DECLARE CONST_LOG 								TINYINT DEFAULT 0;
    DECLARE CONST_MMRULEGROUP_GROUPBETTINGPARLAY	INT DEFAULT 7;
    
	DECLARE lv_RuleTimeStep 				SMALLINT;
	DECLARE lv_CustIDList 					LONGTEXT;
	DECLARE lv_GroupID 						INT; 

    #==================LOG=======================================================
    DECLARE lv_SPName VARCHAR(100) DEFAULT 'CTS_DC_MatchMonitorParlay_RuleGroupBetting_Process';
    IF CONST_LOG = 1 THEN     
		INSERT INTO CTS_Log.CTSLog(LogName, InsertTime, OtherText)
		SELECT lv_SPName, CURRENT_TIMESTAMP(), CONCAT('@ip_LiveIndicator:=',ip_LiveIndicator,',@ip_MatchID:=',ip_MatchID,',@ip_SportType:=',ip_SportType
		,',@ip_ScoreDiff:=',ip_ScoreDiff,',@ip_BettypeID:=',ip_BettypeID,',@ip_BetID:=',ip_BetID,',@ip_Betteam:=',ip_Betteam,',@ip_SequenceIDList:=',ip_SequenceIDList
        ,',@ip_CustGroup:=',ip_CustGroup);
    END IF;
    
    #==================LOG=======================================================   
	DROP TEMPORARY TABLE IF EXISTS Temp_Trans;
    CREATE TEMPORARY TABLE Temp_Trans(
			GroupID			INT
		,	OrderNum		INT
        ,	SequenceID			BIGINT
        ,	TransID				BIGINT
        ,	Refno				BIGINT
        ,	TransDateToSecond 	BIGINT
        ,	TransIDm			BIGINT
        ,	CustID			BIGINT
        ,	CTSCustID		BIGINT
        ,	OldGroupID		INT
        ,	TimeGroupID		INT
        
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
        ,	RefnoList			LONGTEXT
		,	TransIDmList		LONGTEXT
        ,	OldGroupIDList		VARCHAR(500)
		,	CustIDList			LONGTEXT
		,	CTSCustIDList		LONGTEXT
		,	SequenceIDList		LONGTEXT
        ,	IsValidGroup		BOOLEAN
        
	);
    #=======================================================================
	SELECT 	st.TimeStep
	INTO 	lv_RuleTimeStep
	FROM	CTS_DataCenter.MatchMonitorRuleSetting AS st 
	WHERE 	st.RuleGroupID = CONST_MMRULEGROUP_GROUPBETTINGPARLAY
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
   
	DROP TEMPORARY TABLE IF EXISTS Temp_TransIDm;
    CREATE TEMPORARY TABLE Temp_TransIDm (
			TransIDm	BIGINT UNSIGNED PRIMARY KEY
    );
    
	SET @sql = CONCAT("INSERT INTO Temp_TransIDm (TransIDm) VALUES ('", REPLACE(ip_TransIDmList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
 
    IF (ip_LiveIndicator = 1) THEN
  
		INSERT INTO Temp_Trans(GroupID, OrderNum , SequenceID, TransID, Refno, TransDateToSecond, TransIDm, CustID, CTSCustID, OldGroupID)
        SELECT	tmpCg.GroupID
			,	ROW_NUMBER() OVER (PARTITION BY tmpCg.GroupID ORDER BY SequenceID ) AS OrderNum			
			,	mms.SequenceID
            ,	mms.TransID
            ,	mms.Refno
			,	mms.TransDateToSecond
			,	mms.TransIDm
			,	mms.CustID
			,	mms.CTSCustID
            ,	mms.GroupID
        FROM	CTS_DataCenter.MatchMonitorParlayStagingGroupBettingLive AS mms
			INNER JOIN Temp_TransIDm AS tmpSq ON tmpSq.TransIDm = mms.TransIDm
			INNER JOIN Temp_CustGroup AS tmpCg ON tmpCg.CustID = mms.CustID;
      
		INSERT INTO Temp_Trans2(GroupID, OrderNum, TransDateToSecond)
		SELECT tmpTs.GroupID
			,	tmpTs.OrderNum
            ,	tmpTs.TransDateToSecond
		FROM Temp_Trans AS tmpTs;

        SET @n=0;
        UPDATE Temp_Trans AS t
			LEFT JOIN Temp_Trans2 AS t2 ON t.GroupID = t2.GroupID AND t.OrderNum = t2.OrderNum  +1 AND t.TransDateToSecond - t2.TransDateToSecond <= lv_RuleTimeStep
		SET t.TimeGroupID = (CASE WHEN t2.OrderNum IS NOT NULL THEN @n ELSE @n:=@n+1  END);

        INSERT INTO Temp_Group(GroupID, TimeGroupID, TransIDmList, OldGroupIDList, CustIDList, CTSCustIDList, SequenceIDList, TransIDList, RefnoList, IsValidGroup)        
        SELECT	MIN(tmp.GroupID) AS GroupID
			,	tmp.TimeGroupID
            ,	GROUP_CONCAT(tmp.TransIDm ORDER BY tmp.TransIDm) AS TransIDmList
			,	GROUP_CONCAT(DISTINCT tmp.OldGroupID) AS OldGroupIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CustID) AS CustIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CTSCustID) AS CTSCustIDList
			,	GROUP_CONCAT(DISTINCT tmp.SequenceID) AS SequenceIDList
            ,	GROUP_CONCAT(DISTINCT tmp.TransID) AS TransIDList
            ,	GROUP_CONCAT(DISTINCT tmp.Refno) AS RefnoList
            ,	(CASE WHEN COUNT(DISTINCT tmp.CustID) > 1 THEN 1 ELSE 0 END) AS IsValidGroup
        FROM Temp_Trans AS tmp
        GROUP BY TimeGroupID;

	ELSE #(ip_LiveIndicator = 0)

		INSERT INTO Temp_Trans(GroupID, OrderNum , SequenceID, TransID, Refno, TransDateToSecond, TransIDm, CustID, CTSCustID, OldGroupID)
        SELECT	tmpCg.GroupID
			,	ROW_NUMBER() OVER (PARTITION BY tmpCg.GroupID ORDER BY SequenceID ) AS OrderNum			
			,	mms.SequenceID
            ,	mms.TransID
            ,	mms.Refno
			,	mms.TransDateToSecond
			,	mms.TransIDm
			,	mms.CustID
			,	mms.CTSCustID
            ,	mms.GroupID
        FROM	CTS_DataCenter.MatchMonitorParlayStagingGroupBettingNonLive AS mms
			INNER JOIN Temp_TransIDm AS tmpSq ON tmpSq.TransIDm = mms.TransIDm
			INNER JOIN Temp_CustGroup AS tmpCg ON tmpCg.CustID = mms.CustID;
      
		INSERT INTO Temp_Trans2(GroupID, OrderNum, TransDateToSecond)
		SELECT tmpTs.GroupID
			,	tmpTs.OrderNum
            ,	tmpTs.TransDateToSecond
		FROM Temp_Trans AS tmpTs;

        SET @n=0;
        UPDATE Temp_Trans AS t
			LEFT JOIN Temp_Trans2 AS t2 ON t.GroupID = t2.GroupID AND t.OrderNum = t2.OrderNum  +1 AND t.TransDateToSecond - t2.TransDateToSecond <= lv_RuleTimeStep
		SET t.TimeGroupID = (CASE WHEN t2.OrderNum IS NOT NULL THEN @n ELSE @n:=@n+1  END);

        INSERT INTO Temp_Group(GroupID, TimeGroupID, TransIDmList, OldGroupIDList, CustIDList, CTSCustIDList, SequenceIDList, TransIDList, RefnoList, IsValidGroup)        
        SELECT	MIN(tmp.GroupID) AS GroupID
			,	tmp.TimeGroupID
            ,	GROUP_CONCAT(tmp.TransIDm ORDER BY tmp.TransIDm) AS TransIDmList
			,	GROUP_CONCAT(DISTINCT tmp.OldGroupID) AS OldGroupIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CustID) AS CustIDList
            ,	GROUP_CONCAT(DISTINCT tmp.CTSCustID) AS CTSCustIDList
			,	GROUP_CONCAT(DISTINCT tmp.SequenceID) AS SequenceIDList
            ,	GROUP_CONCAT(DISTINCT tmp.TransID) AS TransIDList
            ,	GROUP_CONCAT(DISTINCT tmp.Refno) AS RefnoList
            ,	(CASE WHEN COUNT(DISTINCT tmp.CustID) > 1 THEN 1 ELSE 0 END) AS IsValidGroup
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
	
    # =============RETURN COMPELTE GROUP=========================
	SELECT	tmpGr.GroupID	
        ,	tmpGr.CustIDList
        ,	tmpGr.TransIDList
        ,	tmpGr.RefnoList
        ,	tmpGr.TransIDmList        
    FROM Temp_Group AS tmpGr
		INNER JOIN Temp_Completed AS tmpCp ON tmpGr.GroupID = tmpCp.GroupID
    WHERE tmpCp.GroupID IS NOT NULL AND tmpGr.IsValidGroup = 1;

	# =============RETURN UN-COMPELTE  GROUP=========================
    SELECT	tmpGr.CustIDList
		,	tmpGr.CTSCustIDList
        ,	tmpGr.TransIDmList
    FROM Temp_Group AS tmpGr
		LEFT JOIN Temp_Completed AS tmpCp ON tmpGr.GroupID = tmpCp.GroupID
	WHERE tmpCp.GroupID IS NULL AND tmpGr.IsValidGroup = 1;
    
END$$
DELIMITER ;
