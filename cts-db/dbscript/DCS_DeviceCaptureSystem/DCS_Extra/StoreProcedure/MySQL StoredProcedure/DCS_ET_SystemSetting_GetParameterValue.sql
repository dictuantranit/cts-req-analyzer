/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_SystemSetting_GetParameterValue`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_SystemSetting_GetParameterValue`(
        IN ip_ParameterID   INT
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
        
        Example: CALL DCS_ET_SystemSetting_GetParameterValue(1000);
    */
    
	SELECT	st.VValue AS ParameterValue
    FROM DCS_Extra.SystemSetting AS st 
    WHERE st.ID = ip_ParameterID;
	 
END$$

DELIMITER ;
