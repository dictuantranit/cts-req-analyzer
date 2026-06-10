/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Monitoring_IncorrectData_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Monitoring_IncorrectData_Get`(
		OUT op_IsContinue 	BOOLEAN
    )
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240102@Jonas.Huynh
		Task:		Enhance Monitoring Job [Redmine ID: 197999]
		DB:			CTS_DataCenter
		Original:

		Revisions:
            - 20240102@Jonas.Huynh: Creator [Redmine ID: 197999]
            - 20241213@Jonas.Huynh: Missing Customer [Redmine ID: 214157]
            - 20250417@Thomas.Nguyen: Monitor Customer Latency pool and Remove logic Total Missing Customer[Redmine ID: #223443]
			- 20250911@Logan.Nguyen: Monitor INITIALSMART_B, INITIALSMART_B_LOSING [Redmine ID: #237405]

		Param's Explanation (filtered by):
		Example:
				set @op_IsContinue = 0;
				call CTS_DataCenter.CTS_DC_Monitoring_IncorrectData_Get(@op_IsContinue);
				select @op_IsContinue;

	*/
    DECLARE CONST_JOBMONITORING_ISSUETYPEID             TINYINT DEFAULT 20;
    DECLARE CONST_BATCHSIZE							    SMALLINT DEFAULT 5000;

    DECLARE CONST_ISSUETYPEID_CUSTOMERLATENCYQUEUE		SMALLINT DEFAULT 300;
    DECLARE CONST_ISSUETYPEID_INITIALSMART_B         	SMALLINT DEFAULT 301;
    
    DECLARE lv_LastScanID 			                    BIGINT UNSIGNED;
    DECLARE lv_MaxScanID	 		                    BIGINT UNSIGNED;
    DECLARE lv_CurrentNextScanID 	                    BIGINT UNSIGNED;
    DECLARE lv_Count_CustLatencyQueue	                INT UNSIGNED;
    DECLARE lv_Threshold_CustLatencyQueue               SMALLINT UNSIGNED;
    DECLARE lv_InitialSmart_B_LastLogID 			    BIGINT UNSIGNED;

	DROP TEMPORARY TABLE IF EXISTS Temp_IncorrectData;    
	CREATE TEMPORARY TABLE Temp_IncorrectData(
			ID					BIGINT UNSIGNED
		,	IssueTypeID			SMALLINT UNSIGNED
		,	CustID				INT	UNSIGNED 
        ,	`Value`				BIGINT
        ,	TrackingInfo		VARCHAR(500)
        ,	CreatedTime			DATETIME
        ,	IsResolved			BIT(1) DEFAULT(0)
        ,	IsIssueTypeValid	BIT(1) DEFAULT(1)
        ,	KEY IX_Temp_IncorrectData_ID(ID)	
	);

    SELECT ItemValue
    INTO lv_Threshold_CustLatencyQueue
    FROM CTS_DataCenter.StaticList
    WHERE ListID = CONST_JOBMONITORING_ISSUETYPEID AND ItemID = CONST_ISSUETYPEID_CUSTOMERLATENCYQUEUE;

    SELECT ParameterValue
	INTO lv_LastScanID
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 151; 

    SELECT ParameterValue
	INTO lv_InitialSmart_B_LastLogID
	FROM CTS_DataCenter.SystemParameter 
	WHERE ParameterID = 198; 
    
    INSERT INTO Temp_IncorrectData(ID, CustID, `Value`, TrackingInfo, CreatedTime, IsResolved, IssueTypeID, IsIssueTypeValid)
    SELECT 		a.ID
			,	a.CustID
            ,	a.`Value`
            ,	a.TrackingInfo
            ,	a.CreatedTime
            ,	a.IsResolved
            ,	a.IssueTypeID
            ,	CASE WHEN s.ItemID IS NOT NULL THEN TRUE ELSE FALSE END AS IsIssueTypeValid
    FROM CTS_DataCenter.JobMonitoring_IncorrectData AS a
		LEFT JOIN CTS_DataCenter.StaticList AS s ON s.ListID = CONST_JOBMONITORING_ISSUETYPEID AND s.ItemID = a.IssueTypeID
	WHERE ID > lv_LastScanID
    ORDER BY ID ASC
    LIMIT CONST_BATCHSIZE;   
    
    SELECT MAX(ID) INTO lv_MaxScanID FROM CTS_DataCenter.JobMonitoring_IncorrectData;
    SELECT MAX(ID) INTO lv_CurrentNextScanID FROM Temp_IncorrectData;
    SET op_IsContinue = CASE WHEN lv_CurrentNextScanID < lv_MaxScanID AND lv_CurrentNextScanID IS NOT NULL THEN 1 ELSE 0 END;
    
    SELECT COUNT(1) INTO lv_Count_CustLatencyQueue
    FROM CTS_DataCenter.CTSCustomerLatencyQueue AS clq;

    IF lv_Count_CustLatencyQueue > lv_Threshold_CustLatencyQueue THEN
        INSERT INTO Temp_IncorrectData(ID, CustID, `Value`, TrackingInfo, CreatedTime, IsResolved, IssueTypeID, IsIssueTypeValid)
        SELECT  0 AS ID
            ,	NULL AS CustID
            ,	lv_Count_CustLatencyQueue AS `Value`
            ,	NULL AS TrackingInfo
            ,	CURRENT_TIMESTAMP() AS CreatedTime
            ,	0 AS IsResolved
            ,	CONST_ISSUETYPEID_CUSTOMERLATENCYQUEUE AS IssueTypeID
            ,	1 AS IsIssueTypeValid;
    END IF;

    IF EXISTS (SELECT 1 FROM Customer_InitialSmart_BySport_Log AS cibl) THEN
        INSERT INTO Temp_IncorrectData(ID, CustID, `Value`, TrackingInfo, CreatedTime, IsResolved, IssueTypeID, IsIssueTypeValid)
        SELECT  0 AS ID
            ,	NULL AS CustID
            ,	COUNT(1) AS `Value`
            ,   CONCAT('From ID: ', MIN(ID), ' To ID: ', MAX(ID)) AS TrackingInfo
            ,	CURRENT_TIMESTAMP() AS CreatedTime
            ,	0 AS IsResolved
            ,	CONST_ISSUETYPEID_INITIALSMART_B AS IssueTypeID
            ,	1 AS IsIssueTypeValid
        FROM Customer_InitialSmart_BySport_Log AS cibl
        WHERE cibl.ID > lv_InitialSmart_B_LastLogID;
    END IF;

    SELECT ID, CustID, `Value`, TrackingInfo, CreatedTime, IsResolved, IssueTypeID,  IsIssueTypeValid
    FROM Temp_IncorrectData;

    SELECT MAX(cibl.ID) AS MAX_ID FROM Customer_InitialSmart_BySport_Log AS cibl;
    
END$$
DELIMITER ;