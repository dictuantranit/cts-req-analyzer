/*<info serverAlias="CTSMain-CTS_Adhoc" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
USE CTS_Adhoc;
DROP PROCEDURE IF EXISTS `Adhoc_DCS_DC_Initial_MBRawTransaction`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `Adhoc_DCS_DC_Initial_MBRawTransaction`(
		IN ip_BatchSize INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20250819@Jonathan.Doan
	    Task : Initial MBRawTransaction
	    DB: CTS_Adhoc
	    Original:

	    Revisions:
		    - 20250819@Jonathan.Doan: Created [RedmineID: #235457]
	    Param's Explanation (filtered by):
        
        Example:
			SET sql_safe_updates = 0;
			CALL CTS_Adhoc.Adhoc_DCS_DC_Initial_MBRawTransaction(10000);
	*/
    DECLARE CONST_SYSTEMSETTING_LASTTRANSID 	BIGINT UNSIGNED DEFAULT 1002;
    
    DECLARE lv_LastTransID 						BIGINT UNSIGNED;
    DECLARE lv_MaxTransID 						BIGINT UNSIGNED;
    
    DECLARE lv_From_TransID						BIGINT UNSIGNED;
    DECLARE lv_To_TransID						BIGINT UNSIGNED;
    
    DECLARE lv_CurrentDate 						TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
    
	SET lv_LastTransID = (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_SYSTEMSETTING_LASTTRANSID);
	SET lv_MaxTransID = (SELECT MAX(ID) FROM DCS_DataCenter.MBProcessedTransaction_bk);

    WHILE lv_LastTransID < lv_MaxTransID DO
		WITH cte AS (
			SELECT ID
            FROM DCS_DataCenter.MBProcessedTransaction_bk
			WHERE ID > lv_LastTransID
			ORDER BY ID ASC
			LIMIT ip_BatchSize
        )
        SELECT 	MIN(cte.ID)
			,	MAX(cte.ID)
		INTO lv_From_TransID, lv_To_TransID
        FROM cte;
        
		INSERT INTO DCS_DataCenter.MBRawTransaction(ID, LoginName, SubscriberName, TransTime, IP, IPID, Action, ActionResult, Flagged, MBDeviceCodeMediaDRM, MBDeviceCodeMachine, MBDeviceCodeTagging, IsEmulator, ModelName, Manufacturer, Brand, SDKVersion, OSName, Timezone, Language, CountryName, InsertedTime)
		SELECT	ID
			,	LoginName
			,	SubscriberName
			,	TransTime
			,	IP
			,	IPID
			,	Action
			,	ActionResult
			,	Flagged
			,	MBDeviceCodeMediaDRM
			,	MBDeviceCodeMachine
			,	MBDeviceCodeTagging
			,	IsEmulator
			,	ModelName
			,	Manufacturer
			,	Brand
			,	SDKVersion
			,	OSName
			,	Timezone
			,	Language
			,	Country AS CountryName
			,	InsertedTime
		FROM DCS_DataCenter.MBProcessedTransaction_bk
        WHERE ID BETWEEN lv_From_TransID AND lv_To_TransID
			AND OSName <> 'IOS'
		ORDER BY ID ASC;
        
		INSERT INTO DCS_DataCenter.MBRawTransactionIOS(ID, LoginName, SubscriberName, TransTime, IP, IPID, Action, ActionResult, Flagged, MBDeviceCodeMediaDRM, MBDeviceCodeMachine, MBDeviceCodeTagging, IsEmulator, ModelName, Manufacturer, Brand, SDKVersion, OSName, CountryName, Timezone, Language)
		SELECT	ID
			,	LoginName
			,	SubscriberName
			,	TransTime
			,	IP
			,	IPID
			,	Action
			,	ActionResult
			,	Flagged
			,	MBDeviceCodeMediaDRM
			,	MBDeviceCodeMachine
			,	MBDeviceCodeTagging
			,	IsEmulator
			,	ModelName
			,	Manufacturer
			,	Brand
			,	SDKVersion
			,	OSName
			,	Country AS CountryName
			,	Timezone
			,	Language
		FROM DCS_DataCenter.MBProcessedTransaction_bk
		WHERE ID BETWEEN lv_From_TransID AND lv_To_TransID
			AND OSName = 'IOS'
		ORDER BY ID ASC;
        
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
