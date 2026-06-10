/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Association_GetAssociationMatrixByAccountSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Association_GetAssociationMatrixByAccountSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_AccountID		BIGINT UNSIGNED
	,	IN ip_NoOfCustomer	INT
    ,	IN ip_NoOfDevice	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230720@Casey.Huynh
		Task :		Get Association Account List
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230720@Casey.Huynh: Created [Redmine ID: 189873]
			
		Param's Explanation (filtered by):
			
		Example:
				CALL DCS_ET_Association_GetAssociationMatrixByAccountSubscriber(@ip_SubscriberID:=8000001,@ip_AccountID:=19,@ip_NoOfCustomer:=16, @ip_NoOfDevice:=100);
   
	*/
   
    #======GET Cust Association LIST: ip_AccountID AND ASSOCIATED CUSTOMER=======================================  
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
		,	IsFirstCust			BOOLEAN
		,	LastAssCreatedTime	DATETIME(4)
	);
    
    #==============================================
    INSERT IGNORE INTO Temp_Matrix(DeviceID, FirstDeviceCode, CreatedTime, AccountID, LoginName, AssCreatedTime )
    SELECT  ass.DeviceID
		,	dv.FirstDeviceCode
		,	dv.CreatedTime
        ,	ass.AccountID
        ,	acc.LoginName
        ,	ass.CreatedTime
	FROM DCS_Extra.Association AS ass 
        INNER JOIN DCS_Extra.Device AS dv ON ass.DeviceID = dv.DeviceID
        INNER JOIN DCS_Extra.Account AS acc ON acc.AccountID = ass.AccountID
    WHERE ass.SubscriberID = ip_SubscriberID AND ass.AccountID = ip_AccountID
    ORDER BY ass.CreatedDate DESC, ass.CreatedTime DESC
    LIMIT ip_NoOfDevice;    

    INSERT INTO Temp_RootDevice(DeviceID,FirstDeviceCode,CreatedTime)
    SELECT	tmpMt.DeviceID
		,	tmpMt.FirstDeviceCode
        ,	tmpMt.CreatedTime
    FROM Temp_Matrix AS tmpMt;

	INSERT IGNORE INTO Temp_Matrix(DeviceID, FirstDeviceCode, CreatedTime, AccountID, LoginName, AssCreatedTime)
    SELECT  tmpRd.DeviceID
		,	tmpRd.FirstDeviceCode
		,	tmpRd.CreatedTime
        ,	ass.AccountID
        ,	acc.LoginName
        ,	ass.CreatedTime
	FROM Temp_RootDevice AS tmpRd
		INNER JOIN DCS_Extra.Association AS ass ON tmpRd.DeviceID = ass.DeviceID AND ass.SubscriberID = ip_SubscriberID
        INNER JOIN DCS_Extra.Account AS acc ON acc.AccountID = ass.AccountID;   
 
	INSERT INTO Temp_AccountAssociation(AccountID, IsFirstCust, LastAssCreatedTime)
    SELECT	tmpMt.AccountID
		,	(CASE WHEN tmpMt.AccountID = ip_AccountID THEN 1 ELSE 0 END) AS IsFirstCust
		,	MAX(AssCreatedTime) AS LastAssCreatedTime
	FROM Temp_Matrix AS tmpMt
    GROUP BY tmpMt.AccountID
    ORDER BY IsFirstCust DESC, LastAssCreatedTime DESC
    LIMIT ip_NoOfCustomer;    

    SELECT	tmpMt.AccountID
		,	tmpMt.LoginName
        ,	tmpMt.DeviceID
        ,	tmpMt.FirstDeviceCode
        ,	tmpMt.CreatedTime
    FROM Temp_Matrix AS tmpMt
		INNER JOIN Temp_AccountAssociation AS tmpAc ON tmpAc.AccountID = tmpMt.AccountID
    ORDER BY tmpAc.IsFirstCust DESC, tmpAc.LastAssCreatedTime DESC;
    
END$$
DELIMITER ;