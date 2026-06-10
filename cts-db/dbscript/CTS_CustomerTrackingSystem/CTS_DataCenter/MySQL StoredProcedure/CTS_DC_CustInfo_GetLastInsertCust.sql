/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_GetLastInsertCust`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_GetLastInsertCust`()
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200111@Casey.Huynh
		Task:		CTSCustomer Flow [Redmine ID: 148849]
		DB:			CTS_DataCenter
		Original:

		Revisions: 
			- 20210115@Casey.Huynh: Created [Redmine ID: 148849]
		Param's Explanation (filtered by):

		Example:
			- CALL CTS_DC_CTSCustomer_GetLastInsertCust(0)
	*/
	
		SELECT	s.ParameterValue AS LastCustID
		FROM	CTS_DataCenter.SystemParameter AS s
		WHERE	s.ParameterID = 7 AND s.ParameterName = 'CTSCustomer_LastInsertCustID';

		SELECT	s.ParameterValue AS LastCustSubID
		FROM	CTS_DataCenter.SystemParameter AS s
		WHERE	s.ParameterID = 8 AND s.ParameterName = 'CTSCustomer_LastInsertCustSubID';

    
END$$
DELIMITER ;