/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_AccountInfo_GetPartialByLoginNameSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_AccountInfo_GetPartialByLoginNameSubscriber`(
		IN ip_SubscriberID		INT
	,	IN ip_LoginName			VARCHAR(50)
	,	IN ip_Skip				INT
    ,	IN ip_Take				INT
    ,	OUT	op_TotalItem		INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230720@Casey.Huynh
		Task :		Search parital Account By LoginName in subscribers
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230720@Casey.Huynh: Created [Redmine ID: 189873]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_ET_AccountInfo_GetPartialByLoginNameSubscriber(@ip_SubscriberID:=8000001,@ip_LoginName:='ahmed', @ip_Skip:=0, @ip_Take:=10, @op_TotalItem1); SELECT @op_TotalItem1;
            CALL DCS_ET_AccountInfo_GetPartialByLoginNameSubscriber(@ip_SubscriberID:=8000001,@ip_LoginName:='ahmedj', @ip_Skip:=0, @ip_Take:=10, @op_TotalItem1); SELECT @op_TotalItem1;
	*/   
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Account;
    CREATE TEMPORARY TABLE Temp_Account(
			LoginName		VARCHAR(50)  PRIMARY KEY
        ,	AccountID		BIGINT UNSIGNED
        ,	SubscriberID	INT
        ,	LastLoginTime	DATETIME(4)
        
        ,	INDEX IX_Temp_Account_LastLoginTime(LastLoginTime)
	);
    
    #========SEARCH BY USERNAME=====================
    INSERT INTO Temp_Account (LoginName, AccountID , SubscriberID, LastLoginTime)
    SELECT	acc.LoginName
		,	acc.AccountID
        ,	acc.SubscriberID
        ,	acc.LastLoginTime
    FROM DCS_Extra.Account AS acc
    WHERE acc.SubscriberID = ip_SubscriberID AND acc.LoginName LIKE CONCAT(ip_LoginName,'%')
		AND EXISTS (SELECT 1 FROM DCS_Extra.Association AS ass WHERE ass.AccountID = acc.AccountID LIMIT 1);

    SET op_TotalItem = (SELECT COUNT(1) FROM Temp_Account);
    
    SELECT	tmpAcc.LoginName
		,	tmpAcc.AccountID
        ,	tmpAcc.SubscriberID
        ,	tmpAcc.LastLoginTime
    FROM Temp_Account AS tmpAcc
    ORDER BY tmpAcc.LastLoginTime DESC
	LIMIT ip_Skip, ip_Take;
    
END$$
DELIMITER ;
