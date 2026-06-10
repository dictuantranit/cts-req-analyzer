/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_History_Archive_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_History_Archive_Get`(
)
    SQL SECURITY INVOKER
sp:BEGIN 
	/*
		Created:	20250725@Winfred.Pham	
		Task :		Clean-up Classification Agency History are not used. Only take 180 lastest days.
		DB:			CTS_DataCenter
		Original:
		
		Revisions:	
				- 20250725@Winfred.Pham: 	Created [Redmine ID: #219679]
            
		Param's Explanation (filtered by):

		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_History_Archive_Get;
	*/
	DECLARE lv_BatchSize 		INT;
	DECLARE lv_DateValid 		DATETIME;
	DECLARE lv_TakeDay 			INT;
    DECLARE lv_LastArchiveID 	BIGINT UNSIGNED;
	DECLARE lv_MaxArchiveID 	BIGINT UNSIGNED;    
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust (
		CustID		BIGINT PRIMARY KEY
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_ArchiveHistory;
    CREATE TEMPORARY TABLE Temp_ArchiveHistory (
			ID BIGINT UNSIGNED NOT NULL
		,	CustID BIGINT UNSIGNED
		,	CTSCustID BIGINT UNSIGNED
		,	RoleID TINYINT
		,	ParentID INT UNSIGNED
		,	CategoryID INT
		,	OldCategoryID INT UNSIGNED
		,	DWCategoryID INT UNSIGNED
		,	TargetCC INT
		,	SourceTypeID SMALLINT UNSIGNED
		,	IsDataChanged TINYINT(1)
		,	ActionType TINYINT
		,	IsAuto TINYINT(1)
		,	LastModifiedDate DATETIME 
		,	LastModifiedBy INT UNSIGNED
		,	InsertDate DATETIME
		,	TargetDangerLevel1 SMALLINT
		,	Remark VARCHAR(500) 
		,	IsMarkedDirectly TINYINT(1)
		,	IsFromTW TINYINT(1)
		,	IsFromCTS TINYINT(1)
		,	IsFromAI TINYINT(1)
		,	TurnoverRM DECIMAL(20,4) 
		,	WinlossRM DECIMAL(20,4)
		,	BetCount BIGINT
		,	LastXDaysTurnoverRM DECIMAL(20,4)
		,	LastXDaysWinlossRM DECIMAL(20,4)
		,	LastXDaysBetCount BIGINT
		,	LastYDaysTurnoverRM DECIMAL(20,4) 
		,	LastYDaysWinlossRM DECIMAL(20,4)
		,	LastYDaysBetCount BIGINT 
		,	PerformanceTime DATETIME 
		,	RobotCounter SMALLINT
		,	PRIMARY KEY (ID)
		,	KEY IX_CTSCustomerClassificationAgency_History_Archive_CustID (CustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustDataShouldBeRemoved;
    CREATE TEMPORARY TABLE Temp_CustDataShouldBeRemoved (
		CustID	BIGINT PRIMARY KEY
    ); 
    
	DROP TEMPORARY TABLE IF EXISTS Temp_HistoryShouldNotBeRemoved;
    CREATE TEMPORARY TABLE Temp_HistoryShouldNotBeRemoved (
			ID  BIGINT UNSIGNED PRIMARY KEY
    );            

    SELECT ParameterValue
	INTO lv_LastArchiveID
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 193; 
    
    SELECT ParameterValue
	INTO lv_BatchSize
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 194; 

	SELECT ParameterValue
	INTO lv_TakeDay
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 195;

    SET	lv_DateValid = DATE_SUB(CURRENT_DATE(), INTERVAL lv_TakeDay DAY);

	SELECT MAX(tbl.ID)
    INTO lv_MaxArchiveID
    FROM (SELECT his.ID
		  FROM CTS_DataCenter.CTSCustomerClassificationAgency_History AS his
		  WHERE his.ID > lv_LastArchiveID
				AND his.InsertDate < lv_DateValid
		  ORDER BY his.ID ASC
		  LIMIT lv_BatchSize) AS tbl;
	
    
    INSERT INTO Temp_Cust(CustID)
    SELECT 	DISTINCT his.CustID  
    FROM CTS_DataCenter.CTSCustomerClassificationAgency_History AS his 
	WHERE his.ID > lv_LastArchiveID AND ID <= lv_MaxArchiveID
		AND his.IsDataChanged = 1
        AND his.InsertDate < lv_DateValid;
     
    INSERT INTO Temp_ArchiveHistory(ID,CustID,CTSCustID,RoleID,ParentID,CategoryID,OldCategoryID,DWCategoryID,TargetCC,SourceTypeID,IsDataChanged,ActionType,IsAuto,LastModifiedDate,LastModifiedBy,InsertDate,TargetDangerLevel1,Remark,IsMarkedDirectly,IsFromTW,IsFromCTS,IsFromAI,TurnoverRM,WinlossRM,BetCount,LastXDaysTurnoverRM,LastXDaysWinlossRM,LastXDaysBetCount,LastYDaysTurnoverRM,LastYDaysWinlossRM,LastYDaysBetCount,PerformanceTime,RobotCounter)
	SELECT 	his.ID
		,	his.CustID
		,	his.CTSCustID
		,	his.RoleID
		,	his.ParentID
		,	his.CategoryID
		,	his.OldCategoryID
		,	his.DWCategoryID
		,	his.TargetCC
		,	his.SourceTypeID
		,	his.IsDataChanged
		,	his.ActionType
		,	his.IsAuto
		,	his.LastModifiedDate
		,	his.LastModifiedBy
		,	his.InsertDate
		,	his.TargetDangerLevel1
		,	his.Remark
		,	his.IsMarkedDirectly
		,	his.IsFromTW
		,	his.IsFromCTS
		,	his.IsFromAI
		,	his.TurnoverRM
		,	his.WinlossRM
		,	his.BetCount
		,	his.LastXDaysTurnoverRM
		,	his.LastXDaysWinlossRM
		,	his.LastXDaysBetCount
		,	his.LastYDaysTurnoverRM
		,	his.LastYDaysWinlossRM
		,	his.LastYDaysBetCount
		,	his.PerformanceTime
		,	his.RobotCounter
	FROM CTS_DataCenter.CTSCustomerClassificationAgency_History AS his
		INNER JOIN Temp_Cust AS cus ON his.CustID = cus.CustID
    WHERE his.ID <= lv_MaxArchiveID
		AND his.IsDataChanged = 1 
        AND his.InsertDate < lv_DateValid
    ;
    
    IF EXISTS (SELECT 1 FROM Temp_ArchiveHistory) THEN
    
		ALTER TABLE Temp_ArchiveHistory ADD INDEX IX_Temp_ArchiveHistory_InsertDateLastModifiedDate (`InsertDate`, `LastModifiedDate`);    
        
		# Find custs who have the log ahead --> all logs at this phase should be removed
		INSERT INTO Temp_CustDataShouldBeRemoved(CustID)
		SELECT DISTINCT cus.CustID
		FROM Temp_Cust AS cus
		WHERE EXISTS  (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassificationAgency_History AS his
						WHERE his.ID > lv_MaxArchiveID
							AND his.InsertDate < DATE(NOW())
							AND his.IsDataChanged = 1
                            AND cus.CustID = his.CustID);	

		# find latest log to keep (not be removed)
		INSERT INTO Temp_HistoryShouldNotBeRemoved(ID)
		WITH CTE_CustLogOrdered (CustID, ID, row_num) AS
		(
			SELECT 	arc.CustID
				, 	arc.ID
				, 	ROW_NUMBER() OVER(PARTITION BY arc.CustID ORDER BY arc.InsertDate DESC, arc.LastModifiedDate DESC, arc.ID DESC) AS row_num  
			FROM Temp_ArchiveHistory AS arc
				LEFT JOIN Temp_CustDataShouldBeRemoved AS rem ON arc.CustID = rem.CustID
			WHERE rem.CustID IS NULL
		)
		SELECT cte.ID
		FROM CTE_CustLogOrdered AS cte
		WHERE cte.row_num = 1;        
		
		DELETE arc
		FROM Temp_ArchiveHistory AS arc
			INNER JOIN Temp_HistoryShouldNotBeRemoved AS nre ON nre.ID = arc.ID
		;
    END IF;
	
	SELECT	arc.ID
			,	arc.CustID
			,	arc.CTSCustID
			,	arc.RoleID
			,	arc.ParentID
			,	arc.CategoryID
			,	arc.OldCategoryID
			,	arc.DWCategoryID
			,	arc.TargetCC
			,	arc.SourceTypeID
			,	arc.IsDataChanged
			,	arc.ActionType
			,	arc.IsAuto
			,	arc.LastModifiedDate
			,	arc.LastModifiedBy
			,	arc.InsertDate
			,	arc.TargetDangerLevel1
			,	arc.Remark
			,	arc.IsMarkedDirectly
			,	arc.IsFromTW
			,	arc.IsFromCTS
			,	arc.IsFromAI
			,	arc.TurnoverRM
			,	arc.WinlossRM
			,	arc.BetCount
			,	arc.LastXDaysTurnoverRM
			,	arc.LastXDaysWinlossRM
			,	arc.LastXDaysBetCount
			,	arc.LastYDaysTurnoverRM
			,	arc.LastYDaysWinlossRM
			,	arc.LastYDaysBetCount
			,	arc.PerformanceTime
			,	arc.RobotCounter
		FROM Temp_ArchiveHistory AS arc;

END$$
DELIMITER ;