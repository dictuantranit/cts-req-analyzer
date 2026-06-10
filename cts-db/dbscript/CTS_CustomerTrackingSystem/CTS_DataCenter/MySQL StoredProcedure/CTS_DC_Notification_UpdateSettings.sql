/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Notification_UpdateSettings`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Notification_UpdateSettings`(
		IN ip_UserID			INT
	,	IN ip_FunctionID		SMALLINT
	,	IN ip_IsTurningOn		BIT
	
	,	OUT op_ErrorMessage		VARCHAR(200)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	2020106@Long.Luu
		Task:		Update Notification Settings (On/Off) [Redmine ID: #142414]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 2020106@Long.Luu: Created [Redmine ID: #142414]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
        
		Param's Explanation (filtered by):
	*/
    
    DECLARE lv_CurrentDateTime	 	DATETIME;  
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
      
	SET lv_CurrentDateTime			= CURRENT_TIME();    
            
    IF (ip_IsTurningOn = 0) THEN		
		UPDATE CTS_DataCenter.NotificationSettings
		SET 	GrantedTo = lv_CurrentDateTime
			,	LastModifiedDate = lv_CurrentDateTime
		WHERE UserID = ip_UserID 
			AND FunctionID = ip_FunctionID
            AND GrantedTo IS NULL;
		
        UPDATE CTS_DataCenter.CTSUserPermission
		SET IsTurnedOnNotification = 0
		WHERE UserID = ip_UserID 
			AND FunctionID = ip_FunctionID;
	ELSE
		INSERT INTO NotificationSettings(UserID, FunctionID, FunctionName, GrantedFrom, CreatedDate, LastModifiedDate)
		SELECT 	ip_UserID
			, 	ip_FunctionID
            , 	CASE WHEN ip_FunctionID = 1 THEN 'AssociatedAccountMonitor' ELSE 'ProbationManagement' END
            , 	lv_CurrentDateTime
            , 	lv_CurrentDateTime
            , 	lv_CurrentDateTime;

		UPDATE CTS_DataCenter.CTSUserPermission
		SET IsTurnedOnNotification = 1
		WHERE UserID = ip_UserID 
			AND FunctionID = ip_FunctionID;
	END IF;
	
END$$

DELIMITER ;