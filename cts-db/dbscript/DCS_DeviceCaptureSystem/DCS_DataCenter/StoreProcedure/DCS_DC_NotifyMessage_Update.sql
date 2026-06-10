/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_NotifyMessage_UpdateNotified`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_NotifyMessage_UpdateNotified`(
		IN ip_IDs LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20230615@Jonathan.Doan
	    Task : Update NotifyMessage IsNotified
	    DB: DCS_DataCenter
	    Original:

	    Revisions:		    
			-	20230615@Jonathan.Doan: Created [Redmine ID: 189732]
            
	    Param's Explanation (filtered by):
        
        Example: CALL DCS_DC_NotifyMessage_UpdateNotified('1,2');
    */
    DECLARE lv_CurrentDate DATETIME DEFAULT CURRENT_TIMESTAMP();
    
	DROP TEMPORARY TABLE IF EXISTS Temp_InputTrans;    
	CREATE TEMPORARY TABLE Temp_InputTrans(
		Id	BIGINT UNSIGNED PRIMARY KEY
	);
    
    SET @sql = CONCAT("INSERT INTO Temp_InputTrans (ID) VALUES ('", REPLACE(ip_IDs, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
	UPDATE Temp_InputTrans AS tmp
		INNER JOIN DCS_DataCenter.NotifyMessage AS nm ON tmp.ID = nm.ID
	SET 	nm.IsNotified = 1
		,	nm.SentDate = lv_CurrentDate;
    
END$$
DELIMITER ;
