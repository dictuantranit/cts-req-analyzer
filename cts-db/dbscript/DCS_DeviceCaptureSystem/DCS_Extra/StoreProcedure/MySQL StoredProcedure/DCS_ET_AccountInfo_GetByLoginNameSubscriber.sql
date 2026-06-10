/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_AccountInfo_GetByLoginNameSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_AccountInfo_GetByLoginNameSubscriber`(
		IN ip_SubscriberID	INT
	,	IN ip_LoginName		VARCHAR(50)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230720@Casey.Huynh
		Task :		Search Customer by LoginName in subscribers
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230720@Casey.Huynh: Created [Redmine ID: 189873]
			
		Param's Explanation (filtered by):

		Example:
			CALL DCS_ET_AccountInfo_GetByLoginNameSubscriber(@ip_SubscriberID:=8000001,@ip_LoginName:='Exciting8');
			CALL DCS_ET_AccountInfo_GetByLoginNameSubscriber(@ip_SubscriberID:=8000001,@ip_LoginName:='DenVau');
	*/   

	#========SEARCH BY LoginName=====================
    SELECT	acc.AccountID
		,	acc.LoginName
        ,	acc.SubscriberID
    FROM DCS_Extra.Account AS acc
	WHERE acc.SubscriberID = ip_SubscriberID AND acc.LoginName = ip_LoginName;        
    
END$$
DELIMITER ;
