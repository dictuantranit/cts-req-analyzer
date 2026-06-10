/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociationGroupByAI_GetCustomersByGroup`;

DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociationGroupByAI_GetCustomersByGroup`(
		IN ip_GroupList	 			VARCHAR(1000)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20220404@Long.Luu
		Task:		Get customers by Group of AssociationGroupByAI [Redmine ID: #0000]
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20220404@Long.Luu: Created [Redmine ID: #0000]
            
		Example:
			call CTS_DataCenter.CTS_DC_AssociationGroupByAI_GetCustomersByGroup ('1,10');    
	*/        
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Group;
    CREATE TEMPORARY TABLE Temp_Group (
			GroupID			BIGINT UNSIGNED
    );
    
    SET @sql = CONCAT("INSERT INTO Temp_Group (GroupID) VALUES ('", REPLACE(ip_GroupList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
	
    SELECT DISTINCT g.GroupID, g.OriginGroupID, g.CustID
    FROM AssociationGroupByAI AS g
		INNER JOIN Temp_Group AS t ON g.GroupID = t.GroupID;
    
END$$	
DELIMITER ;