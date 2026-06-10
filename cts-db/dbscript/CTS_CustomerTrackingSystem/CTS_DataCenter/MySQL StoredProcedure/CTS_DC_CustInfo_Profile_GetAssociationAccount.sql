/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_Profile_GetAssociationAccount`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_Profile_GetAssociationAccount`(
		IN ip_CTSCustID BIGINT UNSIGNED 
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20211214@Aries.Nguyen	
		Task :		Enrich the information on customer profile
		DB:			CTS_DataCenter
		
		Revisions: Fix get assocition account  incorrect
			- 20211214@Aries.Nguyen: 	Created [Redmine ID: #165105]
			- 20211229@Aries.Nguyen:  	Fix get assocition account  incorrect [Redmine ID: #165105]
			- 20220408@Casey.Huynh: 	Add AssociationGroupByAI [Redmine ID: #171222]
			- 20230112@Victoria.Le: 	Modify SPs due to restructure AssociationByAI [Redmine ID: #181994]
			- 20230313@Casey.Huynh:		Applied Betting Parten OTGB [Redmine ID: #184791]
			- 20230421@Casey.Huynh: 	Add AssType to AssociationByIP [Redmine ID: #185783]
            
		Param's Explanation (filtered by):
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustInfo_Profile_GetAssociationAccount(10832);
	*/
	DECLARE CONST_ASSTYPE_BETTINGPATTERN	INT DEFAULT 2;
	DECLARE CONST_ASSBYAI_ACTIVESTATUS		INT DEFAULT 1;
    DECLARE CONST_ASSTYPE_IP 				INT DEFAULT 4;
	DECLARE CONST_ASSBYIP_ACTIVESTATUS 		INT DEFAULT 1;
	#=================================================
    
    DECLARE lv_CustID 		BIGINT UNSIGNED;
	DECLARE lv_Count_AI 	INT;   
    DECLARE lv_Count_Manual INT;
    DECLARE lv_Count_Device INT;
    DECLARE lv_Count_IP 	INT;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AccountStatusID;
    CREATE TEMPORARY TABLE Temp_AccountStatusID (
			AccountStatusID 	INT UNSIGNED
        , 	PRIMARY KEY (AccountStatusID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_SubscriberSiteID;
    CREATE TEMPORARY TABLE Temp_SubscriberSiteID (
			SubscriberID 	INT UNSIGNED
		, 	SiteID			INT UNSIGNED
        , 	PRIMARY KEY (SubscriberID,SiteID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationRemove;
    CREATE TEMPORARY TABLE 	Temp_AssociationRemove (
			CTSCustID 	BIGINT UNSIGNED
		,	CustID		BIGINT UNSIGNED
        ,	PRIMARY KEY 	Temp_AssociationRemove_CTSCustID(CTSCustID)
        ,	KEY				Temp_AssociationRemove_CustID(CustID)
	); 
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AssGroupByAI;
	CREATE TEMPORARY TABLE Temp_AssGroupByAI (
			GroupID 	BIGINT UNSIGNED
		, 	PRIMARY KEY (GroupID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AssCustByAI;
	CREATE TEMPORARY TABLE Temp_AssCustByAI (
			CustID 	BIGINT UNSIGNED
		, 	PRIMARY KEY (CustID)
	);
    	
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByAI_AssType (
			AssTypeItemValue INT PRIMARY KEY            
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByIP_AssType (
		AssTypeItemValue INT PRIMARY KEY            
	);
	
    #===========GET AssociationByIP status is Applied==============================================   
	INSERT INTO Temp_AssociationByIP_AssType(AssTypeItemValue)
	SELECT atd.AssTypeItemValue
	FROM CTS_DataCenter.AssociationTypeSetting AS atd
	WHERE atd.AssTypeID = CONST_ASSTYPE_IP 
		AND atd.AssTypeItemStatus = CONST_ASSBYIP_ACTIVESTATUS; 
        
    #===========GET AssociationByAI status is Applied==============================================    
    INSERT INTO Temp_AssociationByAI_AssType(AssTypeItemValue)
    SELECT atd.AssTypeItemValue
    FROM CTS_DataCenter.AssociationTypeSetting AS atd
    WHERE atd.AssTypeID = CONST_ASSTYPE_BETTINGPATTERN 
		AND atd.AssTypeItemStatus = CONST_ASSBYAI_ACTIVESTATUS;
    
    #==========================================    
    INSERT IGNORE INTO Temp_AccountStatusID (AccountStatusID)
	SELECT ItemID 
    FROM CTS_DataCenter.StaticList 
    WHERE ListID = 1 AND PriorityOrder IS NOT NULL;
    
    INSERT IGNORE INTO Temp_SubscriberSiteID (SubscriberID,SiteID)
	SELECT	s.SubscriberID, s.SiteID
    FROM CTS_DataCenter.MappingSubscriberSite AS s 
        INNER JOIN CTS_DataCenter.SubscriberGroup AS sg ON s.SubscriberGroupID = sg.SubscriberGroupID
	WHERE sg.IsActive = 1;
    
    SELECT CustID
    INTO lv_CustID
    FROM CTS_DataCenter.CTSCustomer
    WHERE CTSCustID = ip_CTSCustID;
    
    INSERT IGNORE INTO  Temp_AssociationRemove(CTSCustID,CustID)
    SELECT 	rm.ToCTSCustID 
		,	cus.CustID
    FROM  CTS_DataCenter.AssociationRemove AS rm
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = rm.ToCTSCustID
    WHERE rm.FromCTSCustID = ip_CTSCustID;
    
    INSERT IGNORE INTO  Temp_AssociationRemove(CTSCustID,CustID)
    SELECT  rm.FromCTSCustID
		,	cus.CustID
    FROM  CTS_DataCenter.AssociationRemove AS rm
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = rm.FromCTSCustID
    WHERE rm.ToCTSCustID = ip_CTSCustID;
   
    SELECT COUNT(DISTINCT acc.CTSCustID)
    INTO lv_Count_Device
    FROM CTS_DataCenter.AssociationByDevice AS dv
		INNER JOIN CTS_DataCenter.AssociationByDevice AS acc ON  dv.DCSDeviceID  = acc.DCSDeviceID AND dv.CTSCustID  != acc.CTSCustID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CTSCustID  = acc.CTSCustID
    WHERE dv.CTSCustID = ip_CTSCustID
		AND acc.CTSCustID NOT IN (SELECT rm.CTSCustID FROM Temp_AssociationRemove AS rm)
        AND cust.CustStatusID IN (SELECT sta.AccountStatusID FROM Temp_AccountStatusID AS sta)
        AND (cust.SiteID,cust.SubscriberID) IN (SELECT subInfo.SiteID, subInfo.SubscriberID FROM Temp_SubscriberSiteID AS subInfo);
    
    SELECT COUNT(1)
    INTO lv_Count_Manual 
    FROM CTS_DataCenter.AssociationByManual AS ma
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CTSCustID  = ma.ToCTSCustID
    WHERE ma.FromCTSCustID = ip_CTSCustID 
        AND  ma.ToCTSCustID NOT IN (SELECT rm.CTSCustID FROM Temp_AssociationRemove AS rm)
		AND cust.CustStatusID IN (SELECT sta.AccountStatusID FROM Temp_AccountStatusID AS sta)
        AND (cust.SiteID,cust.SubscriberID) IN (SELECT subInfo.SiteID, subInfo.SubscriberID FROM Temp_SubscriberSiteID AS subInfo);
        

    SELECT COUNT(1) + lv_Count_Manual
    INTO lv_Count_Manual 
    FROM CTS_DataCenter.AssociationByManual AS ma
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CTSCustID  = ma.FromCTSCustID
    WHERE ma.ToCTSCustID = ip_CTSCustID
        AND  ma.FromCTSCustID NOT IN (SELECT rm.CTSCustID FROM Temp_AssociationRemove AS rm)
        AND cust.CustStatusID IN (SELECT sta.AccountStatusID FROM Temp_AccountStatusID AS sta)
        AND (cust.SiteID,cust.SubscriberID) IN (SELECT subInfo.SiteID, subInfo.SubscriberID FROM Temp_SubscriberSiteID AS subInfo);
    
    /*==================GET association from AI===============================================*/
    INSERT IGNORE INTO Temp_AssCustByAI(CustID)
    SELECT cust.CustID
    FROM CTS_DataCenter.AssociationByAI AS ai
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID  = ai.ToCustID AND cust.CustSubID = 0
    WHERE ai.FromCustID = lv_CustID
        AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt)
		AND ai.ToCustID NOT IN (SELECT rm.CustID FROM Temp_AssociationRemove AS rm)
        AND cust.CustStatusID IN (SELECT sta.AccountStatusID FROM Temp_AccountStatusID AS sta)
        AND (cust.SiteID,cust.SubscriberID) IN (SELECT subInfo.SiteID, subInfo.SubscriberID FROM Temp_SubscriberSiteID AS subInfo);   
	
    INSERT IGNORE INTO Temp_AssCustByAI(CustID)
    SELECT cust.CustID
    FROM CTS_DataCenter.AssociationByAI AS ai
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID  = ai.FromCustID AND cust.CustSubID = 0
    WHERE ai.ToCustID = lv_CustID
		AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt)
		AND ai.FromCustID NOT IN (SELECT rm.CustID FROM Temp_AssociationRemove AS rm)
        AND cust.CustStatusID IN (SELECT sta.AccountStatusID FROM Temp_AccountStatusID AS sta)
        AND (cust.SiteID,cust.SubscriberID) IN (SELECT subInfo.SiteID, subInfo.SubscriberID FROM Temp_SubscriberSiteID AS subInfo);
    
    #==================GET association from AI: AssociationGroupByAI===============================================
	INSERT IGNORE INTO Temp_AssGroupByAI(GroupID)
	SELECT	asg.GroupID 
	FROM	CTS_DataCenter.AssociationGroupByAI AS asg
	WHERE	asg.CustID = lv_CustID; 
    
	INSERT IGNORE INTO Temp_AssCustByAI(CustID)
    SELECT cust.CustID
    FROM CTS_DataCenter.AssociationGroupByAI AS asg
		INNER JOIN Temp_AssGroupByAI AS tmpAg ON asg.GroupID = tmpAg.GroupID AND asg.CustID <> lv_CustID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID  = asg.CustID AND cust.CustSubID = 0
    WHERE asg.CustID NOT IN (SELECT rm.CustID FROM Temp_AssociationRemove AS rm)
        AND cust.CustStatusID IN (SELECT sta.AccountStatusID FROM Temp_AccountStatusID AS sta)
        AND (cust.SiteID,cust.SubscriberID) IN (SELECT subInfo.SiteID, subInfo.SubscriberID FROM Temp_SubscriberSiteID AS subInfo);
    
    SELECT COUNT(1)
    INTO lv_Count_AI
    FROM Temp_AssCustByAI;  
    
    /*============================================================*/
    SELECT COUNT(DISTINCT ip.ToCustID)
    INTO lv_Count_IP
    FROM CTS_DataCenter.AssociationByIP AS ip
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID  = ip.ToCustID AND cust.CustSubID = 0
    WHERE 	ip.FromCustID = lv_CustID
		AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt)
		AND ip.ToCustID NOT IN (SELECT rm.CustID FROM Temp_AssociationRemove AS rm)
        AND cust.CustStatusID IN (SELECT sta.AccountStatusID FROM Temp_AccountStatusID AS sta)
        AND (cust.SiteID,cust.SubscriberID) IN (SELECT subInfo.SiteID, subInfo.SubscriberID FROM Temp_SubscriberSiteID AS subInfo);
	 
    SELECT COUNT(DISTINCT ip.FromCustID) + lv_Count_IP
    INTO lv_Count_IP
    FROM CTS_DataCenter.AssociationByIP AS ip
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID  = ip.FromCustID AND cust.CustSubID = 0
    WHERE 	ip.ToCustID = lv_CustID
		AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt)
		AND ip.FromCustID NOT IN (SELECT rm.CustID FROM Temp_AssociationRemove AS rm)
        AND cust.CustStatusID IN (SELECT sta.AccountStatusID FROM Temp_AccountStatusID AS sta)
        AND (cust.SiteID,cust.SubscriberID) IN (SELECT subInfo.SiteID, subInfo.SubscriberID FROM Temp_SubscriberSiteID AS subInfo);
	
    
    SELECT 	lv_Count_AI AS AI
		,	lv_Count_Manual AS Manual
        ,	lv_Count_Device AS Device
        ,	lv_Count_IP AS IP;
END$$

DELIMITER ;