/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_TransformToCTS_TransactionIP_Unsuccess_GetPackage`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_TransformToCTS_TransactionIP_Unsuccess_GetPackage`(IN ip_NoOfTransaction int,IN ip_NoOfBatch int)
    SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20190730@Casey.Huynh
	Task : Get DeviceID NULL From Table Transaction
	DB: DCS_DataCenter
	Original:

	Revisions:
		- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
		
	Param's Explanation (filtered by):
	*/
	
	DECLARE		TotalRecord		INT UNSIGNED DEFAULT 0;
	DECLARE		Batch			TINYINT DEFAULT 1;
    
	### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200)  DEFAULT 'DCS_DC_TransformToCTS_TransactionIP_Unsuccess_GetPackage' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    SET		vrExecKey = CRC32((UUID_Short()));    
    SET		vrNotes = CONCAT('Input: ',ip_NoOfTransaction,'_', ip_NoOfBatch) ;		
    SET 	vrStepID = 1;
    
    SET 	vrStartTime = CURRENT_TIMESTAMP(4);	
    
    INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime)
    VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime);

	### PERFORMANCE: END
    
    DROP TEMPORARY TABLE IF EXISTS Temp_TransactionIP;
    CREATE TEMPORARY TABLE Temp_TransactionIP 
    (	
		BatchID				TINYINT
		, TransID			BIGINT			UNSIGNED	NOT NULL
		, AccountID			INT				UNSIGNED	NOT NULL
        , SubscriberID		INT				NOT NULL
		, IP				VARCHAR(50)			NULL
		, IPID				DECIMAL(50,0)		NULL
		, TransTime			TIMESTAMP(4)	NOT NULL
    ); 
   
	SET TotalRecord = ip_NoOfTransaction*ip_NoOfBatch;
    
	INSERT INTO Temp_TransactionIP(TransID, AccountID, SubscriberID, IP, IPID, TransTime)
	SELECT	tip.TransID
			, tip.AccountID
            , tip.SubscriberID
            , tip.IP
            , tip.IPID
            , tip.TransTime
	FROM 	DCS_DataCenter.TransactionIP_TransformTemp AS tip
	WHERE	tip.IsCTSTransformed < 0
    ORDER BY tip.IsCTSTransformed DESC
	LIMIT	TotalRecord;
    
    WHILE (EXISTS (SELECT (1) FROM Temp_TransactionIP WHERE BatchID IS NULL LIMIT 1)) DO
    	  UPDATE 	Temp_TransactionIP
		  SET		BatchID = Batch
          WHERE		BatchID IS NULL 
          LIMIT 	ip_NoOfTransaction;    
		  SET Batch = Batch + 1;
    END WHILE;

    SELECT	tip.BatchID
			, tip.TransID
			, tip.AccountID
            , tip.SubscriberID
            , tip.IP
            , CONCAT(tip.IPID) AS IPID
            , tip.TransTime
	FROM 	Temp_TransactionIP AS tip;
	
	### PERFORMANCE
	SET		vrEndTime = CURRENT_TIMESTAMP(4);
    
    SELECT 	Count(1), Min(tas.TransID), Max(tas.TransID)
    INTO	vrTotalRecord, vrFromID, vrToID
    FROM	Temp_TransactionIP AS tas;
    
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
