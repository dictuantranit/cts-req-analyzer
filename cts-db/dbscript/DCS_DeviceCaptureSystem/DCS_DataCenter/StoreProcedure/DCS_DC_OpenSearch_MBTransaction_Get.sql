/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_OpenSearch_MBTransaction_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_OpenSearch_MBTransaction_Get`(
		IN ip_BatchSize INT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20250812@Jonathan.Doan
	Task : Get MBTransaction for OpenSearch
	DB: DCS_DataCenter
	Original:

	Revisions:
		- 20250812@Jonathan.Doan: Created [Redmine ID: 235457]
		
	Param's Explanation (filtered by):

	Example:
        CALL DCS_DataCenter.DCS_DC_OpenSearch_MBTransaction_Get(100);
	*/
    DECLARE CONST_DEVICETRANSFORM_MAXMBTRANSACTION07IDCOMPLETED	INT			DEFAULT 4;
	DECLARE CONST_OPENSEARCH_MBTRANSACTION07_TRANSID 			INT 		DEFAULT 102;
    
	DECLARE lv_MaxTransID  				BIGINT UNSIGNED;
	DECLARE lv_MaxTransIDCompleted		BIGINT UNSIGNED;
	DECLARE lv_CurrentDatetime 			DATETIME DEFAULT CURRENT_TIMESTAMP();

	SET lv_MaxTransID			= (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_OPENSEARCH_MBTRANSACTION07_TRANSID);
	SET lv_MaxTransIDCompleted	= (SELECT CAST(VValue AS UNSIGNED) FROM DCS_DataCenter.SystemSetting WHERE ID = CONST_DEVICETRANSFORM_MAXMBTRANSACTION07IDCOMPLETED);

	DROP TEMPORARY TABLE IF EXISTS Temp_MBTrans07;
    
    #======GET DATA FROM MBTRANSACTION07===========================
	CREATE TEMPORARY TABLE Temp_MBTrans07(
			ID				    		BIGINT UNSIGNED NOT NULL PRIMARY KEY
		,	MBRawTransactionID			BIGINT UNSIGNED
		,	TransTime 					DATETIME(4)
		,	SubscriberID 				INT
		,	MBAccountID					BIGINT UNSIGNED
		,	MBDeviceMappingID			BIGINT UNSIGNED
		,	MBDeviceID					BIGINT UNSIGNED
		,	DeviceStatus 				TINYINT
		,	IP 							VARCHAR(50)
		,	IPID 						DECIMAL(50,0)
		,	Flagged 					SMALLINT
		,	MBDeviceModelID				BIGINT UNSIGNED
		,	MBOSID      				BIGINT UNSIGNED
		,	MBUserSettingID  			BIGINT UNSIGNED
	);

	INSERT IGNORE INTO Temp_MBTrans07(ID, MBRawTransactionID, TransTime, SubscriberID, MBAccountID, MBDeviceMappingID, MBDeviceID, DeviceStatus, IP, IPID, Flagged, MBDeviceModelID, MBOSID, MBUserSettingID)
		SELECT 	trans.ID
            ,	trans.MBRawTransactionID
            ,	trans.TransTime
            ,	trans.SubscriberID
            ,	trans.MBAccountID
            ,	trans.MBDeviceMappingID
            ,	trans.MBDeviceID
            ,	trans.DeviceStatus
            ,	trans.IP
            ,	trans.IPID
            ,	trans.Flagged
            ,	trans.MBDeviceModelID
            ,	trans.MBOSID
            ,	trans.MBUserSettingID
	FROM DCS_DataCenter.MBTransaction07 AS trans
	WHERE trans.ID > lv_MaxTransID
		AND trans.ID <= lv_MaxTransIDCompleted
	ORDER BY trans.ID ASC
	LIMIT ip_BatchSize;
	
	#========Return===========================
	SELECT	trans.ID AS TransID
        ,	trans.TransTime
        ,	trans.SubscriberID
        ,	pt.SubscriberName
        ,	trans.MBAccountID
        ,	acc.IsCTSTransformed
        ,	acc.LoginName
        ,	trans.MBDeviceMappingID
        ,	dm.MBDeviceCodeTaggingID
        ,	dm.MBDeviceCodeMachineAccountID
        ,	dm.MBDeviceCodeMachineMediaID
        ,	dm.RecoverType
        ,	trans.MBDeviceID
        ,	trans.DeviceStatus
        ,	trans.IP
        ,	CAST(trans.IPID AS CHAR) AS IPID
        ,	trans.Flagged
        ,	pt.IsEmulator
        ,	trans.MBDeviceModelID
        ,	pt.ModelName
        ,	pt.Manufacturer
        ,	pt.Brand
        ,	trans.MBOSID
        ,	pt.OSName
        ,	pt.SDKVersion
        ,	trans.MBUserSettingID
        ,	pt.Country
        ,	pt.Timezone
        ,	pt.Language
        ,	pt.DeviceDetails
	FROM Temp_MBTrans07 AS trans
        INNER JOIN DCS_DataCenter.MBProcessedTransaction AS pt ON pt.ID = trans.MBRawTransactionID
        INNER JOIN DCS_DataCenter.MBAccount AS acc ON acc.ID = trans.MBAccountID
        LEFT JOIN DCS_DataCenter.MBDeviceMapping AS dm ON dm.ID = trans.MBDeviceMappingID;
END$$
DELIMITER ;
