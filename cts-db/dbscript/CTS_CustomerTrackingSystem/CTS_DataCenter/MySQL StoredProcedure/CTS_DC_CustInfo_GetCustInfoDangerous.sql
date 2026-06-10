/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_GetCustInfoDangerous`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_GetCustInfoDangerous`(
		ip_CustIDList TEXT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20221205@Victoria.Le
		Task:		Get Customer Info
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20221205@Victoria.Le: Initial Writing [Redmine ID: #181208]
            
		Param's Explanation (filtered by): 
			ip_CustIDList: String (custid01,custid02, custid03)
		Example: CALL CTS_DataCenter.CTS_DC_CustInfo_GetCustInfoDangerous ('123,124,125')
        
	*/
    CALL CTS_DataCenter.CTS_DC_Sys_SplitStringToTempItemTable(ip_CustIDList,',','BIGINT');
    
    SELECT 	CustID
			,	CustStatusID
			,	Danger1
			,	Danger2
			,	Danger3
			,	Danger4
			,	Danger5
			,	DangerSabaSc
			,	DangerSabaBkb
		FROM	CTS_DataCenter.CTSCustomer AS cus
			INNER JOIN	TempItemTable AS tmpCus ON cus.CustID = tmpCus.Item;
END$$
DELIMITER ;