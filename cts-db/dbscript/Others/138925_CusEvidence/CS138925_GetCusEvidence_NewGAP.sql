DELIMITER $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.CS138925_GetCusEvidence_NewGAP$$
CREATE PROCEDURE CTS_Adhoc.CS138925_GetCusEvidence_NewGAP()
BEGIN
	/*
		Created:	20200810@Casey.Huynh	
		Task :		Copy data to New table Gap
		DB:			CTS_DataCenter
		Original: 
		Revisions:	
		Param's Explanation (filtered by):
	*/    
    
    DECLARE vrCustEvidID INT;
    DECLARE vrMaxCustEvidID INT ;
    
    SET vrMaxCustEvidID = (SELECT MAX(CustEvidID) FROM CTS_DataCenter.CustEvidence);
    SET vrCustEvidID = (SELECT MAX(CustEvidID) FROM CTS_DataCenter.CS138925_CustEvidence_New);
    
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;
	WHILE (vrCustEvidID < vrMaxCustEvidID)
    DO
		INSERT IGNORE INTO CTS_DataCenter.CS138925_CustEvidence_New(CustEvidID, CTSCustID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy)
		SELECT  	ce.CustEvidID, ce.CTSCustID, ce.EvidenceID, ce.Remark, ce.Level, ce.FromCustID, ce.CreatedDate, ce.CreatedBy
		FROM 		CTS_DataCenter.CustEvidence AS ce
		WHERE 		CustEvidID > vrCustEvidID
		ORDER BY 	CustEvidID ASC 
		LIMIT 10000;
		
		SET vrCustEvidID = (SELECT MAX(CustEvidID) FROM CTS_DataCenter.CS138925_CustEvidence_New);
    END WHILE;
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
END$$	
DELIMITER ;