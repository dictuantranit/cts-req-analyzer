/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustEvidence_InsertMultiple_ByCustId`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_InsertMultiple_ByCustId`(
        IN ip_NewAccountEvidences   JSON
    ,   IN ip_UserID                INT
    
    ,   OUT op_ErrorMessage         VARCHAR(200))
    SQL SECURITY INVOKER
sp: BEGIN
		/*
		Created:	20201001@Harvey.Nguyen
		Task:		Insert multiple customer-evidences by custId [Redmine ID: #134489]
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20200608@Long.Luu: Created [Redmine ID: #134489]
			- 20200807@Casey.Huynh: Chagne CustEvidence Structure for Cross Subscriber : Remove SubscriberID and IsCreatedByMaster [Redmine ID: #138925]
			- 20200824@Roger.Le: Evidence Upload - Overrite the data [Redmine ID: #137551]
			- 20201013@Long.Luu: Sync Evidence to Category [Redmine ID: #141756]
            - 20201020@Irena.Vo: Enhance logic Remove all category (Detail & General) [Redmine ID: #141756]
            - 20201111@Irena.Vo: Enhance logic Insert History for Evidence Category [Redmine ID: #145027]
			- 20201130@Irena.Vo: Enhance logic Insert new evidence (remove existed evidence category before) [Redmine ID: #141563]
			- 20201214-20210107@Irena.Vo: Move logic Sync to Category by new sp: SyncToCategory. Insert Error Log [RedmineID: #145951]
            - 20210622@Aries.Nguyen: Update coding convention and improve locking [Redmine ID: #157203]
            - 20210823@Aries.Nguyen: Enhannce  Affected Evidence flow [Redmine ID: #160470]
            - 20220421@Irena.Vo: Rename select CustId -> CustID [Redmine ID: #170468]
            - 20220426@Casey.Huynh: Return CreatedBy [Redmine ID: #171512]
        
        Example:
            - CALL CTS_DataCenter.CTS_DC_CustEvidence_InsertMultiple_ByCustId('[{"CustID": 43600693, "EvidenceID": 45, "Comment": "na test 1"},{"CustID":43600693, "EvidenceID": 46, "Comment":"na test 2"},{"CustID":43600889, "EvidenceID": 45, "Comment":"na test 3"}]', 8, @op_ErrorMessage);
    
	*/    
    DECLARE		lv_SPName 			VARCHAR(100) DEFAULT 'CTS_DC_CustEvidence_InsertMultiple_ByCustId';  
	DECLARE		lv_CurrentDateTime 	DATETIME DEFAULT CURRENT_TIME();
    DECLARE 	lv_CreatedBy        BIGINT DEFAULT 10278938;
    
	DECLARE	lv_No				INT			 DEFAULT 0;
    DECLARE lv_ErrorNo 			INT          DEFAULT 0;
    DECLARE lv_CodName 			TEXT         DEFAULT '0';

	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN   
		GET DIAGNOSTICS lv_No 	= 	NUMBER;
		GET DIAGNOSTICS CONDITION lv_No 
            op_ErrorMessage 	= 	MESSAGE_TEXT	
		,	lv_ErrorNo 			= 	MYSQL_ERRNO
		,	lv_CodName 			= 	RETURNED_SQLSTATE;
    
        INSERT INTO CTS_Log.CTSErrorLog(EventID, Message, Description)
        VALUES(7, op_ErrorMessage, JSON_OBJECT('err_no',lv_ErrorNo,'cod_name',lv_CodName,'parameter',ip_NewAccountEvidences));
    END;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_MultipleAccountEvidence;    
	CREATE TEMPORARY TABLE Temp_MultipleAccountEvidence(	 
			CustID			BIGINT UNSIGNED    
        ,   CTSCustID		BIGINT UNSIGNED     
        ,	SubscriberID	INT UNSIGNED
        , 	EvidenceID		SMALLINT UNSIGNED
        , 	Remark			VARCHAR(500)  
        , 	PRIMARY KEY	    PK_Temp_MultipleAccountEvidence_CustID_EvidenceID(CustID,EvidenceID) 
    );      

    DROP TEMPORARY TABLE IF EXISTS Temp_CustInfo;
    CREATE TEMPORARY TABLE Temp_CustInfo(
			CustID 	        BIGINT UNSIGNED
        ,	CTSCustID 	    BIGINT UNSIGNED
        , 	SubscriberID    INT
        ,   INDEX	        IX_Temp_CustInfo_CustID(CustID)
	);
    
    INSERT INTO Temp_MultipleAccountEvidence(CustID, EvidenceID, Remark)
	SELECT 	tmpTable.CustID
		, 	tmpTable.EvidenceID
		, 	tmpTable.Remark
	FROM JSON_TABLE(ip_NewAccountEvidences,
		 "$[*]" COLUMNS(
			  CustID 		BIGINT UNSIGNED		PATH "$.CustID"
			, EvidenceID	SMALLINT UNSIGNED	PATH "$.EvidenceID"
			, Remark		VARCHAR(500)		PATH "$.Comment"
		 )) AS tmpTable;  
  
    /*	GET CUSTOMER INFO	*/
    INSERT INTO Temp_CustInfo(CustID, CTSCustID, SubscriberID)
    SELECT  t.CustID
        ,   cus.CTSCustID
        ,   cus.SubscriberID
    FROM Temp_MultipleAccountEvidence AS t
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON t.CustID = cus.CustID AND cus.CustSubID = 0;

    UPDATE Temp_MultipleAccountEvidence AS t
	    INNER JOIN Temp_CustInfo AS cus ON t.CustID = cus.CustID 
    SET     t.CTSCustID = cus.CTSCustID
        ,   t.SubscriberID = cus.SubscriberID;
    
    /*	INSERT NEW FLAGGED EVIDENCE	*/
	INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID,  EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy)
	SELECT 	t.CTSCustID
		,	t.EvidenceID
        ,	t.Remark
        ,	0 
        ,	t.CTSCustID
        ,	lv_CurrentDateTime
        ,	ip_UserID
    FROM Temp_MultipleAccountEvidence AS t;
	   
    /*	INSERT NEW AFFECTED EVIDENCES	*/
    INSERT INTO CTS_DataCenter.CustEvidenceAffectedQueueInsert(CTSCustID,  EvidenceID, Remark, CreatedBy)
	SELECT 	t.CTSCustID
		,	t.EvidenceID
        ,	t.Remark
        ,	ip_UserID
    FROM Temp_MultipleAccountEvidence AS t;
    
     /*	WRITE LOG	*/
	INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	VALUES(3, lv_SPName, 'Insert bunch of Customer Evidences by CustId', lv_CurrentDateTime, ip_UserID);

	-- Return CustID, CTSCustID, SubscriberID, EvidenceID, 0 (ActionType)
    SELECT  DISTINCT 
            temp.CustID
        ,	temp.CTSCustID
        ,	temp.SubscriberID
        ,	temp.EvidenceID
        ,	0 AS ActionType
        ,	ip_UserID AS CreatedBy
    FROM Temp_MultipleAccountEvidence AS temp;

END$$

DELIMITER ;