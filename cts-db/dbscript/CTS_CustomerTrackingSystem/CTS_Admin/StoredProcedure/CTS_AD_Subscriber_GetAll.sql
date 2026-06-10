/*<info serverAlias="CTSMain-CTS_Admin" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_AD_Subscriber_GetAll`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_AD_Subscriber_GetAll`(IN ip_userId INT)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20190715@Harvey
		Task:		Get subscriber by assigned status [Redmine ID: 116528]
		DB:			CTS_Admin
		Original:

		Revisions: 
			- 20190715@Harvey:   Created
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			
		Param's Explanation (filtered by):
	*/

    SELECT	sub.SubscriberID
			,	sub.SubscriberName
			,	(CASE WHEN us.UserID IS NOT NULL THEN 1 ELSE 0 END) AS 'isAssigned'
			,	EXISTS(	SELECT	us1.UserID 
						FROM 	CTS_Admin.UserSubscriber AS us1 
						WHERE	us1.UserID = ip_userId AND us1.SubscriberID = -1) 'IsMaster'
	FROM 		CTS_Admin.Subscriber AS sub 
	LEFT JOIN	CTS_Admin.UserSubscriber AS us 
				ON sub.SubscriberID = us.SubscriberID AND us.UserID = ip_userId
	WHERE 	(us.UserID IS NULL OR us.UserID = ip_userId)
			AND sub.IsTest = 0 
			AND sub.SubscriberStatus IN (1,-1);

END$$

DELIMITER ;