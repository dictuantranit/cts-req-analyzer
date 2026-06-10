/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_SystemParameter_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_SystemParameter_Get`(
	IN ip_ParamID 	SMALLINT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200728@Long.Luu	
		Task :		Get System Parameter by ID
		DB:			CTS_DataCenter
		Original: 	SystemParameter
		Revisions:
			- 20200728@Long.Luu: Created [Redmine ID: #136652]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			- 20210625@Long.Luu: Refactor  [Redmine ID: #157203]
		Param's Explanation:
	*/
    SELECT 	s.ParameterValue
		,	s.ParameterDataType
    FROM CTS_DataCenter.SystemParameter AS s
    WHERE s.ParameterID = ip_ParamID;
END$$
DELIMITER ;
