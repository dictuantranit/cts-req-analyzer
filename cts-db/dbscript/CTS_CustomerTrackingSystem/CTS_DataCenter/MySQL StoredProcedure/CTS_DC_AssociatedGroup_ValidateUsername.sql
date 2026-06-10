/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_ValidateUsername`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_ValidateUsername`(
		IN ip_ListUsername 		LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/* 
		Created:	20220705@Aries.Nguyen
		Task:		[CTS] Fraud Group Management [Redmine ID: #167748]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20220705@Aries.Nguyen: Created [Redmine ID: #167748]
        
		Param's Explanation (filtered by):
        
        Example:			
			- CALL CTS_DataCenter.CTS_DC_AssociatedGroup_ValidateUsername('member19,ITSA1Sub01,memberxx,8RM888,789HK');
	*/
    DROP TEMPORARY TABLE IF EXISTS Temp_Username;
    CREATE TEMPORARY TABLE Temp_Username(
			Username 	VARCHAR(50) PRIMARY KEY
	);
    
	SET @sql = CONCAT("INSERT INTO Temp_Username (Username) VALUES ('", REPLACE(ip_ListUsername, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    SELECT 	tmp.Username
		,	cus.CTSCustID
        ,   cus.CustID
        ,	CASE WHEN cus.CTSCustID IS NULL THEN "Invalid Account"
				 WHEN cus.RoleID != 1 THEN "SMA"
                 WHEN cus.IsInternal = 1 THEN "Specific Account"
                 WHEN acc.CTSCustID IS NOT NULL THEN CONCAT("Existing in ", grp.GroupName)
				 ELSE NULL END AS ErrorMsg
    FROM Temp_Username AS tmp
		LEFT JOIN CTS_DataCenter.CTSCustomer AS cus ON  tmp.Username = cus.Username
        LEFT JOIN CTS_DataCenter.AssociatedGroupAccount AS acc ON cus.CTSCustID = acc.CTSCustID
        LEFT JOIN CTS_DataCenter.AssociatedGroup AS grp ON grp.GroupID = acc.GroupID AND IsDisable = 0;
END$$
DELIMITER ;