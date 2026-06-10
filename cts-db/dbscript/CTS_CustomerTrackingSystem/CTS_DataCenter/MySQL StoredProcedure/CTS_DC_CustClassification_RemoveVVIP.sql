/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin,ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_RemoveVVIP`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_CustClassification_RemoveVVIP`(
    	IN ip_FromAction		TINYINT
	,	IN ip_UplineRoleID		TINYINT
    ,	IN ip_QueueID			BIGINT
    ,	IN ip_AffectDownline	BOOLEAN
    ,	IN ip_CustJson			JSON
    
    , 	OUT op_ErrorMessage 	VARCHAR(200)
)
    SQL SECURITY INVOKER 
BEGIN
	/*
		Created:	20200423@Long.Luu	
		Task :		Insert CTSCustomer Category
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20200423@Long.Luu: Created [Redmine ID: #132623]
            - 20200908@Irena.Vo: Delete VVIP OR All Category has Pin before (Include Customer Class) [Redmine ID: #141020]
            - 20200921@Irena.Vo: Enhance SP & insert Probation Management flow [Redmine ID: #141755]
			- 20200923@Irena.Vo: Enhance SP [Redmine ID: #141755]
            - 20201201@Aries.Nguyen: Update metadata for goSQL. Remove transaction isolation level REPEATABLE READ and READ UNCOMMITTED. Remove logic detail category. [Redmine ID: #145954]
            - 20201214-20201229@Irena.Vo: Insert History Log & Auto Unpin category. Insert Error Log [RedmineID: #145951]
            - 20210226@Irena.Vo: Update CategoryID from VVIP [RedmineID: #150454]
			- 20210525@Irena.Vo: Change col name PinCustomerCategory: CustID -> CTSCustID [RedmineID: #152965] 
			- 20210920@Aries.Nguyen: Split history log  [Redmine ID: #161890]
            - 20220418@Casey.Huynh: Add and Remove VVIP for Downline [Redmine ID: #159013]
            
		Param's Explanation:
			ip_FromAction: 1 From Web, 2 From Service
	*/ 
    DECLARE lv_CurrentDateTime 	DATETIME DEFAULT CURRENT_TIME();
    DECLARE lv_SPName 			VARCHAR(200) DEFAULT 'CTS_DC_CustClassification_RemoveVVIP';
	DECLARE	lv_CategoryID		INT DEFAULT 210;
    DECLARE lv_SportGroupID		INT DEFAULT 200;
    DECLARE lv_LogTypeID		INT DEFAULT 10;
    DECLARE lv_ActionType		INT DEFAULT 2; 
	DECLARE lv_IsAuto			INT DEFAULT 0;
    DECLARE lv_TargetCC			INT DEFAULT -1; 
    DECLARE lv_IsDataChanged	INT DEFAULT 1;     
    DECLARE lv_MaxCTSCustID		BIGINT UNSIGNED;
    DECLARE lv_SourceTypeID		INT;    
    
  
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
 

    DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
	CREATE TEMPORARY TABLE 		Temp_Customer (
		 	CustID			BIGINT UNSIGNED		
         ,  CTSCustID 		BIGINT UNSIGNED
         ,	CreatedBy		BIGINT UNSIGNED
         
         ,	PRIMARY KEY PK_Temp_Customer(CustID)
         ,	INDEX IX_Temp_Customer_CTSCustID(CTSCustID)
	);

	#INSERT INTO CTS_Log.CTSLog(SPName, InsertTime, OtherText ,JsonString1,JsonString2,JsonString3)
	#SELECT 'CTS_DC_CustClassification_RemoveVVIP', current_timestamp(3), CONCAT('ip_FromAction:',ip_FromAction,'; ip_UplineRoleID:',ip_UplineRoleID,'; ip_QueueID:',ip_QueueID,'; ip_AffectDownline:',ip_AffectDownline),ip_CustJson,NULL,NULL;
    
    /**************************************************************************************/
    INSERT INTO Temp_Customer(CustID, CTSCustID, CreatedBy) 
	SELECT 	DISTINCT temp.CustID, temp.CTSCustID, temp.CreatedBy
	FROM JSON_TABLE(ip_CustJson,
		 "$[*]" COLUMNS(
				CustID 		BIGINT UNSIGNED		PATH "$.CustID"
			,	CTSCustID 	BIGINT UNSIGNED		PATH "$.CTSCustID"
            ,	CreatedBy 	BIGINT UNSIGNED		PATH "$.CreatedBy"
            
		 )) AS temp;      

	SELECT MAX(tmpCus.CTSCustID)
    INTO lv_MaxCTSCustID
    FROM Temp_Customer AS tmpCus;
    
    /****SET SourceTypeID for write log******/
    SET lv_SourceTypeID = 	CASE 	WHEN ip_FromAction = 1 THEN 14
									WHEN ip_FromAction = 2 AND ip_UplineRoleID = 4 THEN 27
									WHEN ip_FromAction = 2 AND ip_UplineRoleID = 3 THEN 28
									WHEN ip_FromAction = 2 AND ip_UplineRoleID = 2 THEN 29
							END;   
                            
    /*************************************Remove VVIP*************************************/
	DELETE cls
    FROM CTS_DataCenter.CTSCustomerClassification AS cls
		INNER JOIN Temp_Customer AS tmpCus ON cls.CustID = tmpCus.CustID AND cls.CategoryID = lv_CategoryID;    	
	
	INSERT INTO CTS_DataCenter.CTSCustomerClassification_History(CustID, CTSCustID, CategoryID, SportGroupID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged)
	SELECT 	tmpCus.CustID
		, 	tmpCus.CTSCustID
		,   lv_CategoryID AS CategoryID
		,   lv_SportGroupID AS SportGroupID
		, 	lv_CurrentDateTime AS LastModifiedDate
		, 	tmpCus.CreatedBy AS LastModifiedBy
		,   lv_ActionType AS ActionType
		,   lv_IsAuto AS IsAuto
		,   DATE(lv_CurrentDateTime) AS InsertDate
		,   lv_TargetCC AS TargetCC
		,   lv_SourceTypeID AS SourceTypeID
		,	lv_IsDataChanged AS IsDataChanged
	FROM Temp_Customer AS tmpCus;

	INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log(CustID, CTSCustID, CategoryID, SportGroupID, LastModifiedDate, LastModifiedBy, ActionType, IsAuto, InsertDate, TargetCC, SourceTypeID, IsDataChanged)
	SELECT 	tmpCus.CustID
		, 	tmpCus.CTSCustID
		,   lv_CategoryID AS CategoryID
		,   lv_SportGroupID AS SportGroupID
		, 	lv_CurrentDateTime AS LastModifiedDate
		, 	tmpCus.CreatedBy AS LastModifiedBy
		,   lv_ActionType AS ActionType
		,   lv_IsAuto AS IsAuto
		,   DATE(lv_CurrentDateTime) AS InsertDate
		,   lv_TargetCC AS TargetCC
		,   lv_SourceTypeID AS SourceTypeID
		,	lv_IsDataChanged AS IsDataChanged
	FROM Temp_Customer AS tmpCus;
		
	/*Auto Unpin*/
	DELETE pcc
    FROM CTS_DataCenter.PinCustomerCategory AS pcc
		INNER JOIN Temp_Customer AS tmpCus ON pcc.CTSCustID = tmpCus.CTSCustID;
        
	/***DELETE FROM VVIP TABLE********/
    DELETE clv
    FROM CTS_DataCenter.CTSCustomerClassificationVVIP AS clv
		INNER JOIN Temp_Customer AS tmpCus ON clv.CTSCustID = tmpCus.CTSCustID;
        
	/*Return Remove VVIP List to Rescan*/
    SELECT tmpCus.CustID
	FROM Temp_Customer AS tmpCus;

    /*****UPDATE Queue LastID************/
    IF ip_FromAction = 2 AND ip_QueueID IS NOT NULL THEN
		UPDATE CTS_DataCenter.CTSCustomerClassificationVVIPQueue AS que
		SET que.LastDownlineCTSCustID = lv_MaxCTSCustID
		WHERE que.ID = ip_QueueID;
    END IF;
    
    /*********************User Log*************************************************************/	
    IF ip_FromAction = 1 THEN
        INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		SELECT 10 AS LogTypeID
			, 	lv_SPName
			, 	CONCAT('Remove VVIP: CTSCustID', tmpCus.CTSCustID,'; AffectDownline_', ip_AffectDownline,'; CategoryID_', lv_CategoryID)
            ,	lv_CurrentDateTime
            , 	tmpCus.CreatedBy
        FROM Temp_Customer AS tmpCus;
    END IF;
    
END$$
DELIMITER ;