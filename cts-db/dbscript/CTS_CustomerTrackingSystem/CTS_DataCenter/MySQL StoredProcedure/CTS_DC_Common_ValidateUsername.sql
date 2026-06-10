/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
USE CTS_DataCenter;
DROP PROCEDURE IF EXISTS `CTS_DC_Common_ValidateUsername`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Common_ValidateUsername`(
	  IN ip_ListUsername 		LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210204@Long.Luu
		Task:		Validate a list of usernames [Redmine ID: #148719]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20210204@Long.Luu: Created [Redmine ID: #148719]
			- 20210729@Aries.Nguyen: Change data type param ip_ListUsername  [Redmine ID: #157086]
            - 20220727@Aries.Nguyen: [CTS] Enhance Association Detection [Redmine ID: #175701]
		
		Param's Explanation (filtered by):   
            
		Example:			
			- CALL CTS_DataCenter.CTS_DC_Common_ValidateUsername('member19');
	*/
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Username;
    CREATE TEMPORARY TABLE Temp_Username(
			Username 	VARCHAR(50) PRIMARY KEY
	);
    
	SET @sql = CONCAT("INSERT INTO Temp_Username (Username) VALUES ('", REPLACE(ip_ListUsername, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
	SELECT 	c.UserName
		,	c.CTSCustID
		,	c.CustID
        ,	c.RoleID
        ,	c.IsInternal
    FROM CTS_DataCenter.CTSCustomer AS c
		INNER JOIN Temp_Username AS t ON c.UserName = t.Username;
    
    DROP TEMPORARY TABLE Temp_Username;
END$$
DELIMITER ;