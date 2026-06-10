/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_AssociatedAccountMonitor_UpdateTaggingAssWithPA`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_AssociatedAccountMonitor_UpdateTaggingAssWithPA`(
		IN ip_CTSCustID 			BIGINT
    ,	IN ip_SubscriberID 			INT
    ,	IN ip_CreatedBy 			BIGINT
    ,	IN ip_IsExcludedTagAssPA 	BIT
    
    ,	OUT op_ErrorMessage 		VARCHAR(200)
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20210226@Jonas.Huynh
		Task :		Insert/Remove Mark Tagging By Association With PA
		DB:			CTS_DataCenter
		Original: 
		Revisions:
            - 20210226@Jonas.Huynh: Created  [RedmineID: #150454]
            - 20210525@Irena.Vo: Change col name TaggingExclusion: CustID -> CTSCustID [RedmineID: #152965]
			- 20210729@Irena.Vo: Refactor SP [RedmineID: #157203]
		    - 20210928@Irena.Vo: Split history log  [Redmine ID: #161890]
			- 20220428@Casey.Huynh.Huynh: Update Creator for CustomerClassification [Redmine ID: #171512]
			- 20240618@Victoria.Le:	Renovate CC Phase 2 - Not insert into CTSCustomerClassification_History [Redmine ID: #205317]
		Param's Explanation:
		Example:
			- CALL CTS_DataCenter.CTS_DC_AssociatedAccountMonitor_UpdateTaggingAssWithPA(1, 1, 1, 1, TRUE, @op_ErrorMessage);
	*/ 
	DECLARE CONST_SOURCETYPE_EXCLUDEASSWITHPA	INT DEFAULT 20;
    DECLARE CONST_SOURCETYPE_INCLUDEASSWITHPA	INT DEFAULT 21;
    
    DECLARE lv_CurrentDateTime 					DATETIME DEFAULT CURRENT_TIMESTAMP();
    DECLARE lv_SPName 							VARCHAR(200) DEFAULT 'CTS_DC_AssociatedAccountMonitor_UpdateTaggingAssWithPA'; 
    DECLARE lv_CustID 							BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
    
    SELECT CustID
    INTO lv_CustID
    FROM CTS_DataCenter.CTSCustomer 
    WHERE CTSCustID = ip_CTSCustID AND CustSubID = 0;    
    
    /*Insert Tagging Associated Exclusion With PA.*/
    IF (ip_IsExcludedTagAssPA = 1) THEN
		INSERT INTO CTS_DataCenter.TaggingExclusion(CTSCustID, CreatedTime, CreatedBy) 
		SELECT	ip_CTSCustID
			,	lv_CurrentDateTime
            ,	ip_CreatedBy;
		
		INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log
		(CustID, CTSCustID, LastModifiedDate, LastModifiedBy, SourceTypeID, InsertDate, IsDataChanged, TaggingType)
		SELECT  lv_CustID
			,	ip_CTSCustID
			, 	lv_CurrentDateTime
			, 	ip_CreatedBy
			, 	CONST_SOURCETYPE_EXCLUDEASSWITHPA
			, 	DATE(lv_CurrentDateTime)
            ,	0
            ,	0;
        
		INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		VALUES(30, lv_SPName, CONCAT('Unmark Tagging By Association With PA: ip_CTSCustID_', ip_CTSCustID, ';ip_SubscriberID_', ip_SubscriberID), lv_CurrentDateTime, ip_CreatedBy);
    END IF;   
    
    /*Remove Tagging Associated Exclusion With PA.*/
	IF (ip_IsExcludedTagAssPA = 0) THEN 
		DELETE 	tagging
		FROM 	CTS_DataCenter.TaggingExclusion AS tagging
		WHERE 	tagging.CTSCustID = ip_CTSCustID;
        
        INSERT INTO CTS_DataCenter.CTSCustomerClassification_Log
		(CustID, CTSCustID, LastModifiedDate, LastModifiedBy, SourceTypeID, InsertDate, IsDataChanged)
		SELECT  lv_CustID
			,	ip_CTSCustID
			, 	lv_CurrentDateTime
			, 	ip_CreatedBy
			, 	CONST_SOURCETYPE_INCLUDEASSWITHPA
			, 	DATE(lv_CurrentDateTime)
            ,	0;
        
		INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		VALUES(31, lv_SPName, CONCAT('Mark Tagging By Association With PA: ip_CTSCustID_', ip_CTSCustID, ';ip_SubscriberID_', ip_SubscriberID), lv_CurrentDateTime, ip_CreatedBy);
    END IF; 
END$$
DELIMITER ;