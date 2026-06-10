/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin,ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustEvidenceQueue_Affected_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidenceQueue_Affected_Insert`(
		OUT op_IsDataExist 	 	SMALLINT
)
    SQL SECURITY INVOKER
sp : BEGIN
	/*
		Created:	20210820@Aries.Nguyen
		Task:		Insert afected evidences from queue[Redmine ID: #160470]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20210823@Aries.Nguyen: Created [Redmine ID: #160470]
            - 20210909@Aries.Nguyen: Update bet limit [Redmine ID: #160711]
            - 20211101@Aries.Nguyen: Fix clear data in queue incorect [Redmine ID: #164083]
            
		Param's Explanation (filtered by):
		Example: 
			- CALL CTS_DataCenter.CTS_DC_CustEvidenceQueue_Affected_Insert(@op_IsDataExist);
	*/    
    DECLARE lv_QueueID 			BIGINT UNSIGNED;
    DECLARE lv_QueueID_Next 	BIGINT UNSIGNED;
    DECLARE lv_QueueID_Sync 	BIGINT UNSIGNED;
    DECLARE lv_LastCTSCustID 	BIGINT UNSIGNED;
    DECLARE lv_TotalAff 		INT DEFAULT 0;
    DECLARE lv_SecondBatchSize 	INT DEFAULT 0;
    DECLARE lv_BatchSize 	    INT;	
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustAffectedEvidence;    
	CREATE TEMPORARY TABLE Temp_CustAffectedEvidence(
			QueueID				BIGINT UNSIGNED
		,	CTSCustID			BIGINT UNSIGNED    
		,	CTSCustID_Affected	BIGINT UNSIGNED 
        , 	EvidenceID			SMALLINT UNSIGNED       
        , 	Remark				VARCHAR(500)
		,	CreatedBy			INT UNSIGNED
        ,	Created				DATETIME(3)
        , 	INDEX				IX_Temp_CustAffectedEvidence_CTSCustID_Affected(CTSCustID,CTSCustID_Affected) 
        , 	INDEX				IX_Temp_CustAffectedEvidence_QueueID(QueueID) 
    );
    
    DROP TEMPORARY TABLE IF EXISTS   Temp_AssociatedException;
    CREATE TEMPORARY TABLE Temp_AssociatedException(
			FromCTSCustID 	BIGINT UNSIGNED
        ,	ToCTSCustID 	BIGINT UNSIGNED
        , 	PRIMARY KEY		PK_Temp_AssociatedException_FromCTSCustID_ToCTSCustID(FromCTSCustID,ToCTSCustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS   Temp_AffectedExisted;
    CREATE TEMPORARY TABLE Temp_AffectedExisted(
			CTSCustID 		BIGINT UNSIGNED
		,	FromCustID		BIGINT UNSIGNED	
        ,	EvidenceID		SMALLINT
        , 	PRIMARY KEY(CTSCustID, FromCustID, EvidenceID)
	);
    
    SELECT ParameterValue 
    INTO lv_QueueID
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 30; 
    
    SELECT ParameterValue 
    INTO lv_LastCTSCustID
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 31; 

    SELECT ParameterValue 
    INTO lv_BatchSize
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 42;

    SELECT MAX(tbl.ID)
    INTO lv_QueueID_Next
    FROM (SELECT ID
		  FROM CTS_DataCenter.CustEvidenceAffectedQueueInsert
		  WHERE ID >= lv_QueueID
		  ORDER BY ID ASC
		  LIMIT lv_BatchSize) AS tbl;

    IF lv_QueueID_Next IS NULL THEN
        SET op_IsDataExist = 0;
        LEAVE sp;
    END IF;
    
    INSERT INTO Temp_CustAffectedEvidence(QueueID, CTSCustID, CTSCustID_Affected, EvidenceID, Remark,CreatedBy, Created)
    SELECT 	root.ID
		,	root.CTSCustID
		,  	aff.CTSCustID
		,	root.EvidenceID
		,	root.Remark
		,	root.CreatedBy
        ,	root.Created
	FROM CTS_DataCenter.CustEvidenceAffectedQueueInsert AS root,
	LATERAL
		(SELECT DISTINCT
				ass.CTSCustID
		FROM CTS_DataCenter.AssociationByDevice as dv
		INNER JOIN CTS_DataCenter.AssociationByDevice AS ass ON ass.DCSDeviceID = dv.DCSDeviceID 
																	AND ass.CTSCustID <> root.CTSCustID   
																	AND ass.CTSCustID > lv_LastCTSCustID
		WHERE dv.CTSCustID = root.CTSCustID
		ORDER BY ass.CTSCustID ASC
		LIMIT lv_BatchSize) AS aff
	WHERE root.ID = lv_QueueID 
    ORDER BY  root.ID ASC
	LIMIT lv_BatchSize;
    
    SELECT COUNT(1)
    INTO lv_TotalAff
    FROM Temp_CustAffectedEvidence;
    
    IF lv_BatchSize > lv_TotalAff THEN
		SET lv_SecondBatchSize = lv_BatchSize - lv_TotalAff;
        
        INSERT INTO Temp_CustAffectedEvidence(QueueID, CTSCustID, CTSCustID_Affected, EvidenceID, Remark,CreatedBy,Created)
		SELECT 	root.ID
			,	root.CTSCustID
			,  	aff.CTSCustID
			,	root.EvidenceID
			,	root.Remark
			,	root.CreatedBy
            ,	root.Created
		FROM CTS_DataCenter.CustEvidenceAffectedQueueInsert AS root,
		LATERAL
			(SELECT DISTINCT
					ass.CTSCustID
			 FROM CTS_DataCenter.AssociationByDevice as dv
			 INNER JOIN CTS_DataCenter.AssociationByDevice AS ass ON ass.DCSDeviceID = dv.DCSDeviceID 
																 AND ass.CTSCustID <> root.CTSCustID   
             WHERE dv.CTSCustID = root.CTSCustID
			 ORDER BY ass.CTSCustID ASC
			 LIMIT lv_SecondBatchSize) AS aff
		WHERE root.ID BETWEEN lv_QueueID + 1 AND lv_QueueID_Next
		ORDER BY root.ID ASC
		LIMIT lv_SecondBatchSize;
        
    END IF;
	
    /*********Sync Insert Remove Queue******/
	SELECT ins.QueueID
    INTO lv_QueueID_Sync
    FROM Temp_CustAffectedEvidence AS ins
    WHERE EXISTS (SELECT 1 
				  FROM CTS_DataCenter.CustEvidenceAffectedQueueRemove AS rm 
                  WHERE rm.CTSCustID = ins.CTSCustID 
					AND rm.Created <=  ins.Created)
	ORDER BY  ins.QueueID ASC
    LIMIT 1;
    
    IF lv_QueueID_Sync IS NOT NULL THEN
		DELETE 
		FROM Temp_CustAffectedEvidence
		WHERE QueueID >= lv_QueueID_Sync;
        DO SLEEP(30); /*Sleep 30s wait queue remove completed*/
    END IF;
   
    /*****************************/
    
    SELECT COUNT(1)
    INTO lv_TotalAff
    FROM Temp_CustAffectedEvidence;
    
    IF lv_TotalAff  = 0 THEN
        UPDATE CTS_DataCenter.SystemParameter 
        SET ParameterValue = 0
        WHERE ParameterID = 30; 
	
        UPDATE CTS_DataCenter.SystemParameter 
        SET ParameterValue = 0
        WHERE ParameterID = 31; 
		
        IF lv_QueueID_Sync IS NULL THEN
			DELETE 
			FROM CustEvidenceAffectedQueueInsert
			WHERE ID <= lv_QueueID_Next;
        ELSE
            DELETE 
			FROM CustEvidenceAffectedQueueInsert
			WHERE ID < lv_QueueID_Sync;
		END IF;

        IF EXISTS (SELECT 1 FROM CTS_DataCenter.CustEvidenceAffectedQueueInsert WHERE ID > lv_QueueID_Next) THEN
            SET op_IsDataExist = 1;
            LEAVE sp;
        END IF;
		SET op_IsDataExist = 0;
		LEAVE sp;
    END IF;
    
    SELECT MAX(QueueID)
    INTO lv_QueueID
    FROM Temp_CustAffectedEvidence;
    
    SELECT MAX(CTSCustID_Affected)
    INTO lv_LastCTSCustID
    FROM Temp_CustAffectedEvidence
    WHERE QueueID = lv_QueueID;
    
    INSERT IGNORE INTO Temp_AssociatedException(FromCTSCustID, ToCTSCustID)
    SELECT	ex.FromCTSCustID
		,	ex.ToCTSCustID
    FROM CTS_DataCenter.CustException AS ex
		INNER JOIN Temp_CustAffectedEvidence AS aff ON ex.FromCTSCustID = aff.CTSCustID AND ex.ToCTSCustID = aff.CTSCustID_Affected;
    
    INSERT IGNORE INTO Temp_AssociatedException(FromCTSCustID, ToCTSCustID)
    SELECT	ex.FromCTSCustID
		,	ex.ToCTSCustID
    FROM CTS_DataCenter.CustException AS ex
		INNER JOIN Temp_CustAffectedEvidence AS aff ON ex.FromCTSCustID = aff.CTSCustID_Affected AND ex.ToCTSCustID = aff.CTSCustID;
    
    INSERT IGNORE INTO Temp_AssociatedException(FromCTSCustID, ToCTSCustID)
    SELECT	ex.FromCTSCustID
		,	ex.ToCTSCustID
    FROM CTS_DataCenter.AssociationRemove AS ex
		INNER JOIN Temp_CustAffectedEvidence AS aff ON ex.FromCTSCustID = aff.CTSCustID_Affected AND ex.ToCTSCustID = aff.CTSCustID;
    
    INSERT IGNORE INTO Temp_AssociatedException(FromCTSCustID, ToCTSCustID)
    SELECT	ex.FromCTSCustID
		,	ex.ToCTSCustID
    FROM CTS_DataCenter.AssociationRemove AS ex
		INNER JOIN Temp_CustAffectedEvidence AS aff ON ex.FromCTSCustID = aff.CTSCustID AND ex.ToCTSCustID = aff.CTSCustID_Affected;
    
    DELETE 
    FROM Temp_CustAffectedEvidence AS aff
    WHERE EXISTS (SELECT 1 FROM Temp_AssociatedException AS ex WHERE ex.FromCTSCustID = aff.CTSCustID AND ex.ToCTSCustID = aff.CTSCustID_Affected);
    
    DELETE 
    FROM Temp_CustAffectedEvidence AS aff
    WHERE EXISTS (SELECT 1 FROM Temp_AssociatedException AS ex WHERE ex.FromCTSCustID = aff.CTSCustID_Affected AND ex.ToCTSCustID = aff.CTSCustID);
    
    
    INSERT IGNORE INTO Temp_AffectedExisted(CTSCustID,FromCustID, EvidenceID)
    SELECT FromCustID,CTSCustID, EvidenceID
    FROM  CTS_DataCenter.CustEvidence AS ev
    WHERE EXISTS (SELECT 1 
				  FROM Temp_CustAffectedEvidence AS aff
				  WHERE aff.CTSCustID_Affected  = ev.CTSCustID
					AND	aff.CTSCustID = ev.FromCustID
                    AND aff.EvidenceID = ev.EvidenceID);
    
    DELETE 
    FROM Temp_CustAffectedEvidence AS ev
    WHERE EXISTS (SELECT 1 
				  FROM Temp_AffectedExisted AS ex 
                  WHERE ev.CTSCustID = ex.CTSCustID 
					AND ev.CTSCustID_Affected = ex.FromCustID
                    AND ev.EvidenceID = ex.EvidenceID);
    
    INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy)
    SELECT	DISTINCT 
			aff.CTSCustID_Affected
		,	aff.EvidenceID
		,	aff.Remark
		,	2
		,	aff.CTSCustID
		,	NOW()
		,	aff.CreatedBy
    FROM Temp_CustAffectedEvidence AS aff;
    
    UPDATE CTS_DataCenter.SystemParameter 
    SET ParameterValue = lv_QueueID
    WHERE ParameterID = 30; 
	
    UPDATE CTS_DataCenter.SystemParameter 
    SET ParameterValue = lv_LastCTSCustID
    WHERE ParameterID = 31; 
    
    DELETE 
	FROM CustEvidenceAffectedQueueInsert
    WHERE ID < lv_QueueID;
    
	SET op_IsDataExist = 1;
    
    SELECT  DISTINCT
            cus.CustID
    FROM Temp_CustAffectedEvidence AS ev
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = ev.CTSCustID_Affected;
    
END$$

DELIMITER ;