DELIMITER $$

USE DCS_DataCenter$$

DROP PROCEDURE IF EXISTS DCS_DataCenter.DCS_ST_TransformData_GetPackage$$

CREATE DEFINER=`fps`@`%` PROCEDURE DCS_DataCenter.DCS_ST_TransformData_GetPackage (IN ip_IsProcessed TINYINT, IN ip_NoOfTickets INT, IN ip_NoOfBatch INT)
BEGIN
	/*
	Created: 20190730@Casey.Huynh
	Task : GET Transaction To Transform
	DB: DCS_DataCenter
	Original:

	Revisions:
			[20201006@CaseyHuynh][143011]: Move New Server, Move table RawTransaction from DB "DCS_RawTransaction" to "DCS_DataCenter"
				+ Aplly Partion RawTransaction Select by CreatedDate
                + Remove "SET SESSION TRANSACTION ISOLATION LEVEL..."
    Reviewer:
	Param's Explanation (filtered by):
	*/

	DECLARE		Counter		INT UNSIGNED DEFAULT 0;
    DECLARE		IsStop		INT DEFAULT 0;
    DECLARE		SysMinCreatedDate	DATETIME;
	### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200)  DEFAULT 'DCS_RT_TransformData_GetPackage' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    SET		vrExecKey = CRC32((UUID_Short()));    
    SET		vrNotes = CONCAT('Input: ',ip_NoOfTickets,'_', ip_NoOfBatch) ;		
    SET 	vrStepID = 1;
    
    SET 	vrStartTime = CURRENT_TIMESTAMP(4);	
    
    INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime)
    VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime);

	### PERFORMANCE: END    
    
    SET SysMinCreatedDate = (SELECT DATE(VValue) FROM DCS_DataCenter.SystemSetting WHERE VGroup = "DCS_Device_Transform" AND VName = "MinCreatedDate");
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
    CREATE TEMPORARY TABLE Temp_Transaction 
    (		
		MinTransID			BIGINT UNSIGNED
        , MaxTransID			BIGINT UNSIGNED
    ); 
    
	
     loop_label:  LOOP
		
		IF ((SELECT COUNT(1) FROM Temp_Transaction) < ip_NoOfBatch AND IsStop != -1)   THEN       
			       
			INSERT INTO Temp_Transaction
			SELECT	MIN(pk.TransID) 		AS MinTransID
					, MAX(pk.TransID)	AS MaxTransID
			FROM	(
						SELECT	rt.TransID	
						FROM 	DCS_DataCenter.RawTransaction AS rt
						WHERE	rt.IsProcessed = ip_IsProcessed
									AND TransID > Counter
                                    AND CreatedDate >= SysMinCreatedDate
						LIMIT	 ip_NoOfTickets
					) pk;
                
            SET Counter = (SELECT MAX(MaxTransID) FROM Temp_Transaction);
		ELSE
            LEAVE  loop_label;
        END IF;
        
        IF(Counter = IsStop) THEN 
			SET IsStop = -1;
        ELSE 
			Set IsStop = Counter;
        END IF;
        
    END LOOP;
    
    SELECT	tmpTT.MinTransID
			, tmpTT.MaxTransID
	FROM	Temp_Transaction AS tmpTT;    
	
	### PERFORMANCE
	SET		vrEndTime = CURRENT_TIMESTAMP(4);
    
    SELECT 	Count(1), Min(MinTransID), Max(MaxTransID)
    INTO	vrTotalRecord, vrFromID, vrToID
    FROM	Temp_Transaction AS tts;
    
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
