/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb,ctsAPI" isFunction="0" isNested="0"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_CustEvidence_GetEvidencesByDirectAssociation`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_GetEvidencesByDirectAssociation`(
		IN ip_CustIDs TEXT
)
    SQL SECURITY INVOKER
BEGIN

	/*
		Created:	20210226@JonasHuynh
		Task:		Get Flagged Evidences by Association for level 0,1 [Redmine ID: 150456]
		DB:			CTS_DataCenter
		Original:

		Revisions:
           - 20210226@JonasHuynh: Created [Redmine ID: #150456]
           - 20210308@JonasHuynh: Update logic SP [Redmine ID: #150456]
		   - 20210622@Aries.Nguyen: Update coding convention and improve locking[Redmine ID: #157203]
		   - 20211014@Aries.Nguyen: Remove association unlink[Redmine ID: #163093]
		   - 20211021@Aries.Nguyen: Return only evidence infor[Redmine ID: #163514]
		   
		Param's Explanation (filtered by):		
		
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustEvidence_GetEvidencesByDirectAssociation('43600693,1176086');
	*/
    
	DROP TEMPORARY TABLE IF EXISTS Temp_RootCustomer;    
	CREATE TEMPORARY TABLE Temp_RootCustomer(	  
			RootCustID			INT UNSIGNED  
		,	CustID              BIGINT UNSIGNED PRIMARY KEY
		,	CTSCustID           BIGINT UNSIGNED
        ,	INDEX 				IX_Temp_RootCustomer (CTSCustID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_CustID;    
	CREATE TEMPORARY TABLE Temp_CustID(	  
			CustID              BIGINT UNSIGNED
        ,	INDEX 				IX_Temp_CustID_CustID (CustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Unlink;    
	CREATE TEMPORARY TABLE Temp_Unlink(	  
			RootCTSCustID       BIGINT UNSIGNED
        ,	AssCTSCustID 		BIGINT UNSIGNED 
	);
	      
    DROP TEMPORARY TABLE IF EXISTS   Temp_FlaggedEvidence;
    CREATE TEMPORARY TABLE Temp_FlaggedEvidence(
		 	AssCTSCustID		BIGINT UNSIGNED  
		,	RootCustID			BIGINT UNSIGNED
        ,	RootCTSCustID		BIGINT UNSIGNED
        ,	EvidenceID			INT
		,	CreatedDate			DATETIME
		, 	AssociationLevel	SMALLINT
        ,	INDEX 				IX_Temp_FlaggedEvidence(AssCTSCustID, RootCustID)
	);
        
	/* Insert CustIDs  */
	SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_CustID (CustID) VALUES ('", REPLACE(ip_CustIDs, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1;   
    
	/* Update CTSCustID */
	INSERT IGNORE INTO Temp_RootCustomer(RootCustID, CustID, CTSCustID)
	SELECT  cust.CustID
		,	temp.CustID
		,	cust.CTSCustID
	FROM Temp_CustID AS temp
		INNER JOIN  CTS_DataCenter.CTSCustomer AS cust ON cust.CustID = temp.CustID AND cust.CustSubID = 0;
        
	
    /* Get Direct Association */
    INSERT INTO Temp_FlaggedEvidence (AssCTSCustID, RootCustID, RootCTSCustID, EvidenceID, CreatedDate, AssociationLevel)
	SELECT  ce.FromCustID 	AS AssCTSCustID
		,	c.CustID 		AS RootCustID
        ,	c.CTSCustID		AS RootCTSCustID
        , 	ce.EvidenceID
        , 	ce.CreatedDate
        ,	CASE WHEN ce.Level = 0 THEN 0 ELSE 1 END AS AssociationLevel	   
	FROM Temp_RootCustomer AS c	
		INNER JOIN CTS_DataCenter.CustEvidence AS ce ON ce.CTSCustID = c.CTSCustID;
        
	 /* Unlink  Association */
	INSERT INTO Temp_Unlink(RootCTSCustID, AssCTSCustID)
    SELECT 	tmp.CTSCustID
		,	rm.ToCTSCustID
    FROM  Temp_RootCustomer AS tmp 
		INNER JOIN CTS_DataCenter.AssociationRemove AS rm ON rm.FromCTSCustID = tmp.CTSCustID;
	
    INSERT INTO Temp_Unlink(RootCTSCustID, AssCTSCustID)
    SELECT 	tmp.CTSCustID
		,	rm.FromCTSCustID
    FROM  Temp_RootCustomer AS tmp 
		INNER JOIN CTS_DataCenter.AssociationRemove AS rm ON rm.ToCTSCustID = tmp.CTSCustID;
    
    DELETE ass
    FROM Temp_FlaggedEvidence AS ass
    WHERE EXISTS (SELECT 1 
				  FROM Temp_Unlink AS rm 
                  WHERE rm.RootCTSCustID = ass.RootCTSCustID 
					AND rm.AssCTSCustID = ass.AssCTSCustID);
    
        
	/* Return CustId, Level0CustId, EvidenceCode, EvidenceName, CreatedDate, AssociatedLevel */
    SELECT	DISTINCT 
			e.EvidenceCode			AS EvidenceCode
		,	temp.AssociationLevel	AS AssociatedLevel
		,	temp.RootCustID 		AS Level0CustId
    FROM Temp_FlaggedEvidence AS temp
  		INNER JOIN CTS_DataCenter.Evidence AS e ON e.EvidenceID = temp.EvidenceID AND e.IsActive = True;
  
END$$

DELIMITER ;