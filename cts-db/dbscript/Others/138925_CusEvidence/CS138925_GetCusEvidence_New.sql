DELIMITER $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.CS138925_GetCusEvidence_New$$
CREATE PROCEDURE CTS_Adhoc.CS138925_GetCusEvidence_New()
BEGIN
	/*
		Created:	20200810@Casey.Huynh	
		Task :		GET Evidence BK
		DB:			CTS_DataCenter
		Original: 
		Revisions:	
		Param's Explanation (filtered by):
	*/    
    
    DECLARE vrCustEvidID INT DEFAULT 0;
    DECLARE vrMaxCustEvidID INT ;
    #===0.Declare==========================================================================================
    
	CREATE TABLE IF NOT EXISTS CTS_DataCenter.CS138925_CustEvidence_New(
		CustEvidID			BIGINT		UNSIGNED	AUTO_INCREMENT	NOT NULL
		, CTSCustID			BIGINT		UNSIGNED					NOT NULL
		, EvidenceID		SMALLINT								NOT NULL
		, Remark			VARCHAR(500)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NULL
		, Level				TINYINT									NOT NULL	COMMENT 'Level 1 - 2'
		, FromCustID		BIGINT		UNSIGNED					NOT NULL
		, CreatedDate		DATETIME								NOT NULL
		, CreatedBy			INT										NOT NULL
        
        , PRIMARY KEY	PK_CustEvidence(CTSCustID, FromCustID, EvidenceID)
        , INDEX		IX_CustEvidence(FromCustID, CTSCustID, EvidenceID)
        , UNIQUE INDEX	UX_CustEvidence_CustEvidID(CustEvidID)
	) ENGINE=INNODB  AUTO_INCREMENT=1;  
    
    SET vrMaxCustEvidID = (SELECT MAX(CustEvidID) FROM CTS_DataCenter.CustEvidence);
    
	SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;
	WHILE (vrCustEvidID < vrMaxCustEvidID)
    DO
		INSERT IGNORE INTO CTS_DataCenter.CS138925_CustEvidence_New(CustEvidID, CTSCustID, EvidenceID, Remark, Level, FromCustID, CreatedDate, CreatedBy)
		SELECT  	ce.CustEvidID, ce.CTSCustID, ce.EvidenceID, ce.Remark, ce.Level, ce.FromCustID, ce.CreatedDate, ce.CreatedBy
		FROM 		CTS_DataCenter.CustEvidence AS ce
		WHERE 		CustEvidID > vrCustEvidID
		ORDER BY 	CustEvidID ASC 
		LIMIT 		10000;
		
		SET vrCustEvidID = (SELECT MAX(CustEvidID) FROM CTS_DataCenter.CS138925_CustEvidence_New);
    END WHILE;
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
END$$	
DELIMITER ;