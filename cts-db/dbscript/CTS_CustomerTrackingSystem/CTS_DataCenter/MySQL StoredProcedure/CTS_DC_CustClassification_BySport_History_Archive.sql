/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_BySport_History_Archive`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_History_Archive`(
    	OUT	op_IsDataExist		SMALLINT
)
    SQL SECURITY INVOKER
sp:BEGIN 
	/*
		Created:	20220909@Aries.Nguyen	
		Task :		Clean-up Classification BySport History are not used. Only take 30 lastest days.
		DB:			CTS_DataCenter
		Original:
		
		Revisions:	
			- 20220909@Aries.Nguyen:	Created  [Redmine ID: #176992] 
			- 20230210@Long.Luu: 		Fix Customer Classification Log [Redmine ID: #183279] 
            - 20230707@Jonas.Huynh:		Renovate normal classification [Redmine ID: #189875]
            - 20240628@Thomas.Nguyen: 	Renovate CC phase 2 [Redmine ID: #205317]
            - 20241017@Victoria.Le:		Keeping the last record incorrectly  [Redmine ID: #212240]
            - 20250115@CaseyHuynh: 		Enhance SystemParameter [Redmine ID: #216739]

		Param's Explanation (filtered by):

		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_BySport_History_Archive(@IsDataExist);
	*/
	DECLARE lv_BatchSize 			INT;
	DECLARE lv_DateValid 			DATETIME;
	DECLARE lv_TakeDay 				INT;
    DECLARE lv_LastArchiveID 		BIGINT UNSIGNED;
	DECLARE lv_MaxArchiveID 		BIGINT UNSIGNED;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustSport;
    CREATE TEMPORARY TABLE Temp_CustSport(
			CustID		BIGINT UNSIGNED
        ,	SportID 	SMALLINT UNSIGNED
        
        ,	PRIMARY KEY (CustID, SportID)
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_ArchiveHistory;
    CREATE TEMPORARY TABLE Temp_ArchiveHistory (
			ID 					BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	CustID 				BIGINT UNSIGNED
		,	CTSCustID 			BIGINT UNSIGNED
		,	ParentID  			INT UNSIGNED  
		,	SportID 			SMALLINT UNSIGNED 
		,	CategoryID 			INT UNSIGNED 
		,	TurnoverRM 			DECIMAL(20 , 4 ) 
		,	WinlossRM 			DECIMAL(20 , 4 )
		,	BetCount 			BIGINT 
		,	ActiveDays 			INT
		,	TargetCC 			INT
		,	ActionType 			TINYINT 
		,	LastModifiedDate 	DATETIME 
		,	LastModifiedBy 		INT UNSIGNED 
		,	InsertDate 			DATETIME
        ,	PerformanceTime		DATETIME
		,	SourceTypeID	 	SMALLINT UNSIGNED
		,	Remark			 	VARCHAR(500)
		,	KEY 				IX_Temp_ArchiveHistory_CustIDSportID (CustID, SportID)
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustDataShouldBeRemoved;
    CREATE TEMPORARY TABLE Temp_CustDataShouldBeRemoved (
			CustID  			BIGINT UNSIGNED
		,	SportID				SMALLINT UNSIGNED
        ,	PRIMARY KEY (CustID, SportID)
    ); 
    
	DROP TEMPORARY TABLE IF EXISTS Temp_HistoryShouldNotBeRemoved;
    CREATE TEMPORARY TABLE Temp_HistoryShouldNotBeRemoved (
			ID  BIGINT UNSIGNED PRIMARY KEY
    );                   
	
    SELECT ParameterValue
	INTO lv_BatchSize
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 117; 
    
    SELECT ParameterValue
	INTO lv_LastArchiveID
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 118; 
    
	SELECT ParameterValue
	INTO lv_TakeDay
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 119;
	
    SET	lv_DateValid = DATE_SUB(CURRENT_DATE(), INTERVAL lv_TakeDay DAY);

	SELECT MAX(tbl.ID)
    INTO lv_MaxArchiveID
    FROM (SELECT his.ID
		  FROM CTS_DataCenter.CTSCustomerClassification_BySport_History AS his
		  WHERE his.ID > lv_LastArchiveID
				AND his.InsertDate < lv_DateValid
		  ORDER BY his.ID ASC
		  LIMIT lv_BatchSize) AS tbl;
	
    # RETURN SP IF NOT HAVE NEW DATA
	IF lv_MaxArchiveID IS NULL THEN
		SET op_IsDataExist = 0;
		LEAVE sp; 
	END IF;		
    
    INSERT INTO Temp_CustSport(CustID, SportID)
    SELECT	DISTINCT his.CustID
		,	his.SportID
    FROM CTS_DataCenter.CTSCustomerClassification_BySport_History AS his 
	WHERE his.ID > lv_LastArchiveID 
		AND his.ID <= lv_MaxArchiveID
        AND his.InsertDate < lv_DateValid;    

    INSERT INTO Temp_ArchiveHistory(ID,CustID,CTSCustID,ParentID,SportID,CategoryID,TurnoverRM,WinlossRM,BetCount,ActiveDays,TargetCC,ActionType,LastModifiedDate,LastModifiedBy,InsertDate,PerformanceTime,SourceTypeID,Remark)
    SELECT 	his.ID 					
		,	his.CustID 				
		,	his.CTSCustID 	
		,	his.ParentID		
		,	his.SportID 			
		,	his.CategoryID 			
		,	his.TurnoverRM 			
		,	his.WinlossRM 			
		,	his.BetCount 			
		,	his.ActiveDays 			
		,	his.TargetCC 				
		,	his.ActionType 			
		,	his.LastModifiedDate 	
		,	his.LastModifiedBy 		
		,	his.InsertDate
        ,   his.PerformanceTime
		,	his.SourceTypeID
		,	his.Remark
	FROM CTS_DataCenter.CTSCustomerClassification_BySport_History AS his
		INNER JOIN Temp_CustSport AS cus ON his.CustID = cus.CustID AND his.SportID = cus.SportID
    WHERE his.ID <= lv_MaxArchiveID
        AND his.InsertDate < lv_DateValid;
    
    IF EXISTS (SELECT 1 FROM Temp_ArchiveHistory) THEN
        
		ALTER TABLE Temp_ArchiveHistory ADD INDEX IX_Temp_ArchiveHistory_InsertDate (`InsertDate`);

        # Find custs who have the log ahead --> all logs at this phase should be removed
		INSERT INTO Temp_CustDataShouldBeRemoved(CustID, SportID)
		SELECT 	cus.CustID
			,	cus.SportID
		FROM Temp_CustSport AS cus
		WHERE EXISTS (	SELECT 1
						FROM CTS_DataCenter.CTSCustomerClassification_BySport_History AS his 
                        WHERE  his.ID > lv_MaxArchiveID
							AND his.InsertDate < DATE(NOW())
                            AND cus.CustID = his.CustID 
                            AND cus.SportID = his.SportID
                            )
		;
        
        # find latest log to keep (not be removed)
        INSERT INTO Temp_HistoryShouldNotBeRemoved(ID)
        WITH CTE_CustLogOrdered (CustID, SportID, ID, row_num) AS
		(
			SELECT 	arc.CustID
				,	arc.SportID
				, 	arc.ID
                , 	ROW_NUMBER() OVER(PARTITION BY arc.CustID, arc.SportID ORDER BY arc.InsertDate DESC, arc.LastModifiedDate DESC, arc.ID DESC) AS row_num  
			FROM Temp_ArchiveHistory AS arc
				LEFT JOIN Temp_CustDataShouldBeRemoved AS rem ON arc.CustID = rem.CustID AND arc.SportID = rem.SportID
			WHERE rem.CustID IS NULL
				AND rem.SportID IS NULL
		)
        SELECT cte.ID
        FROM CTE_CustLogOrdered AS cte
        WHERE cte.row_num = 1;
    
		DELETE arc 
		FROM Temp_ArchiveHistory AS arc
			INNER JOIN Temp_HistoryShouldNotBeRemoved AS nre ON nre.ID = arc.ID;
        	
		DELETE his 
		FROM CTS_DataCenter.CTSCustomerClassification_BySport_History AS his
			INNER JOIN Temp_ArchiveHistory AS arc ON arc.ID = his.ID;
    
		SELECT	tmp.ID 					
			,	tmp.CustID 				
			,	tmp.CTSCustID 	
			,	tmp.ParentID		
			,	tmp.SportID 			
			,	tmp.CategoryID 			
			,	tmp.TurnoverRM 			
			,	tmp.WinlossRM 			
			,	tmp.BetCount 			
			,	tmp.ActiveDays 			
			,	tmp.TargetCC 				
			,	tmp.ActionType 			
			,	tmp.LastModifiedDate 	
			,	tmp.LastModifiedBy 		
			,	tmp.InsertDate
			, 	tmp.PerformanceTime
			,	tmp.SourceTypeID
			,	tmp.Remark
		FROM Temp_ArchiveHistory AS tmp;

    END IF;        
	
    SET op_IsDataExist = 1;
    
	UPDATE CTS_DataCenter.SystemParameter
	SET ParameterValue = lv_MaxArchiveID
	WHERE ParameterID = 118; 

END$$
DELIMITER ;