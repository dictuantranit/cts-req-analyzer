/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_GetLastUpdateTime`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_GetLastUpdateTime`()
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210115@Casey.Huynh
		Task:		GET SystemParameter 
		DB:			CTS_DataCenter
		Original:

		Revisions: 
			-	20210115@Casey.Huynh: Created [Redmine ID: 148849]
            -	20210205@Casey.Huynh: Implement Update CTSCustomer by Customer_History [Redmine ID: 149941]
            -	20210423@CaseyHuynh: Update CTSCustomer (Credit Cust Status) by CustProductStatus_History [Redmine ID: #152259]
		Param's Explanation (filtered by):

		Example:
			- CALL `CTS_DC_CTSCustomer_GetLastUpdateTime`()

	*/    
		SELECT	s.ParameterValue AS LastUpdateTimeCustInfo
		FROM	CTS_DataCenter.SystemParameter AS s
		WHERE	s.ParameterID = 9;

		SELECT	s.ParameterValue AS LastUpdateCustIDCustInfo
		FROM	CTS_DataCenter.SystemParameter AS s
		WHERE	s.ParameterID = 10;
    
		SELECT	s.ParameterValue AS LastUpdateTimeCustomer
		FROM	CTS_DataCenter.SystemParameter AS s
		WHERE	s.ParameterID = 11;

		SELECT	s.ParameterValue AS LastUpdateCustIDCustomer
		FROM	CTS_DataCenter.SystemParameter AS s
		WHERE	s.ParameterID = 12;
        
		SELECT	s.ParameterValue AS LastUpdateTimeCustProductStatus
		FROM	CTS_DataCenter.SystemParameter AS s
		WHERE	s.ParameterID = 18;

		SELECT	s.ParameterValue AS LastUpdateCustIDCustProductStatus
		FROM	CTS_DataCenter.SystemParameter AS s
		WHERE	s.ParameterID = 19;
END$$
DELIMITER ;