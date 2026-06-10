/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_SpecialLicSubCC_Scan_Complete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_SpecialLicSubCC_Scan_Complete`(
		IN ip_IDList TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250514@Casey.Huynh
		Task:	 	SpecialLicSubCC Scan Get
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250514@Casey.Huynh: 	Created [Redmine ID: #226847]

		Param's Explanation (filtered by): 

		Example:
			CALL CTS_DC_SpecialLicSubCC_Scan_Complete(@ip_IDList:='3,4,6,9,10');
	*/   
	DECLARE CONST_PROCESSSTATUS_INPROGRESS	TINYINT DEFAULT 1;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ID;
    CREATE TEMPORARY TABLE Temp_ID(
		ID	BIGINT UNSIGNED PRIMARY KEY
    );
   
    SET @sql = CONCAT("INSERT INTO Temp_ID (ID) VALUES ('", REPLACE(ip_IDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    UPDATE CTS_DataCenter.Customer_SpecialLicSubCC AS cus
		INNER JOIN Temp_ID AS tmp ON cus.ID = tmp.ID
	SET cus.ProcessStatus = CONST_PROCESSSTATUS_INPROGRESS;

END$$
DELIMITER ;
