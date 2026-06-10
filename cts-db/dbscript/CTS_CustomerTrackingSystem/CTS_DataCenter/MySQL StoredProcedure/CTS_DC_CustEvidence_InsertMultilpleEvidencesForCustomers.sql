/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsAPIAdmin" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustEvidence_InsertMultilpleEvidencesForCustomers`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_InsertMultilpleEvidencesForCustomers`(
        IN ip_CustIds           VARCHAR(4000)
    ,   IN ip_EvidenceCodes     VARCHAR(4000)
    ,	IN ip_CreatedBy			INT

    ,   OUT op_ErrorMessage     VARCHAR(200)
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20200610@Long.Luu
		Task:		Insert multiple evidences for multiple customers [Redmine ID: #135585]
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20200610@Long.Luu: Created [Redmine ID: #135585] 
            - 20201013@Long.Luu: Sync Evidence to Category [Redmine ID: #141756]
            - 20201020@Irena.Vo: Enhance logic Remove all category (Detail & General) [Redmine ID: #141756]
            - 20201111@Irena.Vo: Enhance logic Insert History for Evidence Category [Redmine ID: #145027]
            - 20201130@Irena.Vo: Enhance logic Insert new evidence (remove existed evidence category before) [Redmine ID: #141563]
			- 20201214-20210107@Irena.Vo: Move logic Sync to Category by new sp: SyncToCategory. Insert Error Log. Remove User Log [RedmineID: #145951] 
            - 20210622@Aries.Nguyen: Update coding convention and improve locking [Redmine ID: #157203]
            - 20210823@Aries.Nguyen: Enhannce  Affected Evidence flow [Redmine ID: #160470]
            - 20220421@Irena.Vo: Rename select CustId -> CustID [Redmine ID: #170468]
            - 20220426@Casey.Huynh: Return CreatedBy [Redmine ID: #171512]
            
		Param's Explanation(filered by):
		
		Example:
            -CALL CTS_DataCenter.CTS_DC_CustEvidence_InsertMultilpleEvidencesForCustomers('43600693,43600889', '6.1', 8, @op_ErrorMessage);
	*/    
	DECLARE		lv_CurrentDateTime 	DATETIME DEFAULT CURRENT_TIME();
    DECLARE		lv_SPName VARCHAR(200) DEFAULT 'CTS_DC_CustEvidence_InsertMultilpleEvidencesForCustomers';
    
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
        VALUES(5, op_ErrorMessage, JSON_OBJECT('err_no',lv_ErrorNo,'cod_name',lv_CodName,'parameter1',ip_CustIds,'parameter2',ip_EvidenceCodes));
    END;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustomerList;
    CREATE TEMPORARY TABLE Temp_CustomerList (
			CustID			BIGINT UNSIGNED 
		,	CTSCustID		BIGINT UNSIGNED    
        ,	SubscriberID	INT
    );

    DROP TEMPORARY TABLE IF EXISTS Temp_CustID;
    CREATE TEMPORARY TABLE Temp_CustID (
			CustID			BIGINT UNSIGNED 
        ,   INDEX           IX_Temp_CustID_CustID(CustID)
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_EvidenceList;
    CREATE TEMPORARY TABLE Temp_EvidenceList (
			EvidenceID		SMALLINT UNSIGNED
        ,	EvidenceCode	VARCHAR(10)
    );

	SET @sql = CONCAT("INSERT INTO Temp_CustID (CustID) VALUES ('", REPLACE(ip_CustIds, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
	SET @sql = CONCAT("INSERT INTO Temp_EvidenceList (EvidenceCode) VALUES ('", REPLACE(ip_EvidenceCodes, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
	
    /*	GET CUSTOMER INFO	*/
    INSERT INTO Temp_CustomerList(CustID, CTSCustID, SubscriberID)
    SELECT  t.CustID
        ,   c.CTSCustID
        ,   c.SubscriberID
    FROM Temp_CustID AS t
        LEFT JOIN 	CTS_DataCenter.CTSCustomer AS c ON t.CustID = c.CustID AND c.CustSubID = 0;
    
	/*	GET EVIDENCE INFO	*/
	UPDATE 		Temp_EvidenceList AS t
	    INNER JOIN 	CTS_DataCenter.Evidence AS c ON t.EvidenceCode = c.EvidenceCode
    SET 		t.EvidenceID = c.EvidenceID;    
    
    /*	INSERT NEW FLAGGED EVIDENCE FOR CUSTOMERS	*/
    INSERT IGNORE INTO CTS_DataCenter.CustEvidence(CTSCustID, EvidenceID, Level, FromCustID, CreatedDate, CreatedBy)
	SELECT 	t.CTSCustID
		,	e.EvidenceID
        ,	0 
        ,	t.CTSCustID
        ,	lv_CurrentDateTime
        ,	ip_CreatedBy
    FROM 	Temp_CustomerList AS t 
        CROSS JOIN Temp_EvidenceList AS e;
   
   /*	INSERT NEW AFFECTED EVIDENCE FOR CUSTOMERS	*/
   INSERT INTO CTS_DataCenter.CustEvidenceAffectedQueueInsert(CTSCustID,  EvidenceID, CreatedBy)
   SELECT 	t.CTSCustID
		,	e.EvidenceID
        ,	ip_CreatedBy
   FROM Temp_CustomerList AS t 
        CROSS JOIN Temp_EvidenceList AS e;
   
    -- Return CustID, CTSCustID, SubscriberID, EvidenceID, 0 (ActionType)
    SELECT  DISTINCT 
            cust.CustID
	    ,	cust.CTSCustID
        ,	cust.SubscriberID
        ,	ev.EvidenceID
        ,	0 AS ActionType
        ,	ip_CreatedBy AS CreatedBy
    FROM Temp_CustomerList AS cust 
        CROSS JOIN  Temp_EvidenceList AS ev;
	
    /*WRITE LOG*/
	INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	VALUES(3, lv_SPName, 'Insert Multiple Evidences for Customers ',lv_CurrentDateTime,ip_CreatedBy);
END$$

DELIMITER ;