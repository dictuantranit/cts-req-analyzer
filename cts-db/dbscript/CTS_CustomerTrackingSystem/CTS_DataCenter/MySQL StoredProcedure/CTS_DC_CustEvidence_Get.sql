/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustEvidence_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_Get`(
		IN ip_CTSCustID INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20191218@Marcus
		Task :		Get Distinct Customer Evidence for All Level
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20200218@CaseyHuynh: Remove Inner Join with EvidenceGroup, and Disctinct Evidence
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
					
		Param's Explanation (filtered by):
	*/
    
	SELECT	DISTINCT 
			e.EvidenceName
		,	e.EvidenceDesc
		,	e.EvidenceCode
		,	e.OrderNo
	FROM   CustEvidence AS ce
		INNER JOIN Evidence AS e  ON ce.EvidenceID = e.EvidenceID
	WHERE  ce.CTSCustID = ip_CTSCustID;

END$$

DELIMITER ;
