/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_SetProblemCategoryByGroupID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_SetProblemCategoryByGroupID`(
		IN ip_GroupID 			BIGINT UNSIGNED
    ,	IN ip_PACategoryID		INT
    ,	IN ip_PACreditSites		TEXT
    ,	IN ip_PALicenseeSites	TEXT
    ,	IN ip_ModifiedBy 		INT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
/* 
		Created:	20221025@Harvey.Nguyen
		Task :		[CTS] Associated Group Enhancement
		DB:			CTS_DataCenter
		Original: 
		Revisions: 
            - 20221025@Harvey.Nguyen: Update PA for group [Redmine ID: #179398]
		
        Param's Explanation: 
			- ip_PACategoryID: 
				>0: Update Sites and PA Category
                -1: Remove All PA
                -2: Remove PA Site WHEN Group Site Remove
		Example:
			- CALL CTS_DC_AssociatedGroup_SetProblemCategoryByGroupID_xtest(@ip_GroupID:=22, @ip_PACategoryID:=-1, @ip_PACreditSites:=NULL, @ip_PALicenseeSites:=2,@ip_ModifiedBy:=8 );
*/  

    DECLARE lv_PACreditSites TEXT;
    DECLARE lv_NewPACreditSites TEXT;
    DECLARE lv_PALicenseeSites TEXT;
    DECLARE lv_NewPALicenseeSites TEXT;
    
    DECLARE lv_LogInfo JSON;
    DECLARE CONST_USERLOG_LOGTYPE SMALLINT DEFAULT 34;
    DECLARE CONST_SPNAME VARCHAR(100) DEFAULT 'CTS_DC_AssociatedGroup_SetProblemCategoryByGroupID';
    
    #============USER LOG====================================
    SET lv_LogInfo = JSON_OBJECT( 'GroupID', ip_GroupID, 
								   'PACategoryID', ip_PACategoryID, 
								   'PACreditSites', ip_PACreditSites, 
                                   'PALicenseeSites', ip_PALicenseeSites);
                                   
     INSERT IGNORE INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	 SELECT CONST_USERLOG_LOGTYPE AS LogTypeID
			,	CONST_SPNAME AS SPName
			,	lv_LogInfo AS LogInfo
			,	NOW() AS CreatedDate
			,	ip_ModifiedBy AS CreatedBy;        

    #============SET Sites and PA================================
    IF ip_PACategoryID >= 0 THEN    
		UPDATE CTS_DataCenter.AssociatedGroup
		SET  	PACategoryID = ip_PACategoryID
			,	PACreditSites = ip_PACreditSites
			,	PALicenseeSites = ip_PALicenseeSites
			,	ModifiedBy = ip_ModifiedBy
		WHERE GroupID = ip_GroupID;
	END IF;
    
    #==================REMOVE PACategory For Site=======================================
	IF ip_PACategoryID = -1 THEN  
		#========Credit Sites=======================
        UPDATE CTS_DataCenter.AssociatedGroup AS ag
        SET ag.PACreditSites = NULL
			, ag.PALicenseeSites = NULL
            , ag.PACategoryID = NULL
		WHERE ag.GroupID = ip_GroupID; 
	END IF;
    
    #==================REMOVE PASites IF GroupSites Is Remove=======================================
    IF ip_PACategoryID = -2 THEN   
    #========Credit Sites=======================
		SELECT ag.PACreditSites 
		INTO lv_PACreditSites 
		FROM CTS_DataCenter.AssociatedGroup AS ag WHERE ag.GroupID = ip_GroupID; 		
		
		DROP TEMPORARY TABLE IF EXISTS Temp_PACreditSites;
		CREATE TEMPORARY TABLE Temp_PACreditSites(SiteID INT PRIMARY KEY);
		IF (lv_PACreditSites IS NOT NULL) THEN
			SET @sql = CONCAT("INSERT INTO Temp_PACreditSites (SiteID) VALUES ('", REPLACE(lv_PACreditSites, ",", "'),('"),"');");
			PREPARE stmt1 FROM @sql;
			EXECUTE stmt1;
		END IF;
		
		DROP TEMPORARY TABLE IF EXISTS Temp_NewCreditSites;
		CREATE TEMPORARY TABLE Temp_NewCreditSites(SiteID INT PRIMARY KEY);
		
		IF (ip_PACreditSites IS NOT NULL) THEN
			SET @sql = CONCAT("INSERT INTO Temp_NewCreditSites (SiteID) VALUES ('", REPLACE(ip_PACreditSites, ",", "'),('"),"');");        
			PREPARE stmt1 FROM @sql;
			EXECUTE stmt1;
		END IF;

		SELECT GROUP_CONCAT(tmpPs.SiteID)
		INTO lv_NewPACreditSites
		FROM Temp_PACreditSites AS tmpPs
			INNER JOIN Temp_NewCreditSites AS tmpRev ON tmpPs.SiteID = tmpRev.SiteID;
		
		UPDATE CTS_DataCenter.AssociatedGroup AS ag
		SET ag.PACreditSites = lv_NewPACreditSites
		WHERE ag.GroupID = ip_GroupID;
		
			#========Licensee Sites=======================
		SELECT ag.PALicenseeSites 
		INTO lv_PALicenseeSites 
		FROM CTS_DataCenter.AssociatedGroup AS ag WHERE ag.GroupID = ip_GroupID; 		
		
		DROP TEMPORARY TABLE IF EXISTS Temp_PALicenseeSites;
		CREATE TEMPORARY TABLE Temp_PALicenseeSites(SiteID INT PRIMARY KEY);
		IF (lv_PALicenseeSites IS NOT NULL) THEN
			SET @sql = CONCAT("INSERT INTO Temp_PALicenseeSites (SiteID) VALUES ('", REPLACE(lv_PALicenseeSites, ",", "'),('"),"');");
			PREPARE stmt1 FROM @sql;
			EXECUTE stmt1;
		END IF;
		
		DROP TEMPORARY TABLE IF EXISTS Temp_NewLicenseeSites;
		CREATE TEMPORARY TABLE Temp_NewLicenseeSites(SiteID INT PRIMARY KEY);
		
		IF (ip_PALicenseeSites IS NOT NULL) THEN
			SET @sql = CONCAT("INSERT INTO Temp_NewLicenseeSites (SiteID) VALUES ('", REPLACE(ip_PALicenseeSites, ",", "'),('"),"');");        
			PREPARE stmt1 FROM @sql;
			EXECUTE stmt1;
		END IF;		
        
		SELECT GROUP_CONCAT(tmpPs.SiteID)
        INTO lv_NewPALicenseeSites
        FROM Temp_PALicenseeSites AS tmpPs
			INNER JOIN Temp_NewLicenseeSites AS tmpRev ON tmpPs.SiteID = tmpRev.SiteID;
		
        UPDATE CTS_DataCenter.AssociatedGroup AS ag
		SET ag.PALicenseeSites = lv_NewPALicenseeSites
		WHERE ag.GroupID = ip_GroupID;
        
        #==============================
        IF lv_NewPALicenseeSites IS NULL AND lv_NewPACreditSites IS NULL
        THEN
			UPDATE CTS_DataCenter.AssociatedGroup AS ag
			SET ag.PACategoryID = NULL
			WHERE ag.GroupID = ip_GroupID;
		END IF;
    END IF;
    
END$$
DELIMITER ;