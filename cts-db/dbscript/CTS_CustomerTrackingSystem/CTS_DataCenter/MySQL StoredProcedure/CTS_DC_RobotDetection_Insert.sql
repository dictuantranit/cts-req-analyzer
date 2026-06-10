/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_RobotDetection_Insert`;

DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_RobotDetection_Insert`(
		IN 	ip_RobotInfo	 		JSON
    ,	IN 	ip_ScanDate			    DATETIME
    
    ,	OUT op_ErrorMessage 		VARCHAR(200)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210922@Long.Luu
		Task:		Insert Robot Detection [Redmine ID: #0000]
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20210217@Long.Luu: Created [Redmine ID: #0000]
			- 20240909@Jonas.Huynh:	Renovate CC [Redmine ID: #205317]
            
		Example:
			call CTS_DataCenter.CTS_DC_RobotDetection_Insert ('[{"C": 123, "R": 1}]','20210911', @ErrorMessage);    
	*/    
    
    DECLARE lv_CurrentDateTime 			TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_RobotInfo;    
	CREATE TEMPORARY TABLE Temp_RobotInfo(	  	
			CustID						BIGINT UNSIGNED
		, 	PeriodRangeType				SMALLINT UNSIGNED
        ,	IsNewRobot					BIT DEFAULT 1
        ,	CreatedDate					TIMESTAMP(3) 
        ,	PRIMARY KEY 				PK_Temp_RobotInfo(CustID, PeriodRangeType)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ExistedRobotInfo;    
	CREATE TEMPORARY TABLE Temp_ExistedRobotInfo(	  	
			CustID						BIGINT UNSIGNED
		, 	PeriodRangeType				SMALLINT UNSIGNED
        ,	CreatedDate					TIMESTAMP(3) 
        ,	PRIMARY KEY 				PK_Temp_RobotInfo(CustID, PeriodRangeType)
	); 
    
    INSERT INTO Temp_RobotInfo(CustID, PeriodRangeType)
	SELECT 	tmpTable.CustID
		, 	tmpTable.PeriodRangeType
	FROM JSON_TABLE(ip_RobotInfo,
		 "$[*]" COLUMNS(
				CustID 					BIGINT UNSIGNED		PATH "$.C"
            , 	PeriodRangeType 		SMALLINT UNSIGNED	PATH "$.R"
		 )) AS tmpTable;  
    
    INSERT INTO Temp_ExistedRobotInfo(CustID, PeriodRangeType, CreatedDate)
	SELECT 	DISTINCT r.CustID
		, 	r.PeriodRangeType
        ,	r.CreatedDate
	FROM Temp_RobotInfo AS t
		INNER JOIN CTS_DataCenter.RobotDetection AS r ON r.CustID = t.CustID;
    
    UPDATE Temp_RobotInfo AS t
		INNER JOIN Temp_ExistedRobotInfo AS r ON r.CustID = t.CustID 
			AND r.PeriodRangeType = t.PeriodRangeType
	SET t.IsNewRobot = 0,
		t.CreatedDate = r.CreatedDate;
       
	DELETE r
	FROM CTS_DataCenter.RobotDetection AS r
		INNER JOIN Temp_RobotInfo AS t ON t.CustID = r.CustID
			AND t.PeriodRangeType = r.PeriodRangeType; 
    
	INSERT INTO CTS_DataCenter.RobotDetection(CustID,PeriodRangeType,IsDisabled,CreatedDate,LastModifiedDate)
	SELECT 	t.CustID
		, 	t.PeriodRangeType
		,	0
		, 	CASE WHEN t.CreatedDate IS NULL THEN lv_CurrentDateTime ELSE t.CreatedDate END
		, 	lv_CurrentDateTime #ip_ScanDate, lv_CurrentDateTime
	FROM Temp_RobotInfo AS t;
		    
    SELECT CustID, PeriodRangeType, IsNewRobot
    FROM Temp_RobotInfo;
     
END$$	
DELIMITER ;