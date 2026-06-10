DELIMITER $$
CREATE DEFINER=`fps`@`%` PROCEDURE `Harvey_UpdateUsername`()
BEGIN
	/*
		Created: 20200305@Harvey
		Task : Update data adhoc
		DB: FPS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
    
	DROP TEMPORARY TABLE IF EXISTS TempCTSCustomer_updateCasey;
	CREATE TEMPORARY TABLE TempCTSCustomer_updateCasey
	(		
	CTSCustID		BIGINT
	);
    
    fixData: LOOP
		insert into TempCTSCustomer_updateCasey
		select CTSCustID from CTSCustomer
		where CustID is null
		and UserName is null
		limit 500;
        
        IF row_count() = 0 THEN 
			LEAVE fixData;
		END IF;
        
		update CTSCustomer cus
		inner join TempCTSCustomer_updateCasey casey on cus.CTSCustID = casey.CTSCustID
		set cus.UserName = '';

		truncate table TempCTSCustomer_updateCasey;
    END LOOP;
            
	END$$
DELIMITER ;
