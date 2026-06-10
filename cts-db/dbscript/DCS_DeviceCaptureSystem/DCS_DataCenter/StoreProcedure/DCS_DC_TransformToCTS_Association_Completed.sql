DELIMITER $$

DROP PROCEDURE IF EXISTS DCS_DataCenter.DCS_DC_TransformToCTS_Association_Completed$$

CREATE PROCEDURE DCS_DataCenter.DCS_DC_TransformToCTS_Association_Completed(IN ip_AssociationJson LONGTEXT)
BEGIN
	/*
	Created: 20191109@Casey.Huynh
	Task : Transform DSC to CTS: Association_Update Completed
	DB: DCS_DataCenter
	Original:

	Revisions:
	Param's Explanation (filtered by):
	*/
	
	DECLARE		TotalRecord		INT UNSIGNED DEFAULT 0;
	DECLARE		Batch			TINYINT DEFAULT 1;
    
	### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200)  DEFAULT 'DCS_DC_TransformToCST_Association_Completed' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    SET		vrExecKey = CRC32((UUID_Short()));    
    SET		vrNotes = CONCAT('Input: ') ;		
    SET 	vrStepID = 1;
    
    SET 	vrStartTime = CURRENT_TIMESTAMP(4);	
    
    INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime)
    VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime);

	### PERFORMANCE: END
    


	DROP TABLE IF EXISTS Temp_Association;

	CREATE TEMPORARY TABLE Temp_Association
	( 
		AssociationID			BIGINT UNSIGNED
	);

	#=======================

	INSERT INTO Temp_Association(AssociationID)
	SELECT 	tempAss.AssociationID
	FROM
	JSON_TABLE(
				ip_AssociationJson
				, "$[*]" COLUMNS(
								AssociationID 		BIGINT UNSIGNED PATH "$.AssociationId"
								)
				) AS  tempAss;

   SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
	
    UPDATE		DCS_DataCenter.Association AS ac
    INNER JOIN 	Temp_Association AS tac
				ON ac.AssociationID = tac.AssociationID
    SET			ac.IsCTSTransformed = 1;
    
	### PERFORMANCE
	SET		vrEndTime = CURRENT_TIMESTAMP(4);
    
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
