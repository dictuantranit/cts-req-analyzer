DELIMITER $$

DROP PROCEDURE IF EXISTS DCS_DataCenter.DCS_DC_TransformData_MoveTransaction$$
CREATE PROCEDURE DCS_DataCenter.DCS_DC_TransformData_MoveTransaction(IN ip_TransIDList TEXT)
BEGIN
	/*
	Created: 20190730@Casey.Huynh
	Task : Archive Data
	DB: DCS_DataCenter
	Original:

	Revisions:
			- [20200226@CaseyHuynh: Move Archive Data to New Table Transaction_BK01 and RawTransaction_BK01]
            - [20200318@CaseyHuynh: Move Archive Data to New Table Transaction07]
            - [20200616@CaseyHuynh: Parallel Moving ]
	Param's Explanation (filtered by):
	*/
	DECLARE	vr_FromID 	BIGINT	UNSIGNED;
	DECLARE	vr_MaxToID	BIGINT	UNSIGNED;

    ### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200)  DEFAULT 'DCS_DC_TransformData_MoveTransaction' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    SET		vrExecKey = CRC32((UUID_Short()));    
    SET		vrNotes = '' ;		
    SET 	vrStepID = 1;
    
    SET 	vrStartTime = CURRENT_TIMESTAMP(4);	
    
    INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime)
    VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime);    
    
    CALL CTS_DataCenter.CTS_DC_Sys_SplitStringToTempItemTable(ip_TransIDList,',','BIGINT UNSIGNED');
    
    
		# ======================MOVE Transaction==========================================================
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	INSERT IGNORE INTO  DCS_DataCenter.Transaction07(TransID, LoginName, TransTime, SubscriberID, AccountID
	, URLID, DeviceCodeID, DeviceID, FirstDeviceCode, DeviceStatus, DeviceFingerprintID
	, UserAgentKey, IP, IPID, ActionResultID, Flagged, PluginID, TransStatus, CreatedDate, InsertTime)      
	SELECT 	ts.TransID, LoginName, TransTime, SubscriberID, AccountID
			, URLID, DeviceCodeID, DeviceID, FirstDeviceCode, DeviceStatus, DeviceFingerprintID
			, UserAgentKey, IP, IPID, ActionResultID, Flagged, PluginID, TransStatus, CreatedDate, InsertTime
	FROM		DCS_DataCenter.Transaction AS ts
	INNER JOIN	CTS_DataCenter.TempItemTable	AS tmp_rm
				ON	ts.TransID = tmp_rm.Item;
				
	SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
	
	DELETE	ts
	FROM		DCS_DataCenter.Transaction AS ts
	INNER JOIN	CTS_DataCenter.TempItemTable	AS tmp_rm
				ON	ts.TransID = 	tmp_rm.Item;
	#=====================================================================       
	UPDATE	DCS_DataCenter.MoveTransaction
	SET		LastTransID = (SELECT MAX(Item) FROM CTS_DataCenter.TempItemTable);      	
	#--===================================================================        
    
	### PERFORMANCE
	SET		vrEndTime = CURRENT_TIMESTAMP(4);
    
    SELECT 	Count(1), Min(Item), Max(Item)
    INTO	vrTotalRecord, vrFromID, vrToID
    FROM	 CTS_DataCenter.TempItemTable AS tts;
    
    UPDATE	DCS_DataCenter.zzTracePerformance AS z
    SET		z.EndTime = vrEndTime
			, z.Duration = TIMESTAMPDIFF(MICROSECOND, vrStartTime, vrEndTime)
            , z.TotalRecord = vrTotalRecord
            , z.FromID = vrFromID
            , z.ToID		= vrToID

    WHERE	z.ExecKey = vrExecKey AND z.StepID = z.StepID;
    ### PERFORMANCE: END 
    
END$$
DELIMITER ;
