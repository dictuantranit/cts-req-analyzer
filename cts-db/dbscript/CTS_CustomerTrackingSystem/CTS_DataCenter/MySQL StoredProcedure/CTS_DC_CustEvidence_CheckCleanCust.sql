/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustEvidence_CheckCleanCust`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_CheckCleanCust`(
    IN ip_CTSCustIDList LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210909@Aries.Nguyen
		Task :		Enhance Place Affected Evidence - Bet Limit Control
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20210909@Aries.Nguyen: Created [Redmine ID: 160711]
		
		Param's Explanation (filtered by):
	*/
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustID;
    CREATE TEMPORARY TABLE Temp_CTSCustID (
			CTSCustID 		BIGINT UNSIGNED PRIMARY KEY
    );     
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CleanCustID;
    CREATE TEMPORARY TABLE Temp_CleanCustID (
			CTSCustID 		BIGINT UNSIGNED PRIMARY KEY
    );
    
    SET @sql = CONCAT("INSERT INTO Temp_CTSCustID (CTSCustID) VALUES ('", REPLACE(ip_CTSCustIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    INSERT INTO Temp_CleanCustID(CTSCustID)
    SELECT CTSCustID 
    FROM Temp_CTSCustID AS cus
    WHERE NOT EXISTS (SELECT 1 
				      FROM CTS_DataCenter.CustEvidence as ev 
                      WHERE ev.CTSCustID = cus.CTSCustID
					    AND NOT EXISTS (SELECT 1 
									    FROM CTS_DataCenter.CustRetractEvidence AS re 
									    WHERE re.CTSCustID = ev.CTSCustID 
										    AND re.EvidenceID = ev.EvidenceID));
    

    SELECT  DISTINCT	
            c.CustID
        ,   a.CTSCustID
    FROM Temp_CleanCustID AS a
		INNER JOIN CTS_DataCenter.CTSCustomer AS c ON a.CTSCustID = c.CTSCustID;
 
END$$

DELIMITER ;
