DELIMITER $$

DROP PROCEDURE IF EXISTS DCS_DataCenter.DCS_DC_TransformToCTS_Association_Unsuccess_GetPackage$$

CREATE PROCEDURE DCS_DataCenter.DCS_DC_TransformToCTS_Association_Unsuccess_GetPackage(IN ip_NoOfAssociation INT)
BEGIN
	/*
	Created: 20190730@Casey.Huynh
	Task : Get DeviceID NULL From Table Transaction
	DB: DCS_DataCenter
	Original:

	Revisions:
		#1. [20200506@CaseyHuynh][133486]:  Update Unsuccessfully flow. Daily and try tranform if IsCTSTransformed > -4
		#2. [20200518@CaseyHuynh][133486]: Change data type (Batch and BatchID) from TINYINT to INT;
        #3. [20200522@CaseyHuynh][133486]:  Add NOLOCK Command;
	Param's Explanation (filtered by):
	*/
	
	DECLARE		TotalRecord		INT UNSIGNED DEFAULT 0;
	DECLARE		Batch			INT UNSIGNED DEFAULT 1;
    
	### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200)  DEFAULT 'DCS_DC_TransformToCTS_Association_Unsuccess_GetPackage' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    SET		vrExecKey = CRC32((UUID_Short()));    
    SET		vrNotes = CONCAT('Input: ',ip_NoOfAssociation) ;		
    SET 	vrStepID = 1;
    
    SET 	vrStartTime = CURRENT_TIMESTAMP(4);	
    
    INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime)
    VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime);

	### PERFORMANCE: END
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
    CREATE TEMPORARY TABLE Temp_Association 
    (	
		BatchID				INT	UNSIGNED
        , AssociationID		BIGINT	UNSIGNED
        , AccountID			BIGINT	UNSIGNED
        , DeviceID			BIGINT  UNSIGNED
        , CreatedTime		TIMESTAMP(4)
        , SubscriberID		INT
    ); 
   
	    
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	INSERT INTO Temp_Association(AssociationID, AccountID, DeviceID, CreatedTime, SubscriberID)
	SELECT	ass.AssociationID
			, ass.AccountID
			, ass.DeviceID
            , ass.CreatedTime
            , ass.SubscriberID
	FROM 	DCS_DataCenter.Association AS ass
	WHERE	ass.IsCTSTransformed < 0 AND ass.IsCTSTransformed > -4
    ORDER BY ass.IsCTSTransformed DESC;
    
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ ;
    
    WHILE (EXISTS (SELECT (1) FROM Temp_Association WHERE BatchID IS NULL LIMIT 1)) DO
    	  UPDATE 	Temp_Association
		  SET		BatchID = Batch
          WHERE		BatchID IS NULL 
          LIMIT 	ip_NoOfAssociation;    
		  SET 		Batch = Batch + 1;
    END WHILE;
    
    SELECT	tas.AssociationID
			, tas.BatchID
			, tas.AccountID
            , tas.DeviceID
            , tas.CreatedTime
            , tas.SubscriberID
	FROM Temp_Association AS tas;    


	### PERFORMANCE
	SET		vrEndTime = CURRENT_TIMESTAMP(4);
    
    SELECT 	Count(1), Min(tas.AssociationID), Max(tas.AssociationID)
    INTO	vrTotalRecord, vrFromID, vrToID
    FROM	Temp_Association AS tas;
    
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
