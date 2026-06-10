/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Subscriber_GetInfoBySubscriberName`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Subscriber_GetInfoBySubscriberName`(
	IN ip_SubscriberName VARCHAR(50)
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230721@Casey.Huynh
		Task:		Return Subscriber Info [Redmine ID: 189873]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20230721@Casey.Huynh: Created [Redmine ID: 189873]

            
		Param's Explanation (filtered by):

            
		Example: CALL DCS_Extra.DCS_ET_Subscriber_GetInfoBySubscriberName ('CTMax')

	*/  
	SELECT 	sub.SubscriberID
		,	sub.SubscriberName
		,	sub.SubscriberPrefix
		,	sub.SubscriberType
		,	(CASE WHEN sub.SubscriberStatus = 1 THEN 1 ELSE 0 END) AS SubscriberStatus
		,	sub.CreatedDate
		,	sub.CreatedBy
		,	sub.IsTest
		,	sub.TerminatedDate
	FROM	DCS_Extra.Subscriber AS sub
	WHERE	sub.SubscriberName = ip_SubscriberName;
        
END$$
DELIMITER ;