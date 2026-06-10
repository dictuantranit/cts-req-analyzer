/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transform_Device_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transform_Device_Insert`(
    IN ip_TransJson LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20200730@Bobby.Nguyen
	    Task : Transform Device Info
	    DB: DCS_Extra
	    Original:
		 
	    Revisions:
		    - 20200908@Bobby.Nguyen: Support multiple threads [Redmine ID: 137963]
            - 0200918@CaseyHuynh: Change column TransID to RawTransID [Redmine ID: 137963]
            - 20201006@CaseyHuynh: Move Server, Get Lastest SP From PRO And Update data length of FingerprintCode from 692 to 620 [Redmine ID: 143011]
		    - 20201019@CaseyHuynh:	Move Server, Phase 2 [Redmine ID: 143011]	
            - 20201020@CaseyHuynh: Update Owner, metadata [Redmine ID: 145271]
            - 20210510@Aries.Nguyen: Remove insert log dba_SP_PerformanceStats [Redmine ID: #154792]
            - 20211129@Casey.Huynh: Remove Transaction07.FingerprintMoreInfo AND Devicefingerprint.CreatedDate Column [Redmine ID: #165167]
			- 20211201@Casey.Huynh: Fix Issue Devicefingerprint.DeviceID = 0 [Redmine ID: #165164]
			- 20230316@Jonathan.Doan: Support return new device login for Alpha [Redmine ID: #185185]
			- 20230426@Jonathan.Doan: Get BotDetectionValue from RawTransaction [Redmine ID: #186644]
            - 2023292023@Casey.Huynh: CTMAX, Velki [RedmineID: #190118]
            - 20230809@Jonathan.Doan: Add more field for IP detail [RedmineID: #192402]
            
	    Param's Explanation (filtered by):
        
        Example:
			CALL DCS_ET_Transform_Device_Insert('[{"TransId": 1},{"TransId": 2}]');
	*/

	DECLARE vrDeviceStatusNew			TINYINT DEFAULT 1;			# New Device
	DECLARE vrDeviceStatusOld			TINYINT DEFAULT 2;			# Old Device
	DECLARE vrDeviceStatusRecover		TINYINT DEFAULT 3;			# Recover Device
    
    DECLARE code CHAR(5) DEFAULT '00000';
    DECLARE err_no int DEFAULT 0;
    DECLARE cod_name varchar(10) DEFAULT '';
	DECLARE err_message varchar(255) DEFAULT '';
    DECLARE info_no int DEFAULT 0;
    DECLARE info_message varchar(255) DEFAULT '';
	DECLARE sch_name varchar(128) DEFAULT 'DCS_Extra';
    DECLARE tab_name varchar(128) DEFAULT '';
    DECLARE col_name varchar(128) DEFAULT '';
    DECLARE sp_name varchar(128) DEFAULT 'DCS_ET_TransformData_Device_Insert';
    

    # STATS count
    DECLARE insertionTime TIMESTAMP(4);
	DECLARE	batchCount INT;
    DECLARE	rowCount INT;
    
    # Perf stats
    DECLARE call_time timestamp(4);
    DECLARE start_time timestamp(4);
    
    # ERROR handler
    DECLARE continue HANDLER FOR 1062
    BEGIN
		GET DIAGNOSTICS CONDITION 1	
			info_message = MESSAGE_TEXT
			,cod_name = RETURNED_SQLSTATE
            ,info_no = MYSQL_ERRNO;
    END;
    
    DECLARE continue HANDLER FOR SQLWARNING
    BEGIN
		GET DIAGNOSTICS CONDITION 1	
			info_message = MESSAGE_TEXT
			,cod_name = RETURNED_SQLSTATE
            ,info_no = MYSQL_ERRNO;
    END;
    
    DECLARE exit HANDLER FOR SQLEXCEPTION
    BEGIN
		GET STACKED DIAGNOSTICS CONDITION 1	
			err_message = MESSAGE_TEXT
            ,err_no = MYSQL_ERRNO
            ,cod_name = RETURNED_SQLSTATE
            ,sch_name = SCHEMA_NAME
            ,tab_name = TABLE_NAME
            ,col_name = COLUMN_NAME;
		
		#SELECT err_no, err_message;
        # Write error log
        #select * from Temp_PerformanceStats;
        
        INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
		WITH CTE_Stats AS (
			SELECT CONCAT('ERROR_',err_no) AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4) ) / 1000 as diff_time, JSON_OBJECT('cod_name', cod_name, 'err_message', err_message, 'sch_name', sch_name, 'tab_name', tab_name, 'col_name', col_name) as stats
		)
        SELECT step_name, start_time, diff_time, stats
        FROM CTE_Stats;

        SET sch_name = IF(LENGTH(sch_name) > 0, sch_name, 'DCS_Extra');
        INSERT INTO MonDB.dba_SP_PerformanceStats (sch_name, sp_name, step_id, step_name, start_time, diff_time, stats, call_time, end_time)
        SELECT sch_name, sp_name, step_id, step_name, start_time, diff_time, stats, call_time, CURRENT_TIMESTAMP(4) as end_time
		FROM Temp_PerformanceStats;
	END;
    
    #============================================
    DROP TEMPORARY TABLE IF EXISTS Temp_ExistedDevice;
    DROP TEMPORARY TABLE IF EXISTS Temp_RecoveredDevice;
    DROP TEMPORARY TABLE IF EXISTS Temp_RecoverDeviceByBet;
	DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
    DROP TEMPORARY TABLE IF EXISTS Temp_PerformanceStats;
    #==============================================
    
    SET call_time = CURRENT_TIMESTAMP(4);
    
    CREATE TEMPORARY TABLE Temp_PerformanceStats(
		step_id INT SIGNED AUTO_INCREMENT PRIMARY KEY,
        step_name varchar(100),
		start_time timestamp(4),
        diff_time int,
        stats varchar(1000)
    ) ENGINE = MEMORY;
       
	#======GET DATA FROM RAW TRANSACTION===========================
	CREATE TEMPORARY TABLE Temp_Transaction(
		 TransID				BIGINT	UNSIGNED PRIMARY KEY
		, AccountID				BIGINT	UNSIGNED
		, SubscriberID			INT
        , UserAgentKey			VARCHAR(32)
		, DeviceCode			VARCHAR(32) 
		, FingerprintCode		VARCHAR(620)
		, CreatedDate			DATETIME
		, TransTime				TIMESTAMP(4) 
        , DeviceCodeID			BIGINT UNSIGNED
        , DeviceID				BIGINT UNSIGNED DEFAULT 0
        , FirstDeviceCode		VARCHAR(32)
        , DeviceStatus			TINYINT
        , DeviceFingerprintID	BIGINT UNSIGNED
        , INDEX 				IX_Temp_Transaction_DeviceCode(DeviceCode)
        , INDEX 				IX_Temp_Transaction_AccountID(AccountID, DeviceCode, FingerprintCode)
	) ENGINE = MEMORY DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    
	#========GET INPUT DATA===========================
    set start_time  = CURRENT_TIMESTAMP(4);
	INSERT INTO Temp_Transaction(TransID, AccountID, SubscriberID, UserAgentKey, DeviceCode, CreatedDate, TransTime,  FingerprintCode)
    WITH CTE_Trans AS (
		SELECT TransID
		FROM JSON_TABLE(
			ip_TransJson,
			 "$[*]" COLUMNS(
				TransID BIGINT UNSIGNED PATH "$.TransId" 
			  )
		) AS t
    )
    SELECT t.TransID
		, AccountID
		, SubscriberID
		, (CASE WHEN tmpTrans.UserAgentKey IS NULL THEN NULL ELSE tmpTrans.UserAgentKey END) AS UserAgentKey
		, (CASE WHEN tmpTrans.DeviceCode IS NULL THEN NULL ELSE tmpTrans.DeviceCode END) AS DeviceCode
		, CreatedDate
		, TransTime
		,  (CASE WHEN tmpTrans.FingerprintCode IS NULL THEN NULL ELSE tmpTrans.FingerprintCode END) AS FingerprintCode
	FROM DCS_Extra.Transaction tmpTrans
	INNER JOIN CTE_Trans t ON tmpTrans.TransId = t.TransId
    ORDER BY t.TransId ASC;

    GET DIAGNOSTICS batchCount = ROW_COUNT;
    INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    WITH CTE_Stats AS (
		SELECT 'GET_DATA' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('batchCount', batchCount) as stats
    )
    SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
    
	IF batchCount = 0 then
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'ERROR: Does not exist trans to process', MYSQL_ERRNO = 1001;
    END IF;
    
    # START
    -- existed device
    CREATE TEMPORARY TABLE Temp_ExistedDevice(
		DeviceID				BIGINT NOT NULL
        , DeviceCode   			VARCHAR(32) NOT NULL
        , DeviceCodeID  		BIGINT NOT NULL
        , FirstTransID  		BIGINT
        , FirstDeviceCode 		VARCHAR(32)
        , IsNew					TINYINT DEFAULT 0
        , PRIMARY KEY 			PK_Temp_ExistedDevice(DeviceCode, DeviceID)
	) ENGINE = MEMORY DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
    ;
    
    SET start_time = CURRENT_TIMESTAMP(4);
    #explain
    INSERT INTO Temp_ExistedDevice (DeviceID, DeviceCode, DeviceCodeID)
    WITH CTE_DeviceCode AS (SELECT DISTINCT DeviceCode FROM Temp_Transaction)
    SELECT dc.DeviceID, dc.DeviceCode, dc.DeviceCodeID
    FROM CTE_DeviceCode tts
    INNER JOIN DCS_Extra.DeviceCode dc ON dc.DeviceCode = tts.DeviceCode;

    GET DIAGNOSTICS rowCount = ROW_COUNT;
    INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    WITH CTE_Stats AS (
		SELECT 'EXISTS_DEVICE' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount) as stats
    )
    SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
    
    #recover steps
    CREATE TEMPORARY TABLE Temp_RecoveredDevice(
		AccountID			BIGINT UNSIGNED
        , DeviceCode   		VARCHAR(32)
		, FingerprintCode	VARCHAR(620)
        , DeviceID			BIGINT UNSIGNED
        , RecoverCode 		VARCHAR(32)
        , PRIMARY KEY 		PK_Temp_RecoveredDevice(AccountID, DeviceCode,FingerprintCode)
        , INDEX 			Temp_RecoveredDevice_Recover(DeviceCode, DeviceID, RecoverCode)
	) ENGINE = MEMORY DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
    
    # Recover DeviceID by Association - Level 1
    SET start_time = CURRENT_TIMESTAMP(4);
    INSERT INTO Temp_RecoveredDevice(AccountID, DeviceCode, FingerprintCode, DeviceID)
    WITH CTE_Assosiation AS (
		SELECT DISTINCT AccountID, DeviceCode, FingerprintCode 
        FROM Temp_Transaction tts
        WHERE NOT EXISTS (SELECT 1 FROM Temp_ExistedDevice td WHERE td.DeviceCode = tts.DeviceCode)
	)
    SELECT tts.AccountID, tts.DeviceCode, tts.FingerprintCode, rc.DeviceID
    FROM CTE_Assosiation tts,
    LATERAL (
		SELECT ass.DeviceID
        FROM DCS_Extra.Association AS ass
        INNER JOIN	DCS_Extra.DeviceFingerprint AS df 
			ON ass.DeviceID = df.DeviceID
        WHERE ass.AccountID = tts.AccountID
			AND DCS_ET_IsListsMatchByItem(';',tts.FingerprintCode, df.FingerprintCode) = 1
		ORDER BY ass.DeviceID ASC
        LIMIT 1
    ) AS rc;

    GET DIAGNOSTICS rowCount = ROW_COUNT;
    INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    WITH CTE_Stats AS (
		SELECT 'RECOVER_DEVICE_L1' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount) as stats
    )
    SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
   
	# UPDATE recover level 2 from incoming deviceid   
    CREATE TEMPORARY TABLE Temp_RecoverDeviceByBet(
		TransID				BIGINT PRIMARY KEY
        , AccountID			BIGINT UNSIGNED
        , DeviceCode		VARCHAR(32)
        , FingerprintCode 	VARCHAR(620)
        , INDEX 			CTE_RecoverDeviceByBet_Recover(AccountID,DeviceCode,FingerprintCode)
    ) engine = MEMORY DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
	
    SET start_time = CURRENT_TIMESTAMP(4);
    INSERT INTO Temp_RecoverDeviceByBet(TransID, AccountID, DeviceCode, FingerprintCode )
    SELECT TransID, AccountID, DeviceCode, FingerprintCode 
	FROM Temp_Transaction tts
	WHERE tts.DeviceCode IS NOT NULL
		AND tts.FingerprintCode IS NOT NULL
		AND NOT EXISTS (SELECT 1 FROM Temp_ExistedDevice de WHERE de.DeviceCode = tts.DeviceCode)
		AND NOT EXISTS (SELECT 1 FROM Temp_RecoveredDevice dr WHERE dr.DeviceCode = tts.DeviceCode);

    INSERT IGNORE INTO Temp_RecoveredDevice(AccountID, DeviceCode, FingerprintCode, DeviceID, RecoverCode)
    SELECT rb.AccountID, rb.DeviceCode, rb.FingerprintCode, rd.DeviceID, rd.RecoverCode
    FROM Temp_RecoverDeviceByBet rb,
    LATERAL (
		SELECT CASE WHEN rb.DeviceCode = ts.DeviceCode THEN 1 ELSE 0 END AS DeviceID
			, ts.DeviceCode AS RecoverCode
        FROM Temp_Transaction ts
        WHERE rb.AccountID = ts.AccountID
			AND rb.TransId > ts.TransId
			AND (
				rb.DeviceCode = ts.DeviceCode #--> exists from incoming deviceid
				OR (rb.DeviceCode <> ts.DeviceCode	AND DCS_ET_IsListsMatchByItem(';',ts.FingerprintCode, rb.FingerprintCode) = 1) #--> recover from incoming deviceid
			)
		ORDER BY ts.TransId ASC
        LIMIT 1
    ) AS rd
    WHERE rd.DeviceID = 0; #--> just get recover case
    
    GET DIAGNOSTICS rowCount = ROW_COUNT;
    INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    WITH CTE_Stats AS (
		SELECT 'RECOVER_DEVICE_L2' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount) as stats
    )
    SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
    
    SET insertionTime = CURRENT_TIMESTAMP(4);
    # INSERT new Devices
    SET start_time = CURRENT_TIMESTAMP(4);
    INSERT IGNORE INTO DCS_Extra.Device(FirstDeviceCode, UserAgentKey, FirstTransID, CreatedTime, CreatedDate, InsertTime)
    SELECT 	tts.DeviceCode
		, tts.UserAgentKey
		, MIN(tts.TransID) AS FirstTransID
		, MIN(tts.TransTime) AS CreatedTime
		, MIN(tts.CreatedDate) AS CreatedDate
		, insertionTime	AS InsertTime
    FROM Temp_Transaction AS tts
    WHERE tts.DeviceCode IS NOT NULL
		AND NOT EXISTS (SELECT 1 FROM Temp_ExistedDevice de WHERE de.DeviceCode = tts.DeviceCode)
		AND NOT EXISTS (SELECT 1 FROM Temp_RecoveredDevice dr WHERE dr.DeviceCode = tts.DeviceCode) 
    GROUP BY tts.DeviceCode, tts.UserAgentKey;
    
    GET DIAGNOSTICS rowCount = ROW_COUNT;
    INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    WITH CTE_Stats AS (
		SELECT 'NEW_DEVICE' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount, 'warning', info_message, 'code', info_no, 'state', cod_name) as stats
    )
    SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
    
    # INSERT new DeviceCode
    SET start_time = CURRENT_TIMESTAMP(4);
    # NEW code - new DeviceID
    INSERT IGNORE INTO DCS_Extra.DeviceCode(DeviceCode, DeviceID, FirstTransID, CreatedTime, CreatedDate, InsertTime)
    WITH CTE_DeviceCode AS (
		SELECT t.DeviceCode
			, MIN(t.TransID) AS FirstTransID
			, MIN(t.TransTime) AS CreatedTime
			, MIN(t.CreatedDate) AS CreatedDate
            , insertionTime	AS InsertTime
		FROM Temp_Transaction AS t
        WHERE NOT EXISTS (SELECT 1 FROM Temp_ExistedDevice de WHERE de.DeviceCode = t.DeviceCode)
			AND NOT EXISTS (SELECT 1 FROM Temp_RecoveredDevice dr WHERE dr.DeviceCode = t.DeviceCode)
        GROUP BY t.DeviceCode
    )
    SELECT tts.DeviceCode
		, dv.DeviceID
		, tts.FirstTransID
		, tts.CreatedTime
		, tts.CreatedDate
		, tts.InsertTime
	FROM CTE_DeviceCode AS tts
	INNER JOIN DCS_Extra.Device dv ON dv.FirstDeviceCode = tts.DeviceCode;

    
    GET DIAGNOSTICS rowCount = ROW_COUNT;
    INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    WITH CTE_Stats AS (
		SELECT 'NEW_DEVICECODE_L1' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount) as stats
    )
    SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
    
    #NEW code vs Old DeviceID
    SET start_time = CURRENT_TIMESTAMP(4);
    INSERT IGNORE INTO DCS_Extra.DeviceCode(DeviceCode, DeviceID, FirstTransID, CreatedTime, CreatedDate, InsertTime)
    WITH CTE_DeviceCode AS (
		SELECT t.DeviceCode
			, MIN(t.TransID) AS FirstTransID
			, MIN(t.TransTime) AS CreatedTime
			, MIN(t.CreatedDate) AS CreatedDate
            , insertionTime	AS InsertTime
		FROM Temp_Transaction AS t
        WHERE NOT EXISTS (SELECT 1 FROM Temp_ExistedDevice de WHERE de.DeviceCode = t.DeviceCode)
        GROUP BY t.DeviceCode
    ), 
    CTE_NewCodeOldDeviceID AS (
		SELECT DISTINCT DeviceCode, DeviceID, RecoverCode FROM Temp_RecoveredDevice
	)
    SELECT tts.DeviceCode
		, IF(dr.DeviceID > 0 , dr.DeviceID, dc.DeviceID) AS DeviceID
		, tts.FirstTransID
		, tts.CreatedTime
		, tts.CreatedDate
		, tts.InsertTime
	FROM CTE_DeviceCode AS tts
	INNER JOIN CTE_NewCodeOldDeviceID dr ON dr.DeviceCode = tts.DeviceCode
    LEFT JOIN DCS_Extra.DeviceCode dc ON dc.DeviceCode = dr.RecoverCode AND dc.DeviceID > 0
    WHERE IF(dr.DeviceID > 0 , dr.DeviceID, dc.DeviceID)  > 0;
	
	GET DIAGNOSTICS rowCount = ROW_COUNT;
    INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    WITH CTE_Stats AS (
		SELECT 'NEW_DEVICECODE_L2' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount) as stats
    )
    SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
    
    # MERGE existed, recovered vs incoming devices
    SET start_time = CURRENT_TIMESTAMP(4);
    INSERT IGNORE INTO Temp_ExistedDevice (DeviceID, DeviceCode, DeviceCodeID, IsNew)
    WITH CTE_DeviceCode AS (SELECT DISTINCT DeviceCode FROM Temp_Transaction)
    SELECT dc.DeviceID, tts.DeviceCode, dc.DeviceCodeID, 1 AS IsNew
    FROM  CTE_DeviceCode tts
    INNER JOIN DCS_Extra.DeviceCode dc ON dc.DeviceCode = tts.DeviceCode;

    GET DIAGNOSTICS rowCount = ROW_COUNT;
    INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    WITH CTE_Stats AS (
		SELECT 'EXISTS_DEVICE_MEGRE' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount) as stats
    )
    SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
    
    # INSERT new DeviceFingerprint
    SET start_time = CURRENT_TIMESTAMP(4);
    
    INSERT IGNORE INTO DCS_Extra.DeviceFingerprint(FingerprintCode, DeviceID, CreatedTime, InsertTime)
	SELECT tts.FingerprintCode
		, tmpEd.DeviceID
		, MIN(tts.TransTime) AS CreatedTime
		, insertionTime	AS InsertTime
    FROM Temp_Transaction AS tts
    INNER JOIN Temp_ExistedDevice AS tmpEd ON tmpEd.DeviceCode = tts.DeviceCode
    WHERE tts.FingerprintCode IS NOT NULL
    GROUP BY tts.FingerprintCode, tmpEd.DeviceID;
    
    GET DIAGNOSTICS rowCount = ROW_COUNT;
    INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    WITH CTE_Stats AS (
		SELECT 'NEW_FingerprintCode' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount, 'warning', info_message, 'code', info_no, 'state', cod_name) as stats
    )
    SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
   
    # INSERT new Association
    SET start_time = CURRENT_TIMESTAMP(4);
    INSERT IGNORE INTO DCS_Extra.Association(DeviceID, AccountID, SubscriberID, CreatedTime, CreatedDate,  InsertTime)
    SELECT de.DeviceID
		, tts.AccountID
		, MIN(tts.SubscriberID) AS SubscriberID
		, MIN(tts.TransTime) AS CreatedTime
		, MIN(tts.CreatedDate) AS CreatedDate
		, insertionTime	AS InsertTime
    FROM Temp_Transaction AS tts
    INNER JOIN Temp_ExistedDevice de ON de.DeviceCode = tts.DeviceCode
    GROUP BY  de.DeviceID, tts.AccountID;
	
    GET DIAGNOSTICS rowCount = ROW_COUNT;
    INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    WITH CTE_Stats AS (
		SELECT 'NEW_Association' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount, 'warning', info_message, 'code', info_no, 'state', cod_name) as stats
    )
    SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
       
    # UPDATE back Temp_ExistedDevice
    SET start_time = CURRENT_TIMESTAMP(4);
    UPDATE Temp_ExistedDevice AS de
    INNER JOIN DCS_Extra.Device dv ON dv.DeviceID = de.DeviceID
    SET de.FirstTransID = dv.FirstTransID
		, de.FirstDeviceCode = dv.FirstDeviceCode;
    
    # UPDATE back Temp_Transaction
    UPDATE Temp_Transaction AS tts
	LEFT JOIN Temp_ExistedDevice de ON de.DeviceCode = tts.DeviceCode
    LEFT JOIN Temp_RecoveredDevice dr ON dr.AccountID = tts.AccountID 
		AND dr.DeviceCode = tts.DeviceCode 
        AND dr.FingerprintCode = tts.FingerprintCode
	LEFT JOIN DCS_Extra.DeviceFingerprint df ON df.DeviceID = de.DeviceID AND df.FingerprintCode = tts.FingerprintCode
	SET	tts.DeviceID 				= IF(de.DeviceID > 0, de.DeviceID, tts.DeviceID)
		, tts.FirstDeviceCode 		= IF(de.DeviceID > 0, de.FirstDeviceCode, tts.FirstDeviceCode)
		, tts.DeviceCodeID 			= IF(de.DeviceID > 0, de.DeviceCodeID, tts.DeviceCodeID)
		, tts.DeviceFingerprintID 	= IF(df.DeviceFingerprintID > 0, df.DeviceFingerprintID, tts.DeviceFingerprintID)
		, tts.DeviceStatus 			= CASE 
										WHEN de.DeviceID > 0 AND tts.TransId > de.FirstTransID AND dr.DeviceID IS NULL THEN vrDeviceStatusOld
										WHEN dr.DeviceID > 0 OR dr.RecoverCode IS NOT NULL THEN vrDeviceStatusRecover
                                        WHEN de.DeviceID > 0 AND de.IsNew = 1 THEN vrDeviceStatusNew  
										ELSE tts.DeviceStatus
									END;

    GET DIAGNOSTICS rowCount = ROW_COUNT;
    INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
    WITH CTE_Stats AS (
		SELECT 'UPDATE_Temp_Transaction' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount) as stats
    )
    SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
	
    /*****MOVE TRans competed to Trans07****************************************************/
    IF err_no = 0 THEN
		SET start_time = CURRENT_TIMESTAMP(4);
		INSERT IGNORE INTO  DCS_Extra.Transaction07(RawTransID, LoginName, TransTime, SubscriberID, AccountID, URLID, DeviceCodeID, DeviceID, FirstDeviceCode, DeviceStatus, DeviceFingerprintID, UserAgentKey, IP, IPID, ActionResultID, Flagged, PluginID, TransStatus, CreatedDate, InsertTime, BotDetectionValue, BotComponentID, IPInfoID)
		SELECT 	ifnull(ts.RawTransID, ts.TransID)
			,	ts.LoginName
            ,	ts.TransTime
            ,	ts.SubscriberID
            ,	ts.AccountID
            ,	ts.URLID
            ,	tmp_rm.DeviceCodeID
            ,	tmp_rm.DeviceID
            ,	tmp_rm.FirstDeviceCode
            ,	tmp_rm.DeviceStatus
            ,	tmp_rm.DeviceFingerprintID
            ,	ts.UserAgentKey
            ,	ts.IP
            ,	ts.IPID
            ,	ts.ActionResultID
            ,	ts.Flagged
            ,	ts.PluginID
            ,	ts.TransStatus
            ,	ts.CreatedDate
            ,	ts.InsertTime
            ,	ts.BotDetectionValue
            ,	ts.BotComponentID
			,   ts.IPInfoID
		FROM DCS_Extra.Transaction AS ts
		INNER JOIN Temp_Transaction AS tmp_rm
			ON	ts.TransID = tmp_rm.TransID
		WHERE tmp_rm.DeviceID IS NOT NULL;
        
		#DELETE Transaction
		DELETE ts
		FROM DCS_Extra.Transaction AS ts
		INNER JOIN	Temp_Transaction AS tmp_rm
					ON	ts.TransID = tmp_rm.TransID
		WHERE tmp_rm.DeviceID IS NOT NULL;

		GET DIAGNOSTICS rowCount = ROW_COUNT;
		INSERT INTO Temp_PerformanceStats(step_name, start_time, diff_time, stats)
		WITH CTE_Stats AS (
			SELECT 'MOVE_DELETE_Transaction07' AS step_name, start_time, TIMESTAMPDIFF(MICROSECOND, start_time, CURRENT_TIMESTAMP(4)) / 1000 as diff_time, JSON_OBJECT('rowCount', rowCount) as stats
		)
		SELECT step_name, start_time, diff_time, stats FROM CTE_Stats;
	END IF;
	# END transform
    
    # INSERT perf counter
    #INSERT INTO MonDB.dba_SP_PerformanceStats (sch_name, sp_name, step_id, step_name, start_time, diff_time, stats, call_time, end_time)
	#SELECT sch_name, sp_name, step_id, step_name, st.start_time, diff_time, stats, call_time, CURRENT_TIMESTAMP(4) as end_time
	#FROM Temp_PerformanceStats st;
END$$

DELIMITER ;
