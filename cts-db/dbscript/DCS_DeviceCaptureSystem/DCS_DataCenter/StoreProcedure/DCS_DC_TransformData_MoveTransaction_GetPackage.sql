DELIMITER $$

DROP PROCEDURE IF EXISTS DCS_DataCenter.DCS_DC_TransformData_MoveTransaction_GetPackage$$

CREATE PROCEDURE DCS_DataCenter.DCS_DC_TransformData_MoveTransaction_GetPackage(IN ip_NoOfRecord INT, IN ip_NoOfBatch INT)
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
	DECLARE vr_TotalRecord INT;
    ### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200)  DEFAULT 'DCS_DC_TransformData_MoveTransaction_GetPackage' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    SET		vrExecKey = CRC32((UUID_Short()));    
    SET		vrNotes = CONCAT('ip_NoOfRecord: ',ip_NoOfRecord) ;		
    SET 	vrStepID = 1;
    
    SET 	vrStartTime = CURRENT_TIMESTAMP(4);	
    
    INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime)
    VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime);    
    
    DROP TEMPORARY TABLE IF EXISTS Temp_MoveTrans;
    CREATE TEMPORARY TABLE Temp_MoveTrans
    (
		
        ID			INT  SIGNED AUTO_INCREMENT
        , TransID		BIGINT	UNSIGNED
        
        , PRIMARY KEY PK_Temp_MoveTrans_ID(ID)
    );
    
	SET vr_TotalRecord =   ip_NoOfRecord*ip_NoOfBatch;
    
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;   
	INSERT INTO Temp_MoveTrans(TransID)
	SELECT TransID 
	FROM    DCS_DataCenter.Transaction
    WHERE 	DeviceID IS NOT NULL
	LIMIT   vr_TotalRecord; 
    
	SELECT 		(((tmpList.ID-1) DIV ip_NoOfRecord) + 1) AS BatchID
				, TransID
	FROM 		Temp_MoveTrans	AS tmpList;     
    
    
	### PERFORMANCE
	SET		vrEndTime = CURRENT_TIMESTAMP(4);
    
    SELECT 	Count(1), Min(TransId), Max(TransId)
    INTO	vrTotalRecord, vrFromID, vrToID
    FROM	Temp_MoveTrans AS tts;
    
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
