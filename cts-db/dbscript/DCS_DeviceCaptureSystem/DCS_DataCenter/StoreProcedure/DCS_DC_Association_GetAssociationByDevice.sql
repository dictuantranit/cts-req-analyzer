/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Association_GetAssociationByDevice`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Association_GetAssociationByDevice`(
		IN	ip_SubscriberID	INT	    
    ,	IN	ip_FirstDeviceCode VARCHAR(32)
    ,	IN	ip_FromDate DATE
    ,	IN	ip_ToDate DATE
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240924@Jonathan.Doan
		Task:		Get association by Device and Subscriber [Redmine ID: 211226]
		DB:			DCS_DataCenter
		Original:

		Revisions:
		- 20240924@Jonathan.Doan: Created [Redmine ID: #206262]
		
        Param's Explanation (filtered by):

		Example:
			CALL DCS_DC_Association_GetAssociationByDevice(@ip_SubscriberID:=2,@ip_FirstDeviceCode:='464d165f74c441ee924c2c7adedba28f',@ip_FromDate:='2024-09-23',@ip_ToDate:='2024-09-25');
            
	*/
	DECLARE lv_DeviceID	BIGINT UNSIGNED;
    
	SELECT DeviceID
    INTO lv_DeviceID
	FROM DCS_DataCenter.Device
	WHERE FirstDeviceCode = ip_FirstDeviceCode
    LIMIT 1;

	SELECT	acc.LoginName
		,	MIN(trans.TransDate) AS MnUsageDate
		,	MAX(trans.TransDate) AS MaxUsageDate
		,	SUM(trans.TotalTrans) AS UsageCount
	FROM DCS_DataTrace.LoginTransactionSummaryByDevice AS trans
		INNER JOIN DCS_DataCenter.Account AS acc ON acc.AccountID = trans.AccountID
	WHERE trans.SubscriberID = ip_SubscriberID
		AND trans.DeviceID = lv_DeviceID
        AND trans.TransDate BETWEEN ip_FromDate AND ip_ToDate
	GROUP BY trans.AccountID;
    
END$$

DELIMITER ;
