/*1.1 Remove Subscriber 
4427	asiabet88
4428	mansion88
4431	haifa
*/
DELETE
FROM	CTS_Admin.Subscriber
WHERE	SubscriberID IN (4427, 4428, 4431);

DELETE 
FROM 	CTS_DataCenter.MappingSubscriberSite 
WHERE	SubscriberID IN (4427, 4428, 4431);

#======================================================
/*1.2 	Update MappingSubscriberSite (siteID and SiteName)
102	M88
104	BBin
105	Fun88
*/

UPDATE CTS_DataCenter.MappingSubscriberSite 
SET 	SiteID = 34
		, SiteName = 'mansion88'
        , SubscriberType = 1
WHERE SubscriberID = 102;

UPDATE CTS_DataCenter.MappingSubscriberSite 
SET 	SiteID = 44
		, SiteName = 'haifa'
        , SubscriberType = 1
WHERE SubscriberID = 104;

UPDATE CTS_DataCenter.MappingSubscriberSite 
SET 	SiteID = 31
		, SiteName = 'asiabet88'
        , SubscriberType = 1
WHERE SubscriberID = 105;
#=========================================================
