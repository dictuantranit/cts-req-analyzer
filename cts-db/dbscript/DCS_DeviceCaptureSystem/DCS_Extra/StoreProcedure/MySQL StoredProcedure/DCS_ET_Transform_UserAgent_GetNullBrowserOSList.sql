/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transform_UserAgent_GetNullBrowserOSList`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transform_UserAgent_GetNullBrowserOSList`(
		IN ip_size INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20190815@Terry.Nguyen
		Task :		Get user agent list by size
		DB:			DCS_Extra
		Original:

		Revisions:
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			- 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
			- 20210914@Casey.Huynh: BrowserID and OSID Exceed DataRange [#161576]
			- 20210916@Aries.Nguyen: Update sp [#161576]
			- 20211214@Aries.Nguyen: Enrich the information on customer profile [Redmine ID: #165105]
            - 2023292023@Casey.Huynh: CTMAX, Velki [RedmineID: #190118]

		Param's Explanation (filtered by):
	*/

	SELECT	ua.UserAgentKey
		,	ua.UserAgent
		,	ua.CreatedDate
	FROM DCS_Extra.UserAgent AS ua
    WHERE	BrowserID IS NULL 
	
    UNION 
    
	SELECT	ua.UserAgentKey
		,	ua.UserAgent
		,	ua.CreatedDate
	FROM DCS_Extra.UserAgent AS ua
    WHERE	ua.OSID IS NULL

	UNION 
    
	SELECT	ua.UserAgentKey
		,	ua.UserAgent
		,	ua.CreatedDate
	FROM 	DCS_Extra.UserAgent AS ua
    WHERE	ua.DeviceTypeID IS NULL

    LIMIT ip_size;
		
END$$

DELIMITER ;