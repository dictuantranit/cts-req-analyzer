/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_UpdateCustomerComplete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_UpdateCustomerComplete`(
		IN ip_LastUpdateTime	DATETIME(3) 
	,	IN ip_LastUpdateCustID	INT 
	,	IN ip_CustomerInfo		JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210208@Casey.Huynh
		Task:		Update CTSCustomer Info Complete [Redmine ID: 149941]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20210208@Casey.Huynh: 	Created [Redmine ID: 149941]
			- 20210622@Aries.Nguyen: 	Update coding convention  [Redmine ID: #157203]
			- 20220519@Aries.Nguyen: 	Init cust info: IsLicensee, IsInternal [Redmine ID: #202204]
			- 20220829@Aries.Nguyen: 	Remove hard-coding of internal account in CTS [Redmine ID: #177042]
			- 20230602@Long.Luu: 		Add new agent as internal account [Redmine ID: #188554]
            - 20231024@Long.Luu: 		Add Agent HITRM & WINRM as internal account [Redmine ID: #195355]
			- 20231207@Long.Luu: 		Add Agent M999RM00 as internal account [Redmine ID: #197915]
			- 20241216@Tony.Nguyen: 	Remove UNSIGNED of SMA Recommend (Redmine ID: #214585)
			- 20250923@Long.Luu: 		Add Agents ORI6RM & ORI20RM  as internal account [Redmine ID: #239117]

		Param's Explanation (filtered by):
		
		Example: 
	*/
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerCustSub;
	CREATE TEMPORARY TABLE Temp_CTSCustomerCustSub(
			CustID			INT UNSIGNED
        ,	CTSCustID		BIGINT UNSIGNED
        ,	SubscriberID	INT
        ,	SiteID			INT
        ,	Site			VARCHAR(20) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	UserName		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	RegisterName	VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		,	IsLicensee		BIT
		,	IsInternal		BIT
    );
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomer;
	CREATE TEMPORARY TABLE Temp_CTSCustomer(
			CustID			INT UNSIGNED
		,	UserName		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		,	UserName2		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	RegisterName	VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	SiteID			INT
        ,	Site			VARCHAR(20) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		,	RoleID			TINYINT		 
		,	SRecommend		INT UNSIGNED
		,	MRecommend		INT
		,	Recommend		INT
        ,	Currency		VARCHAR(50) 	
		,	CurrencyID		INT
        ,	SubscriberID	INT
        ,	UpdateType		TINYINT	/*1: Diff(Site, UserName, UserName2) , 0: Others*/
		,	IsLicensee		BIT
		,	IsInternal		BIT
		,	INDEX IX_Temp_CTSCustomer_CustID(CustID)
	);	
 
	INSERT INTO Temp_CTSCustomer(CustID, UserName, UserName2, SiteID, Site, RoleID, SRecommend, MRecommend, Recommend, Currency, CurrencyID, UpdateType,IsLicensee,IsInternal)
	SELECT	js.CustID
		,	js.UserName
        ,	js.UserName2
        ,	js.SiteID
        ,	js.Site
        ,	js.RoleID        
		,	js.SRecommend		
		,	js.MRecommend
		,	js.Recommend
        ,	js.Currency
		,	js.CurrencyID
		,	js.UpdateType
		,   CASE WHEN mss.SubscriberGroupID = 2 THEN 1 
				 WHEN mss.SubscriberGroupID IS NULL THEN NULL
			ELSE 0 END AS IsLicensee
        ,   CASE WHEN js.UserName Like '%CashOut' OR 
						  stl.ItemID IS NOT NULL OR 						 
                          js.SRecommend IN (41430709) OR 
                          js.MRecommend IN (27899314,11656504,12146012) OR
                          js.Recommend IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800) THEN 1 
				 ELSE 0 END AS IsInternal
	FROM JSON_TABLE(ip_CustomerInfo, 
		"$[*]" COLUMNS(
				CustID			INT UNSIGNED	PATH "$.CustID"    
			,	UserName		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	PATH "$.UserName"
            ,	UserName2		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	PATH "$.UserName2"
            ,	SiteID			INT UNSIGNED	PATH "$.SiteID"
            ,	Site			VARCHAR(20) 	PATH "$.Site"
            ,	RoleID			INT UNSIGNED	PATH "$.RoleID"
            ,	SRecommend		INT UNSIGNED	PATH "$.SRecommend" 
			,	MRecommend		INT 		 	PATH "$.MRecommend" 
			,	Recommend		INT 		 	PATH "$.Recommend"
            ,	Currency		VARCHAR(50) 	PATH "$.Currency" 
			,	CurrencyID		INT		 		PATH "$.CurrencyID"	
            ,	UpdateType		TINYINT			PATH "$.UpdateType"	
		)
	) AS js
		INNER JOIN	CTS_DataCenter.MappingSubscriberSite mss ON js.SiteID = mss.SiteID 
																AND ((mss.RoleMapping = 1 AND js.RoleID = 1)
																	OR (mss.RoleMapping = 2 AND js.RoleID > 1)
																	OR (mss.RoleMapping = 0))
        LEFT JOIN CTS_DataCenter.StaticList AS stl ON stl.ItemID = js.SiteID AND stl.ListID = 11;       	

    IF EXISTS (SELECT 1 FROM Temp_CTSCustomer AS tmpCus WHERE  tmpCus.UpdateType = 1 )
    THEN
		UPDATE 		Temp_CTSCustomer AS tmpCus
			INNER JOIN	CTS_DataCenter.MappingSubscriberSite mss  ON tmpCus.SiteID = mss.SiteID 
																	AND ((mss.RoleMapping = 1 AND tmpCus.RoleID = 1)
																		OR (mss.RoleMapping = 2 AND tmpCus.RoleID > 1)
																		OR (mss.RoleMapping = 0))
		SET 	tmpCus.SubscriberID = mss.SubscriberID
			,	tmpCus.RegisterName = SUBSTRING(tmpCus.UserName2, LOCATE('$',tmpCus.UserName2) + 1)
		WHERE	tmpCus.UpdateType = 1;        
        	
		INSERT INTO Temp_CTSCustomerCustSub(CustID, CTSCustID, SubscriberID, SiteID, Site,  UserName, RegisterName,IsLicensee,IsInternal)
        SELECT	ctsCust.CustID
			,	ctsCust.CTSCustID
			,	tmpCus.SubscriberID
			,	tmpCus.SiteID
			,	tmpCus.Site
			,	ctsCust.UserName
			,	ctsCust.RegisterName
			,	tmpCus.IsLicensee
			,	tmpCus.IsInternal
        FROM		CTS_DataCenter.CTSCustomer AS ctsCust
			INNER JOIN	Temp_CTSCustomer AS tmpCus ON ctsCust.CustID = tmpCus.CustID        
        WHERE	ctsCust.CustSubID > 0
			AND tmpCus.UpdateType = 1
			AND ctsCust.SiteID != tmpCus.SiteID;      
	END IF;     
    
	UPDATE 	IGNORE	CTS_DataCenter.CTSCustomer AS ctsCust
		INNER JOIN 	Temp_CTSCustomer AS tempCust ON ctsCust.CustID = tempCust.CustID
	SET		
			ctsCust.UserName = tempCust.UserName
        ,	ctsCust.UserName2 = tempCust.UserName2
        ,	ctsCust.RegisterName = IFNULL(tempCust.RegisterName,ctsCust.RegisterName)
		,	ctsCust.SubscriberID = IFNULL(tempCust.SubscriberID,ctsCust.SubscriberID)
        ,	ctsCust.SiteID = tempCust.SiteID
        ,	ctsCust.Site = tempCust.Site
        ,	ctsCust.RoleID = tempCust.RoleID
		,	ctsCust.SRecommend = tempCust.SRecommend
		,	ctsCust.MRecommend = tempCust.MRecommend
		, 	ctsCust.Recommend = tempCust.Recommend
        ,	ctsCust.Currency = tempCust.Currency
		,	ctsCust.CurrencyID = tempCust.CurrencyID
		,	ctsCust.IsLicensee = tempCust.IsLicensee
		,	ctsCust.IsInternal =  tempCust.IsInternal
		,	ctsCust.ModifiedTime = CURRENT_TIMESTAMP(4)
	WHERE	ctsCust.CustSubID = 0;    
   
	UPDATE 	IGNORE CTS_DataCenter.CTSCustomer AS ctsCust
		INNER JOIN	Temp_CTSCustomerCustSub AS tmpCus ON ctsCust.CTSCustID = tmpCus.CTSCustID
    SET		ctsCust.SubscriberID = tmpCus.SubscriberID
		,	ctsCust.SiteID = tmpCus.SiteID
		,	ctsCust.Site = tmpCus.Site            
        ,	ctsCust.ModifiedTime = CURRENT_TIMESTAMP(4)
		,	ctsCust.IsLicensee = tmpCus.IsLicensee
		,	ctsCust.IsInternal =  tmpCus.IsInternal
	WHERE	ctsCust.CustSubID > 0;
   
	#========Retry Transform Cust Sub==========================================
	INSERT INTO DCS_DataCenter.AccountTransformStatus(AccountID, IsCTSTransformed)
	SELECT	acc.AccountID
		,	0
	FROM  DCS_DataCenter.Account AS acc
		INNER JOIN	Temp_CTSCustomerCustSub AS tmpCus ON acc.LoginName = tmpCus.RegisterName AND	acc.SubscriberID = tmpCus.SubscriberID
	WHERE acc.IsCTSTransformed = -1; 

	INSERT INTO DCS_DataCenter.AccountTransformStatus(AccountID, IsCTSTransformed)
	SELECT	acc.AccountID
		,	0
	FROM  DCS_DataCenter.Account AS acc
		INNER JOIN	Temp_CTSCustomerCustSub AS tmpCus ON acc.LoginName = tmpCus.UserName AND acc.SubscriberID = tmpCus.SubscriberID
	WHERE acc.IsCTSTransformed = -1; 
	
		
	#========Retry Transform Account By tmpCus.UpdateType = 1==========================================

	INSERT INTO DCS_DataCenter.AccountTransformStatus(AccountID, IsCTSTransformed)
	SELECT	acc.AccountID
		,	0
	FROM  DCS_DataCenter.Account AS acc
		INNER JOIN	Temp_CTSCustomer AS tmpCus ON acc.LoginName = tmpCus.RegisterName AND	acc.SubscriberID = tmpCus.SubscriberID
	WHERE	acc.IsCTSTransformed = -1
		AND tmpCus.UpdateType = 1; 
  
	
	INSERT INTO DCS_DataCenter.AccountTransformStatus(AccountID, IsCTSTransformed)
	SELECT	acc.AccountID
		,	0
	FROM  DCS_DataCenter.Account AS acc
		INNER JOIN	Temp_CTSCustomer AS tmpCus ON acc.LoginName = tmpCus.UserName AND acc.SubscriberID = tmpCus.SubscriberID
	WHERE	acc.IsCTSTransformed = -1
		AND tmpCus.UpdateType = 1; 
	   	
    
    #=========Update System Parameter=====================
    UPDATE	CTS_DataCenter.SystemParameter AS s
	SET		s.ParameterValue = ip_LastUpdateTime
	WHERE	s.ParameterID = 11 AND s.ParameterName = 'CTSCustomer_LastUpdateTimeCustomer';
	
	UPDATE	CTS_DataCenter.SystemParameter AS s
	SET		s.ParameterValue = ip_LastUpdateCustID
	WHERE	s.ParameterID = 12 AND s.ParameterName = 'CTSCustomer_LastUpdateCustIDCustomer';

END$$
DELIMITER ;