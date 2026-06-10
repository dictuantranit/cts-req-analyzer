/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_Scan`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_Scan`(
		OUT	op_GroupID			BIGINT
	,	OUT	op_GroupName		VARCHAR(100)
	,	OUT	op_ABI				INT
    ,	OUT	op_Ori				INT
    ,	OUT	op_PACategoryID		INT
    ,	OUT op_LastCTSCustID	BIGINT
) 
    SQL SECURITY INVOKER
sp : BEGIN
	/* 
		Created:	20220705@Aries.Nguyen
		Task:		[CTS] Fraud Group Management [Redmine ID: #167748]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20220705@Aries.Nguyen: 	Created [Redmine ID: #167748]
			- 20220831@Aries.Nguyen: 	Associated Group Enhancement [Redmine ID: #176991]
			- 20221028@Harvey.Nguyen: 	Check PA site [Redmine ID: #179398]
			- 20230112@Victoria.Le: 	Modify SPs due to restructure AssociationByAI [Redmine ID: #181994]
			- 20230313@Casey.Huynh:		Applied Betting Parten OTGB [Redmine ID: #184791]
            - 20230421@Casey.Huynh: 	Add AssType to AssociationByIP [Redmine ID: #185783]
            - 20240628@Thomas.Nguyen:	Renovate CC phase 2 - Change datatype for lv_PACategoryID to INT [Redmine ID: #205317]
            - 20241219@Casey.Huynh: 	HF Add Association Member Only [Redmine ID: #215554]

		Param's Explanation (filtered by):

		Example:
			- CALL  CTS_DC_AssociatedGroup_Scan(@op_GroupID,@op_GroupName,@op_ABI,@op_Ori,@op_PACategoryID,@op_LastCTSCustID);
	*/
	DECLARE CONST_ASSTYPE_BETTINGPATTERN 	INT DEFAULT 2;
	DECLARE CONST_ASSBYAI_ACTIVESTATUS 		INT DEFAULT 1;
	DECLARE CONST_ASSTYPE_IP 				INT DEFAULT 4;
	DECLARE CONST_ASSBYIP_ACTIVESTATUS 		INT DEFAULT 1;
    
    DECLARE CONST_ROLEID_MEMBER				TINYINT DEFAULT 1;
    #=================================================
    DECLARE lv_BatchSize 		BIGINT;
    DECLARE lv_LastGroupID 		BIGINT;
    DECLARE lv_LastCTSCustID 	BIGINT;
    DECLARE lv_AllCredit		SMALLINT;
	DECLARE lv_AllLicensee		SMALLINT;
    DECLARE lv_Sites			LONGTEXT;
    DECLARE lv_PASites			LONGTEXT;
    DECLARE lv_HasDevice		BIT;
    DECLARE lv_HasManual		BIT;
	DECLARE lv_HasIP			BIT;
    DECLARE lv_HasAI			BIT;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE 		Temp_Cust (
			CTSCustID 			BIGINT UNSIGNED PRIMARY KEY
		,	CustID 				BIGINT UNSIGNED
		,	AddGroupDate 		DATETIME
        ,	INDEX 				IX_Temp_Cust_CustID(CustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Site;
	CREATE TEMPORARY TABLE 		Temp_Site (
			SiteID 		BIGINT UNSIGNED PRIMARY KEY
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_PASite;
	CREATE TEMPORARY TABLE 		Temp_PASite (
			SiteID 		BIGINT UNSIGNED PRIMARY KEY
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustDetected;
	CREATE TEMPORARY TABLE 		Temp_CustDetected (
			CTSCustID 			BIGINT UNSIGNED PRIMARY KEY
		,  	CustID 				BIGINT UNSIGNED 
		,	SiteID				INT	UNSIGNED        
        ,	RoleID				TINYINT
        ,	SubscriberID		INT
        ,	IsLicensee			BIT
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Device;
	CREATE TEMPORARY TABLE 	Temp_Device (
			DCSDeviceID			BIGINT PRIMARY KEY
		,	AddGroupDate 		DATETIME	
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AIGroup;
	CREATE TEMPORARY TABLE 	Temp_AIGroup (
			GroupID				BIGINT UNSIGNED PRIMARY KEY
		,	AddGroupDate 		DATETIME
	);
    
    #=============================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByAI_AssType (
			AssTypeItemValue INT PRIMARY KEY            
	);
	#=============================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByIP_AssType (
			AssTypeItemValue INT PRIMARY KEY            
	);
    
    #===========GET AssociationByIP status is Applied==============================================    
    INSERT INTO Temp_AssociationByIP_AssType(AssTypeItemValue)
    SELECT atd.AssTypeItemValue
    FROM CTS_DataCenter.AssociationTypeSetting AS atd
    WHERE atd.AssTypeID = CONST_ASSTYPE_IP AND atd.AssTypeItemStatus = CONST_ASSBYIP_ACTIVESTATUS; 
    
    #===========GET AssociationByAI status is Applied==============================================    
    INSERT INTO Temp_AssociationByAI_AssType(AssTypeItemValue)
    SELECT atd.AssTypeItemValue
    FROM CTS_DataCenter.AssociationTypeSetting AS atd
    WHERE atd.AssTypeID = CONST_ASSTYPE_BETTINGPATTERN AND atd.AssTypeItemStatus = CONST_ASSBYAI_ACTIVESTATUS; 
    
	SELECT ParameterValue 
    INTO lv_BatchSize 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 97;
    
    SELECT ParameterValue 
    INTO lv_LastGroupID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 98;
    
    SELECT ParameterValue 
    INTO lv_LastCTSCustID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 99;
    
    IF lv_LastGroupID IS NULL OR  lv_LastGroupID = 0 THEN
		SELECT GroupID  
		INTO lv_LastGroupID 
		FROM  CTS_DataCenter.AssociatedGroup
        WHERE IsDisable = 0
		ORDER BY GroupID ASC
        LIMIT 1;
        
        SET lv_LastCTSCustID = 0;
	END  IF;

    INSERT INTO Temp_Cust(CTSCustID, CustID, AddGroupDate)
    SELECT 	acc.CTSCustID
		,	cus.CustID
		,	acc.Created
    FROM CTS_DataCenter.AssociatedGroupAccount AS acc
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON acc.CTSCustID = cus.CTSCustID
    WHERE acc.GroupID = lv_LastGroupID 
		AND acc.CTSCustID > lv_LastCTSCustID
	LIMIT lv_BatchSize;
	
    IF NOT EXISTS (SELECT 1 FROM Temp_Cust) THEN
		SELECT 	GroupID  
			,	ABI
            ,	PACategoryID
		INTO 	op_GroupID
			,	op_ABI
            ,	op_PACategoryID
		FROM  CTS_DataCenter.AssociatedGroup
        WHERE IsDisable = 0
			AND GroupID > lv_LastGroupID
		ORDER BY GroupID ASC
        LIMIT 1;
        
		SET op_LastCTSCustID = 0;
        
        LEAVE sp;
    END IF;
    
    SELECT 	GroupName
		,	ABI  
		,	Danger1
		,	PACategoryID
		,	AllCredit
        ,	AllLicensee
        ,	Sites
        ,	CONCAT(IFNULL(ag.PACreditSites,''),',',IFNULL(ag.PALicenseeSites,'')) AS PASites
        ,	HasDevice
        ,	HasManual
        ,	HasIP
        ,	HasAI
    INTO 	op_GroupName
		,	op_ABI
		,	op_Ori
		,	op_PACategoryID
		,	lv_AllCredit
        ,	lv_AllLicensee
        ,	lv_Sites
        ,	lv_PASites
        ,	lv_HasDevice
        ,	lv_HasManual
        ,	lv_HasIP
        ,	lv_HasAI
	FROM  CTS_DataCenter.AssociatedGroup AS ag
    WHERE GroupID = lv_LastGroupID
	LIMIT 1;
    
    IF lv_Sites IS NOT NULL AND lv_Sites != "" THEN
		SET @sql= CONCAT("INSERT IGNORE INTO Temp_Site (SiteID) VALUES ('", REPLACE(lv_Sites, ',', "'),('"),"');");
		PREPARE 	stmt1 FROM @sql;
		EXECUTE 	stmt1;
	END IF;
    
    IF lv_PASites IS NOT NULL AND lv_PASites != "" THEN
		SET @sql= CONCAT("INSERT IGNORE INTO Temp_PASite (SiteID) VALUES ('", REPLACE(lv_PASites, ',', "'),('"),"');");
		PREPARE 	stmt1 FROM @sql;
		EXECUTE 	stmt1;
	END IF;

    /**************************Device*******************************/
    IF lv_HasDevice = 1 THEN
		INSERT IGNORE INTO Temp_Device(DCSDeviceID,AddGroupDate)
		SELECT 	dv.DCSDeviceID
			,	MIN(tmp.AddGroupDate) AS AddGroupDate
		FROM Temp_Cust AS tmp 
			INNER JOIN CTS_DataCenter.AssociationByDevice AS dv ON  dv.CTSCustID = tmp.CTSCustID
		GROUP BY dv.DCSDeviceID; 
		
		INSERT IGNORE INTO Temp_CustDetected(CTSCustID,CustID,SiteID, RoleID, SubscriberID,IsLicensee)
		SELECT 	cus.CTSCustID
			,	cus.CustID
            ,	cus.SiteID
            ,	cus.RoleID
			,	cus.SubscriberID
            ,	cus.IsLicensee
		FROM  Temp_Device AS dv
			STRAIGHT_JOIN CTS_DataCenter.AssociationByDevice AS lv1 ON dv.DCSDeviceID = lv1.DCSDeviceID
			STRAIGHT_JOIN CTS_Archive.CTSCustomerAssociationStatus AS tkd ON tkd.CTSCustID = lv1.CTSCustID AND tkd.LastTicketDate >= dv.AddGroupDate 
			STRAIGHT_JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = lv1.CTSCustID AND cus.RoleID = CONST_ROLEID_MEMBER
		WHERE NOT EXISTS (SELECT 1 
						  FROM AssociatedGroupAccount AS acc 
							INNER JOIN CTS_DataCenter.AssociatedGroup AS ag ON acc.GroupID =  ag.GroupID AND ag.IsDisable = 0
						  WHERE lv1.CTSCustID = acc.CTSCustID);
    END IF;
    
    /**************************Manual*******************************/
    IF lv_HasManual = 1 THEN
		INSERT IGNORE INTO Temp_CustDetected(CTSCustID,CustID,SiteID, RoleID, SubscriberID,IsLicensee)
		SELECT  cus.CTSCustID
			,	cus.CustID
			,	cus.SiteID
            ,	cus.RoleID
			,	cus.SubscriberID
            ,	cus.IsLicensee
		FROM Temp_Cust AS tmp 
			STRAIGHT_JOIN CTS_DataCenter.AssociationByManual AS ma ON ma.ToCTSCustID = tmp.CTSCustID
			STRAIGHT_JOIN CTS_Archive.CTSCustomerAssociationStatus AS tkd ON tkd.CTSCustID = ma.FromCTSCustID AND tkd.LastTicketDate >= tmp.AddGroupDate 
			STRAIGHT_JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = ma.FromCTSCustID AND cus.RoleID = CONST_ROLEID_MEMBER
		WHERE NOT EXISTS (SELECT 1 
						  FROM AssociatedGroupAccount AS acc 
							INNER JOIN CTS_DataCenter.AssociatedGroup AS ag ON acc.GroupID =  ag.GroupID AND ag.IsDisable = 0
						  WHERE ma.FromCTSCustID = acc.CTSCustID);
		
		INSERT IGNORE INTO Temp_CustDetected(CTSCustID, CustID, SiteID, RoleID, SubscriberID, IsLicensee)
		SELECT  cus.CTSCustID
			,	cus.CustID
            ,	cus.SiteID
            ,	cus.RoleID
			,	cus.SubscriberID
            ,	cus.IsLicensee
		FROM Temp_Cust AS tmp 
			STRAIGHT_JOIN CTS_DataCenter.AssociationByManual AS ma ON ma.FromCTSCustID  = tmp.CTSCustID
			STRAIGHT_JOIN CTS_Archive.CTSCustomerAssociationStatus AS tkd ON tkd.CTSCustID = ma.ToCTSCustID AND tkd.LastTicketDate >= tmp.AddGroupDate
			STRAIGHT_JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = ma.ToCTSCustID AND cus.RoleID = CONST_ROLEID_MEMBER
		WHERE NOT EXISTS (SELECT 1 
						  FROM AssociatedGroupAccount AS acc
							INNER JOIN CTS_DataCenter.AssociatedGroup AS ag ON acc.GroupID =  ag.GroupID AND ag.IsDisable = 0
						  WHERE ma.ToCTSCustID = acc.CTSCustID);
    END IF;

    IF lv_HasAI = 1 THEN

		/**************************AI*******************************/
		INSERT IGNORE INTO Temp_CustDetected(CTSCustID, CustID, SiteID, RoleID, SubscriberID, IsLicensee)
		SELECT  cus.CTSCustID
			,	cus.CustID
            ,	cus.SiteID
            ,	cus.RoleID
			,	cus.SubscriberID
            ,	cus.IsLicensee
		FROM (	SELECT * 
				FROM Temp_Cust AS tmp 
					,	LATERAL (	SELECT DISTINCT ai.ToCustID 
									FROM CTS_DataCenter.AssociationByAI AS ai
										INNER JOIN Temp_AssociationByAI_AssType AS tmpAt ON ai.FromCustID = tmp.CustID AND ai.AssType = tmpAt.AssTypeItemValue) AS ltr
			) AS tmpAi
			STRAIGHT_JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmpAi.ToCustID AND cus.CustSubID = 0 AND cus.RoleID = CONST_ROLEID_MEMBER
			STRAIGHT_JOIN CTS_Archive.CTSCustomerAssociationStatus AS tkd ON tkd.CTSCustID = cus.CTSCustID AND tkd.LastTicketDate >= tmpAi.AddGroupDate 
		WHERE NOT EXISTS (SELECT 1 
						  FROM CTS_DataCenter.AssociatedGroupAccount AS acc
							INNER JOIN CTS_DataCenter.AssociatedGroup AS ag ON acc.GroupID =  ag.GroupID AND ag.IsDisable = 0
						  WHERE cus.CTSCustID = acc.CTSCustID);

		INSERT IGNORE INTO Temp_CustDetected(CTSCustID, CustID, SiteID, RoleID, SubscriberID, IsLicensee)
		SELECT  cus.CTSCustID
			,	cus.CustID
            ,	cus.SiteID
            ,	cus.RoleID
			,	cus.SubscriberID
            ,	cus.IsLicensee
		FROM (	SELECT * 
				FROM Temp_Cust AS tmp
				,	LATERAL (	SELECT DISTINCT ai.FromCustID 
								FROM CTS_DataCenter.AssociationByAI AS ai
									INNER JOIN Temp_AssociationByAI_AssType AS tmpAt ON ai.ToCustID = tmp.CustID AND ai.AssType = tmpAt.AssTypeItemValue) AS ltr
			) AS tmpAi
			STRAIGHT_JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmpAi.FromCustID AND cus.CustSubID = 0 AND cus.RoleID = CONST_ROLEID_MEMBER
			STRAIGHT_JOIN CTS_Archive.CTSCustomerAssociationStatus AS tkd ON tkd.CTSCustID = cus.CTSCustID AND tkd.LastTicketDate >= tmpAi.AddGroupDate 
		WHERE NOT EXISTS (SELECT 1 
						  FROM AssociatedGroupAccount AS acc 
							INNER JOIN CTS_DataCenter.AssociatedGroup AS ag ON acc.GroupID =  ag.GroupID AND ag.IsDisable = 0
                             WHERE cus.CTSCustID = acc.CTSCustID);

		/**************************AI Group*******************************/
		INSERT IGNORE INTO Temp_AIGroup(GroupID,AddGroupDate)
		SELECT asg.GroupID 
			,	MIN(tmp.AddGroupDate) AS AddGroupDate
		FROM Temp_Cust AS tmp 
			INNER JOIN CTS_DataCenter.AssociationGroupByAI AS asg ON  asg.CustID = tmp.CustID
		GROUP BY asg.GroupID; 
		
		INSERT IGNORE INTO Temp_CustDetected(CTSCustID, CustID, SiteID, RoleID, SubscriberID, IsLicensee)
		SELECT 	cus.CTSCustID
			,	cus.CustID
            ,	cus.SiteID
            ,	cus.RoleID
			,	cus.SubscriberID
            ,	cus.IsLicensee
		FROM  Temp_AIGroup AS gp
			STRAIGHT_JOIN CTS_DataCenter.AssociationGroupByAI AS lv1 ON gp.GroupID = lv1.GroupID
			STRAIGHT_JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = lv1.CustID AND cus.CustSubID = 0 AND cus.RoleID = CONST_ROLEID_MEMBER
			STRAIGHT_JOIN CTS_Archive.CTSCustomerAssociationStatus AS tkd ON tkd.CTSCustID = cus.CTSCustID AND tkd.LastTicketDate >= gp.AddGroupDate 
		WHERE NOT EXISTS (SELECT 1 
						  FROM AssociatedGroupAccount AS acc
							INNER JOIN CTS_DataCenter.AssociatedGroup AS ag ON acc.GroupID =  ag.GroupID AND ag.IsDisable = 0
						  WHERE cus.CTSCustID = acc.CTSCustID);
    END IF;
    
    /**************************IP*******************************/
    IF lv_HasIP = 1 THEN
		INSERT IGNORE INTO Temp_CustDetected(CTSCustID, CustID, SiteID, RoleID, SubscriberID, IsLicensee)
		SELECT  cus.CTSCustID
			,	cus.CustID
            ,	cus.SiteID
            ,	cus.RoleID
			,	cus.SubscriberID
            ,	cus.IsLicensee
		FROM (	SELECT * 
				FROM Temp_Cust AS tmp 
					,	LATERAL (	SELECT DISTINCT ip.ToCustID 
									FROM CTS_DataCenter.AssociationByIP AS ip
										INNER JOIN Temp_AssociationByIP_AssType AS tmpAt ON ip.FromCustID = tmp.CustID AND ip.AssType = tmpAt.AssTypeItemValue) AS ltr
			 ) AS tmpIp
			STRAIGHT_JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmpIp.ToCustID AND cus.CustSubID = 0 AND cus.RoleID = CONST_ROLEID_MEMBER
			STRAIGHT_JOIN CTS_Archive.CTSCustomerAssociationStatus AS tkd ON tkd.CTSCustID = cus.CTSCustID AND tkd.LastTicketDate >= tmpIp.AddGroupDate 
		WHERE NOT EXISTS (SELECT 1 
						  FROM AssociatedGroupAccount AS acc 
							INNER JOIN CTS_DataCenter.AssociatedGroup AS ag ON acc.GroupID =  ag.GroupID AND ag.IsDisable = 0
						  WHERE cus.CTSCustID = acc.CTSCustID);
		
		INSERT IGNORE INTO Temp_CustDetected(CTSCustID, CustID, SiteID, RoleID, SubscriberID, IsLicensee)
		SELECT  cus.CTSCustID
			,	cus.CustID
            ,	cus.SiteID
            ,	cus.RoleID
			,	cus.SubscriberID
            ,	cus.IsLicensee
		FROM (	SELECT * 
				FROM Temp_Cust AS tmp 
					,	LATERAL (	SELECT DISTINCT ip.FromCustID 
									FROM CTS_DataCenter.AssociationByIP AS ip
										INNER JOIN Temp_AssociationByIP_AssType AS tmpAt ON ip.ToCustID = tmp.CustID AND ip.AssType = tmpAt.AssTypeItemValue) AS ltr
			 ) AS tmpIp
			STRAIGHT_JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmpIp.FromCustID AND cus.CustSubID = 0 AND cus.RoleID = CONST_ROLEID_MEMBER
			STRAIGHT_JOIN CTS_Archive.CTSCustomerAssociationStatus AS tkd ON tkd.CTSCustID = cus.CTSCustID AND tkd.LastTicketDate >= tmpIp.AddGroupDate 
		WHERE NOT EXISTS (SELECT 1 
						  FROM AssociatedGroupAccount AS acc 
							INNER JOIN CTS_DataCenter.AssociatedGroup AS ag ON acc.GroupID =  ag.GroupID AND ag.IsDisable = 0
						  WHERE cus.CTSCustID = acc.CTSCustID);
	END IF;
    
    SELECT MAX(CTSCustID)
    INTO op_LastCTSCustID
    FROM Temp_Cust;
    
    SET op_GroupID = lv_LastGroupID;

    SELECT 	cus.CTSCustID
		,	cus.CustID
        ,	CASE WHEN paSite.SiteID IS NULL THEN 0 ELSE 1 END AS 'IsSyncPA'
        ,	cus.RoleID
        ,	cus.SubscriberID
        ,	cus.IsLicensee
    FROM Temp_CustDetected AS cus
		LEFT JOIN Temp_PASite AS paSite ON cus.SiteID = paSite.SiteID
	WHERE cus.RoleID = CONST_ROLEID_MEMBER
		AND ((cus.IsLicensee = 0 AND lv_AllCredit = 1) 
			OR (cus.IsLicensee = 1 AND lv_AllLicensee = 1)
			OR EXISTS (SELECT 1 FROM Temp_Site AS site WHERE site.SiteID = cus.SiteID));
    
END$$
DELIMITER ;