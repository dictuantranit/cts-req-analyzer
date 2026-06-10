/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_Subscriber_GetByGroup`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_Subscriber_GetByGroup`()
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20201215@Lex.Khuat
		Task :		Listing subscriber by group [Redmine ID: #146844]
		DB:			CTS_DataCenter
		Revisions:
			- 20201215@Lex.Khuat: Created [Redmine ID: #146844]
			- 20200423@Irena.Vo: Ignore IsTest for subcriber [Redmine ID: #152963] 
		Param's Explanation (filtered by):  
		Example:  
			- CALL CTS_DC_Subscriber_GetByGroup (); 
	*/
	SELECT	s.SubscriberID
		,	s.SubscriberName
        ,	MAX(sg.SubscriberGroupID) AS SubscriberGroupID
        ,	MAX(sg.SubscriberGroupName) AS SubscriberGroupName
    FROM CTS_DataCenter.MappingSubscriberSite AS s
        INNER JOIN CTS_DataCenter.SubscriberGroup AS sg ON s.SubscriberGroupID = sg.SubscriberGroupID
	WHERE sg.IsActive = 1
	GROUP BY s.SubscriberID, s.SubscriberName
	ORDER BY SubscriberGroupName ASC, SubscriberName ASC;
END$$
DELIMITER ;