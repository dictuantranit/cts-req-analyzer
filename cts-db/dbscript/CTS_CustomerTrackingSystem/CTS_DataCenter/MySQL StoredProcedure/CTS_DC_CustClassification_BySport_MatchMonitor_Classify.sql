/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_MatchMonitor_Classify`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_MatchMonitor_Classify`(
    IN ip_BatchSize			INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20251113@Winfred.pham	
		Task :		Get CTSCustomer Category by sport
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20251113@Winfred.pham : Created [Redmine ID: #239955]
            
		Param's Explanation:
        
		Example:
			CALL CTS_DataCenter.CTS_DC_CustClassification_BySport_MatchMonitor_Classify();

	 */

	DECLARE	CONST_CATEID_SYSTEMDETECTGB				INT;
  	DECLARE	CONST_CATEGROUPID_SYSTEMDETECTGB		INT;
    
	DECLARE lv_MatchID INT;
    DECLARE lv_SportGroup INT;

    SET CONST_CATEID_SYSTEMDETECTGB	 			= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_SYSTEMDETECTGB');    
    SET CONST_CATEGROUPID_SYSTEMDETECTGB 		= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_SYSTEMDETECTGB');

        /*****GET SYSTEM Parameter VALUE****/
   
    SELECT s.ParameterValue
    INTO lv_MatchID
    FROM CTS_DataCenter.SystemParameter AS s
    WHERE s.ParameterID = 199;
   
    IF lv_MatchID = 0 THEN    
		SELECT mm.MatchID
        INTO lv_MatchID
        FROM CTS_DataCenter.MatchMonitor AS mm
        WHERE mm.SportType IN (1) AND mm.ClassifyStatusBySport = 2 AND mm.LeagueGroupID = 42
        ORDER BY mm.KickOffTime ASC
        LIMIT 1;
        
        UPDATE CTS_DataCenter.SystemParameter AS s
        SET s.ParameterValue = lv_MatchID
        WHERE s.ParameterID = 199;        
	END IF;

    SELECT CASE WHEN SportType IN (1) AND mm.LeagueGroupID = 42 THEN 145 ELSE 0 END AS lv_SportGroup
    INTO lv_SportGroup
    FROM CTS_DataCenter.MatchMonitor AS mm
    WHERE mm.SportType IN (1) AND  mm.ClassifyStatusBySport = 2 AND mm.MatchID = lv_MatchID
    ORDER BY mm.KickOffTime ASC
    LIMIT 1;
 
    DROP TEMPORARY TABLE IF EXISTS Temp_MatchMonitorDetailsCust;
    CREATE TEMPORARY TABLE Temp_MatchMonitorDetailsCust(
			CustID			INT UNSIGNED
		,	MMDetailsID		INT
        ,	Reason			TINYINT
		,	MatchID			INT		      
        ,	NoOfCust		INT
        
        ,	INDEX IX_Temp_MatchMonitorDetailsCust(CustID, MMDetailsID)
    );
   
	DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust(
			CustID			INT UNSIGNED
		,	MMDetailsID		INT  
		,	MatchID			INT		      
        ,	CTSCustID		BIGINT UNSIGNED
        ,	RoleID			TINYINT
        ,	SubscriberID	INT UNSIGNED
        ,	IsLicensee		TINYINT(1)
        
        ,	PRIMARY KEY PK_Temp_Cust(CustID, MMDetailsID)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_ExcludePACategoryID;
    CREATE TEMPORARY TABLE Temp_ExcludePACategoryID(
			CategoryID		INT UNSIGNED	       
        ,	PRIMARY KEY PK_Temp_ExcludePA(CategoryID)
    );

	INSERT INTO Temp_ExcludePACategoryID(CategoryID)
    SELECT ccs.CategoryID
    FROM CTS_DataCenter.CustomerCategorySettings AS ccs
    WHERE ccs.ExcludedFromClassifyMM = 1;

    INSERT INTO Temp_MatchMonitorDetailsCust(CustID, MMDetailsID, MatchID, NoOfCust)
    WITH CTE_MatchMonitorDetials AS
    ( 	SELECT	mmd.ID AS MMDetailsID
			,	mmd.HighStakeLicCustList
            ,	mmd.MatchID
		FROM CTS_DataCenter.MatchMonitorDetails AS mmd
        WHERE mmd.MatchID = lv_MatchID
			AND mmd.Reason = 0
			AND mmd.ClassifyStatusBySport = 0
        LIMIT ip_BatchSize
	)
	SELECT	js.CustID
		,	cte.MMDetailsID
        ,	cte.MatchID
        ,	LENGTH(cte.HighStakeLicCustList) - LENGTH(REPLACE(cte.HighStakeLicCustList,',','')) + 1 AS NoOfCust
	FROM CTE_MatchMonitorDetials AS cte
		JOIN JSON_TABLE(REPLACE(JSON_ARRAY(cte.HighStakeLicCustList), ',', '","'), 
						'$[*]' COLUMNS (CustID BIGINT UNSIGNED PATH '$')
						) js;    

    INSERT INTO Temp_Cust(CustID, MMDetailsID, MatchID, CTSCustID, RoleID, SubscriberID, IsLicensee)
    SELECT	tmpMmc.CustID
		,	tmpMmc.MMDetailsID
        ,	tmpMmc.MatchID
        ,	cus.CTSCustID
        ,	cus.RoleID
        ,	cus.SubscriberID
        ,	cus.IsLicensee
    FROM Temp_MatchMonitorDetailsCust AS tmpMmc
		LEFT JOIN CTS_DataCenter.CTSCustomer AS cus ON tmpMmc.CustID = cus.CustID
	WHERE tmpMmc.CustID IS NOT NULL;

    SELECT	DISTINCT tmpCust.CustID
        ,	tmpCust.MatchID
        ,	tmpCust.CTSCustID
        ,	tmpCust.RoleID
        ,	tmpCust.SubscriberID
        ,	tmpCust.IsLicensee
        ,	CONST_CATEID_SYSTEMDETECTGB AS CategoryID # Group Betting
        , 	CONST_CATEGROUPID_SYSTEMDETECTGB AS CategoryGroup # Group Betting
        ,   lv_SportGroup AS SportGroup
	FROM Temp_Cust AS tmpCust
	WHERE NOT EXISTS (	SELECT 1 
						FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cls 
							INNER JOIN Temp_ExcludePACategoryID AS exl ON cls.CategoryID = exl.CategoryID
						WHERE cls.CustID = tmpCust.CustID AND cls.sportID = lv_SportGroup);
        
    SELECT GROUP_CONCAT(DISTINCT MMDetailsID) AS MMDetailsIDList
    FROM Temp_MatchMonitorDetailsCust AS tmp;
    
    SELECT lv_MatchID AS MatchID;
    
END$$
DELIMITER ;