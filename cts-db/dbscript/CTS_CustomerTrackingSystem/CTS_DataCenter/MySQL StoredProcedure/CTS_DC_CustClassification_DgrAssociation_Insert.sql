/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_DgrAssociation_Insert`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_DgrAssociation_Insert`(
		IN 	ip_CustIDList 		LONGTEXT
)
SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20241203@Thomas.Nguyen
		Task:	 	
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20241203@Thomas.Nguyen: 	Created [Redmine ID: #214353]

		Example:
			CALL CTS_DC_CustClassification_DgrAssociation_Insert (@ip_CustInfo:='[{"CTSCustID":1275,"DCSDeviceID":0.1419399977},{"CTSCustID":1277,"DCSDeviceID":0.7015600204}]');
	*/

    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE Temp_Cust(
			CustID 				BIGINT NOT NULL PRIMARY KEY
	);

	INSERT IGNORE INTO Temp_Cust(CustID)
    SELECT DISTINCT	tmp.CustID
    FROM JSON_TABLE(REPLACE(JSON_ARRAY(ip_CustIDList), ',', '","'), 
						'$[*]' COLUMNS (CustID BIGINT UNSIGNED PATH '$')
						) AS tmp;

    INSERT IGNORE INTO CTS_DataCenter.DangerousAssociation(CustID)
    SELECT tmp.CustID
    FROM Temp_Cust AS tmp
    WHERE NOT EXISTS (SELECT 1 FROM CTS_DataCenter.DangerousAssociation AS da WHERE da.CustID = tmp.CustID AND da.IsDisabled = 0);

END$$
DELIMITER ;