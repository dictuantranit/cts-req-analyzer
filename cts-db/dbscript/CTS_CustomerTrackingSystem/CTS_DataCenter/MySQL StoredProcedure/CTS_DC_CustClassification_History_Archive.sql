/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_History_Archive`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_History_Archive`(
    	OUT	op_IsDataExist		SMALLINT
)
    SQL SECURITY INVOKER
sp:BEGIN 
	/*
		Created:	20210901@Aries.Nguyen	
		Task :		Clean-up Classification History are not used. Only take 30 lastest days.
		DB:			CTS_DataCenter
		Original:
		
		Revisions:	
			- 20210901@Aries.Nguyen: 	Created [RedmineID: #160758]	
			- 20220519@Aries.Nguyen: 	Renovate the Category Log History[Redmine ID: #172560]
			- 20220909@Aries.Nguyen: 	Handle lv_NextLastID is null [Redmine ID: #176992] 
			- 20230210@Long.Luu: Fix 	Customer Classification Log [Redmine ID: #183279] 
			- 20230315@Victoria.Le:		Add Robot Imperva [Redmine ID: #184773]
			- 20230404@Victoria.Le		TVS Abnormal Bet and Abnormal Account - Add IsParlay,SportType,IssueTypeID [Redmine ID: #185319] 
			- 20230428@Jonas.Huynh: 	Realtime Renovation [Redmine ID: #186678]
			- 20231108@Victoria.Le: 	Add First5TWGBTicketCount [Redmine ID: #195060]
            - 20240628@Thomas.Nguyen: 	Renovate CC phase 2 [Redmine ID: #205317]
            - 20241231@Victoria.Le: 	Adjust code to update NextID as expected [Redmine ID: #216125]
			- 20250115@CaseyHuynh: 		Enhance SystemParameter when Archive Batch (AllRecords.IsDataChanged = 0) [Redmine ID: #216739]
            
		Param's Explanation (filtered by):

		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_History_DataChanged_CleanUp(@IsDataExist);
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
			ID  					BIGINT UNSIGNED 
		,	CustID  				BIGINT 
		,	CTSCustID  				BIGINT UNSIGNED
		,	ParentID  				INT UNSIGNED 
		,	CategoryID  			INT  
		,	TurnoverRM  			DECIMAL(20,4 )  
		,	WinlossRM  				DECIMAL(20,4 )  
		,	BetCount  				BIGINT  
		,	ActiveDays  			INT  
		,	RobotCounter  			SMALLINT  
		,	TargetCC  				INT  
		,	SourceTypeID  			SMALLINT UNSIGNED  
		,	OldCategoryID  			INT UNSIGNED  
		,	DWCategoryID  			INT UNSIGNED  
		,	IsDataChanged  			TINYINT(1)
		,	ActionType  			TINYINT  
		,	IsAuto  				TINYINT(1)  
		,	LastModifiedDate  		DATETIME  
		,	LastModifiedBy  		INT UNSIGNED  
		,	InsertDate  			DATETIME
		,	TaggingType  			SMALLINT
		,	TargetDangerLevel1  	SMALLINT  
		,	TWGroupBettingRate  	DECIMAL(10,4)  
		,	TWTicketRejectRate  	DECIMAL(10,4)  
		,	TWBetCount  			BIGINT  
		,	TWDesktopUsageRate  	DECIMAL(10,4)  
        ,	Remark 					VARCHAR(500)
		,	IsMarkedDirectly		TINYINT(1) 
		,	TVSRequestID			BIGINT UNSIGNED 
        ,	IsFromTVS 				TINYINT(1) 
		,	IsFromTW 				TINYINT(1)
		,	IsFromCTS 				TINYINT(1)
		,	IsFromAI 				TINYINT(1) 
		,	IsFromImperva			TINYINT(1)
		,	IsParlay				TINYINT(1)
		,	SportType				SMALLINT
		,	IssueTypeID				TINYINT
        ,	PerformanceTime			DATETIME
		,	PRIMARY KEY (ID)
		,	KEY 					IX_CTSCustomerClassification_History_CustID (CustID)
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
	WHERE ParameterID = 35; 
    
    SELECT ParameterValue
	INTO lv_BatchSize
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 40; 

	SELECT ParameterValue
	INTO lv_TakeDay
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 41;

    SET	lv_DateValid = DATE_SUB(CURRENT_DATE(), INTERVAL lv_TakeDay DAY);

	SELECT MAX(tbl.ID)
    INTO lv_MaxArchiveID
    FROM (SELECT his.ID
		  FROM CTS_DataCenter.CTSCustomerClassification_History AS his
		  WHERE his.ID > lv_LastArchiveID
				AND his.InsertDate < lv_DateValid
		  ORDER BY his.ID ASC
		  LIMIT lv_BatchSize) AS tbl;
	
    # RETURN SP IF NOT HAVE NEW DATA
	IF lv_MaxArchiveID IS NULL THEN
		SET op_IsDataExist = 0;
		LEAVE sp; 
	END IF;	
    
    INSERT INTO Temp_Cust(CustID)
    SELECT 	DISTINCT his.CustID  
    FROM CTS_DataCenter.CTSCustomerClassification_History AS his 
	WHERE his.ID > lv_LastArchiveID AND ID <= lv_MaxArchiveID
		AND his.IsDataChanged = 1
        AND his.InsertDate < lv_DateValid;
     
    INSERT INTO Temp_ArchiveHistory(ID,CustID,CTSCustID,ParentID,CategoryID,TurnoverRM,WinlossRM,BetCount,ActiveDays,RobotCounter,TargetCC,SourceTypeID,OldCategoryID,DWCategoryID,IsDataChanged,ActionType,IsAuto,LastModifiedDate,LastModifiedBy,InsertDate,TaggingType,TargetDangerLevel1,TWGroupBettingRate,TWTicketRejectRate,TWBetCount,TWDesktopUsageRate,Remark,IsMarkedDirectly,TVSRequestID,IsFromTVS,IsFromTW,IsFromCTS,IsFromAI,IsFromImperva,IsParlay,SportType,IssueTypeID,PerformanceTime)
	SELECT 	his.ID  					
		,	his.CustID  				
		,	his.CTSCustID  				
		,	his.ParentID  			
		,	his.CategoryID  			
		,	his.TurnoverRM  			
		,	his.WinlossRM  				
		,	his.BetCount  				
		,	his.ActiveDays  			
		,	his.RobotCounter  		
		,	his.TargetCC  				
		,	his.SourceTypeID  			
		,	his.OldCategoryID  		
		,	his.DWCategoryID  			
		,	his.IsDataChanged  			
		,	his.ActionType  			
		,	his.IsAuto  				
		,	his.LastModifiedDate  		
		,	his.LastModifiedBy  		
		,	his.InsertDate  			
		,	his.TaggingType  			
		,	his.TargetDangerLevel1  	
		,	his.TWGroupBettingRate  	
		,	his.TWTicketRejectRate  	
		,	his.TWBetCount  			
		,	his.TWDesktopUsageRate  
		,	his.Remark 			
		,	his.IsMarkedDirectly
		,	his.TVSRequestID
		,	his.IsFromTVS 				 
		,	his.IsFromTW 				
		,	his.IsFromCTS 				
		,	his.IsFromAI 	
		,	his.IsFromImperva
		,	his.IsParlay
		,	his.SportType
		,	his.IssueTypeID
		,	his.PerformanceTime
	FROM CTS_DataCenter.CTSCustomerClassification_History AS his
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
		WHERE EXISTS  (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassification_History AS his
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
			
		DELETE his  
		FROM CTS_DataCenter.CTSCustomerClassification_History AS his
			INNER JOIN Temp_ArchiveHistory AS arc ON arc.ID = his.ID
		;

		SELECT	arc.ID  					
			,	arc.CustID  				
			,	arc.CTSCustID  				
			,	arc.ParentID  			
			,	arc.CategoryID  			
			,	arc.TurnoverRM  			
			,	arc.WinlossRM  				
			,	arc.BetCount  				
			,	arc.ActiveDays  			
			,	arc.RobotCounter  		
			,	arc.TargetCC  				
			,	arc.SourceTypeID  			
			,	arc.OldCategoryID  		
			,	arc.DWCategoryID  			
			,	arc.IsDataChanged  			
			,	arc.ActionType  			
			,	arc.IsAuto  				
			,	arc.LastModifiedDate  		
			,	arc.LastModifiedBy  		
			,	arc.InsertDate  			
			,	arc.TaggingType  			
			,	arc.TargetDangerLevel1  	
			,	arc.TWGroupBettingRate  	
			,	arc.TWTicketRejectRate  	
			,	arc.TWBetCount  			
			,	arc.TWDesktopUsageRate 
			,	arc.Remark 	
			,	arc.IsMarkedDirectly
			,	arc.TVSRequestID
			,	arc.IsFromTVS 				 
			,	arc.IsFromTW 				
			,	arc.IsFromCTS 				
			,	arc.IsFromAI 	
			,	arc.IsFromImperva
			,	arc.IsParlay
			,	arc.SportType
			,	arc.IssueTypeID
			,	arc.PerformanceTime
		FROM Temp_ArchiveHistory AS arc;
    
    END IF;
    
    # UPDATE SYSTEM PARAMETER
	SET op_IsDataExist = 1;

    UPDATE CTS_DataCenter.SystemParameter
	SET ParameterValue = lv_MaxArchiveID
	WHERE ParameterID = 35;

END$$
DELIMITER ;