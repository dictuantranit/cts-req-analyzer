/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_SystemSetting_UpdateParameterByID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_SystemSetting_UpdateParameterByID`(
        IN ip_ParameterID   	INT
	,	IN ip_ParameterValue 	VARCHAR(255)
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20231009@Jonathan.Doan
	    Task :	Update System Parameter
	    DB:		DCS_DataTrace
	    Original:
	
	    Revisions:
			- 20231009@Jonathan.Doan: Create [RedmineID: #190118]
			- 20231026@Jonathan.Doan: Refactor code [Redmine ID: 195332]
            
	    Param's Explanation (filtered by):
        
        Example: CALL DCS_DT_SystemSetting_UpdateParameterByID(1, 0);
    */
    
    UPDATE DCS_DataTrace.SystemSetting AS st 
    SET st.VValue = ip_ParameterValue
    WHERE st.ID = ip_ParameterID;
	 
END$$

DELIMITER ;
