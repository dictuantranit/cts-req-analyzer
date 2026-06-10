/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_GetPASites`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_GetPASites`(
		IN ip_GroupID 			BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
/* 
		Created:	20221025@Harvey.Nguyen
		Task :		[CTS] Associated Group Enhancement
		DB:			CTS_DataCenter
		Original: 
		Revisions: 
            - 20221025@Harvey.Nguyen: Get sites for PA setting [Redmine ID: #179398]
		
        Param's Explanation: 

		Example:
			- CALL CTS_DC_AssociatedGroup_GetPASites(1);

*/	
	DECLARE lv_AllCredit		SMALLINT;
	DECLARE lv_AllLicensee		SMALLINT;
    DECLARE lv_Sites			LONGTEXT;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_GroupSite;
	CREATE TEMPORARY TABLE 		Temp_GroupSite (
			SiteID 		BIGINT UNSIGNED PRIMARY KEY
	);
    
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
    
    SELECT 	CONCAT(IFNULL(ag.PACreditSites,''),',',IFNULL(ag.PALicenseeSites,''))
    INTO 	lv_Sites
	FROM  CTS_DataCenter.AssociatedGroup AS ag
    WHERE GroupID = ip_GroupID
	LIMIT 1;
	
    IF lv_Sites IS NOT NULL AND lv_Sites != "," THEN
		SET @sql= CONCAT("INSERT IGNORE INTO Temp_GroupSite (SiteID) VALUES ('", REPLACE(lv_Sites, ',', "'),('"),"');");
		PREPARE 	stmt1 FROM @sql;
		EXECUTE 	stmt1;
	END IF;
    
    CALL CTS_DC_Common_GetSites(1);
    
    DELETE si
	FROM Temp_SiteInfo AS si
	LEFT JOIN Temp_GroupSite AS gs ON si.SiteID = gs.SiteID
	WHERE gs.SiteID IS NULL;
        
	UPDATE Temp_SiteInfo AS tmpSi
    INNER JOIN Temp_GroupSite AS tmpGs ON tmpGs.SiteID = tmpSi.SiteID
    SET tmpSi.IsChosen = 1;
	
    SELECT 	tmpSi.SiteID 			
        ,   tmpSi.SiteName 			
        ,   tmpSi.IsLicensee		
        ,	tmpSi.IsChosen	
    FROM Temp_SiteInfo AS tmpSi;
END$$
DELIMITER ;