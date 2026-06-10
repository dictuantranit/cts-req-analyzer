/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustInfo_Healing_GetCustIDs`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_CustInfo_Healing_GetCustIDs`(
		IN ip_Size INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210818@Casey.Huynh
		Task:		Initial CustStatus[Redmine ID: 152259]
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20210115@Casey.Huynh: Created [Redmine ID: 152259]
            
		Param's Explanation (filtered by):

		Example: CALL CTS_DC_CustInfo_Healing_GetCustIDs (100);
	*/  
	DECLARE lv_LastCustID INT UNSIGNED;
    
    SELECT ParameterValue
    INTO lv_LastCustID
    FROM SystemParameter WHERE ParameterID = 28;
    
    SELECT	cus.CustID
    FROM CTS_DataCenter.CTSCustomer AS cus
    WHERE cus.CustID < lv_LastCustID AND CustSubID = 0
    ORDER BY CustID DESC
    LIMIT ip_Size;
    
END$$
DELIMITER ;