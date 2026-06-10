CREATE DEFINER=`fps`@`%` PROCEDURE `CTS_DC_AddMultiCustomerEvidence`(
		IN ip_NewAccountEvidences 	JSON    
    ,	IN ip_UserID 				INT
    ,	IN ip_IsCreatedByMaster 	BOOL
    
    , 	OUT op_ErrorMessage 		VARCHAR(200))
sp: BEGIN
	/*
		Created:	20200608@Long.Luu
		Task:		Insert multiple customer-evidences [Redmine ID: 134489]
		DB:			CTS_DataCenter
		Original:

		Revisions:
		   - 20200608@Long.Luu: Created [Redmine ID: 134489]
	*/    
   /*
	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
  */
  
    DECLARE	vr_SPName 		VARCHAR(100) DEFAULT 'CTS_DC_AddMultiCustomerEvidence';  
    DECLARE	vr_CreatedDate	DATETIME;      
    SET	vr_CreatedDate 		= CURRENT_TIME();
     
    DROP TEMPORARY TABLE IF EXISTS tmpMultipleAccountEvidence;    
	CREATE TEMPORARY TABLE tmpMultipleAccountEvidence 
    (	 
			CTSCustID		BIGINT UNSIGNED     
		,	SubscriberID	INT UNSIGNED
        , 	EvidenceID		SMALLINT UNSIGNED
        , 	Remark			VARCHAR(500)  
        , 	PRIMARY KEY	tmpMultipleAccountEvidence(CTSCustID,EvidenceID) 
    );      
    
	DROP TABLE IF EXISTS tmpAssociationException;
    CREATE TEMPORARY TABLE tmpAssociationException(
			FromCTSCustID 	BIGINT UNSIGNED
        ,	ToCTSCustID 	BIGINT UNSIGNED
        , 	PRIMARY KEY	tmpAssociationException(FromCTSCustID,ToCTSCustID)
	);
    
    DROP TABLE IF EXISTS tmpAffectedDevices;
    CREATE TEMPORARY TABLE tmpAffectedDevices(
			CTSCustID		BIGINT UNSIGNED     
		,	DCSDeviceID		BIGINT UNSIGNED
        , 	PRIMARY KEY	tmpAffectedDevices(CTSCustID,DCSDeviceID) 
	);
    
    INSERT INTO tmpMultipleAccountEvidence(CTSCustID, EvidenceID, Remark)
	SELECT 	tmpTable.CTSCustID
		, 	tmpTable.EvidenceID
		, 	tmpTable.Remark
	FROM JSON_TABLE(ip_NewAccountEvidences,
		 "$[*]" COLUMNS(
			  CTSCustID 	BIGINT UNSIGNED		PATH "$.CTSCustID"
			, EvidenceID	SMALLINT UNSIGNED	PATH "$.EvidenceID"
			, Remark		VARCHAR(500)		PATH "$.Comment"
		 )) AS tmpTable;  
         
	IF EXISTS (	SELECT 1 
				FROM tmpMultipleAccountEvidence AS t 
					LEFT JOIN CTS_DataCenter.CustEvidence AS ce ON t.CTSCustID = ce.CTSCustID AND t.EvidenceID = ce.EvidenceID
				WHERE ce.CTSCustID IS NOT NULL
					AND ce.EvidenceID IS NOT NULL
                    AND Level = 0) THEN
		SET op_ErrorMessage = 'This Customer has already been flagged with this Evidence.';
		LEAVE sp;
	END IF;
     
	SET SQL_SAFE_UPDATES = 0;
    UPDATE tmpMultipleAccountEvidence AS t
		INNER JOIN CTS_DataCenter.CTSCustomer AS c ON t.CTSCustID = c.CTSCustID
    SET t.SubscriberID = c.SubscriberID;
      
	INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, SubscriberID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy, IsCreatedByMaster)
	SELECT 	t.CTSCustID
		,	t.SubscriberID
		,	t.EvidenceID
        ,	t.Remark
        ,	0 
        ,	t.CTSCustID
        ,	vr_CreatedDate
        ,	ip_UserID
        ,	ip_IsCreatedByMaster
    FROM tmpMultipleAccountEvidence AS t;
	
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;       
    INSERT INTO tmpAffectedDevices(CTSCustID, DCSDeviceID)
    SELECT DISTINCT t.CTSCustID, a.DCSDeviceID
    FROM CTS_DataCenter.AssociationByDevice AS a    
		INNER JOIN tmpMultipleAccountEvidence AS t ON a.CTSCustID = t.CTSCustID AND a.SubscriberID = t.SubscriberID;

    INSERT INTO tmpAssociationException(FromCTSCustID, ToCTSCustID)
    SELECT DISTINCT t.CTSCustID
		,	CASE WHEN e.LeastCTSCustID_Order = t.CTSCustID THEN e.GreatestCTSCustID_Order ELSE e.LeastCTSCustID_Order END
    FROM CTS_DataCenter.CustException AS e
		INNER JOIN tmpMultipleAccountEvidence AS t ON e.LeastCTSCustID_Order = t.CTSCustID
													OR e.GreatestCTSCustID_Order = t.CTSCustID;
    
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;    
	INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, SubscriberID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy, IsCreatedByMaster)
    SELECT DISTINCT a.CTSCustID, c.SubscriberID, t.EvidenceID, t.Remark, 2, t.CTSCustID, vr_CreatedDate, ip_UserID, ip_IsCreatedByMaster
    FROM tmpMultipleAccountEvidence AS t
		INNER JOIN tmpAffectedDevices AS d ON t.CTSCustID = d.CTSCustID
		INNER JOIN CTS_DataCenter.AssociationByDevice AS a ON a.DCSDeviceID = d.DCSDeviceID
        LEFT JOIN CTS_DataCenter.CTSCustomer AS c ON a.CTSCustID = c.CTSCustID
        LEFT JOIN tmpAssociationException AS e ON t.CTSCustID = e.FromCTSCustID AND a.CTSCustID = e.ToCTSCustID
	WHERE a.CTSCustID <> d.CTSCustID		
    	AND (e.FromCTSCustID IS NULL OR e.ToCTSCustID IS NULL);
    
	INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	VALUES(3, vr_SPName, 'Insert bunch of Customer Evidences', vr_CreatedDate, ip_UserID);
END