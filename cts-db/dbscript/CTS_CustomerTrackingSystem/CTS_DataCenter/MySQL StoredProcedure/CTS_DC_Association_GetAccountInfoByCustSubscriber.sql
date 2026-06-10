/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_GetAccountInfoByCustSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_GetAccountInfoByCustSubscriber`(
		IN ip_SubscriberID		INT
	,	IN ip_CTSCustID			BIGINT UNSIGNED       
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230601@Casey.Huynh
		Task :		Search Customer by UserName in subscribers
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230601@Casey.Huynh: Created [Redmine ID: 185787]
            -	20230706@Casey.Huynh: Show Device Association Info [Redmine ID: 190950]
            -	20250610@Aida.Tran: Exclude Test Account [Redmine ID: 227652]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL CTS_DC_Association_GetAccountInfoByCustSubscriber(@ip_SubscriberID:=6,@ip_CTSCustID:=14417);
	*/
    DECLARE lv_FirstDeviceID BIGINT UNSIGNED;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
	CREATE TEMPORARY TABLE Temp_Association(		
			CTSCustID	BIGINT UNSIGNED
		,	AccountID	BIGINT UNSIGNED
        ,	DeviceID	BIGINT 
        ,	CreatedTime	DATETIME(4)
        ,	AssociationID BIGINT UNSIGNED
        
        ,	PRIMARY KEY PK_Temp_Association(DeviceID, AccountID)
        ,	INDEX IX_Temp_Association_CTSCustID(CTSCustID)
        ,	INDEX IX_Temp_Association_AssociationID(AssociationID)
    ); 
    
    #======GET ACCOUNT LIST: ip_CTSCustID AND ASSOCIATED CUSTOMER=======================================    
    INSERT INTO Temp_Association(CTSCustID, AccountID, DeviceID, CreatedTime, AssociationID)
    SELECT	cda.CTSCustID
		,	cda.AccountID
        ,	ass.DeviceID
        ,	ass.CreatedTime
        ,	ass.AssociationID
	FROM CTS_DataCenter.CustDCSAccount AS cda 
        INNER JOIN DCS_DataCenter.Association AS ass ON cda.AccountID = ass.AccountID 
    WHERE cda.SubscriberID = ip_SubscriberID AND cda.CTSCustID = ip_CTSCustID;
    
    SELECT tmpAss.DeviceID
    INTO lv_FirstDeviceID
    FROM Temp_Association AS tmpAss
    ORDER BY tmpAss.CreatedTime ASC
    LIMIT 1;

    SELECT 	COUNT(DISTINCT tmpAs1.DeviceID) AssociatedDevices
		,	COUNT(DISTINCT cus.CTSCustID) AS AssociatedAccounts
        ,	MIN(tmpAs1.CreatedTime) AS FirstLogin
        ,	(SELECT dv.FirstDeviceCode FROM DCS_DataCenter.Device AS dv WHERE dv.DeviceID = lv_FirstDeviceID) AS FirstDevice
    FROM Temp_Association AS tmpAs1
		LEFT JOIN DCS_DataCenter.Association AS ass ON tmpAs1.DeviceID = ass.DeviceID 
													AND tmpAs1.AccountID <> ass.AccountID 
													AND ass.SubscriberID = ip_SubscriberID   
        LEFT JOIN CTS_DataCenter.CustDCSAccount AS cda ON cda.AccountID = ass.AccountID
		LEFT JOIN CTS_DataCenter.CTSCustomer AS cus ON cda.CTSCustID = cus.CTSCustID 
													AND cus.IsInternal = 0 
													AND cus.CurrencyID NOT IN (20, 27, 28, 72);
        
END$$
DELIMITER ;
