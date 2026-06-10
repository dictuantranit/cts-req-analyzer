/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustEvidence_InsertFromAssociation`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_InsertFromAssociation`()
    SQL SECURITY INVOKER
sp : BEGIN
	/*
		Created:	20200123@Casey.Huynh	
		Task :		Place Affected Evidence for New AssociationByDevice
		DB:			CTS_DataCenter
		Original:
		
		Revisions:	
			- 20200303@Casey.Huynh: Update Affected CreateBy = Root CreatedBy
			- 20200805@Casey.Huynh: Update Bussiness affect Crosssub and correct update value LastCTSAssDevID
			- 20200807@Casey.Huynh:[138925] Chagne CustEvidence Structure for Cross Subscriber : Remove SubscriberID and IsCreatedByMaster
			- 20200821@Casey.Huynh:[140100]: Return CustID is added affected evidence
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			- 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
			- 20210823@Aries.Nguyen: Enhannce  Affected Evidence flow [Redmine ID: #160470]
			- 20210909@Aries.Nguyen: Update bet limit [Redmine ID: #160711]
			- 20211001@Aries.Nguyen: Get batch size from sys parameter table [Redmine ID: #164083]

		Param's Explanation (filtered by):
	*/
    
    DECLARE	lv_LastCTSAssDevID BIGINT UNSIGNED;
    DECLARE	lv_LastCTSCustIDAff BIGINT UNSIGNED;
    DECLARE lv_TotalAff 		INT DEFAULT 0;
    DECLARE lv_SecondBatchSize 	INT DEFAULT 0;
	DECLARE	lv_BatchSize		INT DEFAULT 1000;

  
    DROP TEMPORARY TABLE IF EXISTS   Temp_AssociatedException;
    CREATE TEMPORARY TABLE Temp_AssociatedException(
			FromCTSCustID 	BIGINT UNSIGNED
        ,	ToCTSCustID 	BIGINT UNSIGNED
        , 	PRIMARY KEY		PK_Temp_AssociatedException_FromCTSCustID_ToCTSCustID(FromCTSCustID,ToCTSCustID)
	);

    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustAffectedEvidence;    
	CREATE TEMPORARY TABLE Temp_CustAffectedEvidence( 	
			CTSAssDevID			BIGINT	UNSIGNED
        ,	CTSCustID			BIGINT	UNSIGNED
        ,	CTSCustID_Affected	BIGINT	UNSIGNED
		,	INDEX				IX_Temp_CustAffectedEvidence_CTSAssDevID(CTSAssDevID)
		,	INDEX				IX_Temp_CustAffectedEvidence_CTSCustID_Affected(CTSCustID,CTSCustID_Affected)
	);
    
    DROP TEMPORARY TABLE IF EXISTS   Temp_AffectedExisted;
    CREATE TEMPORARY TABLE Temp_AffectedExisted(
			CTSCustID 		BIGINT UNSIGNED
		,	FromCustID		BIGINT UNSIGNED	
        ,	EvidenceID		SMALLINT
        , 	PRIMARY KEY(CTSCustID, FromCustID, EvidenceID)
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustEvidence;    
	CREATE TEMPORARY TABLE Temp_CustEvidence(
			CTSCustID			BIGINT UNSIGNED					
		,	EvidenceID			SMALLINT								
		,	Remark				VARCHAR(500)	
		,	Level				TINYINT									
		,	FromCustID			BIGINT UNSIGNED					
		,	CreatedDate			DATETIME								
		,	CreatedBy			INT										
        ,	PRIMARY KEY			PK_CustEvidence(CTSCustID, FromCustID, EvidenceID)
	);
    
	#===1. GET List of New Association=====================================================================
	SELECT ParameterValue 
    INTO lv_BatchSize
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 61;


    SELECT ParameterValue 
    INTO lv_LastCTSAssDevID
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 33; 
    
    SELECT ParameterValue 
    INTO lv_LastCTSCustIDAff
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 34;
    
    INSERT INTO Temp_CustAffectedEvidence(CTSAssDevID, CTSCustID, CTSCustID_Affected)
    SELECT 	dv.CTSAssDevID
		,	dv.CTSCustID
        ,	aff.CTSCustID
	FROM CTS_DataCenter.AssociationByDevice AS dv,
	LATERAL
		(SELECT ass.CTSCustID
		 FROM CTS_DataCenter.AssociationByDevice AS ass
		 WHERE dv.DCSDeviceID = ass.DCSDeviceID 
			AND dv.CTSCustID != ass.CTSCustID
			AND ass.CTSCustID > lv_LastCTSCustIDAff
		 ORDER BY ass.DCSDeviceID ASC, ass.CTSCustID ASC
		 LIMIT lv_BatchSize) AS aff
	WHERE dv.CTSAssDevID = lv_LastCTSAssDevID 
	LIMIT lv_BatchSize;
    
    SELECT COUNT(1)
    INTO lv_TotalAff
    FROM Temp_CustAffectedEvidence;   
    
    IF lv_BatchSize > lv_TotalAff THEN
		SET lv_SecondBatchSize = lv_BatchSize - lv_TotalAff;
        
        INSERT INTO Temp_CustAffectedEvidence(CTSAssDevID, CTSCustID, CTSCustID_Affected)
		SELECT 	dv.CTSAssDevID
			,	dv.CTSCustID
			,	aff.CTSCustID
		FROM CTS_DataCenter.AssociationByDevice AS dv,
		LATERAL
			(SELECT ass.CTSCustID
			 FROM CTS_DataCenter.AssociationByDevice AS ass
			 WHERE dv.DCSDeviceID = ass.DCSDeviceID AND   dv.CTSCustID != ass.CTSCustID
             ORDER BY ass.DCSDeviceID ASC, ass.CTSCustID ASC
			 LIMIT lv_SecondBatchSize) AS aff
		WHERE dv.CTSAssDevID > lv_LastCTSAssDevID  
        ORDER BY dv.CTSAssDevID ASC
		LIMIT lv_SecondBatchSize;
        
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM Temp_CustAffectedEvidence) THEN
		LEAVE sp;
    END IF;
    
    SELECT MAX(CTSAssDevID)
    INTO lv_LastCTSAssDevID
    FROM Temp_CustAffectedEvidence;
    
    SELECT MAX(CTSCustID_Affected)
    INTO lv_LastCTSCustIDAff
    FROM Temp_CustAffectedEvidence
    WHERE CTSAssDevID = lv_LastCTSAssDevID;
	
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
    
	INSERT IGNORE INTO Temp_CustEvidence(CTSCustID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy)
	SELECT	aff.CTSCustID_Affected
		,	ce.EvidenceID
		,	'Auto New AssDev' AS Remark
		,	2 AS Level
		,	aff.CTSCustID
		,	NOW() AS CreatedDate
		,	ce.CreatedBy AS CreatedBy
	FROM CTS_DataCenter.CustEvidence AS ce USE INDEX FOR JOIN (IX_CustEvidence_Level_CTSCustID)
		INNER JOIN	Temp_CustAffectedEvidence AS aff ON ce.CTSCustID = aff.CTSCustID AND ce.Level = 0;
	
    INSERT IGNORE INTO Temp_CustEvidence(CTSCustID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy)
	SELECT	aff.CTSCustID
		,	ce.EvidenceID
		,	'Auto New AssDev' AS Remark
		,	2 AS Level
		,	aff.CTSCustID_Affected
		,	NOW() AS CreatedDate
		,	ce.CreatedBy AS CreatedBy
	FROM CTS_DataCenter.CustEvidence AS ce USE INDEX FOR JOIN (IX_CustEvidence_Level_CTSCustID)
		INNER JOIN	Temp_CustAffectedEvidence AS aff ON ce.CTSCustID = aff.CTSCustID_Affected AND ce.Level = 0;  
			
    INSERT IGNORE INTO Temp_AffectedExisted(CTSCustID,FromCustID, EvidenceID)
    SELECT CTSCustID,FromCustID, EvidenceID
    FROM  CTS_DataCenter.CustEvidence AS ev
    WHERE EXISTS (SELECT 1 
				  FROM Temp_CustEvidence AS aff
				  WHERE aff.CTSCustID = ev.CTSCustID
					AND	aff.FromCustID = ev.FromCustID
                    AND aff.EvidenceID = ev.EvidenceID);
    
    DELETE 
    FROM Temp_CustEvidence AS ev
    WHERE EXISTS (SELECT 1 
				  FROM Temp_AffectedExisted AS ex 
                  WHERE ev.CTSCustID = ex.CTSCustID 
					AND ev.FromCustID = ex.FromCustID
                    AND ev.EvidenceID = ex.EvidenceID);
    
    INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy)
	SELECT	tce.CTSCustID
		,	tce.EvidenceID
		,	tce.Remark
		,	tce.Level
		,	tce.FromCustID
		,	tce.CreatedDate
		,	tce.CreatedBy
	FROM	Temp_CustEvidence	AS tce;
    
    UPDATE CTS_DataCenter.SystemParameter 
    SET ParameterValue = lv_LastCTSAssDevID
    WHERE ParameterID = 33; 
	
    UPDATE CTS_DataCenter.SystemParameter 
    SET ParameterValue = lv_LastCTSCustIDAff
    WHERE ParameterID = 34; 

	SELECT	DISTINCT
            cus.CustID 
	FROM Temp_CustEvidence AS cusEv
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cusEv.CTSCustID = cus.CTSCustID;


END$$

DELIMITER ;