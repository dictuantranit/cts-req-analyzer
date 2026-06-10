/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustEvidence_GetFlaggedFromCustList`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_GetFlaggedFromCustList`(IN ip_FromCTSCustID bigint,IN ip_ToCTSCustID varchar(50))
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200123@Casey.Huynh	
		Task :		GET Affeted Evidence List between 2 customers
		DB:			CTS_DataCenter
		Original: 
		
		Revisions:
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			
		Param's Explanation (filtered by):
	*/
    
    SELECT 		DISTINCT ed.EvidenceCode , ed.EvidenceName
    FROM		CTS_DataCenter.CustEvidence AS ce
    INNER JOIN	CTS_DataCenter.Evidence AS ed
				ON ce.EvidenceID = ed.EvidenceId
	WHERE		(( ce.CTSCustID = ip_FromCTSCustID)
				OR (ce.CTSCustID = ip_ToCTSCustID))
                AND	ce.Level = 0;

END$$

DELIMITER ;