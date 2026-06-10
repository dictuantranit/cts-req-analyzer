/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="1" isNested="0"></info>*/
DROP FUNCTION IF EXISTS `CTS_DC_CategoryTypeParent_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` FUNCTION `CTS_DC_CategoryTypeParent_Get`(
    	ip_CateTypeParentName		VARCHAR(200)
)
RETURNS INT
DETERMINISTIC
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240618@Victoria.Le
		Task:		Function to return the ParentID/CategoryID/CategoryGroupID/CustomerClass/.....
		DB:			CTS_DataCenter
			
		Param's Expanation:
			- ip_CateTypeParentName: refer to table CTS_DataCenter.StaticList 
				+ ListID = 6: 	ParentID/CategoryID/CategoryGroupID/CustomerClass/.... GroupID = 1;
				+ ListID = 24: 	Inputflow - General: INSERT/RESCAN/REMOVE and BySport: INSERT/REMOVE GroupID = 2;
		
		Example:
			- CALL CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
			
		Revisions: 
			- 20240618@Victoria.Le: 		Initial Writing [Redmine ID: #205317]
			- 20241003@Thomas.Nguyen: 		CC Agency [Redmine ID: #185799]
			- 20241003@winfred.pham: 		Rescan by sport [Redmine ID: #239955]
*/

	DECLARE CONST_LIST_CLASSIFICATION		INT DEFAULT 6;
	DECLARE CONST_LIST_INPUTFLOW			INT DEFAULT 24;
	
	DECLARE lv_GetTypeID	 				INT;
	DECLARE lv_CateTypeParentID 			INT UNSIGNED;
	DECLARE lv_GroupID						INT DEFAULT 0;
	
	SET ip_CateTypeParentName	= UPPER(ip_CateTypeParentName);
    
    IF ip_CateTypeParentName LIKE '%BIZCATEGROUPID%' THEN
		SET lv_GetTypeID = 1;
		SET lv_GroupID = 1;
		
	ELSEIF ip_CateTypeParentName LIKE '%PARENTID%' THEN
		SET lv_GetTypeID = 2;
		SET lv_GroupID = 1;
		
	ELSEIF ip_CateTypeParentName LIKE '%CATEID%' THEN
		SET lv_GetTypeID = 3;
		SET lv_GroupID = 1;
		
	ELSEIF ip_CateTypeParentName LIKE '%CATEGROUPID%' THEN
		SET lv_GetTypeID = 4;
		SET lv_GroupID = 1;
		
	ELSEIF ip_CateTypeParentName LIKE '%_CC_%' THEN
		SET lv_GetTypeID = 5;
		SET lv_GroupID = 1;
		
	ELSEIF ip_CateTypeParentName LIKE '%REMARKID%' THEN
		SET lv_GetTypeID = 6;
		SET lv_GroupID = 1;
	
	ELSEIF ip_CateTypeParentName LIKE '%INPUTFLOWID_GENERAL_INSERT%' THEN
		SET lv_GetTypeID = 1;
		SET lv_GroupID = 2;
		
	ELSEIF ip_CateTypeParentName LIKE '%INPUTFLOWID_GENERAL_RESCAN%' THEN 
		SET lv_GetTypeID = 2;
		SET lv_GroupID = 2;
		
	ELSEIF ip_CateTypeParentName LIKE '%INPUTFLOWID_GENERAL_REMOVE%' THEN 
		SET lv_GetTypeID = 3;
		SET lv_GroupID = 2;
	
	ELSEIF ip_CateTypeParentName LIKE '%INPUTFLOWID_BYSPORT_INSERT%' THEN 
		SET lv_GetTypeID = 4;
		SET lv_GroupID = 2;
		
	ELSEIF ip_CateTypeParentName LIKE '%INPUTFLOWID_BYSPORT_REMOVE%' THEN 
		SET lv_GetTypeID = 5;
		SET lv_GroupID = 2;
			
	ELSEIF ip_CateTypeParentName LIKE '%INPUTFLOWID_BYSPORT_RESCAN%' THEN 
		SET lv_GetTypeID = 6;
		SET lv_GroupID = 2;
		
	END IF;

	SET lv_CateTypeParentID = (	SELECT 	stl.ItemDefaultValue
								FROM 	CTS_DataCenter.StaticList AS stl
								WHERE 	stl.ListID = CASE	WHEN lv_GroupID = 1 THEN CONST_LIST_CLASSIFICATION 
															WHEN lv_GroupID = 2 THEN CONST_LIST_INPUTFLOW
													 END
									AND stl.ItemParentItemID = lv_GetTypeID
									AND stl.ItemName = ip_CateTypeParentName);

	RETURN (lv_CateTypeParentID);

END$$
DELIMITER ;