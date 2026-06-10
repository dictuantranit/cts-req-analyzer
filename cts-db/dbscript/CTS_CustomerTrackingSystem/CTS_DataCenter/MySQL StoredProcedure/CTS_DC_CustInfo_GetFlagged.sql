/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_GetFlagged`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_GetFlagged`(
	IN ip_CTSCustID INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20191225@Casey.Huynh	
		Task :		Get Flag Info By CTSCustID
		DB:			CTS_DataCenter
		Original: 
		
		Revisions:
			- 20200706@Lex: Fix logic return flag and affected evidence for root account [Redmine ID: #137055]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			- 20210622@Aries.Nguyen: Update coding convention and improve locking [Redmine ID: #157203]
			- 20210823@Aries.Nguyen: Enhannce  Affected Evidence flow [Redmine ID: #160470]

		Param's Explanation (filtered by):
	*/
    
    DECLARE		lv_IsFlagged	BIT DEFAULT 0 ;  # 0: NOT Flagged, 1: Flagged; 
    DECLARE		lv_IsAffected	BIT DEFAULT 0 ;  # 0: NOT Affected, 1: Affected; 
 
	 /*Check If Account IS IS  FLAG*/
	SELECT EXISTS  (SELECT	1
				    FROM CTS_DataCenter.CustEvidence AS ced
						INNER JOIN	CTS_DataCenter.Evidence	AS  evd ON ced.EvidenceID = evd.EvidenceID
					WHERE ced.CTSCustID = ip_CTSCustID        
                          AND ced.Level = 0) 
	INTO lv_IsFlagged;  
    
    /*Check If Account IS IS Affected*/
	SELECT EXISTS  (SELECT 1
					FROM CTS_DataCenter.CustEvidence AS ced
						INNER JOIN	CTS_DataCenter.Evidence	AS  evd ON ced.EvidenceID = evd.EvidenceID
						LEFT JOIN CTS_DataCenter.CustRetractEvidence AS crev ON ced.CTSCustID = crev.CTSCustID AND ced.EvidenceID = crev.EvidenceID
					WHERE ced.CTSCustID		= ip_CTSCustID        
						AND ced.Level = 2
						AND crev.CTSCustID IS NULL) 
	INTO lv_IsAffected;
    
    SELECT lv_IsFlagged AS Flagged, lv_IsAffected AS Affected;
    
END$$

DELIMITER ;

