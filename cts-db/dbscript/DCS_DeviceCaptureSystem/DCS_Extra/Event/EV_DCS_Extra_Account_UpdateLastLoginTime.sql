DROP EVENT IF EXISTS EV_DCS_Extra_Account_UpdateLastLoginTime;
DELIMITER //

/*
	Creator:	20230628@Casey.Huynh
	Task:	 	New DB DCS_Extra
	Server:  	Master
	DBName:		DCS_Extra

	Revisions: 
			- 20230628@Casey.Huynh: Created [Redmine ID: #190118]
		Reviewer:
*/
CREATE DEFINER=`DBMaintainer`@`%` EVENT `EV_DCS_Extra_Account_UpdateLastLoginTime` ON SCHEDULE EVERY 4 SECOND STARTS '2023-06-30 00:00:00' ON COMPLETION NOT PRESERVE ENABLE DO BEGIN
	IF EXISTS(SELECT 1 FROM CTS_DataCenter.SystemEventStatus WHERE EventName = 'EV_DCS_Extra_Account_UpdateLastLoginTime' AND Status = 'Stop') THEN
		UPDATE CTS_DataCenter.SystemEventStatus 
		SET Status = 'Start' 
		WHERE EventName = 'EV_DCS_Extra_Account_UpdateLastLoginTime' ;

		CALL DCS_Extra.DCS_ET_Transform_Account_UpdateLastLoginTime(1000); 

		UPDATE CTS_DataCenter.SystemEventStatus 
		SET Status = 'Stop' 
		WHERE EventName = 'EV_DCS_Extra_Account_UpdateLastLoginTime' ;

	END IF;
      
END //
DELIMITER ;