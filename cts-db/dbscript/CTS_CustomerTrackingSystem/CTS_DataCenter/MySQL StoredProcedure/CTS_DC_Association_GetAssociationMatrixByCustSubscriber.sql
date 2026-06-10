/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_GetAssociationMatrixByCustSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_GetAssociationMatrixByCustSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_CTSCustID		BIGINT UNSIGNED
	,	IN ip_NoOfCustomer	INT
    ,	IN ip_NoOfDevice	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230601@Casey.Huynh
		Task :		Get Association Account List
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230601@Casey.Huynh: Created [Redmine ID: 185787]
            -	20250610@Aida.Tran: Exclude Test Account [Redmine ID: 227652]
			
		Param's Explanation (filtered by):
			
		Example:
				CALL CTS_DC_Association_GetAssociationMatrixByCustSubscriber(@ip_SubscriberID:=120,@ip_CTSCustID:=2614369,@ip_NoOfCustomer:=16, @ip_NoOfDevice:=100);
   
	*/
   
    #======GET Cust Association LIST: ip_CTSCustID AND ASSOCIATED CUSTOMER=======================================  
    DROP TEMPORARY TABLE IF EXISTS Temp_Matrix;
    CREATE TEMPORARY TABLE Temp_Matrix(
			DeviceID		BIGINT UNSIGNED		
        ,	CreatedTime		DATETIME(4)
        ,	FirstDeviceCode	VARCHAR(32)
        ,	CTSCustID 		BIGINT UNSIGNED
        ,	Username		VARCHAR(50)
        ,	RegisterName	VARCHAR(50)        
        ,	AssCreatedTime	DATETIME(4)
        
        ,	PRIMARY KEY (DeviceID, CTSCustID)
        
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_RootDevice;
    CREATE TEMPORARY TABLE Temp_RootDevice(
			DeviceID	BIGINT UNSIGNED	PRIMARY KEY
        ,   FirstDeviceCode	VARCHAR(32)
        ,	CreatedTime DATETIME(4)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AssCustomer;
    CREATE TEMPORARY TABLE Temp_AssCustomer(
			CTSCustID BIGINT UNSIGNED PRIMARY KEY
		,	IsFirstCust		BOOLEAN
		,	LastAssCreatedTime DATETIME(4)
	);
    
    #==============================================
    INSERT IGNORE INTO Temp_Matrix(DeviceID, FirstDeviceCode, CreatedTime, CTSCustID, UserName, RegisterName, AssCreatedTime )
    SELECT  ass.DeviceID
		,	dv.FirstDeviceCode
		,	dv.CreatedTime
        ,	cus.CTSCustID
        ,	cus.UserName
        ,	cus.RegisterName
        ,	ass.CreatedTime
	FROM CTS_DataCenter.CTSCustomer AS cus
		INNER JOIN CTS_DataCenter.CustDCSAccount AS cda ON cda.CTSCustID = cus.CTSCustID
		INNER JOIN DCS_DataCenter.Association AS ass ON ass.AccountID = cda.AccountID
        INNER JOIN DCS_DataCenter.Device AS dv ON ass.DeviceID = dv.DeviceID
    WHERE cus.SubscriberID = ip_SubscriberID AND cda.CTSCustID = ip_CTSCustID
    ORDER BY ass.CreatedDate DESC, ass.CreatedTime DESC
    LIMIT ip_NoOfDevice;    

    INSERT INTO Temp_RootDevice(DeviceID,FirstDeviceCode,CreatedTime)
    SELECT	tmpMt.DeviceID
		,	tmpMt.FirstDeviceCode
        ,	tmpMt.CreatedTime
    FROM Temp_Matrix AS tmpMt;

	INSERT IGNORE INTO Temp_Matrix(DeviceID, FirstDeviceCode, CreatedTime, CTSCustID, UserName, RegisterName, AssCreatedTime)
    SELECT  tmpRd.DeviceID
		,	tmpRd.FirstDeviceCode
		,	tmpRd.CreatedTime
        ,	cus.CTSCustID
        ,	cus.UserName
        ,	cus.RegisterName
        ,	ass.CreatedTime
	FROM Temp_RootDevice AS tmpRd
		INNER JOIN DCS_DataCenter.Association AS ass ON tmpRd.DeviceID = ass.DeviceID AND ass.SubscriberID = ip_SubscriberID
		INNER JOIN CTS_DataCenter.CustDCSAccount AS cda ON cda.AccountID = ass.AccountID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = cda.CTSCustID 
														AND IsInternal = 0  
														AND cus.CurrencyID NOT IN (20, 27, 28, 72);    
 
	INSERT INTO Temp_AssCustomer(CTSCustID, IsFirstCust, LastAssCreatedTime)
    SELECT	tmpMt.CTSCustID
		,	(CASE WHEN tmpMt.CTSCustID = ip_CTSCustID THEN 1 ELSE 0 END) AS IsFirstCust
		,	MAX(AssCreatedTime) AS LastAssCreatedTime
	FROM Temp_Matrix AS tmpMt
    GROUP BY CTSCustID
    ORDER BY IsFirstCust DESC, LastAssCreatedTime DESC
    LIMIT ip_NoOfCustomer;    

    SELECT	tmpMt.CTSCustID
		,	tmpMt.UserName
        ,	tmpMt.RegisterName
        ,	tmpMt.DeviceID
        ,	tmpMt.FirstDeviceCode
        ,	tmpMt.CreatedTime
    FROM Temp_Matrix AS tmpMt
		INNER JOIN Temp_AssCustomer AS tmpAc ON tmpAc.CTSCustID = tmpMt.CTSCustID
    ORDER BY tmpAc.IsFirstCust DESC, tmpAc.LastAssCreatedTime DESC;
    
END$$
DELIMITER ;