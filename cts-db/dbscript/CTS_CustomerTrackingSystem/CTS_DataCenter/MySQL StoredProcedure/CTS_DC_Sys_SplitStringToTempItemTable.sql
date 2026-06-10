/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin,ctsService,ctsAPIAdmin,ctsAPI,ctsWebAdmin,ctsWeb" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Sys_SplitStringToTempItemTable`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Sys_SplitStringToTempItemTable`(IN ip_String LONGTEXT, IN ip_Seperator VARCHAR(10), IN ip_toDataType VARCHAR(100))
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200604@Casey.Huynh
		Task:		Return Table Item with datatype = 
		DB:			CTS_DataCenter
		Original:

		Revisions:
			-	20240617@Casey.Huynh: Update Data Type [Redmine ID: #206564]
        
		Param's Explanation (filtered by):
                

   */ 
        
        
	DROP TEMPORARY TABLE IF EXISTS TempItemTable;
    SET @schemaStr =  CONCAT('CREATE TEMPORARY TABLE TempItemTable(Item ',ip_toDataType,');');
    
    PREPARE schemaStr FROM @schemaStr;
    EXECUTE schemaStr;
    
	SET @insertStr = CONCAT("INSERT INTO TempItemTable (Item) VALUES ('", REPLACE(ip_String, ip_Seperator, "'),('"),"');");

	PREPARE insertStr FROM @insertStr;
	EXECUTE insertStr;
END$$
DELIMITER ;
