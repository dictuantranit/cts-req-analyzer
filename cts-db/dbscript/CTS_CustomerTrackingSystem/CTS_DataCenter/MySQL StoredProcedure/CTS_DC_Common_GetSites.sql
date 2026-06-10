/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Common_GetSites`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Common_GetSites`(
		IN ip_IsNestedCalled 			BIT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20220922@Long.Luu
		Task :		Get all subscribers/sites with grouped
		DB:			CTS_DataCenter
		Original: 
		Revisions:        
            - 20220922@Long.Luu: adjust to be called internally inside another SP [Redmine ID: 176991]
			
		Param's Explanation:
        
        Example:
			- CALL CTS_DC_Common_GetAllSubscriberGroups();
	*/
    
    DROP TEMPORARY TABLE IF EXISTS Temp_SiteInfo;
	CREATE TEMPORARY TABLE 		Temp_SiteInfo (
			SiteID 					BIGINT UNSIGNED PRIMARY KEY
        ,   SiteName 				VARCHAR(50)
		,	SubscriberGroupID		SMALLINT UNSIGNED
        ,	SubscriberGroupName		VARCHAR(50)
        ,	ParentID				SMALLINT UNSIGNED
        ,	DisplayOrder			TINYINT UNSIGNED
        ,   IsLicensee				SMALLINT
        ,	IsChosen				SMALLINT DEFAULT 0
	);
            
	INSERT INTO Temp_SiteInfo (SiteID,SiteName,SubscriberGroupID,SubscriberGroupName,ParentID,DisplayOrder,IsLicensee)
    SELECT DISTINCT s.SiteID
		, 	s.SiteName
        , 	s.SubscriberGroupID
        , 	sg.SubscriberGroupName
        , 	sg.ParentID
        , 	sg.DisplayOrder
        ,	CASE WHEN MAX(s.SubscriberGroupID) = 2 THEN 1 ELSE 0 END AS IsLicensee
    FROM CTS_DataCenter.MappingSubscriberSite AS s
		INNER JOIN CTS_DataCenter.SubscriberGroup AS sg ON s.SubscriberGroupID = sg.SubscriberGroupID
        LEFT JOIN CTS_Admin.Subscriber AS sub ON s.SubscriberID = sub.SubscriberID
    WHERE sg.IsActive = 1
		AND sub.IsTest = 0
        AND sub.SubscriberStatus = 1
	GROUP BY s.SiteID
		, 	s.SiteName
        , 	s.SubscriberGroupID
        , 	sg.SubscriberGroupName
        , 	sg.ParentID
        , 	sg.DisplayOrder;
    
    IF (ip_IsNestedCalled <> 1)
		THEN
			SELECT DISTINCT SiteID
				, 	SiteName
				, 	SubscriberGroupID
				, 	SubscriberGroupName
				, 	ParentID
				, 	DisplayOrder
				, 	1 AS IsActive
			FROM Temp_SiteInfo
			ORDER BY DisplayOrder ASC, SiteName ASC;
	END IF;
END$$

DELIMITER ;

