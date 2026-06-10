/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb,ctsAPI,ctsService" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustInfo_GetCustIDsRole`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_GetCustIDsRole`(
		IN ip_CustIDs TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210408@Irena.Vo	
		Task :		Get Customer Info by CustID list
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20210408@Irena.Vo [Redmine ID: #132623]: Created 
			- 20210622@Aries.Nguyen: Update coding convention and improve locking [Redmine ID: #157203]
			- 20241029@Jonas.Huynh: Retrieve IsLicensee [Redmine ID: #185799]
            
		Param's Explanation:
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustInfo_GetCustomerRoles('5,1284');
	*/ 
	DROP TEMPORARY TABLE IF EXISTS Temp_CustomerRoles;
    CREATE TEMPORARY TABLE Temp_CustomerRoles (
			CustID              BIGINT UNSIGNED PRIMARY KEY 
        ,	RoleID				TINYINT
    );  

    -- Insert CustIDs
	SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_CustomerRoles (CustID) VALUES ('", REPLACE(ip_CustIDs, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1;    
       
	SELECT	temp.CustId
		,	cust.RoleId
        ,	cust.IsLicensee
	FROM Temp_CustomerRoles AS temp
		LEFT JOIN 	CTS_DataCenter.CTSCustomer AS cust ON cust.CustID = temp.CustID AND cust.CustSubID = 0;
END$$
DELIMITER ;