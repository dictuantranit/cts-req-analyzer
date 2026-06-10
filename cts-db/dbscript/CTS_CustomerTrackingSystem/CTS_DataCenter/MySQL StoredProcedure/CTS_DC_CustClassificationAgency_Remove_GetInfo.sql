/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_Remove_GetInfo`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_Remove_GetInfo`(
		IN	ip_InputFlowID			INT 
	,	IN	ip_CustInfo				JSON
)
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240927@Thomas.Nguyen
		Task:		
		DB:			CTS_DataCenter
		
		Revisions: 
			- 20240927@Thomas.Nguyen: Created [Redmine ID: #185799]
            - 20250725@Casey.Huynh: Agent CC, Insert Considerable Agency [Redmine ID: #219679]
			
		Param's Expanation:
			- CALL CTS_DC_CustClassificationAgency_Remove_GetInfo (1225,'[{"CustID":24150964,"RoleID":2,"SubscriberID":168,"CTSCustID":11059,"CreatedBy":8,"Remark":"Thomas unmark PA","IsExceptDirectDownline":false,"IsMarkedDirectly":true}]');
*/
	
	DECLARE CONST_AGENCY_PARENTID_VVIP 									INT;
    DECLARE CONST_AGENCY_PARENTID_PA 									INT;
    DECLARE CONST_AGENCY_PARENTID_CONSIDERABLEDANGER					INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP 				INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA 					INT;
    DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_CONSIDERABLEDANGER	INT;

	SET CONST_AGENCY_PARENTID_VVIP 									= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');
    SET CONST_AGENCY_PARENTID_PA 									= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
	SET CONST_AGENCY_PARENTID_CONSIDERABLEDANGER					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_CONSIDERABLEDANGER');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA');
    SET CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_CONSIDERABLEDANGER	= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_CONSIDERABLEDANGER');
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustomerClassification;
	CREATE TEMPORARY TABLE Temp_CustomerClassification (
			CustID								BIGINT UNSIGNED 
		, 	CTSCustID							BIGINT UNSIGNED
		, 	SubscriberID						INT UNSIGNED
		,	RoleID								INT	
		,	Remark 								VARCHAR(500) 
		,	CreatedBy 							INT UNSIGNED
		,	IsExistVVIP							TINYINT(1) 
		,	IsExceptDirectDownline				TINYINT(1) DEFAULT NULL
        ,	IsMarkedDirectly					TINYINT(1) DEFAULT NULL
		,	IsRemovedPA							TINYINT(1) DEFAULT 0
		,	IsRemovedConsiderableDanger			TINYINT(1) DEFAULT 0
		,	CategoryID 							INT UNSIGNED
		,	Ext_EvidenceID_Credit				SMALLINT UNSIGNED
		,	IsCleanPA							TINYINT(1) DEFAULT 1
		,	CustomerClassPriority				SMALLINT
		,	CustomerClass						INT UNSIGNED
		,	IsReturnData						TINYINT(1) DEFAULT 0
		,	IsExistRobot						TINYINT(1) DEFAULT 0
		,	IsFromTW							TINYINT(1) DEFAULT 0
		,	IsFromCTS							TINYINT(1) DEFAULT 0
		,	KEY IX_Temp_CC_CustID_CategoryID (CustID, CategoryID)
		,	KEY IX_Temp_CC_CTSCustID (CTSCustID)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
	CREATE TEMPORARY TABLE Temp_Customer (
			CustID								BIGINT UNSIGNED PRIMARY KEY
		, 	CTSCustID							BIGINT UNSIGNED
		, 	SubscriberID						INT UNSIGNED
		,	RoleID								INT	
		,	Remark 								VARCHAR(500) 
		,	CreatedBy 							INT UNSIGNED
		,	IsExceptDirectDownline				TINYINT(1) DEFAULT NULL
        ,	IsMarkedDirectly					TINYINT(1) DEFAULT NULL
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_KeepDirect;
	CREATE TEMPORARY TABLE Temp_KeepDirect(
			CustID 								BIGINT UNSIGNED PRIMARY KEY
	);
	
	IF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP THEN /*VVIP*/
		INSERT INTO Temp_CustomerClassification(CustID, CTSCustID, CreatedBy, CategoryID, IsExistVVIP, IsReturnData)
		SELECT DISTINCT temp.CustID, temp.CTSCustID, temp.CreatedBy
			, 	cls.CategoryID
			, 	(CASE WHEN cls.CustID IS NOT NULL THEN 1 ELSE 0 END) AS IsExistVVIP
			,	1 AS IsReturnData
		FROM JSON_TABLE(ip_CustInfo,
						"$[*]" COLUMNS(
											CustID 				BIGINT UNSIGNED				PATH "$.CustID"
										,	CTSCustID 			BIGINT UNSIGNED				PATH "$.CTSCustID"
										,	CreatedBy 			INT UNSIGNED				PATH "$.CreatedBy"
										)) AS temp
			LEFT JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS cls ON temp.CustID = cls.CustID 
																			AND cls.ParentID = CONST_AGENCY_PARENTID_VVIP;        
										
	ELSEIF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA THEN /*PA*/
		INSERT INTO Temp_Customer(CustID, CTSCustID, RoleID, SubscriberID, CreatedBy, Remark, IsExceptDirectDownline, IsMarkedDirectly)
		SELECT DISTINCT temp.CustID, temp.CTSCustID, temp.RoleID, temp.SubscriberID, temp.CreatedBy, temp.Remark, temp.IsExceptDirectDownline, temp.IsMarkedDirectly
		FROM JSON_TABLE(ip_CustInfo,
						"$[*]" COLUMNS(
											CustID 					BIGINT UNSIGNED		PATH "$.CustID"
										, 	CTSCustID				BIGINT UNSIGNED 	PATH "$.CTSCustID"
										,   RoleID 					INT					PATH "$.RoleID"
										,   SubscriberID 			INT	UNSIGNED		PATH "$.SubscriberID"
										, 	CreatedBy				INT UNSIGNED		PATH "$.CreatedBy"
										, 	Remark					VARCHAR(500)		PATH "$.Remark"
										, 	IsExceptDirectDownline	TINYINT(1) 			PATH "$.IsExceptDirectDownline"
										, 	IsMarkedDirectly		TINYINT(1) 			PATH "$.IsMarkedDirectly"
										)) AS temp
			LEFT JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS cls ON temp.CustID = cls.CustID 
																			AND cls.ParentID = CONST_AGENCY_PARENTID_VVIP
		WHERE cls.CustID IS NULL;    
        
	ELSEIF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_CONSIDERABLEDANGER THEN #CONSIDERABLEDANGER    
		
        INSERT INTO Temp_CustomerClassification(CustID, CTSCustID, CreatedBy, CategoryID, IsRemovedConsiderableDanger, IsReturnData)
		SELECT DISTINCT temp.CustID
			, 	temp.CTSCustID
            , 	temp.CreatedBy
			, 	cls.CategoryID
            ,	1 AS IsRemovedConsiderableDanger
			,	1 AS IsReturnData
		FROM JSON_TABLE(ip_CustInfo,
						"$[*]" COLUMNS(
											CustID 				BIGINT UNSIGNED				PATH "$.CustID"
										,	CTSCustID 			BIGINT UNSIGNED				PATH "$.CTSCustID"
										,	CreatedBy 			INT UNSIGNED				PATH "$.CreatedBy"
										)) AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS cls ON temp.CustID = cls.CustID AND cls.ParentID = CONST_AGENCY_PARENTID_CONSIDERABLEDANGER
		;     
        
	END IF;

END$$
DELIMITER ;