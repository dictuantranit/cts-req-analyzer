DELIMITER //
DROP EVENT IF EXISTS Event_Daily_ArchiveProcessedTransaction;
CREATE EVENT Event_Daily_ArchiveProcessedTransaction	
    ON SCHEDULE
    /*
	Created: 20200330@Terry.Nguyen
	Task : Archive processed raw transaction
	DB: DCS_RawTransaction
	Original:
	Revisions:
	Param's Explanation (filtered by):
	*/
    
		#EVERY 1 DAY
		#STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 1 HOUR)
        EVERY 30 MINUTE
        STARTS NOW()
        ON COMPLETION PRESERVE ENABLE
    COMMENT 'Archive processed raw transaction'
    DO this_event:BEGIN      	
		 DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
		 BEGIN
		   DO RELEASE_LOCK('lock_event');
		 END;
         IF GET_LOCK('lock_event', 0) THEN
				CALL DCS_RawTransaction.DCS_ST_ArchiveProcessedTransaction(7);  
		 END IF;
		 DO RELEASE_LOCK('lock_event');             
      END //
DELIMITER ;