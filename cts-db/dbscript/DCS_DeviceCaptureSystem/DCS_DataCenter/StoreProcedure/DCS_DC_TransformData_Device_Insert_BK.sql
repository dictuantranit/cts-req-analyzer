DELIMITER $$

DROP PROCEDURE IF EXISTS DCS_DataCenter.DCS_DC_TransformData_Device_Insert$$

CREATE PROCEDURE DCS_DataCenter.DCS_DC_TransformData_Device_Insert(IN ip_TransJson LONGTEXT)
BEGIN
	/*
	Created: 20190730@Casey.Huynh
	Task : Transform Device Info
	DB: DCS_DataCenter
	Original:

	Revisions:
			[20200310@Casey.Huynh][130110]: After Transform Device Done, Move Transaction From Transaction Table to Transaction07 Table
	Param's Explanation (filtered by):
	*/

	DECLARE vrDeviceStatusNew			TINYINT DEFAULT 1;			# New Device
	DECLARE vrDeviceStatusOld			TINYINT DEFAULT 2;			# Old Device
	DECLARE vrDeviceStatusRecover		TINYINT DEFAULT 3;			# Recover Device
	DECLARE	vrMaxDeviceID				BIGINT;

	### PERFORMANCE START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName	VARCHAR(200) DEFAULT 'DCS_DC_TransformData_Device_Insert' ;
    DECLARE		vrStepID	INT;
	DECLARE 	vrNotes	 	VARCHAR(500);
	DECLARE 	vrStartTime	TIMESTAMP(4);
	DECLARE		vrEndTime 	TIMESTAMP(4);
	DECLARE		vrDuration 	BIGINT;
	
    DECLARE		vrFromID	BIGINT;
    DECLARE		vrToID		BIGINT;
    DECLARE		vrBegin		BIGINT;
    DECLARE		vrTotalRecord		INT;
  
    SET		vrExecKey = CRC32((UUID_Short()));
    
    SET		vrNotes = 'DCS_DC_TransformData_Device_Insert';
	SET 	vrStartTime = CURRENT_TIMESTAMP(4);	
    SET 	vrStepID = 1;
    
    INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime)
    VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime);    
	### PERFORMANCE  END
	
	#======GET DATA FROM RAW TRANSACTION===========================
	DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
	CREATE TEMPORARY TABLE Temp_Transaction(
		 TransID				BIGINT	UNSIGNED
		, AccountID				BIGINT	UNSIGNED
		, SubscriberID			INT
        , UserAgentKey			VARCHAR(32)
		, DeviceCode			VARCHAR(32)
		, FingerprintCode		VARCHAR(640)
        , FingerprintMoreInfo	TEXT	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		, CreatedDate			DATETIME
		, TransTime				TIMESTAMP(4)
		
		, DeviceCodeID			BIGINT	UNSIGNED		NULL
        , FirstDeviceCode		VARCHAR(32)				NULL
        , DeviceID				BIGINT	UNSIGNED		NULL
		, DeviceStatus			TINYINT					NULL DEFAULT 1
		, DeviceFingerprintID	BIGINT	UNSIGNED		NULL
        , RecoverTransID		BIGINT  UNSIGNED		NULL
	);
    
   
	#========GET INPUT DATA===========================
	INSERT INTO Temp_Transaction(TransID, AccountID, SubscriberID, UserAgentKey, DeviceCode, CreatedDate, TransTime,  FingerprintCode, FingerprintMoreInfo, DeviceStatus)
    SELECT TransID
			, AccountID
			, SubscriberID
            , (CASE WHEN tmpTrans.UserAgentKey ="null" THEN NULL ELSE tmpTrans.UserAgentKey END) AS UserAgentKey
			, (CASE WHEN tmpTrans.DeviceCode ="null" THEN NULL ELSE tmpTrans.DeviceCode END) AS DeviceCode
            , CreatedDate
			, TransTime
            ,  (CASE WHEN tmpTrans.FingerprintCode ="null" THEN NULL ELSE tmpTrans.FingerprintCode END) FingerprintCode
			,  (CASE WHEN tmpTrans.FingerprintMoreInfo ="null" THEN NULL ELSE tmpTrans.FingerprintMoreInfo END)FingerprintMoreInfo
            , vrDeviceStatusNew AS DeviceStatus
			 FROM
			   JSON_TABLE(
				ip_TransJson,
				 "$[*]" COLUMNS(
				  TransID 			BIGINT UNSIGNED PATH "$.TransId"         
				, AccountID					INT UNSIGNED PATH "$.AccountId"
				, SubscriberID				INT PATH "$.SubscriberId"
                , UserAgentKey 				VARCHAR(32) PATH "$.UserAgentKey"         
				, DeviceCode				VARCHAR(32) PATH "$.DeviceCode"
                , TransTime				TIMESTAMP(4) PATH "$.TransTime"
				, CreatedDate			DATETIME PATH "$.CreatedDate"	
                , FingerprintCode			VARCHAR(2000) PATH "$.FingerprintCode"
                , FingerprintMoreInfo		TEXT CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' PATH "$.FingerprintMoreInfo"                			
				 )
			   ) AS  tmpTrans ;

    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;   
    # *******1. PROCESS OLD DEVICE*************************
    # **************************************************
	# 1.1 Get Existing DeviceID BY Existing Device Code
	UPDATE		Temp_Transaction AS tts
    INNER JOIN	DCS_DataCenter.DeviceCode	AS dc
				ON	tts.DeviceCode = dc.DeviceCode
	SET			tts.DeviceID = dc.DeviceID
				, tts.DeviceStatus = vrDeviceStatusOld
                , tts.DeviceCodeID =  dc.DeviceCodeID;    

    # 1.2 Recover Existing DeviceID  BY AccountID and FingerprintCode
    UPDATE		Temp_Transaction AS tts
    INNER JOIN	DCS_DataCenter.Association AS ass 
				ON tts.AccountID = ass.AccountID
	INNER JOIN	DCS_DataCenter.DeviceFingerprint AS df
				ON ass.DeviceID = df.DeviceID
					AND DCS_DC_ISLISTSMATCHBYITEM(';',tts.FingerprintCode, df.FingerprintCode) = 1
	SET			tts.DeviceFingerprintID = df.DeviceFingerprintID
				, tts.DeviceID = df.DeviceID
                , tts.DeviceStatus = vrDeviceStatusRecover
	WHERE		tts.DeviceID IS NULL;
    
	SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    
    # *******2. PROCESS NEW DEVICE*********************
    # **************************************************
	DROP TEMPORARY TABLE IF EXISTS Temp_NewDeviceCode;
    CREATE TEMPORARY TABLE Temp_NewDeviceCode(
		DeviceCode		VARCHAR(32)
		, MinTransID	BIGINT UNSIGNED
	);
    
    # 2.1 Get the First TransID Group By DeviceCode
    INSERT INTO Temp_NewDeviceCode(DeviceCode, MinTransID)
    SELECT	tts.DeviceCode
			, Min(tts.TransID)
	FROM	Temp_Transaction AS tts
    WHERE	tts.DeviceID IS NULL
    GROUP BY tts.DeviceCode;
    
    # 2.2  Update DeviceStatus IS 'Old DeviceCode' For TransID (excluding FirstTransID (Step 2.1)
	UPDATE		Temp_Transaction AS tts
    INNER JOIN  Temp_NewDeviceCode AS nd
				ON tts.DeviceCode 	= nd.DeviceCode
                AND tts.TransID 	!= nd.MinTransID
    SET			tts.DeviceStatus	= vrDeviceStatusOld;
    
    
    # 2.3 Update DeviceStatus Recover
	DROP TEMPORARY TABLE IF EXISTS Temp_AccountFingerprint;
    CREATE TEMPORARY TABLE Temp_AccountFingerprint(
		TransID				VARCHAR(32)
		, AccountID			BIGINT
        , FingerprintCode	VARCHAR(640)
	);
    
    INSERT INTO Temp_AccountFingerprint(TransID, AccountID, FingerprintCode)
    SELECT		TransID
				, AccountID
                , FingerprintCode
	FROM		Temp_Transaction AS tts
    WHERE		tts.DeviceID IS NULL;
    
    UPDATE		Temp_Transaction AS tts
    INNER JOIN	Temp_AccountFingerprint AS taf
				ON tts.AccountID = taf.AccountID
				AND  DCS_DC_ISLISTSMATCHBYITEM(';',tts.FingerprintCode, taf.FingerprintCode) = 1
	SET			tts.RecoverTransID = taf.TransID
				, tts.DeviceStatus = vrDeviceStatusRecover
    WHERE		tts.TransID > taf.TransID
				AND tts.DeviceID IS NULL
                AND tts.DeviceStatus = vrDeviceStatusNew;
   
    
   # 2.4  Insert New Device for New DeviceCode with DeviceStatus Is NEW
    INSERT IGNORE INTO DCS_DataCenter.Device(FirstDeviceCode, UserAgentKey, FirstTransID, CreatedTime, CreatedDate, InsertTime)
    SELECT 		tts.DeviceCode
				, tts.UserAgentKey
                , tts.TransID
                , tts.TransTime
                , tts.CreatedDate
                , CURRENT_TIMESTAMP(4)	AS InsertTime
    FROM		Temp_Transaction AS tts
    WHERE		tts.DeviceStatus = vrDeviceStatusNew
				AND tts.DeviceCode IS NOT NULL;
	
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
    
    # 2.4  Update to DeviceID for New Device
    UPDATE		Temp_Transaction AS tts
    INNER JOIN 	DCS_DataCenter.Device AS dv
				ON tts.DeviceCode	= dv.FirstDeviceCode
	SET			tts.DeviceID 		= dv.DeviceID
    WHERE		tts.DeviceStatus	= vrDeviceStatusNew;
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;    

    # 2.5  Update to DeviceID for Recover Device
    DROP TEMPORARY TABLE IF EXISTS Temp_RecoverDevice;
    CREATE TEMPORARY TABLE Temp_RecoverDevice(
		TransID				VARCHAR(32)
		, DeviceID			BIGINT
	);
    
    INSERT INTO Temp_RecoverDevice(TransID, DeviceID)
    SELECT 	tts.TransID
			, tts.DeviceID
    FROM	Temp_Transaction AS tts
    WHERE 	tts.DeviceStatus = vrDeviceStatusNew;
    
    UPDATE  Temp_Transaction AS tts
    INNER JOIN  Temp_RecoverDevice AS tgd
				ON tts.RecoverTransID = tgd.TransID
    SET		tts.DeviceID = tgd.DeviceId
    WHERE	tts.DeviceID IS NULL;
  
   
    # 2.5 Insert New DeviceCode
    INSERT IGNORE INTO DCS_DataCenter.DeviceCode(DeviceCode, DeviceID, FirstTransID, CreatedTime, CreatedDate, InsertTime)
    SELECT 	tts.DeviceCode
			, tts.DeviceID
            , tts.TransID
            , tts.TransTime
            , tts.CreatedDate
            , CURRENT_TIMESTAMP(4)	AS InsertTime
    From	Temp_Transaction AS tts
    WHERE	(tts.DeviceStatus = vrDeviceStatusNew
			OR tts.DeviceStatus = vrDeviceStatusRecover)
            AND tts.DeviceCode IS NOT NULL;    
    
    # 2.6 Update DeviceCodeID
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
	UPDATE		Temp_Transaction AS tts
    LEFT JOIN	DCS_DataCenter.DeviceCode	AS dc
				ON	tts.DeviceCode = dc.DeviceCode
	SET			tts.DeviceID = IFNULL(dc.DeviceID,0)
                , tts.DeviceCodeID =  dc.DeviceCodeID;    
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    
    # 2.7 Insert New DeviceFingerprint
    INSERT IGNORE INTO DCS_DataCenter.DeviceFingerprint(FingerprintCode, FingerprintMoreInfo, DeviceID, CreatedTime, CreatedDate, InsertTime)
     SELECT tts.FingerprintCode
			, MIN(tts.FingerprintMoreInfo)
            , tts.DeviceID
            , MIN(tts.TransTime)
            , MIN(tts.CreatedDate)
            , CURRENT_TIMESTAMP(4)	AS InsertTime
    FROM	Temp_Transaction AS tts
    WHERE	tts.FingerprintCode IS NOT NULL
    GROUP BY tts.FingerprintCode, tts.DeviceID;
    
    # 2.6 Insert New Association
    INSERT IGNORE INTO DCS_DataCenter.Association(DeviceID, AccountID, SubscriberID, CreatedTime, CreatedDate,  InsertTime)
    SELECT tts.DeviceID
			, tts.AccountID
            , tts.SubscriberID
            , MIN(tts.TransTime)
            , MIN(tts.CreatedDate)
            , CURRENT_TIMESTAMP(4)	AS InsertTime
    FROM 		Temp_Transaction AS tts
    WHERE		DeviceID > 0
    GROUP BY  	tts.DeviceID, tts.AccountID, tts.SubscriberID; 
    
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	UPDATE		Temp_Transaction AS tts
    INNER JOIN	DCS_DataCenter.DeviceCode	AS dc
				ON	tts.DeviceCode = dc.DeviceCode
	
	SET			tts.DeviceID = dc.DeviceID
                , tts.DeviceCodeID =  dc.DeviceCodeID
	WHERE 		tts.DeviceCodeID IS NULL;    
	  
	UPDATE		Temp_Transaction AS tts
    INNER JOIN 	DCS_DataCenter.Device AS dv
				ON tts.DeviceID 		= dv.DeviceID
	SET			tts.FirstDeviceCode	= dv.FirstDeviceCode;
       
	UPDATE		Temp_Transaction AS tts
    INNER JOIN	DCS_DataCenter.DeviceFingerprint	AS df
				ON	tts.FingerprintCode = df.FingerprintCode
					AND tts.DeviceID = df.DeviceID
	SET			tts.DeviceID = df.DeviceID
                , tts.DeviceFingerprintID =  df.DeviceFingerprintID;  
                
	SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    
    UPDATE	Temp_Transaction AS tts
    SET		DeviceStatus = NULL
    WHERE	DeviceID = 0;
    
    # 2.7 Update Transacton Info (DeviceCodeID, DeviceID, FirstDeviceCode, DeviceStatus, DeviceFingerprintID)    
	UPDATE	DCS_DataCenter.Transaction AS ts
    INNER JOIN	Temp_Transaction AS tts
				ON ts.TransID = tts.TransID
	SET			ts.DeviceCodeID = tts.DeviceCodeID
                , ts.DeviceID = tts.DeviceID
                , ts.FirstDeviceCode = tts.FirstDeviceCode
                , ts.DeviceStatus = tts.DeviceStatus
                , ts.DeviceFingerprintID = tts.DeviceFingerprintID;   
   	
	### PERFORMANCE
	SET	vrEndTime = CURRENT_TIMESTAMP(4);
    
    SELECT 	Count(1), Min(tts.TransID), Max(tts.TransID)
    INTO	vrTotalRecord, vrFromID, vrToID
    FROM	Temp_Transaction AS tts;
    
    UPDATE	DCS_DataCenter.zzTracePerformance AS z
    SET		z.EndTime = vrEndTime
			, z.Duration = TIMESTAMPDIFF(MICROSECOND, vrStartTime, vrEndTime)
            , z.TotalRecord = vrTotalRecord
            , z.FromID = vrFromID
            , z.ToID		= vrToID
    WHERE	z.ExecKey = vrExecKey AND z.StepID = vrStepID;
    ### PERFORMANCE: END
	
    #============================================
    DROP TEMPORARY TABLE IF EXISTS Temp_NewDeviceCode;
	DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;

    #==============================================
END$$

DELIMITER ;
