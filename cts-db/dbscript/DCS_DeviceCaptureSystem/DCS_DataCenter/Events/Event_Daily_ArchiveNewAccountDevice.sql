DELIMITER //
DROP EVENT IF EXISTS Event_Daily_ArchiveNewAccountDevice;
/*
	Created: 20230417@Jonathan.Doan
	Task : Archive Data From ArchiveNewAccountDevice using DROP PARTITION
	DB: DCS_DataCenter
	Original:

	Revisions:
	Param's Explanation (filtered by):
	*/
CREATE DEFINER=`vndbaDeployment`@`%` EVENT Event_Daily_ArchiveNewAccountDevice
    ON SCHEDULE
		EVERY 1 WEEK
		STARTS '2023-04-17 00:00:00'
        ON COMPLETION PRESERVE ENABLE
    COMMENT 'Archive Data From ArchiveNewAccountDevice using DROP PARTITION'
    DO this_event:BEGIN      	
		 DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
		 BEGIN
		   DO RELEASE_LOCK('lock_event');
		 END;
         IF GET_LOCK('lock_event', 0) THEN
				CALL DCS_DataCenter.DCS_DC_ArchiveData_NewAccountDevice();
		 END IF;
		 DO RELEASE_LOCK('lock_event');             
      END //
DELIMITER ;