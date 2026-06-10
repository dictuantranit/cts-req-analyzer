/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_Profile_GetEvidence`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_Profile_GetEvidence`(
		IN ip_CTSCustID BIGINT UNSIGNED 
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20211214@Aries.Nguyen	
		Task :		Enrich the information on customer profile
		DB:			CTS_DataCenter
		
		Revisions:
			- 20211214@Aries.Nguyen: Created [Redmine ID: #165105]

		Param's Explanation (filtered by):
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustInfo_Profile_GetEvidence(200);
	*/
	SELECT 	EvidenceID
		,	EvidenceCode
        ,	1 AS IsFlag
	FROM CTS_DataCenter.Evidence AS ev
	WHERE EXISTS (SELECT 1 
				  FROM CTS_DataCenter.CustEvidence AS cust
				  WHERE cust.CTSCustID = ip_CTSCustID
					AND	cust.Level = 0
					AND cust.EvidenceID =  ev.EvidenceID)
	UNION ALL 
	SELECT 	EvidenceID
		,	EvidenceCode
        ,	0 AS IsFlag
	FROM CTS_DataCenter.Evidence AS ev
	WHERE EXISTS (SELECT 1 
				  FROM CTS_DataCenter.CustEvidence AS cust
				  WHERE cust.CTSCustID = ip_CTSCustID
					AND	cust.Level = 2
					AND cust.EvidenceID =  ev.EvidenceID);
END$$

DELIMITER ;