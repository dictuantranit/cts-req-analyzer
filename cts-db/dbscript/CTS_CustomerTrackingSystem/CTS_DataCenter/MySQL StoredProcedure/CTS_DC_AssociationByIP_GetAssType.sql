/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociationByIP_GetAssType`;

DELIMITER $$ 
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociationByIP_GetAssType`(
		IN 	ip_FromCustID	BIGINT 
	,	IN 	ip_ToCustID	BIGINT   
)
    SQL SECURITY INVOKER
BEGIN  
	/*  
		Created:	20230420@Casey.Huynh
		Task:		Get Association IP Type Bu CustID
		DB:			CTS_DataCenter
        
		Revisions:
			- 20230421@Casey.Huynh: Created [Redmine ID: #185783]

		Param's Explanation (filtered by): 
        
        Example:
			CALL CTS_DC_AssociationByIP_AssType_Get(@ip_FromCustID:=1234, @ip_FromCustID:=1277);
	*/   
	DECLARE lv_FromCustID BIGINT;
    DECLARE lv_ToCustID BIGINT;
    
    SET lv_FromCustID = LEAST(ip_FromCustID, ip_ToCustID);
    SET lv_ToCustID = GREATEST(ip_FromCustID, ip_ToCustID);
    
    SELECT	ap.AssType		
    FROM CTS_DataCenter.AssociationByIP AS ap
    WHERE ap.FromCustID = lv_FromCustID AND ap.ToCustID = lv_ToCustID;
    
END$$

DELIMITER ;
