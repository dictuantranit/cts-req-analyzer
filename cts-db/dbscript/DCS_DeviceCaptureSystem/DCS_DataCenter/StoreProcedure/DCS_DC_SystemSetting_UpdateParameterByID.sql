/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_SystemSetting_UpdateParameterByID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_SystemSetting_UpdateParameterByID`(
        IN ip_ParameterID   	INT
	,	IN ip_ParameterValue 	VARCHAR(255)
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20240515@Jonathan.Doan
	    Task :	Update System Parameter
	    DB:		DCS_DataCenter
	    Original:
	
	    Revisions:
			- 20240515@Jonathan.Doan: Create [RedmineID: #203691]
            
	    Param's Explanation (filtered by):
        
        Example: 
			CALL DCS_DC_SystemSetting_UpdateParameterByID(4963734, 5);
    */
    
    UPDATE DCS_DataCenter.SystemSetting AS st 
    SET st.VValue = ip_ParameterValue
    WHERE st.ID = ip_ParameterID;
	 
END$$

DELIMITER ;