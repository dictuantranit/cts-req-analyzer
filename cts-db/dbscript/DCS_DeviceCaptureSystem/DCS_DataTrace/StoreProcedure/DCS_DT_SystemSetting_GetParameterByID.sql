/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_SystemSetting_GetParameterByID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_SystemSetting_GetParameterByID`(
        IN ip_ParameterID   INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20231009@Jonathan.Doan
	    Task :	Get System Parameter
	    DB:		DCS_DataTrace
	    Original:
	
	    Revisions:
			- 20231009@Jonathan.Doan: Create [RedmineID: #194933]
            
	    Param's Explanation (filtered by):
        
        Example: CALL DCS_DT_SystemSetting_GetParameterByID(1);
    */
    
	SELECT	st.VValue AS ParameterValue
    FROM DCS_DataTrace.SystemSetting AS st 
    WHERE st.ID = ip_ParameterID;
	 
END$$

DELIMITER ;