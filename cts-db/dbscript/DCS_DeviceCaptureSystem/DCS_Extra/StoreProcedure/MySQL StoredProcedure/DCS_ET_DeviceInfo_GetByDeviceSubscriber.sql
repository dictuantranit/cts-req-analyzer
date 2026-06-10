/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_DeviceInfo_GetByDeviceSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_DeviceInfo_GetByDeviceSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_DeviceCode	VARCHAR(32)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230809@Casey.Huynh
		Task :		Search Device by DeviceCode in subscribers
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230809@Casey.Huynh: Created [Redmine ID: 192402]
			
		Param's Explanation (filtered by):

		Example:
			CALL DCS_ET_DeviceInfo_GetByDeviceSubscriber(@ip_SubscriberID:=8000001,@ip_DeviceCode:='71ea9dc88d474a96b042e0436f9c745f');
            CALL DCS_ET_DeviceInfo_GetByDeviceSubscriber(@ip_SubscriberID:=8000001,@ip_DeviceCode:='bf2de4decc2dfc258d0ac7f148d82faa');
	*/   

	#========SEARCH BY DeviceCode=====================
    DECLARE lv_DeviceID BIGINT UNSIGNED;
    DECLARE lv_DeviceCode VARCHAR(32);
    DECLARE lv_UserAgentKey VARCHAR(32);
    DECLARE lv_OS VARCHAR(20);
     
    SELECT	dv.DeviceID, dv.FirstDeviceCode, dv.UserAgentKey
    INTO lv_DeviceID, lv_DeviceCode, lv_UserAgentKey
    FROM DCS_Extra.Device AS dv
	WHERE dv.FirstDeviceCode = ip_DeviceCode
		AND EXISTS (SELECT 1 FROM DCS_Extra.Association AS ass WHERE ass.DeviceID = dv.DeviceID AND ass.SubscriberID = ip_SubscriberID);   

    #===========Return Info=============
    IF lv_UserAgentKey IS NOT NULL THEN	
		SELECT ua.OS
        INTO lv_OS
		FROM  DCS_Extra.UserAgent AS ua
		WHERE ua.UserAgentKey = lv_UserAgentKey;
	END IF;
	SELECT lv_DeviceID AS DeviceID , lv_DeviceCode AS DeviceCode, lv_OS AS OS;
    
END$$
DELIMITER ;
