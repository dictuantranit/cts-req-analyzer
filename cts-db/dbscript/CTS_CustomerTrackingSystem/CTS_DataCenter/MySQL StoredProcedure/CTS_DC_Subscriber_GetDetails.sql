/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Subscriber_GetDetails`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Subscriber_GetDetails`(
		IN ip_SubscriberID	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200924@Lex.Khuat
		Task :		Get Subcriber site details
		DB:			CTS_DataCenter
		Original: 
		Revisions:
            - 20200924@Lex.Khuat[138102]: Created
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
            
		Param's Explanation:
	*/

    SELECT	RoleMapping
		,	SiteID
        ,	SiteName
	FROM CTS_DataCenter.MappingSubscriberSite
    WHERE SubscriberID = IFNULL(ip_SubscriberID, 0)
    ORDER BY	RoleMapping ASC
			,	SiteID ASC;

END$$

DELIMITER ;

