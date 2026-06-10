/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Association_GetAccountInfoByAccountSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Association_GetAccountInfoByAccountSubscriber`(
		IN ip_SubscriberID		INT
	,	IN ip_AccountID			BIGINT UNSIGNED       
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230720@Casey.Huynh
		Task :		Search Customer by UserName in subscribers
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230720@Casey.Huynh: Created [Redmine ID: 189873]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_ET_Association_GetAccountInfoByAccountSubscriber(@ip_SubscriberID:=8000001,@ip_AccountID:=19);
	*/
    DECLARE lv_FirstDeviceID BIGINT UNSIGNED;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
	CREATE TEMPORARY TABLE Temp_Association(	
			AccountID	BIGINT UNSIGNED
        ,	DeviceID	BIGINT 
        ,	CreatedTime	DATETIME(4)
        ,	AssociationID BIGINT UNSIGNED
        
        ,	PRIMARY KEY PK_Temp_Association(DeviceID, AccountID)
        ,	INDEX IX_Temp_Association_AssociationID(AssociationID)
    ); 
    
    #======GET ACCOUNT LIST: ip_AccountID AND ASSOCIATED CUSTOMER=======================================    
    INSERT INTO Temp_Association(AccountID, DeviceID, CreatedTime, AssociationID)
    SELECT	ass.AccountID
        ,	ass.DeviceID
        ,	ass.CreatedTime
        ,	ass.AssociationID
	FROM DCS_Extra.Association AS ass  
    WHERE ass.SubscriberID = ip_SubscriberID AND ass.AccountID = ip_AccountID;
    
    SELECT tmpAss.DeviceID
    INTO lv_FirstDeviceID
    FROM Temp_Association AS tmpAss
    ORDER BY tmpAss.CreatedTime ASC
    LIMIT 1;

    SELECT 	COUNT(DISTINCT tmpAs1.DeviceID) AssociatedDevices
		,	COUNT(DISTINCT ass.AccountID) AS AssociatedAccounts
        ,	MIN(tmpAs1.CreatedTime) AS FirstLogin
        ,	(SELECT dv.FirstDeviceCode FROM DCS_Extra.Device AS dv WHERE dv.DeviceID = lv_FirstDeviceID) AS FirstDevice
    FROM Temp_Association AS tmpAs1
		LEFT JOIN DCS_Extra.Association AS ass ON tmpAs1.DeviceID = ass.DeviceID AND tmpAs1.AccountID <> ass.AccountID AND ass.SubscriberID = ip_SubscriberID;
        
END$$
DELIMITER ;
