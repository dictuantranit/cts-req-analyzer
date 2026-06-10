/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_UserAgent_UpdateOSBrowser`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_UserAgent_UpdateOSBrowser`(
		IN ip_UserAgentJson JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20190815@Terry.Nguyen
		Task :		Update User Agent (OS, Browser)
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20201020@CaseyHuynh: Update Owner, metadata, remove ISOLATION setting, Change DB log to CTS_Log [RedmineID: #145271]
			- 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
            - 20210914@Casey.Huynh: BrowserID and OSID Exceed DataRange [#161576]
			- 20211214@Aries.Nguyen: Enrich the information on customer profile [Redmine ID: #165105]

		Param's Explanation (filtered by):
	*/


	DROP TEMPORARY TABLE IF EXISTS Temp_UserAgent;
	CREATE TEMPORARY TABLE Temp_UserAgent( 
			UserAgentKey 	VARCHAR(32)
		,	BrowserName		VARCHAR(100)
		,	OSName			VARCHAR(100)
        ,	DeviceTypeName	VARCHAR(15)	
        ,   CreatedDate		DATETIME
        ,	BrowserID		INT UNSIGNED
        ,	OSID			INT UNSIGNED
        ,	DeviceTypeID	INT UNSIGNED
	);

	#=======================

	INSERT INTO Temp_UserAgent(UserAgentKey, BrowserName, OSName,DeviceTypeName, CreatedDate)
	SELECT 	tmpUA.UserAgentKey
		,	tmpUA.BrowserName
		,	tmpUA.OSName
        ,	tmpUA.DeviceTypeName
		,	tmpUA.CreatedDate
	FROM
	JSON_TABLE(ip_UserAgentJson
		, "$[*]" COLUMNS(
							UserAgentKey 		VARCHAR(32)		PATH "$.UserAgentKey"							
						,	BrowserName			VARCHAR(100)	PATH "$.BrowserName" 
						,	OSName				VARCHAR(100)	PATH "$.OSName"
                        ,	DeviceTypeName		VARCHAR(20)		PATH "$.DeviceTypeName"
                        ,	CreatedDate			DATETIME		PATH "$.CreatedDate" 
		)
	) AS  tmpUA;

	#=======================
	
	# Insert Browser
	INSERT IGNORE INTO DCS_DataCenter.Browser(BrowserName, CreatedDate)
	SELECT	tmpBr.BrowserName
		,	MIN(CreatedDate) 
    FROM Temp_UserAgent AS tmpBr 
    GROUP BY 	tmpBr.BrowserName;

	# Insert OS
	INSERT IGNORE INTO DCS_DataCenter.OS(OSName, CreatedDate)
	SELECT	tmpOs.OSName
		,	MIN(CreatedDate) 
	FROM Temp_UserAgent AS tmpOs 
    GROUP BY tmpOs.OSName;
    
    # Insert Device Type
	INSERT IGNORE INTO DCS_DataCenter.DeviceType(DeviceTypeName, GroupName, Created)
	SELECT	tmpDv.DeviceTypeName
		,	'Others'
		,	NOW() 
	FROM Temp_UserAgent AS tmpDv 
    GROUP BY tmpDv.DeviceTypeName;
	
	# Update Browser and OS Id into temporary table
	UPDATE Temp_UserAgent as tmpAU 
		INNER JOIN	DCS_DataCenter.OS AS os ON tmpAU.OSName = os.OSName
		INNER JOIN	DCS_DataCenter.Browser AS br ON tmpAU.BrowserName = br.BrowserName
        INNER JOIN	DCS_DataCenter.DeviceType AS dv ON tmpAU.DeviceTypeName = dv.DeviceTypeName
	SET		tmpAU.BrowserID = br.BrowserID
		,	tmpAU.OSID = os.OSID
        ,	tmpAU.DeviceTypeID = dv.DeviceTypeID;    
                
	# Update Browser and OS into User Agent table
	UPDATE DCS_DataCenter.UserAgent AS us 
		INNER JOIN	Temp_UserAgent AS tmp ON us.UserAgentKey = tmp.UserAgentKey
	SET		us.BrowserID = tmp.BrowserID
		,	us.OSID = tmp.OSID
		,	us.Browser = tmp.BrowserName
		,	us.OS = tmp.OSName
        ,	us.DeviceTypeID = tmp.DeviceTypeID;

END$$

DELIMITER ;