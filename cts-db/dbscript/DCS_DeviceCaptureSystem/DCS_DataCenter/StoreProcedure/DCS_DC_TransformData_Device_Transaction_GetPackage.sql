/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin,ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_TransformData_Device_Transaction_GetPackage`;

DELIMITER $$
CREATE DEFINER=`dcsService`@`%` PROCEDURE `DCS_DC_TransformData_Device_Transaction_GetPackage`(
        IN ip_NoOfTickets INT
    ,   IN ip_NoOfBatch INT
)
     SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20200908@Bobby.Nguyen
	    Task : Get List TransID to process Device Transform
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
            - 20201012@Casey.Huynh: Add Trace Performance log
            - 20210510@Aries.Nguyen: Remove insert log dba_SP_PerformanceStats [Redmine ID: #154792]
	    Param's Explanation (filtered by):
	*/
	
	DECLARE		totalRecord		INT UNSIGNED DEFAULT 0;
	DECLARE		rateBatch		DECIMAL(4,2);
    DECLARE 	fromTransID		BIGINT;
    DECLARE		fromCreatedDate	DATE;
    DECLARE		vGroupLookup	varchar(128);
    DECLARE		vKeyLookup		varchar(128);
     # Perf stats
	DECLARE 	sch_name	varchar(128);
    DECLARE 	sp_name		varchar(128);
    DECLARE 	call_time   timestamp(4);
    DECLARE 	start_time  timestamp(4);
    DECLARE 	rowCount    INT;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Trans;
    DROP TEMPORARY TABLE IF EXISTS Temp_PerformanceStats;
    #==============================================
    
    SET sch_name = 'DCS_DataCenter';
    SET sp_name = 'DCS_DC_TransformData_Device_Transaction_GetPackage';
    SET call_time = CURRENT_TIMESTAMP(4);
    
    CREATE TEMPORARY TABLE Temp_PerformanceStats(
		step_id INT SIGNED AUTO_INCREMENT PRIMARY KEY,
        step_name varchar(100),
		start_time timestamp(4),
        diff_time int,
        stats varchar(1000)
    ) ENGINE = MEMORY;
    
    CREATE TEMPORARY TABLE Temp_Trans(	
		  TransID		BIGINT	UNSIGNED PRIMARY KEY
		, BatchID		INT
        , CreatedDate	DATE
    ) engine=MEMORY; 
    
	SET rateBatch 		= 1;#MonDB.DCS_f_GetRateBatch();	
    SET ip_NoOfTickets 	= ceil(ip_NoOfTickets*rateBatch);
	SET totalRecord 	= ip_NoOfTickets*ip_NoOfBatch;
    SET vGroupLookup 	= 'DCS_Device_Transform';
    SET vKeyLookup 		= 'MinTransId';
    SET fromTransID 	= IFNULL((SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE VGroup=vGroupLookup AND VName=vKeyLookup), 0);
    
    #SET start_time = CURRENT_TIMESTAMP(4);
	SET @RowId = 0;
    INSERT INTO Temp_Trans (TransID, CreatedDate, BatchID)
    SELECT TransID, CreatedDate, BatchID
    FROM (
		SELECT	@RowId := @RowId + 1
				, ts.TransID
                , ts.CreatedDate
				, ceil(@RowId/ip_NoOfTickets) AS BatchID
		FROM 	DCS_DataCenter.Transaction AS ts
		WHERE	ts.TransId >= fromTransID
		LIMIT totalRecord
    ) AS t;
	
    #GET DIAGNOSTICS rowCount = ROW_COUNT;
    #INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    #WITH CTE_Stats AS (
	#	SELECT 'GET_DATA' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount) as stats
    #)
    #SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
    
    #UPDATE back fromTransID
    #SET start_time = CURRENT_TIMESTAMP(4);
    SET fromTransID = IFNULL((SELECT MIN(TransID) FROM Temp_Trans), fromTransID);
    SET fromCreatedDate = IFNULL((SELECT MIN(CreatedDate) FROM Temp_Trans), date_add(current_timestamp(), interval -2 week));
    INSERT INTO DCS_DataCenter.SystemSetting (VGroup, VName, VValue, UpdatedTime)
    SELECT VGroup, VName, VValue, UpdatedTime
    FROM (
    SELECT vGroupLookup AS VGroup
		, vKeyLookup AS VName
		, CONCAT('', fromTransID) AS VValue
        , current_timestamp() AS UpdatedTime
	UNION ALL 
    SELECT vGroupLookup
		, 'MinCreatedDate'
		, CONCAT('', fromCreatedDate)
        , current_timestamp() AS UpdatedTime
	) as t
	ON DUPLICATE KEY UPDATE  VValue = t.VValue
                           , UpdatedTime = t.UpdatedTime;

    #GET DIAGNOSTICS rowCount = ROW_COUNT;
    #INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    #WITH CTE_Stats AS (
	#	SELECT 'UPDATE_SystemSetting' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount) as stats
    #)
    #SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
    
    #RETURN OUTPUT
    SELECT TransID, BatchID
    FROM Temp_Trans;
    
    # INSERT perf counter
    #INSERT INTO MonDB.dba_SP_PerformanceStats (sch_name, sp_name, step_id, step_name, start_time, diff_time, stats, call_time, end_time)
	#SELECT sch_name, sp_name, step_id, step_name, st.start_time, diff_time, stats, call_time, CURRENT_TIMESTAMP(4) as end_time
	#FROM Temp_PerformanceStats st;
END$$
DELIMITER ;
