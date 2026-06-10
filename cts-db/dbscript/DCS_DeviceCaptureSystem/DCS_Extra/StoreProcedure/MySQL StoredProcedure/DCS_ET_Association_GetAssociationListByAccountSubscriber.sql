/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Association_GetAssociationListByAccountSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Association_GetAssociationListByAccountSubscriber`(
		IN ip_SubscriberID		INT
	,	IN ip_AccountID			BIGINT UNSIGNED
	,	IN ip_NoOfRecord		INT
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
			@ip_NoOfRecord = 0 GET all Ass Account
            @ip_NoOfRecord > 0 GET ip_NoOfRecord ass account
            
		Example:
			CALL DCS_ET_Association_GetAssociationListByAccountSubscriber(@ip_SubscriberID:=8000001,@ip_AccountID:=19,@ip_NoOfRecord:=1); 
            CALL DCS_ET_Association_GetAssociationListByAccountSubscriber(@ip_SubscriberID:=8000001,@ip_AccountID:=19,@ip_NoOfRecord:=0); 
   
	*/    
    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
	CREATE TEMPORARY TABLE Temp_Association(
			AccountID		BIGINT UNSIGNED
		,	DeviceID		BIGINT UNSIGNED
        ,	CreatedDate		DATETIME
        ,	CreatedTime		DATETIME(4)
        
        ,	PRIMARY KEY PK_Temp_Association(AccountID, DeviceID)
        ,	INDEX IX_Temp_Association_DeviceID(DeviceID)
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
		,	LoginName 			VARCHAR(50)
        ,	DeviceInCommon		INT
        ,	OtherDeives			INT
        ,	AssociatedAccount	INT
        ,	IsFirstAccount			BOOLEAN
        ,	MaxCreatedTime		DATETIME(4)
        
        ,	INDEX IX_Temp_AssociatedAccount(IsFirstAccount DESC, MaxCreatedTime DESC)
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AccountAssociation;
	CREATE TEMPORARY TABLE Temp_AccountAssociation(
			RootAccountID BIGINT UNSIGNED
        ,	DeviceID BIGINT UNSIGNED
        ,	CreatedTime DATETIME(4)
        ,	AssAccountID BIGINT UNSIGNED
        , 	PRIMARY KEY PK_Temp_AccountAssociation(RootAccountID,DeviceID, AssAccountID));
    
    #======GET Cust Association LIST: ip_AccountID AND ASSOCIATED CUSTOMER=======================================    
    INSERT INTO Temp_Association(AccountID, DeviceID, CreatedDate, CreatedTime)
    SELECT	ass.AccountID
		,	ass.DeviceID
        ,	ass.CreatedDate
        ,	ass.CreatedTime
	FROM DCS_Extra.Association AS ass 
    WHERE ass.SubscriberID = ip_SubscriberID AND ass.AccountID = ip_AccountID;

    IF ip_NoOfRecord > 0 THEN 
    
		INSERT INTO Temp_AccountID(AccountID, LastCreatedTime)
		SELECT DISTINCT ass.AccountID
			,	MAX(ass.CreatedTime) AS LastCreatedTime
		FROM DCS_Extra.Association AS ass
			INNER JOIN Temp_Association AS tmpAs ON ass.DeviceID = tmpAs.DeviceID AND ass.SubscriberID = ip_SubscriberID
		GROUP BY ass.AccountID
		ORDER BY LastCreatedTime DESC
		LIMIT ip_NoOfRecord;   

	END IF;
    IF ip_NoOfRecord = 0 THEN 

		INSERT INTO Temp_AccountID(AccountID, LastCreatedTime)
		SELECT DISTINCT ass.AccountID
			,	MAX(ass.CreatedTime) AS LastCreatedTime
		FROM DCS_Extra.Association AS ass
			INNER JOIN Temp_Association AS tmpAs ON ass.DeviceID = tmpAs.DeviceID AND ass.SubscriberID = ip_SubscriberID
		GROUP BY ass.AccountID
		ORDER BY LastCreatedTime DESC;  
	END IF;

    #=====GET ASSOCIATION LIST OF ALL Association Cust===============================================================================
    INSERT IGNORE INTO Temp_Association(AccountID, DeviceID,  CreatedTime)
    SELECT	ass.AccountID
		,	ass.DeviceID
        ,	tmpAcc.LastCreatedTime
    FROM DCS_Extra.Association AS ass
		INNER JOIN Temp_AccountID AS tmpAcc ON ass.SubscriberID = ip_SubscriberID AND ass.AccountID = tmpAcc.AccountID AND tmpAcc.AccountID <> ip_AccountID;

	INSERT IGNORE INTO Temp_AccountAssociation(RootAccountID,DeviceId,CreatedTime,AssAccountID)
    SELECT tmpAs.AccountID, tmpAs.DeviceID, tmpAs.CreatedTime, ass.AccountID
	FROM Temp_Association AS tmpAs
        LEFT JOIN DCS_Extra.Association AS ass ON ass.SubscriberID = ip_SubscriberID AND tmpAs.DeviceID = ass.DeviceID AND tmpAs.AccountID <> ass.AccountID;

    INSERT INTO Temp_AssociatedAccount(AccountID, DeviceInCommon, OtherDeives, AssociatedAccount, IsFirstAccount, MaxCreatedTime)
    SELECT	tmpAs.RootAccountID AS AccountID
		,	COUNT(DISTINCT CASE WHEN tmpAs.AssAccountID > 0 THEN tmpAs.DeviceID ELSE NULL END) AS DeviceInCommon
        ,	COUNT(DISTINCT tmpAs.DeviceID) - COUNT(DISTINCT CASE WHEN tmpAs.AssAccountID > 0 THEN tmpAs.DeviceID ELSE NULL END) AS OtherDevices
		,	COUNT(DISTINCT CASE WHEN tmpAs.AssAccountID > 0 THEN tmpAs.AssAccountID ELSE NULL END) AS AsscociatedAccount
        ,	MAX(CASE WHEN tmpAs.RootAccountID = ip_AccountID THEN 1 ELSE 0 END) AS IsFirstAccount
        ,	MAX(tmpAs.CreatedTime) AS MaxCreatedTime
    FROM Temp_AccountAssociation AS tmpAs		
    GROUP BY tmpAs.RootAccountID;

	SELECT	tmpAa.AccountID
		,	acc.LoginName
		,	tmpAa.DeviceInCommon
		,	tmpAa.OtherDeives
		,	tmpAa.AssociatedAccount
    FROM Temp_AssociatedAccount AS tmpAa	
		INNER JOIN DCS_Extra.Account AS acc ON acc.AccountID = tmpAa.AccountID
	ORDER BY IsFirstAccount DESC, MaxCreatedTime DESC;
	
END$$
DELIMITER ;
