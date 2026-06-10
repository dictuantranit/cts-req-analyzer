/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_AffectedDownline_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_AffectedDownline_Insert`(
		 IN ip_TableName	VARCHAR(200)
    ,    IN ip_InputFlowID 	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240625@Jonas.Huynh
		Task:		Renovate CC [Redmine ID: #205317]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20240625@Jonas.Huynh: Created [Redmine ID: #205317]
			- 20240927@Thomas.Nguyen: Classify Agent's CC [Redmine ID: #185799]

		Param's Explanation (filtered by):
			- ip_ActionType: 1:Insert VVIP, 2:Remove VVIP, 3:Mark PA, 4:UnMark PA
	*/
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP				INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_PACATEGORY			INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP 				INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA 					INT;
    DECLARE	CONST_ACTION_INSERTVVIP 									INT DEFAULT 1;
	DECLARE	CONST_ACTION_REMOVEVVIP 									INT DEFAULT 2;
	DECLARE	CONST_ACTION_MARKPA 										INT DEFAULT 3;
	DECLARE	CONST_ACTION_UNMARKPA	 									INT DEFAULT 4;
    
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP					= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_PACATEGORY				= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_PACATEGORY');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP					= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA						= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA');

	DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
    CREATE TEMPORARY TABLE Temp_Customer(
			CTSCustID			BIGINT PRIMARY KEY
		,	CustID				BIGINT
        ,	RoleID				TINYINT
        ,	SubscriberID		INT
        ,	CreatedBy			BIGINT
        ,	Remark				VARCHAR(300)
        ,	CategoryID			INT
        ,	CategoryGroupID		INT
        ,	IsFromTW			BIT(1)
        ,	IsFromCTS			BIT(1)
		,	LastModifiedDate	DATETIME(3)
	);
    
	SET @sql =CONCAT("	INSERT IGNORE INTO Temp_Customer (CTSCustID, CustID, RoleID, SubscriberID, CreatedBy, Remark
							, CategoryID, CategoryGroupID, IsFromTW, IsFromCTS, LastModifiedDate) 
						SELECT	ipTbl.CTSCustID
							,	ipTbl.CustID
                            ,	ipTbl.RoleID
                            ,	ipTbl.SubscriberID
                            ,	ipTbl.CreatedBy
                            ,	ipTbl.Remark
                            ,	ipTbl.NewCategoryID
                            ,	ipTbl.NewCategoryGroupID
                            ,	ipTbl.IsFromTW
                            ,	ipTbl.IsFromCTS
							,	ipTbl.LastModifiedDate
						FROM ",ip_TableName," AS ipTbl"
						);
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1; 
    
	INSERT IGNORE INTO CTS_DataCenter.CTSCustomerClassificationQueue(CTSCustID, CustID, RoleID, SubscriberID, CreatedBy, Remark, CategoryID, CategoryGroupID, LastDownlineCTSCustID
		, IsFromTW, IsFromCTS, ActionType, InsertTime)
	SELECT tmpPa.CTSCustID
		,	tmpPa.CustID
		,	tmpPa.RoleID
		,	tmpPa.SubscriberID
		,	tmpPa.CreatedBy
		,	tmpPa.Remark        
		,	tmpPa.CategoryID
		,	tmpPa.CategoryGroupID
		,	0 AS LastDownlineCTSCustID
		,	tmpPa.IsFromTW
		,	tmpPa.IsFromCTS
		,	CASE	
				WHEN ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_VVIP THEN CONST_ACTION_INSERTVVIP
                WHEN ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_PACATEGORY THEN CONST_ACTION_MARKPA
                WHEN ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_PA THEN CONST_ACTION_UNMARKPA
                WHEN ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_REMOVE_VVIP THEN CONST_ACTION_REMOVEVVIP
			END AS ActionType
		,	CURRENT_TIMESTAMP(3) AS InsertTime
	FROM Temp_Customer AS tmpPa        
	WHERE tmpPa.RoleID > 1
	ORDER BY tmpPa.LastModifiedDate, tmpPa.CategoryID;
END$$

DELIMITER ;