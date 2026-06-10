/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_GetAssociationListByCustSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_GetAssociationListByCustSubscriber`(
		IN ip_SubscriberID		INT
	,	IN ip_CTSCustID			BIGINT UNSIGNED
	,	IN ip_NoOfRecord		INT
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
			-	20230706@Casey.Huynh: Show Device Association Info [Redmine ID: 190950]
            -	20250610@Aida.Tran: Exclude Test Account [Redmine ID: 227652]
            
		Param's Explanation (filtered by):
			@ip_NoOfRecord = 0 GET all Ass Account
            @ip_NoOfRecord > 0 GET ip_NoOfRecord ass account
            
		Example:
			CALL CTS_DC_Association_GetAssociationListByCustSubscriber(@ip_SubscriberID:=6,@ip_CTSCustID:=2605665,@ip_NoOfRecord:=30); 
            CALL CTS_DC_Association_GetAssociationListByCustSubscriber(@ip_SubscriberID:=6,@ip_CTSCustID:=2605665,@ip_NoOfRecord:=0); 
   
	*/    
    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
	CREATE TEMPORARY TABLE Temp_Association(
			AccountID		BIGINT UNSIGNED
		,	DeviceID		BIGINT UNSIGNED
        ,	CTSCustID		BIGINT UNSIGNED
        ,	CreatedDate		DATETIME
        ,	CreatedTime		DATETIME(4)
        
        ,	PRIMARY KEY PK_Temp_Association(AccountID, DeviceID)
        ,	INDEX IX_Temp_Association_DeviceID(DeviceID)
        ,	INDEX IX_Temp_Association_CTSCustID(CTSCustID)
        ,	INDEX IX_Temp_Association_CreatedTime(CreatedTime)
    ); 
        
	DROP TEMPORARY TABLE IF EXISTS Temp_AccountID;
	CREATE TEMPORARY TABLE Temp_AccountID(
			AccountID		BIGINT UNSIGNED PRIMARY KEY
		,	LastCreatedTime		DATETIME(4)
        
        ,	INDEX IX_Temp_AccountID_CreatedTime(LastCreatedTime)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedAccount;
	CREATE TEMPORARY TABLE Temp_AssociatedAccount(
			AccountID			BIGINT UNSIGNED PRIMARY KEY
		,	CTSCustID			BIGINT UNSIGNED
		,	UserName 			VARCHAR(50)
        ,	RegisterName		VARCHAR(50)
        ,	LastCreatedTime		DATETIME(4)
    );

	DROP TEMPORARY TABLE IF EXISTS Temp_AssociatedCustomer;
    CREATE TEMPORARY TABLE Temp_AssociatedCustomer(
			CTSCustID			BIGINT UNSIGNED PRIMARY KEY
		,	UserName 			VARCHAR(50)
        ,	RegisterName		VARCHAR(50)
        ,	DeviceInCommon		INT
        ,	OtherDeives			INT
        ,	AssociatedAccount	INT
        ,	IsFirstCust			BOOLEAN
        ,	MaxCreatedTime		DATETIME(4)
        
        ,	INDEX IX_Temp_AssociatedCustomer(IsFirstCust DESC, MaxCreatedTime DESC)
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AssCust;
	CREATE TEMPORARY TABLE Temp_AssCust(
			RootCTSCustID BIGINT UNSIGNED
        ,	DeviceID BIGINT UNSIGNED
        ,	CreatedTime DATETIME(4)
        ,	AssCTSCustID BIGINT UNSIGNED
        , 	PRIMARY KEY PK_Temp_AssCust(RootCTSCustID,DeviceId, AssCTSCustID));
    
    #======GET Cust Association LIST: ip_CTSCustID AND ASSOCIATED CUSTOMER=======================================    
    INSERT INTO Temp_Association(AccountID, DeviceID, CTSCustID, CreatedDate, CreatedTime)
    SELECT	ass.AccountID
		,	ass.DeviceID
		,	cda.CTSCustID
        ,	ass.CreatedDate
        ,	ass.CreatedTime
    FROM CTS_DataCenter.CustDCSAccount AS cda
		INNER JOIN DCS_DataCenter.Association AS ass ON cda.AccountID = ass.AccountID
    WHERE cda.SubscriberID = ip_SubscriberID AND cda.CTSCustID = ip_CTSCustID;

    IF ip_NoOfRecord > 0 THEN 
		
		INSERT INTO Temp_AccountID(AccountID, LastCreatedTime)
		SELECT DISTINCT ass.AccountID
			,	MAX(ass.CreatedTime) AS LastCreatedTime
		FROM DCS_DataCenter.Association AS ass
			INNER JOIN Temp_Association AS tmpAs ON ass.DeviceID = tmpAs.DeviceID AND ass.SubscriberID = ip_SubscriberID
            INNER JOIN CTS_DataCenter.CustDCSAccount AS cda ON cda.AccountID = ass.AccountID
		GROUP BY AccountID
		ORDER BY LastCreatedTime DESC
		LIMIT ip_NoOfRecord;   
	END IF;
    IF ip_NoOfRecord = 0 THEN 

		INSERT INTO Temp_AccountID(AccountID, LastCreatedTime)
		SELECT DISTINCT ass.AccountID
			,	MAX(ass.CreatedTime) AS LastCreatedTime
		FROM DCS_DataCenter.Association AS ass
			INNER JOIN Temp_Association AS tmpAs ON ass.DeviceID = tmpAs.DeviceID AND ass.SubscriberID = ip_SubscriberID
            INNER JOIN CTS_DataCenter.CustDCSAccount AS cda ON cda.AccountID = ass.AccountID
		GROUP BY AccountID
		ORDER BY LastCreatedTime DESC;
  
	END IF;

	INSERT INTO Temp_AssociatedAccount(AccountID, CTSCustID, UserName, RegisterName, LastCreatedTime)
    SELECT	tmp.AccountID
		,	cus.CTSCustID
        ,	cus.UserName
        ,	cus.RegisterName
        ,	tmp.LastCreatedTime
	FROM Temp_AccountID AS tmp
		INNER JOIN CTS_DataCenter.CustDCSAccount AS cda ON tmp.AccountID = cda.AccountID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cda.CTSCustID = cus.CTSCustID 
													AND cus.IsInternal = 0 
                                                    AND cus.CurrencyID NOT IN (20, 27, 28, 72)
	ORDER BY tmp.LastCreatedTime DESC;

	DELETE tmpAs
    FROM Temp_Association AS tmpAs
		LEFT JOIN Temp_AssociatedAccount AS tmpCs ON tmpAs.AccountID = tmpCs.AccountID
	WHERE tmpCs.CTSCustID IS NULL;

    #=====GET ASSOCIATION LIST OF ALL Association Cust===============================================================================
    INSERT IGNORE INTO Temp_Association(AccountID, DeviceID, CTSCustID,  CreatedTime)
    SELECT	ass.AccountID
		,	ass.DeviceID
        ,	tmpAcc.CTSCustID
        ,	tmpAcc.LastCreatedTime
    FROM DCS_DataCenter.Association AS ass
		INNER JOIN Temp_AssociatedAccount AS tmpAcc ON ass.SubscriberID = ip_SubscriberID AND ass.AccountID = tmpAcc.AccountID AND tmpAcc.CTSCustID <> ip_CTSCustID;

	INSERT IGNORE INTO Temp_AssCust(RootCTSCustID,DeviceId,CreatedTime,AssCTSCustID)
    SELECT tmpAs.CTSCustID, tmpAs.DeviceID, tmpAs.CreatedTime, cus.CTSCustID
	FROM Temp_Association AS tmpAs
        LEFT JOIN DCS_DataCenter.Association AS ass ON ass.SubscriberID = ip_SubscriberID AND tmpAs.DeviceID = ass.DeviceID AND tmpAs.AccountID <> ass.AccountID
        LEFT JOIN CTS_DataCenter.CustDCSAccount AS cda ON ass.AccountID = cda.AccountID
        LEFT JOIN CTS_DataCenter.CTSCustomer AS cus ON cda.CTSCustID = cus.CTSCustID 
													AND cus.IsInternal = 0  
                                                    AND cus.CurrencyID NOT IN (20, 27, 28, 72) ;

    INSERT INTO Temp_AssociatedCustomer(CTSCustID, DeviceInCommon, OtherDeives, AssociatedAccount, IsFirstCust, MaxCreatedTime)
    SELECT	tmpAs.RootCTSCustID
		,	COUNT(DISTINCT CASE WHEN tmpAs.AssCTSCustID > 0 THEN tmpAs.DeviceID ELSE NULL END) AS DeviceInCommon
        ,	COUNT(DISTINCT tmpAs.DeviceID) - COUNT(DISTINCT CASE WHEN tmpAs.AssCTSCustID > 0 THEN tmpAs.DeviceID ELSE NULL END) AS OtherDevices
		,	COUNT(DISTINCT CASE WHEN tmpAs.AssCTSCustID > 0 THEN tmpAs.AssCTSCustID ELSE NULL END) AS AsscociatedAccount
        ,	MAX(CASE WHEN tmpAs.RootCTSCustID = ip_CTSCustID THEN 1 ELSE 0 END) AS IsFirstCust
        ,	MAX(tmpAs.CreatedTime) AS MaxCreatedTime
    FROM Temp_AssCust AS tmpAs
    GROUP BY RootCTSCustID;

	SELECT	tmpAa.CTSCustID
		,	tmpCs.UserName
        ,	tmpCs.RegisterName
		,	tmpAa.DeviceInCommon
		,	tmpAa.OtherDeives
		,	tmpAa.AssociatedAccount
    FROM Temp_AssociatedCustomer AS tmpAa		
		INNER JOIN Temp_AssociatedAccount AS tmpCs ON tmpAa.CTSCustID = tmpCs.CTSCustID
	ORDER BY IsFirstCust DESC, MaxCreatedTime DESC;
	
END$$
DELIMITER ;
