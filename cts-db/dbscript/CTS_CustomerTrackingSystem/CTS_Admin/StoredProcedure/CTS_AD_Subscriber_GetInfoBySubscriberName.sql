/*<info serverAlias="CTSMain-CTS_Admin" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_AD_Subscriber_GetInfoBySubscriberName`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_AD_Subscriber_GetInfoBySubscriberName`(
	IN ip_SubscriberName VARCHAR(50)
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210409@Casey.Huynh
		Task:		Return Subscriber Info [Redmine ID: 153202]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20210115@Casey.Huynh: Created [Redmine ID: 153202]

            
		Param's Explanation (filtered by):

            
		Example: CALL CTS_Admin.CTS_AD_Subscriber_GetInfoBySubscriberName ('Athena00')

	*/  
		SELECT 	SubscriberID
			,	SubscriberName
			,	SubscriberPrefix
			,	SubscriberType
			,	SubscriberStatus
			,	CreatedDate
			,	CreatedBy
			,	IsTest
			,	DCSStatus
			,	DCSIntegrationDate
			,	FPSSubscriberID
			,	TerminatedDate
        FROM	CTS_Admin.Subscriber AS s
        WHERE	SubscriberName = ip_SubscriberName;
        
END$$
DELIMITER ;