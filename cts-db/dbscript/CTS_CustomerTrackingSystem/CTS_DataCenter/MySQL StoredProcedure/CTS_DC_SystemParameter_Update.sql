/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin,ctsAPI,ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_SystemParameter_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_SystemParameter_Update`(	
		IN ip_ParamID			SMALLINT UNSIGNED
    ,   IN ip_ParamValue		VARCHAR(50)
    
    , 	OUT op_ErrorMessage 	VARCHAR(200)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200728@Long.Luu	
		Task :		Get System Parameter by ID
		DB:			CTS_DataCenter
		Original: SystemParameter
		Revisions:
			- 20200728@Long.Luu: Created [Redmine ID: #136652]
			- 20210625@Long.Luu: Refactor  [Redmine ID: #157203]
		Param's Explanation:
	*/ 
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
    
    UPDATE CTS_DataCenter.SystemParameter AS s
	SET s.ParameterValue = ip_ParamValue
    WHERE s.ParameterID = ip_ParamID;
END$$
DELIMITER ;