/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Association_GetAssociationMatrixByDeviceSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Association_GetAssociationMatrixByDeviceSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_DeviceID		BIGINT UNSIGNED
	,	IN ip_NoOfCustomer	INT
    ,	IN ip_NoOfDevice	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230720@Casey.Huynh
		Task :		Get Matrix By Device
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230809@Casey.Huynh: Created [Redmine ID: 192402]
			
		Param's Explanation (filtered by):
			
		Example:
				CALL DCS_ET_Association_GetAssociationMatrixByDeviceSubscriber(@ip_SubscriberID:=8000001,@ip_DeviceID:=1,@ip_NoOfCustomer:=16, @ip_NoOfDevice:=100);
                CALL DCS_ET_Association_GetAssociationMatrixByDeviceSubscriber(8000001, 141, 15, 100);
   
	*/
   
    #======GET Cust Association LIST: ip_DeviceID AND ASSOCIATED CUSTOMER=======================================  
    DROP TEMPORARY TABLE IF EXISTS Temp_Matrix;
    CREATE TEMPORARY TABLE Temp_Matrix(
			DeviceID		BIGINT UNSIGNED		
        ,	CreatedTime		DATETIME(4)
        ,	FirstDeviceCode	VARCHAR(32)
        ,	AccountID 		BIGINT UNSIGNED
        ,	LoginName		VARCHAR(50)
        ,	AssCreatedTime	DATETIME(4)
        
        ,	PRIMARY KEY (DeviceID, AccountID)        
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_RootDevice;
    CREATE TEMPORARY TABLE Temp_RootDevice(
			DeviceID	BIGINT UNSIGNED	PRIMARY KEY
        ,   FirstDeviceCode	VARCHAR(32)
        ,	CreatedTime DATETIME(4)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AccountAssociation;
    CREATE TEMPORARY TABLE Temp_AccountAssociation(
			AccountID 			BIGINT UNSIGNED PRIMARY KEY
		,	LastAssCreatedTime	DATETIME(4)
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Account;
    CREATE TEMPORARY TABLE Temp_Account(
			AccountID 	BIGINT UNSIGNED PRIMARY KEY
		,	LoginName	VARCHAR(50)
        ,	CreatedTime	DATETIME(4)
	);
    #==============================================
	INSERT INTO Temp_Account(AccountID, LoginName, CreatedTime)
    SELECT DISTINCT	ass.AccountID
		,	acc.LoginName
        ,	ass.CreatedTime
    FROM DCS_Extra.Association AS ass 
		INNER JOIN DCS_Extra.Account AS acc ON acc.AccountID = ass.AccountID
    WHERE ass.SubscriberID = ip_SubscriberID AND ass.DeviceID = ip_DeviceID
    ORDER BY ass.CreatedTime DESC
    LIMIT ip_NoOfCustomer;  
    
    INSERT IGNORE INTO Temp_RootDevice(DeviceID,FirstDeviceCode,CreatedTime)
    SELECT DISTINCT	dv.DeviceID
		,	dv.FirstDeviceCode
        ,	dv.CreatedTime
	FROM DCS_Extra.Association AS ass
		INNER JOIN Temp_Account AS tmpAc ON tmpAc.AccountID = ass.AccountID
        INNER JOIN DCS_Extra.Device AS dv ON dv.DeviceID = ass.DeviceID        
    ORDER BY  dv.CreatedTime DESC
    LIMIT ip_NoOfDevice;    
    
    INSERT IGNORE INTO Temp_Matrix(DeviceID, FirstDeviceCode, CreatedTime, AccountID, LoginName, AssCreatedTime )
    SELECT  ass.DeviceID
		,	dv.FirstDeviceCode
		,	dv.CreatedTime
        ,	ass.AccountID
        ,	tmpAc.LoginName
        ,	ass.CreatedTime
	FROM DCS_Extra.Association AS ass
		INNER JOIN Temp_Account AS tmpAc ON tmpAc.AccountID = ass.AccountID
        INNER JOIN Temp_RootDevice AS dv ON dv.DeviceID = ass.DeviceID        
    ;

	INSERT INTO Temp_AccountAssociation(AccountID, LastAssCreatedTime)
    SELECT	tmpMt.AccountID
		,	MAX(AssCreatedTime) AS LastAssCreatedTime
	FROM Temp_Matrix AS tmpMt
    GROUP BY tmpMt.AccountID
    ORDER BY LastAssCreatedTime DESC; 

    SELECT	tmpMt.AccountID
		,	tmpMt.LoginName
        ,	tmpMt.DeviceID
        ,	tmpMt.FirstDeviceCode
        ,	tmpMt.CreatedTime
    FROM Temp_Matrix AS tmpMt
		INNER JOIN Temp_AccountAssociation AS tmpAc ON tmpAc.AccountID = tmpMt.AccountID
    ORDER BY tmpAc.LastAssCreatedTime DESC;
    
END$$
DELIMITER ;
