DELIMITER $$
USE CTS_DataCenter $$
DROP PROCEDURE IF EXISTS CTS_DataCenter.CTS_DC_CustEvidence_GetTemp_FlaggedCustomers $$

CREATE PROCEDURE CTS_DC_CustEvidence_GetTemp_FlaggedCustomers (IN ip_CustIds LONGTEXT)
BEGIN
	/*
		Created:	20200610@Harvey
		Task:		Get flagged customer for AI Ghost [Redmine ID: 135649]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20200619@Harvey: only get FLAGGED customer (has evidence level 0)
        
		Param's Explanation (filtered by):
        
        CALL CTS_DC_CustEvidence_GetTemp_FlaggedCustomers ('3698310,910137,1176070,1176083');
	*/
    
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    DROP TEMPORARY TABLE IF EXISTS Temp_Temp_FlaggedCustomers;
    CREATE TEMPORARY TABLE Temp_FlaggedCustomers (
			CTSCustID		BIGINT
		,	CustId 			INT
		,	EviID			SMALLINT
		,	EvidenceCode 	VARCHAR(10)
        ,	EvidenceName 	VARCHAR(50)
        ,	Level			TINYINT
        ,	FromCTSCustID	BIGINT
        ,	CreatedDate 	DATETIME
    );

	DROP TEMPORARY TABLE IF EXISTS Temp_CustIDList;
    CREATE TEMPORARY TABLE Temp_CustIDList (
		CustID INT PRIMARY KEY
    );
    
	SET @sql = CONCAT("INSERT INTO Temp_CustIDList (CustID) VALUES ('", REPLACE(ip_CustIds, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    INSERT INTO Temp_FlaggedCustomers
	SELECT 	cevi.CTSCustID
		,	cust.CustID
		,	cevi.EvidenceID
		,	evi.EvidenceCode
        ,	evi.EvidenceName
		,	cevi.LEVEL
		,	cevi.FromCustID
		,	cevi.CreatedDate
	FROM Temp_CustIDList AS tcust
		INNER JOIN CTSCustomer AS cust ON cust.CustID = tcust.CustID AND cust.CustSubID = 0
        INNER JOIN CustEvidence AS cevi ON cust.CTSCustID = cevi.CTSCustID AND cust.SubscriberID = cevi.SubscriberID
        INNER JOIN Evidence AS evi ON cevi.EvidenceID = evi.EvidenceID
	WHERE cevi.LEVEL = 0;

    SELECT 	CustId
		,	EvidenceCode 
        ,	EvidenceName
		,	CreatedDate
	FROM Temp_FlaggedCustomers;
    
END$$
DELIMITER ;