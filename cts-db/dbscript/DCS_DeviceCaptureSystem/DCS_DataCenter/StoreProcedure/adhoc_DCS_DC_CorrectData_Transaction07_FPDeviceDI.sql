/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `adhoc_DCS_DC_CorrectData_Transaction07_FPDeviceID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `adhoc_DCS_DC_CorrectData_Transaction07_FPDeviceID`(
		IN ip_BatchSize INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20241024@Jonathan.Doan
	    Task : Update Data for new FP flow (Reset data)
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20241024@Jonathan.Doan: Created [RedmineID: #212641]
	    Param's Explanation (filtered by):
        
        Example:
			SET sql_safe_updates = 0;
			CALL adhoc_DCS_DC_CorrectData_Transaction07_FPDeviceID(1);
	*/
    DECLARE CONST_SYSTEMSETTING_LASTTRANSID 	BIGINT UNSIGNED DEFAULT 1000;
    DECLARE CONST_SYSTEMSETTING_LIMITTRANSID 	BIGINT UNSIGNED DEFAULT 1001;
    
    DECLARE lv_LastTransID 						BIGINT UNSIGNED;
    DECLARE lv_LimitTransID 					BIGINT UNSIGNED;
    
    DECLARE lv_From_TransID						BIGINT UNSIGNED;
    DECLARE lv_To_TransID						BIGINT UNSIGNED;
    
    DECLARE lv_CurrentDate 						TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
    
	SET lv_LastTransID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_SYSTEMSETTING_LASTTRANSID);
	SET lv_LimitTransID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_SYSTEMSETTING_LIMITTRANSID);
    
    
    WHILE lv_LastTransID < lv_LimitTransID DO
		WITH cte AS (
			SELECT TransID
            FROM DCS_DataCenter.Transaction07
			WHERE TransID > lv_LastTransID
				AND TransID <= lv_LimitTransID
				AND FP_DeviceMappingID > 0
			ORDER BY TransID ASC
			LIMIT ip_BatchSize
        )
        SELECT 	MIN(cte.TransID)
			,	MAX(cte.TransID)
		INTO lv_From_TransID, lv_To_TransID
        FROM cte;
        
        UPDATE DCS_DataCenter.Transaction07
		SET FP_DeviceMappingID = 0,
			FP_DeviceID = 0,
			FP_DeviceStatus = 0
        WHERE TransID BETWEEN lv_From_TransID AND lv_To_TransID
			AND FP_DeviceMappingID > 0;
		
        
        SET lv_LastTransID = lv_To_TransID;
		IF lv_LastTransID IS NOT NULL AND lv_LastTransID > 0 THEN
			UPDATE DCS_DataCenter.SystemSetting AS sys
			SET sys.VValue = CONCAT('', lv_LastTransID),
				sys.UpdatedTime = lv_CurrentDate
			WHERE ID = CONST_SYSTEMSETTING_LASTTRANSID;
		END IF;
    END WHILE;
END$$

DELIMITER ;
