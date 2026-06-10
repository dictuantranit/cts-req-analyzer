/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_SystemSetting_UpdateParameterValue`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_SystemSetting_UpdateParameterValue`(
        IN ip_ParameterID   INT
	,	IN ip_ParameterValue VARCHAR(255)
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20230718@Casey.Huynh
	    Task :	Get System Parameter
	    DB:		DCS_Extra
	    Original:
	
	    Revisions:
			- 20230718@Casey.Huynh: Create [RedmineID: #190118]
            
	    Param's Explanation (filtered by):
        
        Example: CALL DCS_ET_SystemSetting_UpdateParameterValue(1000, '2022-12-31 23:59:59');
    */
    
    UPDATE DCS_Extra.SystemSetting AS st 
    SET st.VValue = ip_ParameterValue
    WHERE st.ID = ip_ParameterID;
	 
END$$

DELIMITER ;
