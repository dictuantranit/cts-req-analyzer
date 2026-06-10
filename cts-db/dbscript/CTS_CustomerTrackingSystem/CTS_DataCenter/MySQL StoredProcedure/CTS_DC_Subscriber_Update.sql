/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Subscriber_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Subscriber_Update`(
		OUT op_ErrorMessage			VARCHAR(2000)
	
	,	IN ip_SubscriberID			INT
	,	IN ip_SubscriberName		VARCHAR(50)
	,	IN ip_SubscriberType		TINYINT
	,	IN ip_SubscriberSourceID	TINYINT
	,	IN ip_SubscriberPrefix		VARCHAR(30)
	,	IN ip_IsTest				BIT
	,	IN ip_SiteList				JSON
	,	IN ip_UserID				INT
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20200911@Roger.Le
		Task :		Function add new subscriber
		DB:			CTS_DataCenter
		Original: 
		Revisions:
            - [20200911@Roger.Le][138102]: Created
            - [20200924@Lex.Khuat][138102]: Support insert/update sub with multiple sites
            - [20201118@Lex.Khuat][145576]: Fix issue multi site update skip prefix, remove rule validate duplicating site
            - [20200912@Lex.Khuat][146563]: Rollback code to #138102, no validating for updating multi sites sub
            - 20200911@Casey.Huynh: Return Subscriber is updated or Add New [Redmine ID: 148849]
            - 20210412@Casey.Huynh: SET DCSStatus = 1 for New Subscriber [Redmine ID: 153202]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
			- 20230911@Victoria.Le: Add new column SubscriberSourceID [Redmine ID: #193044]

		Param's Explanation:
			- ip_SubscriberID: 0 => Insert mode, <> 0 => Update mode, input siteID
			- ip_SubscriberType: 0 => Credit, 1 => Licensees
            - ip_SubscriberPrefix: null => skip
			- ip_SubscriberSourceID: 0: Others, 1: Direct API, 2: Oddsfeed
	*/
    
    DECLARE lv_CurrentTime		DATETIME		DEFAULT CURRENT_TIME();
    DECLARE lv_SubscriberID		INT				DEFAULT IFNULL(ip_SubscriberID, 0);
    DECLARE lv_SPName 			VARCHAR(200)	DEFAULT 'CTS_DC_Subscriber_Update';
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
    
    #============================================
    DROP TEMPORARY TABLE IF EXISTS Temp_Sites;
    DROP TEMPORARY TABLE IF EXISTS Temp_SitesDelete;
    #============================================
    
	CREATE TEMPORARY TABLE Temp_Sites( 	 
			SiteID				INT
		, 	SiteName			VARCHAR(50)
		, 	RoleMapping 		TINYINT
        ,	CurrentSubID		INT	DEFAULT 0
        , 	INDEX				IX_Temp_Sites_SiteID (SiteID)
        ,	INDEX				IX_Temp_Sites_CurrentSubID (CurrentSubID)
    );
    
	CREATE TEMPORARY TABLE Temp_SitesDelete( 	 
			SiteID				INT
		, 	SiteName			VARCHAR(50)
		, 	RoleMapping 		TINYINT
		,	SubscriberID		INT
        ,	SubscriberGroupID	SMALLINT UNSIGNED
        , 	INDEX				IX_Temp_Sites_SiteID (SiteID)
        ,	INDEX				IX_Temp_Sites_CurrentSubID (SubscriberID)
    );
    
    #========= CHECK SUBSCRIBER NAME ALREADY EXISTS =========
    IF (EXISTS (SELECT 1
				FROM CTS_Admin.Subscriber
				WHERE SubscriberID <> lv_SubscriberID
                AND LOWER(SubscriberName) = LOWER(IFNULL(ip_SubscriberName, '')))) THEN
		SET op_ErrorMessage = 'Subscriber name already exists';
		LEAVE sp;
	END IF;
    
    #========= CHECK PREFIX ALREADY EXISTS =========
	IF (IFNULL(ip_SubscriberPrefix, '') != ''
		AND EXISTS (SELECT 1
				FROM CTS_Admin.Subscriber
				WHERE SubscriberID <> lv_SubscriberID
				AND LOWER(SubscriberPrefix) = LOWER(IFNULL(ip_SubscriberPrefix, '')))) THEN
		SET op_ErrorMessage = 'Subscriber prefix already exists';
		LEAVE sp;
	END IF;

    #========= GET DATA TO UPDATE =========
	INSERT INTO Temp_Sites (SiteID, SiteName, RoleMapping, CurrentSubID)
	SELECT	DISTINCT
			tmpTable.SiteID
		,	tmpTable.SiteName
        ,	tmpTable.RoleMapping
        ,	IFNULL(site.SubscriberID, 0)
	FROM JSON_TABLE(ip_SiteList,
		 "$[*]" COLUMNS(
		  SiteID				INT				PATH "$.SiteID" 
		, SiteName 				VARCHAR(50) 	PATH "$.SiteName"
		, RoleMapping			TINYINT 		PATH "$.RoleMapping" 
		 )
	) as tmpTable
		LEFT JOIN CTS_DataCenter.MappingSubscriberSite AS site ON tmpTable.SiteID = site.SiteID AND site.SubscriberID = lv_SubscriberID;

    #========= CHECK IF SITEID DUPLICATED IN PARAM =========
    IF (EXISTS (SELECT 1
				FROM Temp_Sites
                GROUP BY SiteID
                HAVING COUNT(*) > 1)) THEN
		
		SELECT LEFT(CONCAT('SiteID duplicating: ', GROUP_CONCAT(DISTINCT SiteID ORDER BY SiteID ASC SEPARATOR ', ')), 2000)
        INTO op_ErrorMessage
        FROM Temp_Sites
        GROUP BY SiteID
		HAVING COUNT(*) > 1;
		LEAVE sp;
	
    END IF;

	IF lv_SubscriberID <> 0 THEN
		#========= UPDATE SUBSCRIBER =========
		INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		SELECT	27
			,	lv_SPName
			,	CONCAT('Update subscriber: SubID_', SubscriberID, '; SubName_', SubscriberName, '; SubPrefix_', SubscriberPrefix, '; SubType_', SubscriberType, '; SubSourceID_', SubscriberSourceID, '; IsTest_', IsTest)
			,	lv_CurrentTime
			,	ip_UserID
		FROM CTS_Admin.Subscriber
        WHERE SubscriberID = lv_SubscriberID
			AND (LOWER(SubscriberName) <> LOWER(IFNULL(ip_SubscriberName, ''))
				OR LOWER(SubscriberPrefix) <> LOWER(IFNULL(ip_SubscriberPrefix, ''))
                OR SubscriberType <> ip_SubscriberType
				OR SubscriberSourceID <> ip_SubscriberSourceID);
        
		UPDATE CTS_Admin.Subscriber
        SET		SubscriberName = ip_SubscriberName
			,	SubscriberPrefix = ip_SubscriberPrefix
            ,	SubscriberType = ip_SubscriberType
			,	SubscriberSourceID = ip_SubscriberSourceID
            ,	IsTest = ip_IsTest
		WHERE SubscriberID = lv_SubscriberID;
        
    ELSE
		#========= INSERT SUBSCRIBER =========
		INSERT INTO CTS_Admin.Subscriber (SubscriberName, SubscriberPrefix, SubscriberType, SubscriberSourceID, SubscriberStatus, CreatedDate, CreatedBy, IsTest, DCSStatus)
		SELECT	ip_SubscriberName
			,	ip_SubscriberPrefix
			,	ip_SubscriberType
			,	ip_SubscriberSourceID
			,	1 AS SubscriberStatus
			,	lv_CurrentTime
			,	ip_UserID
			,	ip_IsTest
			,	1 AS DCSStatus;
		#========= GET NEW INSERTED SUBSCRIBER ID =========
		SELECT	SubscriberID
		INTO	lv_SubscriberID
		FROM CTS_Admin.Subscriber
		WHERE SubscriberName = ip_SubscriberName
		LIMIT 1;
        
		INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		VALUES	(28
			,	lv_SPName
			,	CONCAT('Insert subscriber: SubID_', lv_SubscriberID, '; SubName_', ip_SubscriberName, '; SubPrefix_', ip_SubscriberPrefix, '; SubType_', ip_SubscriberType, '; SubSourceID_', ip_SubscriberSourceID, '; IsTest_', EXPORT_SET(ip_IsTest, '1', '0', '', 1))
			,	lv_CurrentTime
			,	ip_UserID);

	END IF;

	#========= INSERT NEW SITES =========
	INSERT INTO CTS_DataCenter.MappingSubscriberSite(SubscriberID, SubscriberName, RoleMapping, SubscriberType, SubscriberStatus, SubscriberGroupID, SiteID, SiteName)
	SELECT	lv_SubscriberID
		,	ip_SubscriberName
		,	tmp.RoleMapping
		,	ip_SubscriberType
		,	1
		,	CASE	WHEN ip_SubscriberType = 0 THEN 1 # Credit
					WHEN ip_SubscriberType = 1 THEN 2 # Licensee
					ELSE 2
			END AS SubscriberGroupID
		,	tmp.SiteID
		,	tmp.SiteName
	FROM Temp_Sites AS tmp
	WHERE tmp.CurrentSubID = 0;
    
    INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
    SELECT	25
		,	lv_SPName
        ,	CONCAT('Add site mapping: SiteID_', SiteID, '; SiteName_', SiteName, '; Role_', RoleMapping, '; SubID_', lv_SubscriberID, '; SubGroupID_',
			CASE	WHEN ip_SubscriberType = 0 THEN 1 # Credit
					WHEN ip_SubscriberType = 1 THEN 2 # Licensee
					ELSE 2
			END)
        ,	lv_CurrentTime
        ,	ip_UserID
	FROM Temp_Sites
    WHERE CurrentSubID = 0;

	#========= UPDATE EXISTING SITES =========
	INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
    SELECT	24
		,	lv_SPName
        ,	CONCAT('Update site mapping: SiteID_', site.SiteID, '; SiteName_', site.SiteName, '; Role_', site.RoleMapping, '; SubID_', site.SubscriberID, '; SubGroupID_', site.SubscriberGroupID)
        ,	lv_CurrentTime
        ,	ip_UserID
	FROM CTS_DataCenter.MappingSubscriberSite AS site
		INNER JOIN Temp_Sites AS tmp ON site.SiteID = tmp.SiteID AND site.SubscriberID = tmp.CurrentSubID
    WHERE tmp.CurrentSubID = lv_SubscriberID
		AND (site.SiteName <> tmp.SiteName
			OR site.RoleMapping <> tmp.RoleMapping);
    
    UPDATE CTS_DataCenter.MappingSubscriberSite AS site
		INNER JOIN Temp_Sites AS tmp ON site.SiteID = tmp.SiteID AND site.SubscriberID = tmp.CurrentSubID
    SET		site.SiteName = tmp.SiteName
		,	site.RoleMapping = tmp.RoleMapping
        ,	site.SubscriberName = ip_SubscriberName
        ,	site.SubscriberType = ip_SubscriberType
        ,	site.SubscriberGroupID = CASE	WHEN ip_SubscriberType = 0 THEN 1 # Credit
											WHEN ip_SubscriberType = 1 THEN 2 # Licensee
											ELSE 2
									 END
	WHERE tmp.CurrentSubID = lv_SubscriberID;

	#========= REMOVE UNWANTED SITES =========
    INSERT INTO Temp_SitesDelete(SiteID, SiteName, RoleMapping, SubscriberID, SubscriberGroupID)
    SELECT	site.SiteID
		,	site.SiteName
        ,	site.RoleMapping
        ,	site.SubscriberID
        ,	site.SubscriberGroupID
    FROM CTS_DataCenter.MappingSubscriberSite AS site
		LEFT JOIN Temp_Sites AS tmp ON site.SiteID = tmp.SiteID
	WHERE	site.SubscriberID = lv_SubscriberID
		AND tmp.SiteID IS NULL;

	INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
    SELECT	23
		,	lv_SPName
        ,	CONCAT('Remove site mapping: SiteID_', SiteID, '; SiteName_', SiteName, '; Role_', RoleMapping, '; SubID_', SubscriberID, '; SubGroupID_', SubscriberGroupID)
        ,	lv_CurrentTime
        ,	ip_UserID
	FROM Temp_SitesDelete;

	DELETE site
    FROM CTS_DataCenter.MappingSubscriberSite AS site
    INNER JOIN Temp_SitesDelete AS del ON site.SiteID = del.SiteID AND site.SubscriberID = del.SubscriberID
	WHERE site.SubscriberID = lv_SubscriberID;
    
	#======Return New SubID/SiteID for Update CTSCustomer
    SELECT	lv_SubscriberID AS SubscriberID
		,	tmp.SiteID
        ,	tmp.RoleMapping
	FROM 	Temp_Sites AS tmp;
    
END$$

DELIMITER ;

