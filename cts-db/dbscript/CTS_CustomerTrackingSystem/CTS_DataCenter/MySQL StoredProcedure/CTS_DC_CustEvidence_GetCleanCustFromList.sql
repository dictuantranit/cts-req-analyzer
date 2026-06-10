/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustEvidence_GetCleanCustFromList`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_GetCleanCustFromList`(IN ip_CTSCustIDList varchar(2000))
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200820@Long.Luu
		Task :		Get Clean Customers After removing evidence
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20200820@Long.Luu: Created [Redmine ID: 139701]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
		
		Param's Explanation (filtered by):
	*/
    
    DROP TEMPORARY TABLE IF EXISTS TempCTSCustIDs;
    CREATE TEMPORARY TABLE TempCTSCustIDs (
			CTSCustID 		BIGINT UNSIGNED PRIMARY KEY
    );    
    
    DROP TEMPORARY TABLE IF EXISTS TempCustEvidence;
    CREATE TEMPORARY TABLE TempCustEvidence (
			CTSCustID 		BIGINT UNSIGNED
		,	EvidenceID		SMALLINT
        ,	INDEX TempCustEvidence_CTSCustIDEvidenceID(CTSCustID,EvidenceID)
    );
    
    DROP TEMPORARY TABLE IF EXISTS TempCleanCustID;
    CREATE TEMPORARY TABLE TempCleanCustID (
			CTSCustID 		BIGINT UNSIGNED PRIMARY KEY
    );
    
    SET @sql = CONCAT("INSERT INTO TempCTSCustIDs (CTSCustID) VALUES ('", REPLACE(ip_CTSCustIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    INSERT INTO TempCustEvidence(CTSCustID, EvidenceID)
    SELECT c.CTSCustID, c.EvidenceID
    FROM CTS_DataCenter.CustEvidence AS c
		INNER JOIN TempCTSCustIDs AS t ON c.CTSCustID = t.CTSCustID;
    
    SET SQL_SAFE_UPDATES = 0;
    
    DELETE c
    FROM TempCustEvidence AS c
		INNER JOIN CTS_DataCenter.CustRetractEvidence AS r ON c.CTSCustID = r.CTSCustID AND c.EvidenceID = r.EvidenceID;
    
    INSERT INTO TempCleanCustID(CTSCustID)
	SELECT DISTINCT c.CTSCustID
	FROM TempCTSCustIDs AS c
		LEFT JOIN (	SELECT DISTINCT CTSCustID
					FROM TempCustEvidence) AS r ON c.CTSCustID = r.CTSCustID
	WHERE r.CTSCustID IS NULL ;
    
    SELECT DISTINCT	c.CustID
    FROM TempCleanCustID AS a
		INNER JOIN CTS_DataCenter.CTSCustomer AS c ON a.CTSCustID = c.CTSCustID;
 
    DROP TEMPORARY TABLE IF EXISTS TempCTSCustIDs;  
    DROP TEMPORARY TABLE IF EXISTS TempCustEvidence;  
    DROP TEMPORARY TABLE IF EXISTS TempCleanCustID;  
    
END$$

DELIMITER ;
