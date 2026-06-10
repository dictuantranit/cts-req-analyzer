/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin,ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustEvidenceQueue_Affected_Remove`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidenceQueue_Affected_Remove`(
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
			- 20210622@Aries.Nguyen:  Created [Redmine ID: #160470]
            - 20210909@Aries.Nguyen: Update bet limit [Redmine ID: #160711]
            - 20211101@Aries.Nguyen: Fix clear data in queue incorect [Redmine ID: #164083]
            
		Param's Explanation (filtered by):
		Example: 
			- CALL CTS_DataCenter.CTS_DC_CustEvidenceQueue_Affected_Remove(@op_IsDataExist);
	*/    
	DECLARE lv_QueueID 		    BIGINT UNSIGNED;
    DECLARE lv_QueueID_Next     BIGINT UNSIGNED;
    DECLARE lv_QueueID_Sync 	BIGINT UNSIGNED;
    DECLARE lv_TotalAff 	    INT DEFAULT 0;
    DECLARE	lv_BatchSize 	    INT;
        
	DROP TEMPORARY TABLE IF EXISTS Temp_CustAffectedEvidence;    
	CREATE TEMPORARY TABLE Temp_CustAffectedEvidence(
			QueueID				BIGINT UNSIGNED
		,	CTSCustID			BIGINT UNSIGNED  
        ,	CTSCustID_Aff		BIGINT UNSIGNED
		,	CustEvidID			BIGINT UNSIGNED  
        ,	Created				DATETIME(3)
        ,	INDEX 				IX_Temp_CustAffectedEvidence_QueueID(QueueID)
        ,	INDEX 				IX_Temp_CustAffectedEvidence_CustEvidID(CustEvidID)
        ,	INDEX 				IX_Temp_CustAffectedEvidence_CTSCustID_Aff(CTSCustID_Aff)
    );

    SELECT ParameterValue 
    INTO lv_QueueID
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 32; 

    SELECT ParameterValue 
    INTO lv_BatchSize
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 42;

    SELECT MAX(tbl.ID)
    INTO lv_QueueID_Next
    FROM (SELECT ID
		  FROM CTS_DataCenter.CustEvidenceAffectedQueueRemove
		  WHERE ID >= lv_QueueID
		  ORDER BY ID ASC
		  LIMIT lv_BatchSize) AS tbl;

    IF lv_QueueID_Next IS NULL THEN
        SET op_IsDataExist = 0;
        LEAVE sp;
    END IF;
   
    INSERT INTO Temp_CustAffectedEvidence(QueueID, CTSCustID, CTSCustID_Aff, CustEvidID, Created)
    SELECT 	root.ID
		,	root.CTSCustID
        ,	aff.CTSCustID
		,	aff.CustEvidID
        ,	root.Created
	FROM CTS_DataCenter.CustEvidenceAffectedQueueRemove AS root,
	LATERAL(
        SELECT  ev.CTSCustID
            ,   ev.CustEvidID   
		FROM CTS_DataCenter.CustEvidence AS ev
		WHERE ev.FromCustID = root.CTSCustID 
            AND (root.EvidenceID IS NULL OR ev.EvidenceID = root.EvidenceID)
            AND ev.Level =  2
		LIMIT lv_BatchSize) AS aff
	WHERE root.ID BETWEEN  lv_QueueID AND lv_QueueID_Next
    ORDER BY root.ID ASC 
	LIMIT lv_BatchSize;
    
    /*********Sync Insert Remove Queue******/
	SELECT rm.QueueID
    INTO lv_QueueID_Sync
    FROM Temp_CustAffectedEvidence AS rm
    WHERE EXISTS (SELECT 1 
				  FROM CTS_DataCenter.CustEvidenceAffectedQueueInsert AS ins 
                  WHERE ins.CTSCustID = rm.CTSCustID 
					AND ins.Created <  rm.Created)
	ORDER BY  rm.QueueID ASC
    LIMIT 1;
    
    IF lv_QueueID_Sync IS NOT NULL THEN
		DELETE 
		FROM Temp_CustAffectedEvidence
		WHERE QueueID >= lv_QueueID_Sync;
        DO SLEEP(30); /*Sleep 30s wait queue insert completed*/
    END IF;
   
    /*****************************/
    
    
    SELECT COUNT(1)
    INTO lv_TotalAff
    FROM Temp_CustAffectedEvidence;

    IF lv_TotalAff = 0 THEN
         UPDATE CTS_DataCenter.SystemParameter 
         SET ParameterValue = 0
         WHERE ParameterID = 32; 

         IF lv_QueueID_Sync IS NULL THEN
             DELETE 
	         FROM CustEvidenceAffectedQueueRemove
             WHERE ID <= lv_QueueID_Next;
         ELSE
            DELETE 
			FROM CustEvidenceAffectedQueueRemove
			WHERE ID < lv_QueueID_Sync;
		END IF;

        IF EXISTS (SELECT 1 FROM CTS_DataCenter.CustEvidenceAffectedQueueRemove WHERE ID > lv_QueueID_Next) THEN
            SET op_IsDataExist = 1;
            LEAVE sp;
        END IF;
        
		SET op_IsDataExist = 0;
		LEAVE sp;
    END IF;
    
    DELETE 
    FROM CTS_DataCenter.CustEvidence AS ev
    WHERE EXISTS (SELECT 1 FROM Temp_CustAffectedEvidence AS aff WHERE aff.CustEvidID = ev.CustEvidID);
    
    SELECT MAX(QueueID)
    INTO lv_QueueID
    FROM Temp_CustAffectedEvidence;
    
    UPDATE CTS_DataCenter.SystemParameter 
    SET ParameterValue = lv_QueueID
    WHERE ParameterID = 32; 
    
    DELETE 
	FROM CTS_DataCenter.CustEvidenceAffectedQueueRemove
    WHERE ID < lv_QueueID;
    
    SELECT  DISTINCT
            cus.CustID 
    FROM Temp_CustAffectedEvidence AS cusEv
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cusEv.CTSCustID_Aff = cus.CTSCustID
    WHERE NOT EXISTS (SELECT 1 
				      FROM CTS_DataCenter.CustEvidence as ev 
                      WHERE ev.CTSCustID = cusEv.CTSCustID
					    AND NOT EXISTS (SELECT 1 
									    FROM CTS_DataCenter.CustRetractEvidence AS re 
									    WHERE re.CTSCustID = ev.CTSCustID 
										    AND re.EvidenceID = ev.EvidenceID));
    
	SET op_IsDataExist = 1;	
    
END$$

DELIMITER ;