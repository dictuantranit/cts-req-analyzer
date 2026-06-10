/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_Account_Add`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_Account_Add`(
		IN ip_GroupID 		BIGINT UNSIGNED
    ,	IN ip_CTSCustIDs 	LONGTEXT
    ,	IN ip_IsAuto		TINYINT
    ,	IN ip_Remark 		VARCHAR(200)
    ,	IN ip_CreatedBy 	INT UNSIGNED 
)
    SQL SECURITY INVOKER
BEGIN
	/* 
		Created:	20220705@Aries.Nguyen
		Task:		[CTS] Fraud Group Management [Redmine ID: #167748]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20220705@Aries.Nguyen: Created [Redmine ID: #167748]
            - 20220831@Aries.Nguyen: Associated Group Enhancement [Redmine ID: #176991]
            - 20221028@Harvey.Nguyen: Check PA site [Redmine ID: #179398]
			- 20240628@Thomas.Nguyen: Renovate CC phase 2 - Change datatype for lv_PACategoryID to INT [Redmine ID: #205317]

		Param's Explanation (filtered by):

        Example: 
			- CALL CTS_DC_AssociatedGroup_Account_Add(@ip_GroupID:=14,@ip_CTSCustIDs:='9,10',@ip_IsAuto:=1,@ip_Remark:="Test Remark",@ip_CreatedBy:=169368);
	*/
    DECLARE lv_Sites			LONGTEXT;
    DECLARE lv_PACategoryID		INT;
    
    DECLARE lv_LogInfo JSON;
    DECLARE CONST_USERLOG_LOGTYPE SMALLINT DEFAULT 34;
    DECLARE CONST_SPNAME VARCHAR(100) DEFAULT 'CTS_DC_AssociatedGroup_Account_Add';
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE 	Temp_Cust (
			CTSCustID 		BIGINT UNSIGNED PRIMARY KEY
		,	CustID			INT
		,	SiteID			INT        
        ,	RoleID			TINYINT
        ,	SubscriberID	INT
        ,	IsLicensee		TINYINT
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_PASite;
	CREATE TEMPORARY TABLE 	Temp_PASite (
			SiteID 		BIGINT UNSIGNED PRIMARY KEY
	);
    
	IF ip_IsAuto = 0 THEN
		#============USER LOG====================================
		SET lv_LogInfo = JSON_OBJECT('GroupID', ip_GroupID, 
									   'CTSCustIDs', ip_CTSCustIDs, 
									   'IsAuto', ip_IsAuto, 
									   'Remark', ip_Remark);
									   
		 INSERT IGNORE INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
		 SELECT CONST_USERLOG_LOGTYPE AS LogTypeID
				,	CONST_SPNAME AS SPName
				,	lv_LogInfo AS LogInfo
				,	NOW() AS CreatedDate
				,	ip_CreatedBy AS CreatedBy;      
    END IF;
    
    
    INSERT INTO Temp_Cust(CTSCustID, CustID, SiteID, RoleID, SubscriberID, IsLicensee)
    SELECT cus.CTSCustID, cus.CustID, cus.SiteID, cus.RoleID, cus.SubscriberID, cus.IsLicensee
    FROM JSON_TABLE(CONCAT('[',ip_CTSCustIDs,']'),'$[*]' COLUMNS(NESTED PATH '$' COLUMNS (CTSCustID BIGINT UNSIGNED PATH '$'))) AS tmp
		INNER JOIN CTSCustomer cus ON tmp.CTSCustID = cus.CTSCustID;
    
    SELECT 		CONCAT(IFNULL(ag.PACreditSites,''),',',IFNULL(ag.PACreditSites,''))
			, 	ag.PACategoryID
    INTO 		lv_Sites
			, 	lv_PACategoryID
	FROM  CTS_DataCenter.AssociatedGroup AS ag
    WHERE GroupID = ip_GroupID LIMIT 1;
    
    IF lv_Sites IS NOT NULL AND lv_Sites != "," THEN
		SET @sql= CONCAT("INSERT IGNORE INTO Temp_PASite (SiteID) VALUES ('", REPLACE(lv_Sites, ',', "'),('"),"');");
		PREPARE 	stmt1 FROM @sql;
		EXECUTE 	stmt1;
	END IF;
    
    INSERT IGNORE INTO CTS_DataCenter.AssociatedGroupAccount(GroupID,CTSCustID,IsAuto,Remark,CreatedBy)
    SELECT 	ip_GroupID AS GroupID
		,	tmp.CTSCustID
        ,	ip_IsAuto AS IsAuto
        ,	ip_Remark AS Remark
        ,	ip_CreatedBy AS CreatedBy
    FROM Temp_Cust AS tmp;
    
    SELECT 	tmp.CTSCustID
		,	CASE WHEN site.SiteID IS NULL THEN 0 ELSE 1 END AS 'IsSyncPA'
        ,	tmp.CustID
        ,	tmp.RoleID
        ,	tmp.SubscriberID
        ,	tmp.IsLicensee
        ,	lv_PACategoryID AS 'CategoryID'
        ,	lv_PACategoryID AS 'CategoryGroup'
    FROM Temp_Cust AS tmp 
		LEFT JOIN Temp_PASite AS site ON tmp.SiteID = site.SiteID;
END$$
DELIMITER ;