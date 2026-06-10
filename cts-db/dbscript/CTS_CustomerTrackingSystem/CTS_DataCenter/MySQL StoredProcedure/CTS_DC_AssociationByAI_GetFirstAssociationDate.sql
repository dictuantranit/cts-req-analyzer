/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_AssociationByAI_GetFirstAssociationDate`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociationByAI_GetFirstAssociationDate`(
		IN 	ip_CustID1				BIGINT 		UNSIGNED
	,	IN 	ip_CustID2				BIGINT 		UNSIGNED
	,	IN 	ip_AssType				SMALLINT 	UNSIGNED
)
    SQL SECURITY INVOKER
sp:BEGIN  
	/*  
		Created:	20230220@Victoria.Le
		Task:		Get Association Date
		DB:			CTS_DataCenter
        
		Revisions:
			- 20230220@Victoria.Le:		Initial Writing [Redmine ID: #181994]

		Param's Explanation (filtered by): 
			- ip_AssType: 1: OTGB; 2: 5G3S

        Example:
			- CALL CTS_DataCenter.CTS_DC_Association_GetAssociationDate(@ip_CustID1 := 62218173, @ip_CustID2:=66688622, @ip_AssType := 2);
	*/   
	
    SELECT CreatedDate AS FirstAssociationDate
	FROM CTS_DataCenter.AssociationByAI
	WHERE FromCustID = ip_CustID1
		AND ToCustID = ip_CustID2
		AND AssType = ip_AssType; 
    
END$$

DELIMITER ;
