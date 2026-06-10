CREATE DEFINER=`fps`@`%` PROCEDURE `CTS_DC_TransformAssociation_AffectedEvidence`(IN ip_Batch INT)
BEGIN
	/*
		Created:	20200123@Casey.Huynh	
		Task :		Place Affected Evidence for New AssociationByDevice
		DB:			CTS_DataCenter
		Original: 
		Revisions:	
					[20200303@Casey.Huynh]. Update Affected CreateBy = Root CreatedBy
                    [20200805@Casey.Huynh]: Update Bussiness affect Crosssub and correct update value LastCTSAssDevID
		Param's Explanation (filtered by):
	*/
    
    #===0.Declare==========================================================================================
    DECLARE	vr_LastCTSAssDevID BIGINT UNSIGNED;
    DECLARE	vr_CreatedDate	DATETIME;
	### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200) DEFAULT 'CTS_DC_TransformAssociation_AffectedEvidence' ;
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
    
    SET	vr_CreatedDate = CURRENT_TIME();
    
	DROP TEMPORARY TABLE IF EXISTS TempAssociationByDevice;    
	CREATE TEMPORARY TABLE TempAssociationByDevice
	( 	
		CTSAssDevID		BIGINT	UNSIGNED
        , FromCTSCustID	BIGINT	UNSIGNED
        , DCSDeviceID	BIGINT	UNSIGNED
        , FromSubscriberID	INT
	);
	
	DROP TEMPORARY TABLE IF EXISTS TempCustAssociation;    
	CREATE TEMPORARY TABLE TempCustAssociation
	( 	
		
		FromCTSCustID		BIGINT	UNSIGNED
        , FromSubscriberID	INT
        , ToCTSCustID		BIGINT	UNSIGNED
        , ToSubscriberID	INT
	);	
    
	#===1. GET List of New Association=====================================================================
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;

    SET vr_LastCTSAssDevID = (SELECT LastCTSAssDevID FROM CTS_DataCenter.ProcessAffectedEvidence LIMIT 1);
    
    INSERT INTO TempAssociationByDevice(CTSAssDevID, FromCTSCustID, DCSDeviceID, FromSubscriberID)
    SELECT		ad.CTSAssDevID
				, ad.CTSCustID		AS FromCTSCustID
                , ad.DCSDeviceID
                , ad.SubscriberID
    FROM		CTS_DataCenter.AssociationByDevice AS ad
	WHERE		ad.CTSAssDevID > vr_LastCTSAssDevID
    LIMIT		ip_Batch;    
    
    #===2.GET CTSCust Association with Step1 (CTSCust, Device, Subscriber)=================================
    INSERT INTO	TempCustAssociation(FromCTSCustID, FromSubscriberID, ToCTSCustID, ToSubscriberID)
    SELECT		DISTINCT tmp_ad.FromCTSCustID
						, tmp_ad.FromSubscriberID
						, ad.CTSCustID AS ToCTSCustID
						, ad.SubscriberID
	FROM		TempAssociationByDevice	AS tmp_ad
    INNER JOIN	CTS_DataCenter.AssociationByDevice AS ad
				ON tmp_ad.DCSDeviceID = ad.DCSDeviceID
	WHERE		tmp_ad.FromCTSCustID <> ad.CTSCustID;
    
    DELETE 		tmp_ca
    FROM		TempCustAssociation 			AS tmp_ca
    INNER JOIN	CTS_DataCenter.CustException	AS ce
				ON	ce.LeastCTSCustID_Order = LEAST(tmp_ca.FromCTSCustID, tmp_ca.ToCTSCustID)
					AND GreatestCTSCustID_Order = GREATEST(tmp_ca.FromCTSCustID, tmp_ca.ToCTSCustID);
                    
                   
    #===3. Place Affected Evidence Level 0  Of (FromCTSCust) for (ToCTSCust)===============================
    IF EXISTS (SELECT 1 FROM TempCustAssociation LIMIT 1) THEN        
		INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, SubscriberID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy, IsCreatedByMaster)
		SELECT	tmp_ca.ToCTSCustID
				, tmp_ca.ToSubscriberID
				, ce.EvidenceID
				, 'Auto New AssDev' AS Remark
				, 2 				AS Level
				, tmp_ca.FromCTSCustID
				, vr_CreatedDate	AS CreatedDate
				, ce.CreatedBy 		AS CreatedBy
                , ce.IsCreatedByMaster 
		FROM		CTS_DataCenter.CustEvidence	AS ce
		INNER JOIN	TempCustAssociation AS tmp_ca
					ON		ce.CTSCustID 	= tmp_ca.FromCTSCustID
		WHERE		ce.CTSCustID	= tmp_ca.FromCTSCustID
					AND ce.Level	= 0;    
			
    #===4. Place Affected Evidence Of Level 0 (ToCTSCust) for (ToCTSCust)==================================
		INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, SubscriberID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy, IsCreatedByMaster)
			SELECT	tmp_ca.FromCTSCustID
					, tmp_ca.FromSubscriberID
					, ce.EvidenceID
					, 'Auto New AssDev' AS Remark
					, 2 				AS Level
					, tmp_ca.ToCTSCustID
					, vr_CreatedDate	AS CreatedDate
					, ce.CreatedBy 		AS CreatedBy
                    , ce.IsCreatedByMaster
			FROM		CTS_DataCenter.CustEvidence	AS ce
			INNER JOIN	TempCustAssociation AS tmp_ca
						ON	ce.CTSCustID = tmp_ca.ToCTSCustID
			WHERE		ce.CTSCustID	= tmp_ca.ToCTSCustID
						AND ce.Level	= 0;	                        

	END IF;
    
	#=====Update ProcessAffectedEvidence ===============================================
    UPDATE	CTS_DataCenter.ProcessAffectedEvidence
    SET		LastCTSAssDevID = (SELECT IFNULL(MAX(CTSAssDevID),LastCTSAssDevID) FROM TempAssociationByDevice);
    
	
    ### PERFORMANCE
	SET	vrEndTime = CURRENT_TIMESTAMP(4);
    
    SELECT 	Count(1), Min(tts.CTSAssDevID), Max(tts.CTSAssDevID)
    INTO	vrTotalRecord, vrFromID, vrToID
    FROM	TempAssociationByDevice AS tts;
    
    UPDATE	DCS_DataCenter.zzTracePerformance AS z
    SET		z.EndTime = vrEndTime
			, z.Duration = TIMESTAMPDIFF(MICROSECOND, vrStartTime, vrEndTime)
            , z.TotalRecord = vrTotalRecord
            , z.FromID = vrFromID
            , z.ToID		= vrToID
    WHERE	z.ExecKey = vrExecKey AND z.StepID = vrStepID;
    ### PERFORMANCE: END
	SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ ;
END