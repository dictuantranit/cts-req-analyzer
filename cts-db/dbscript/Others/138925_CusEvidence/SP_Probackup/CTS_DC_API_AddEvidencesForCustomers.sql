CREATE DEFINER=`fps`@`%` PROCEDURE `CTS_DC_API_AddEvidencesForCustomers`(
		IN ip_CustIds 				VARCHAR(4000)
    ,   IN ip_EvidenceCodes 		VARCHAR(4000)
    
    , 	OUT op_ErrorMessage 		VARCHAR(200))
sp: BEGIN
	/*
		Created:	20200610@Long.Luu
		Task:		Insert multiple evidences for multiple customers [Redmine ID: 135585]
		DB:			CTS_DataCenter
		Original:

		Revisions:
		   - 20200610@Long.Luu: Created [Redmine ID: 135585]
	*/    
   /*
	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
  */
    DECLARE	vr_SPName 		VARCHAR(100) DEFAULT 'CTS_DC_API_AddEvidencesForCustomers';  
    DECLARE	vr_CreatedDate	DATETIME;      
    SET	vr_CreatedDate 		= CURRENT_TIME();
	SET @ip_IsCreatedByMaster = 1;
    SET @ip_UserID = 1027893;
     
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
    
    DROP TEMPORARY TABLE IF EXISTS tmpAccountList;
    CREATE TEMPORARY TABLE tmpAccountList (
			CustID			BIGINT UNSIGNED    
		,	CTSCustID		BIGINT UNSIGNED    
        ,	SubscriberID		INT UNSIGNED
    );
    
	SET @sql = CONCAT("INSERT INTO tmpAccountList (CustID) VALUES ('", REPLACE(ip_CustIds, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    DROP TEMPORARY TABLE IF EXISTS tmpEvidenceList;
    CREATE TEMPORARY TABLE tmpEvidenceList (
			EvidenceID		SMALLINT UNSIGNED    
        ,	EvidenceCode	VARCHAR(10)
    );
    
	SET @sql = CONCAT("INSERT INTO tmpEvidenceList (EvidenceCode) VALUES ('", REPLACE(ip_EvidenceCodes, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    # START
    SET SQL_SAFE_UPDATES = 0;
    UPDATE tmpAccountList AS t
		INNER JOIN CTS_DataCenter.CTSCustomer AS c ON t.CustID = c.CustID AND c.CustSubID = 0
    SET t.CTSCustID = c.CTSCustID
		,	t.SubscriberID = c.SubscriberID;
        
	UPDATE tmpEvidenceList AS t
		INNER JOIN CTS_DataCenter.Evidence AS c ON t.EvidenceCode = c.EvidenceCode
    SET t.EvidenceID = c.EvidenceID;    
    
    INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, SubscriberID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy, IsCreatedByMaster)
	SELECT 	t.CTSCustID
		,	t.SubscriberID
		,	e.EvidenceID
        ,	''
        ,	0 
        ,	t.CTSCustID
        ,	vr_CreatedDate
        ,	@ip_UserID
        ,	@ip_IsCreatedByMaster
    FROM tmpAccountList AS t
		CROSS JOIN tmpEvidenceList AS e;
    
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;       
    INSERT INTO tmpAffectedDevices(CTSCustID, DCSDeviceID)
    SELECT DISTINCT t.CTSCustID, a.DCSDeviceID
    FROM CTS_DataCenter.AssociationByDevice AS a    
		INNER JOIN tmpAccountList AS t ON a.CTSCustID = t.CTSCustID AND a.SubscriberID = t.SubscriberID;

    INSERT INTO tmpAssociationException(FromCTSCustID, ToCTSCustID)
    SELECT DISTINCT t.CTSCustID
		,	CASE WHEN e.LeastCTSCustID_Order = t.CTSCustID THEN e.GreatestCTSCustID_Order ELSE e.LeastCTSCustID_Order END
    FROM CTS_DataCenter.CustException AS e
		INNER JOIN tmpAccountList AS t ON e.LeastCTSCustID_Order = t.CTSCustID
													OR e.GreatestCTSCustID_Order = t.CTSCustID;
    
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;    
	INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, SubscriberID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy, IsCreatedByMaster)
    SELECT DISTINCT a.CTSCustID, c.SubscriberID, ev.EvidenceID, '', 2, t.CTSCustID, vr_CreatedDate, @ip_UserID, @ip_IsCreatedByMaster
    FROM tmpAccountList AS t
		INNER JOIN tmpAffectedDevices AS d ON t.CTSCustID = d.CTSCustID
		INNER JOIN CTS_DataCenter.AssociationByDevice AS a ON a.DCSDeviceID = d.DCSDeviceID
        LEFT JOIN CTS_DataCenter.CTSCustomer AS c ON a.CTSCustID = c.CTSCustID AND c.CustSubID = 0
        LEFT JOIN tmpAssociationException AS e ON t.CTSCustID = e.FromCTSCustID AND a.CTSCustID = e.ToCTSCustID
        CROSS JOIN tmpEvidenceList AS ev
	WHERE a.CTSCustID <> d.CTSCustID		
    	AND (e.FromCTSCustID IS NULL OR e.ToCTSCustID IS NULL);
    
	INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	VALUES(3, vr_SPName, 'Insert bunch of Customers - Evidences', vr_CreatedDate, @ip_UserID);
    
END