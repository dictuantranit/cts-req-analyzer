/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_SystemSetting_GetParameterByID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_SystemSetting_GetParameterByID`(
        IN ip_ParameterID   INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20240515@Jonathan.Doan
	    Task :	Get System Parameter
	    DB:		DCS_DataCenter
	    Original:
	
	    Revisions:
			- 20240515@Jonathan.Doan: Create [RedmineID: #203691]
            
	    Param's Explanation (filtered by):
        
        Example: 
			CALL DCS_DC_SystemSetting_GetParameterByID(4963734);
    */
    
	SELECT	st.VValue AS ParameterValue
    FROM DCS_DataCenter.SystemSetting AS st 
    WHERE st.ID = ip_ParameterID;
	 
END$$

DELIMITER ;