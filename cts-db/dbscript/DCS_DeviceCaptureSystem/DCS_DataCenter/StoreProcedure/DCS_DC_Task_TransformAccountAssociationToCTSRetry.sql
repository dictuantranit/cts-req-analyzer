/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsOwner" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Task_TransformAccountAssociationToCTSRetry`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Task_TransformAccountAssociationToCTSRetry`()
    SQL SECURITY INVOKER
BEGIN
/*
		Created:	2020101@Casey.Huynh
		Task:		Retry Transform DCS Account and Association to CTS 
		DB:			CTS_DataCenter
		Original:

		Revisions: 
            - 20201116@Aries.Nguyen: Update metadata, revision [RedmineID : #145277]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]

		Param's Explanation (filtered by):
                
	*/    
	DECLARE vrAccountMinutes TINYINT DEFAULT 60;
	DECLARE vrAssociationMinutes TINYINT DEFAULT 70;
	DECLARE vrAccountRow INT DEFAULT 0;
	DECLARE vrAssociationRow INT DEFAULT 0;
    DECLARE vrMinAccountID INT DEFAULT 0;
	DECLARE vrMinAssociationID INT DEFAULT 0;
    ### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200) DEFAULT 'DCS_DC_Task_TransformAccountAssociationToCTSRetry' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    SET		vrExecKey = CRC32((UUID_Short()));    
    SET		vrNotes = '';		
    SET 	vrStepID = 1;
	SET 	vrStartTime = CURRENT_TIMESTAMP(4);  
    
    INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime)
    VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime);
	  
	### PERFORMANCE: END
	SET vrMinAccountID = (SELECT ParameterValue FROM CTS_DataCenter.SystemParameter WHERE ParameterID = 4);
    SET vrMinAssociationID = (SELECT ParameterValue FROM CTS_DataCenter.SystemParameter WHERE ParameterID = 5);

	SELECT  MIN(acc.AccountID)
    INTO	vrMinAccountID
    FROM	DCS_DataCenter.Account AS acc
    WHERE   TIMESTAMPDIFF(MINUTE, inserttime, CURRENT_TIMESTAMP()) < vrAccountMinutes AND acc.ISCTSTransformed = -1 AND acc.AccountID  > vrMinAccountID;
    
	SELECT  MIN(ass.AssociationID)
    INTO	vrMinAssociationID
    FROM	DCS_DataCenter.Association AS ass
    WHERE   TIMESTAMPDIFF(MINUTE, inserttime, CURRENT_TIMESTAMP()) < vrAssociationMinutes AND ass.ISCTSTransformed = -1 AND ass.AssociationID  > vrMinAssociationID;
    
    UPDATE 	DCS_DataCenter.Account AS acc
	SET 	acc.ISCTSTransformed = 0
	WHERE	acc.ISCTSTransformed = -1 AND acc.AccountID > vrMinAccountID;
    
    SET vrAccountRow = ROW_COUNT();
    
    UPDATE DCS_DataCenter.Association as ass
	INNER JOIN DCS_DataCenter.Account as acc
			ON ass.AccountID = acc.AccountID
			AND acc.ISCTSTransformed=1
	SET ass.ISCTSTransformed = 0
	WHERE ass.ISCTSTransformed = -1 AND ass.AssociationID > vrMinAssociationID;

    SET vrAssociationRow = ROW_COUNT();
    
    IF (vrMinAccountID IS NOT NULL)
    THEN
		UPDATE CTS_DataCenter.SystemParameter
		SET 	ParameterValue = vrMinAccountID
		WHERE 	ParameterID = 4;
    END IF;
    
    IF (vrMinAssociationID IS NOT NULL)
    THEN
		UPDATE CTS_DataCenter.SystemParameter
		SET 	ParameterValue = vrMinAssociationID
		WHERE 	ParameterID = 5;
    END IF;
    #=======================    
	### PERFORMANCE
	SET	vrEndTime = CURRENT_TIMESTAMP(4);	
    
    UPDATE	DCS_DataCenter.zzTracePerformance AS z
    SET		z.EndTime = vrEndTime
			, z.Duration = TIMESTAMPDIFF(MICROSECOND, vrStartTime, vrEndTime)
            , z.TotalRecord = vrTotalRecord
            , z.FromID = vrAccountRow
            , z.ToID		= vrAssociationRow
            , z.Notes = CONCAT(vrAccountMinutes,'_',vrAssociationMinutes)
    WHERE	z.ExecKey = vrExecKey  AND z.StepID = vrStepID;
    ### PERFORMANCE: END
	
END$$

DELIMITER ;