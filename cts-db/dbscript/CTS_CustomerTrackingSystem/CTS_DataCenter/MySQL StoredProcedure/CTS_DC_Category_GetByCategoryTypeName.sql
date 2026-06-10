/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Category_GetByCategoryTypeName`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Category_GetByCategoryTypeName`(
		IN ip_CategoryTypeName	VARCHAR(100)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240717@Jonas.Huynh
		Task:		Get Category by Name
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20240717@Jonas.Huynh: Created [Redmine ID: #150457]

		Param's Explanation (filtered by):
        Example:
				CALL CTS_DC_Category_GetByCategoryTypeName('CONST_BIZCATEGROUPID_PA');
	*/
	
    SELECT CTS_DC_CategoryTypeParent_Get (ip_CategoryTypeName);
    
END$$
DELIMITER ;