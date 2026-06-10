/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_TransformToCTS_Association_GetPackage`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_TransformToCTS_Association_GetPackage`(
        IN ip_NoOfAssociation INT
    ,   IN ip_NoOfBatch INT
)
SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20190730@Casey.Huynh
	    Task : Get DeviceID NULL From Table Transaction
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20201112@CaseyHuynh: GET Lastest Code Move Server P3, update Permission and Add Meta data. Enhance  script1 [RedmineID: #145271]
            - 20201201@CaseyHuynh: Get Association if it completed Trasformed Account (Account.IsCTSTransformed !=0)
            - 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]

	    Param's Explanation (filtered by):
	*/
	
	DECLARE		TotalRecord		INT UNSIGNED DEFAULT 0;
	DECLARE		Batch			TINYINT DEFAULT 1;
    
	### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200)  DEFAULT 'DCS_DC_TransformToCTS_Association_GetPackage' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    #SET		vrExecKey = CRC32((UUID_Short()));    
    #SET		vrNotes = CONCAT('Input: ',ip_NoOfAssociation,'_', ip_NoOfBatch) ;		
    #SET 	vrStepID = 1;
    
    #SET 	vrStartTime = CURRENT_TIMESTAMP(4);	
    
    #INSERT INTO CTS_Log.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime)
    #VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime);

	### PERFORMANCE: END
	SET TotalRecord = ip_NoOfAssociation*ip_NoOfBatch;
    
    SET @RowID = 1;
    SET @MinAssociationID = (SELECT IFNULL(MAX(AssociationID),0) FROM DCS_DataCenter.Association AS ac WHERE IsCTSTransformed = 0) ;
    SET @MaxAssociationID = 0;
    
	SET TotalRecord = ip_NoOfAssociation*ip_NoOfBatch;  
	SELECT	ceil(@RowID/ip_NoOfAssociation) AS BatchID
            , ass.AssociationID
			, ass.AccountID
            , ass.DeviceID
            , ass.CreatedTime
            , ass.SubscriberID
            , @RowID := @RowID+1
            , @MaxAssociationID := GREATEST(@MaxAssociationID,ass.AssociationID)
	FROM 	DCS_DataCenter.Association AS ass
    INNER JOIN	DCS_DataCenter.Account AS acc
				ON ass.AccountID = acc.AccountID
	WHERE	ass.IsCTSTransformed = 0
			AND acc.IsCTSTransformed != 0
	LIMIT	TotalRecord;    
      
	### PERFORMANCE
	#SET		vrEndTime = CURRENT_TIMESTAMP(4);
    
    #UPDATE	CTS_Log.zzTracePerformance AS z
    #SET		z.EndTime = vrEndTime
	#		 , z.Duration = TIMESTAMPDIFF(MICROSECOND, vrStartTime, vrEndTime)
    #        , z.TotalRecord = @RowID - 1
    #        , z.FromID 		= @MinAssociationID
    #        , z.ToID		= @MaxAssociationID
    #WHERE	z.ExecKey = vrExecKey AND z.StepID = z.StepID;
    ### PERFORMANCE: END 
END$$
DELIMITER ;
