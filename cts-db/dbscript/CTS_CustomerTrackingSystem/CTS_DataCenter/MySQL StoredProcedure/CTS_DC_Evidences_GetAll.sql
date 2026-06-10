/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Evidences_GetAll`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Evidences_GetAll`()
    SQL SECURITY INVOKER
BEGIN
/*
	Created:	20200203@Adam.Tran
	Task :		Chain To Evidence
	DB:			CTS_DataCenter
	Original:

	Revisions:
		- 20200203@Adam.Tran: Created
		- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
		
	Param's Explanation (filtered by):
*/
    
	SELECT e.EvidenceID
			,e.EvidenceCode
		    ,e.EvidenceName
			,e.EvidenceDesc
	FROM   Evidence AS e
    WHERE e.IsActive = 1
    ORDER BY e.EvidenceGroupID, e.OrderNo;

END$$

DELIMITER ;
