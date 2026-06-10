DELIMITER $$

DROP PROCEDURE IF EXISTS DCS_DataCenter.DCS_DC_TransformToCTS_Account_Unsuccess_GetPackage$$

CREATE PROCEDURE DCS_DataCenter.DCS_DC_TransformToCTS_Account_Unsuccess_GetPackage(IN ip_NoOfAccount INT)
BEGIN
	/*
	Created: 20190730@Casey.Huynh
	Task : Get DeviceID NULL From Table Transaction
	DB: DCS_DataCenter
	Original:

	Revisions:
		#1. [20191217@CaseyHuynh][#125530]: Implement LastLoginTime
        #2. [20200506@CaseyHuynh][133486]:  Update Unsuccessfully flow. Daily and try tranform if IsCTSTransformed > -3
        #3. [20200518@CaseyHuynh][133486]: Change data type (Batch and BatchID) from TINYINT to INT;
        
	Param's Explanation (filtered by):
	*/
	
	DECLARE		TotalRecord		INT UNSIGNED DEFAULT 0;
	DECLARE		Batch			INT UNSIGNED DEFAULT 1;
    
	### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200)  DEFAULT 'DCS_DC_TransformToCTS_Account_Unsuccess_GetPackage' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    SET		vrExecKey = CRC32((UUID_Short()));    
    SET		vrNotes = CONCAT('Input: ',ip_NoOfAccount) ;		
    SET 	vrStepID = 1;
    
    SET 	vrStartTime = CURRENT_TIMESTAMP(4);	
    
    INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime)
    VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime);

	### PERFORMANCE: END
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Account;
    CREATE TEMPORARY TABLE Temp_Account 
    (	
		BatchID					INT UNSIGNED
        , AccountID				BIGINT	UNSIGNED
        , LoginName				VARCHAR(50)
        , SubscriberID			INT
        , LastLoginTime			TIMESTAMP(4)
    ); 
   
	#SET TotalRecord = ip_NoOfAccount*ip_NoOfBatch;
    
	INSERT INTO Temp_Account( AccountID, LoginName, SubscriberID, LastLoginTime)
	SELECT	ac.AccountID
			, ac.LoginName
            , ac.SubscriberID
            , ac.LastLoginTime
	FROM 	DCS_DataCenter.Account AS ac
	WHERE	ac.IsCTSTransformed < 0 AND ac.IsCTSTransformed > -3
    ORDER BY	IsCTSTransformed DESC;

    
    WHILE (EXISTS (SELECT (1) FROM Temp_Account WHERE BatchID IS NULL LIMIT 1)) DO
    	  UPDATE 	Temp_Account
		  SET		BatchID = Batch
          WHERE		BatchID IS NULL 
          LIMIT 	ip_NoOfAccount;    
		  SET 		Batch = Batch + 1;
    END WHILE;
    
    SELECT	ac.BatchID
			, ac.AccountID
            , ac.LoginName
            , ac.SubscriberID
            , ac.LastLoginTime
	FROM Temp_Account AS ac;
    
   SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
	
	### PERFORMANCE
	SET		vrEndTime = CURRENT_TIMESTAMP(4);
    
    SELECT 	Count(1), Min(AccountID), Max(AccountID)
    INTO	vrTotalRecord, vrFromID, vrToID
    FROM	Temp_Account AS tts;
    
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
