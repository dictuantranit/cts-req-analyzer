/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_Insert`(
		IN ip_CustomerList JSON
    ,	IN ip_IsNewCustomer BOOLEAN
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20191107@Harvey
		Task:		Insert Customer [Redmine ID: 116528]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20200704@Harvey: Handle updating/mapping customer on username for deposit
            - 20200603@Harvey: add column RegisterName for search nick name
            - 20200618@Harvey: use CustId as a key when update data (do not have new deposit in our db from now)
            - 20200625@Long.Luu: insert more customer info [Redmine ID: #136046]
            - 20201118@Aries.Nguyen: Add columns InsertedTime, ModifiedTime [RedmineID : #145271]
            - 20200111@Casey.Huynh: Remove SubscriberID from Json, Move Update Customer Info to other SP
			- 20200118@CaseyHuynh: Enhance CTSCustomer Flow - [Redmine: #148849]
            - 202101295@Casey.Huynh: Add Ignore to Update statement [Redmine ID: 149639]
            - 20210506@Casey.Huynh: Remove Error Message Log [Redmine ID: 154633]
			- 20210622@Aries.Nguyen: Update coding convention and improve locking [Redmine ID: #157203]
			- 20210804@Irena.Vo: Fix issue No rescan for existed Customer [Redmine ID: #159706]
            - 20220110@Casey.Huynh: HF Missing CustSub [Redmine ID: #167242]
            - 20220418@Casey.Huynh: Add and Remove VVIP for Downline [Redmine ID: #159013]
            - 20220511@Casey.Huynh: Missing ArchiveCust  [Redmine ID: #172615]
            - 20220512@Casey.Huynh: HF Return more info in VVIP List [Redmine ID: #172712]
            - 20220519@Aries.Nguyen: Init cust info: IsLicensee, IsInternal [Redmine ID: #202204]
			- 20220520@Aries.Nguyen: Separating insert new customer and classification [Redmine ID: #172561]
			- 20220616@Aries.Nguyen: CTS - Problem Account Renovation Issues [Redmine ID: #174136]
			- 20220829@Aries.Nguyen: Remove hard-coding of internal account in CTS [Redmine ID: #177042]
            - 20220923@Aries.Nguyen: CTS - Missing Customer Info on CTS Pro [Redmine ID: #176768]
            - 20220930@Aries.Nguyen: Renovate Association Detection [RedmineID: #178311]
            - 20221202@Victoria.Le:	 Add columns DangerSabaSc (Saba Soccer) and DangerSabaBkb (Saba Baseketball) [Redmine ID: #181208]
			- 20230602@Long.Luu:	Add new agent as internal account [Redmine ID: #188554]
            - 20230926@Casey.Huynh: Create New Category before Insert New Customer [Redmine ID: #193049]
            - 20231024@Long.Luu: Add Agent HITRM & WINRM as internal account [Redmine ID: #195355]
			- 20231024@Jonas.Huynh: HF wrong reactivated category [Redmine ID: #193050]
			- 20231207@Long.Luu: 	Add Agent M999RM00 as internal account [Redmine ID: #197915]
			- 20240703@Victoria.Le	Renovate CC Phase2 [Redmine ID: #205317]
            - 202409266@Casey.Huynh: Return Agent [Redmine ID: #185799]
			- 20241216@Tony.Nguyen:	Remove UNSIGNED of SMA Recommend (Redmine ID: #214585)
			- 20250725@Winfred.Pham: Get Agent for Member Credit add Queue Considerable (Redmine ID: #219679)
			- 20250923@Long.Luu: 	Add Agents ORI6RM & ORI20RM  as internal account [Redmine ID: #239117]
            
		Param's Explanation (filtered by):
		Example:
			 CALL CTS_DataCenter.CTS_DC_CustInfo_Insert('[
				 {"BatchId":1,"CustID":10040738,"CustStatusID":1,"UserName":"HAIFARMB01151207","UserName2":"haifa$20297251","Site":"haifa","SiteID":44,"RoleID":1,"CurrencyID":13,"Currency":"RMB","SRecommend":4359240,"MRecommend":4359287,"Recommend":4359308,"CreatedDate":"2013-01-27 05:56:00.000","Danger1":0,"Danger2":0,"Danger3":0,"CustSubID":0}
				,{"BatchId":1,"CustID":15124347,"CustStatusID":1,"UserName":"HAIFARMB01554620","UserName2":"haifa$40834748","Site":"haifa","SiteID":44,"RoleID":1,"CurrencyID":13,"Currency":"RMB","SRecommend":4359240,"MRecommend":4359287,"Recommend":4359308,"CreatedDate":"2014-06-19 09:12:00.000","Danger1":0,"Danger2":0,"Danger3":0,"CustSubID":0}
				,{"BatchId":1,"CustID":18349232,"CustStatusID":1,"UserName":"HAIFARMB01897790","UserName2":"haifa$83884255","Site":"haifa","SiteID":44,"RoleID":1,"CurrencyID":13,"Currency":"RMB","SRecommend":4359240,"MRecommend":4359287,"Recommend":4359308,"CreatedDate":"2015-06-28 07:22:00.000","Danger1":0,"Danger2":0,"Danger3":0,"CustSubID":0}]', true);
	
    */
    DECLARE CONST_ROLEID_MEMBER					TINYINT DEFAULT 1;
    DECLARE CONST_ROLEID_AGENT            		TINYINT DEFAULT 2;
    DECLARE CONST_ROLEID_MASTER            		TINYINT DEFAULT 3;
    DECLARE CONST_ROLEID_SUPER            		TINYINT DEFAULT 4;
	DECLARE lv_AgentCreditList 					LONGTEXT DEFAULT NULL;

	DECLARE lv_LastArchiveID 	BIGINT UNSIGNED;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomer;    
	CREATE TEMPORARY TABLE Temp_CTSCustomer( 	  
			SubscriberID 	INT 			
		,	CustID			INT	 UNSIGNED NOT NULL
        ,	CustStatusID	TINYINT
        ,	Danger1			TINYINT
        ,	Danger2			TINYINT
        ,	Danger3			TINYINT
        ,	Danger4			TINYINT
        ,	Danger5			TINYINT
		,	DangerSabaSc	TINYINT
		,	DangerSabaBkb	TINYINT
		,	CustSubID		INT UNSIGNED			
		,	UserName		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		,	UserName2		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	RegisterName	VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		,	SiteID			INT
        ,	Site			VARCHAR(20) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
		,	RoleID			TINYINT		 
		,	Currency		VARCHAR(50) 	
		,	CurrencyID		INT			 	
		,	SRecommend		INT	UNSIGNED
		,	MRecommend		INT
		,	Recommend		INT
        ,	CreatedDate		DATETIME
        ,	DuplicateType 	TINYINT DEFAULT 0#1-Dup(CustID and CustSubID), 2-Dup UserName(not dup CustID and CustSubID)
        ,	OldCTSCustID	BIGINT UNSIGNED
        ,	IsLicensee		BIT
		,	IsInternal		BIT
        ,	PRIMARY KEY PK_Temp_CTSCustomer(CustID, CustSubID)
        ,	INDEX IX_Temp_CTSCustomer_SiteIDRoleID(SiteID, RoleID)
        ,	INDEX IX_Temp_CTSCustomer_DuplicateType(DuplicateType)
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustExist;    
	CREATE TEMPORARY TABLE Temp_CustExist(
			CustID			INT UNSIGNED
		,	CustSubID		INT UNSIGNED
        
        ,	PRIMARY KEY PK_Temp_CustExist(CustID,CustSubID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustArchive;    
	CREATE TEMPORARY TABLE Temp_CustArchive(
			CTSCustID		BIGINT UNSIGNED 
        , 	AccountID	    BIGINT UNSIGNED
        , 	PRIMARY KEY(CTSCustID, AccountID)
	);
	
    DROP TEMPORARY TABLE IF EXISTS Temp_DupUserName;    
	CREATE TEMPORARY TABLE Temp_DupUserName(
			UserName		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	CustID			INT UNSIGNED
		,	CustSubID		INT UNSIGNED
        ,	OldCTSCustID	BIGINT UNSIGNED
        ,	OldCustID		BIGINT UNSIGNED
        ,	PRIMARY KEY PK_Temp_DupUserName(UserName)
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustInfo;    
	CREATE TEMPORARY TABLE Temp_CustInfo(
			CustID			INT UNSIGNED
		,	CustSubID		INT UNSIGNED
		,	SubscriberID 	INT UNSIGNED
		,	RegisterName	VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	PRIMARY KEY PK_Temp_CustInfo(CustID,CustSubID)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Result;    
	CREATE TEMPORARY TABLE Temp_Result(
			CTSCustID		BIGINT UNSIGNED NOT NULL
		,	SubscriberID	INT UNSIGNED
    	,	CustID			INT UNSIGNED NOT NULL
		,	UserName		VARCHAR(50)
    	,	RegisterName	VARCHAR(50)
		,	RoleID			TINYINT
    	,	CustSubID		INT UNSIGNED NOT NULL
        ,	PRIMARY KEY		PK_Temp_Result(CTSCustID)
		,	INDEX			IX_Temp_Result_CustID(CustID,CustSubID)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustNewCategory;
    CREATE TEMPORARY TABLE Temp_CustNewCategory(
			CustID			INT PRIMARY KEY
        ,	IsInternal		BOOLEAN
        ,	SiteID			INT
	);

    INSERT INTO Temp_CTSCustomer(CustID, CustStatusID, Danger1, Danger2, Danger3, Danger4, Danger5, DangerSabaSc, DangerSabaBkb, CustSubID, UserName, UserName2, SiteID, Site, RoleID, Currency, CurrencyID, SRecommend, MRecommend, Recommend, CreatedDate,IsLicensee,IsInternal)
	SELECT		js.CustID	
			,	js.CustStatusID
			,	js.Danger1
			,	js.Danger2
			,	js.Danger3	
            ,	js.Danger4
			,	js.Danger5	
			,	js.DangerSabaSc
			,	js.DangerSabaBkb
			,	js.CustSubID		
			,	js.UserName		
			,	(CASE WHEN js.UserName2 = 'null' THEN NULL ELSE js.UserName2 END) AS UserName2
			,	js.SiteID
			,	(CASE WHEN js.Site = 'null' THEN NULL ELSE js.Site END) AS Site
			,	js.RoleID		
			,	js.Currency		
			,	js.CurrencyID	
			,	js.SRecommend	
			,	js.MRecommend	
			,	js.Recommend	
			,	js.CreatedDate
            ,	js.IsLicensee
            ,   CASE WHEN js.UserName Like '%CashOut' OR 
						  stl.ItemID IS NOT NULL OR 						 
                          js.SRecommend IN (41430709) OR 
                          js.MRecommend IN (27899314,11656504,12146012) OR
                          js.Recommend IN (52466,5707545,29270764,134456,27787409,48367475,93558369,16604398,260963471,260963800)  THEN 1 
				ELSE 0 END AS IsInternal
	FROM JSON_TABLE(ip_CustomerList,
		 "$[*]" COLUMNS(
				CustID			INT	UNSIGNED	PATH "$.CustID" 
			,	CustStatusID	TINYINT			PATH "$.CustStatusID" 
			,	Danger1			TINYINT		 	PATH "$.Danger1" 
			,	Danger2			TINYINT		 	PATH "$.Danger2" 
			,	Danger3			TINYINT		 	PATH "$.Danger3" 
            ,	Danger4			TINYINT		 	PATH "$.Danger4" 
			,	Danger5			TINYINT		 	PATH "$.Danger5" 
			,	DangerSabaSc	TINYINT		 	PATH "$.DangerSabaSc" 
			,	DangerSabaBkb	TINYINT		 	PATH "$.DangerSabaBkb" 
			,	CustSubID		INT	UNSIGNED	PATH "$.CustSubID" 
			,	UserName		VARCHAR(50)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	PATH "$.UserName"
			,	UserName2		VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	PATH "$.UserName2" 
			,	SiteID			INT 			PATH "$.SiteID" 
			,	Site			VARCHAR(20)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' 	PATH "$.Site" 
			,	RoleID			TINYINT		 	PATH "$.RoleID" 
			,	Currency		VARCHAR(50) 	PATH "$.Currency" 
			,	CurrencyID		INT			 	PATH "$.CurrencyID" 
			,	SRecommend		INT UNSIGNED	PATH "$.SRecommend" 
			,	MRecommend		INT	 		 	PATH "$.MRecommend" 
			,	Recommend		INT	 		 	PATH "$.Recommend" 
			,	CreatedDate		DATETIME	 	PATH "$.CreatedDate" 
            ,	IsLicensee		BOOLEAN 		PATH "$.IsLicensee" 
			)
	) AS js
		LEFT JOIN CTS_DataCenter.StaticList AS stl ON stl.ItemID = js.SiteID AND stl.ListID = 11;	   

	INSERT INTO Temp_CustExist(CustID, CustSubID)
	SELECT	tmpCus.CustID
		,	tmpCus.CustSubID        
	FROM Temp_CTSCustomer AS tmpCus
		INNER JOIN	CTS_DataCenter.CTSCustomer AS cus ON tmpCus.CustID = cus.CustID AND tmpCus.CustSubID = cus.CustSubID;
  
	INSERT INTO Temp_DupUserName(UserName, CustID, CustSubID, OldCTSCustID, OldCustID)
	SELECT  tmpCus.UserName		
		,	tmpCus.CustID
        ,	tmpCus.CustSubID
        ,	cus.CTSCustID
        ,	cus.CustID
	FROM Temp_CTSCustomer AS tmpCus
		LEFT JOIN Temp_CustExist AS tmpEx ON tmpCus.CustID = tmpEx.CustID AND tmpCus.CustSubID = tmpEx.CustSubID
		INNER JOIN	CTS_DataCenter.CTSCustomer AS cus ON tmpCus.UserName = cus.UserName
	WHERE tmpEx.CustID IS NULL;

    UPDATE Temp_CTSCustomer AS tmpCus
		INNER JOIN Temp_CustExist AS tmpEx ON tmpCus.CustID = tmpEx.CustID AND tmpCus.CustSubID = tmpEx.CustSubID
    SET tmpCus.DuplicateType = 1;

    UPDATE Temp_CTSCustomer AS tmpCus
		INNER JOIN Temp_DupUserName AS tmpDun ON tmpCus.UserName = tmpDun.UserName
    SET tmpCus.DuplicateType = 2
		, tmpCus.OldCTSCustID = tmpDun.OldCTSCustID;
     
	INSERT IGNORE INTO CTS_DataCenter.CTSCustomerDuplicate(SubscriberID, CustID, CustSubID, UserName, UserName2, SiteID, Site, RoleID, Currency, CurrencyID
			, SRecommend, MRecommend, Recommend, CreatedDate , RegisterName , CustStatusID , Danger1 ,Danger2 , Danger3 , InsertedTime , ModifiedTime, DuplicateType, OldCTSCustID)
	SELECT    tmpCus.SubscriberID
			, tmpCus.CustID
            , tmpCus.CustSubID
            , tmpCus.UserName
            , tmpCus.UserName2
            , tmpCus.SiteID
            , tmpCus.Site
            , tmpCus.RoleID
            , tmpCus.Currency
            , tmpCus.CurrencyID
            , tmpCus.SRecommend
            , tmpCus.MRecommend
            , tmpCus.Recommend
            , tmpCus.CreatedDate
            , tmpCus.RegisterName
            , tmpCus.CustStatusID
            , tmpCus.Danger1
            , tmpCus.Danger2
            , tmpCus.Danger3
            , CURRENT_TIMESTAMP(4) AS InsertedTime
            , CURRENT_TIMESTAMP(4) AS ModifiedTime
            , tmpCus.DuplicateType
            , tmpCus.OldCTSCustID
    FROM Temp_CTSCustomer AS tmpCus
    WHERE tmpCus.DuplicateType = 2;
    
    SELECT ParameterValue
	INTO lv_LastArchiveID
	FROM CTS_DataCenter.SystemParameter
	WHERE ParameterID = 45;
    
    INSERT IGNORE INTO Temp_CustArchive(CTSCustID, AccountID)
    SELECT 	arc.CTSCustID
		,	IFNULL(arc.AccountID,0) AS AccountID
    FROM Temp_DupUserName AS cus
		INNER JOIN CTS_DataCenter.ArchiveCustomer_CTSCustomer AS arc ON arc.CustID = cus.OldCustID AND arc.ID > lv_LastArchiveID;
    
    DELETE 
    FROM CTS_DataCenter.CTSCustomer AS cus
    WHERE EXISTS (SELECT 1 FROM Temp_CustArchive AS arc WHERE arc.CTSCustID =  cus.CTSCustID);
    
    DELETE 
    FROM DCS_DataCenter.Account AS acc
    WHERE EXISTS (SELECT 1 FROM Temp_CustArchive AS arc WHERE arc.AccountID =  acc.AccountID);
    
    UPDATE Temp_CTSCustomer AS cus
    SET cus.DuplicateType = 0
    WHERE EXISTS  (SELECT 1 FROM Temp_CustArchive AS arc WHERE arc.CTSCustID =  cus.OldCTSCustID)
		AND cus.DuplicateType = 2;

    # Remove Duplicate UserName 
    DELETE tmpCus
    FROM Temp_CTSCustomer AS tmpCus
    WHERE tmpCus.DuplicateType = 2; 
    
	INSERT IGNORE INTO Temp_CustInfo(CustID, CustSubID, SubscriberID, RegisterName)
	SELECT  tmpCus.CustID
		, 	tmpCus.CustSubID
		,	mss.SubscriberID
		,	SUBSTRING(tmpCus.UserName2, LOCATE('$',tmpCus.UserName2) + 1)
	FROM Temp_CTSCustomer AS tmpCus
		INNER JOIN	CTS_DataCenter.MappingSubscriberSite mss ON tmpCus.SiteID = mss.SiteID 
																AND ((mss.RoleMapping = 1 AND tmpCus.RoleID = 1)
																	OR (mss.RoleMapping = 2 AND tmpCus.RoleID > 1)
																	OR (mss.RoleMapping = 0));     
        
	UPDATE Temp_CTSCustomer AS tmpCus
    INNER JOIN Temp_CustInfo AS cus ON tmpCus.CustID = cus.CustID AND tmpCus.CustSubID = cus.CustSubID
	SET   tmpCus.SubscriberID = cus.SubscriberID
		, tmpCus.RegisterName = cus.RegisterName;      
	
    #====CREATE CATEGORY FOR NEW OR REACTIVATED MEMBER=====================================
    INSERT INTO Temp_CustNewCategory(CustID, IsInternal, SiteID)
    SELECT	tmpCus.CustID
		,	tmpCus.IsInternal
        ,	tmpCus.SiteID
    FROM Temp_CTSCustomer AS tmpCus
    WHERE tmpCus.RoleID = CONST_ROLEID_MEMBER
        AND tmpCus.CustSubID = 0;    

	CALL CTS_DataCenter.CTS_DC_CustClassification_InsertNormalAccount_NewCategory('Temp_CustNewCategory', ip_IsNewCustomer);

    #====CREATE CATEGORY FOR NEW OR REACTIVATED AGENT=====================================
	TRUNCATE TABLE Temp_CustNewCategory;
    INSERT INTO Temp_CustNewCategory(CustID, IsInternal, SiteID)
    SELECT	tmpCus.CustID
		,	tmpCus.IsInternal
        ,	tmpCus.SiteID
    FROM Temp_CTSCustomer AS tmpCus
    WHERE tmpCus.RoleID = CONST_ROLEID_AGENT AND tmpCus.IsLicensee = 0
        AND tmpCus.CustSubID = 0;    

	CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_Insert_NewCategory('Temp_CustNewCategory', ip_IsNewCustomer);    

    #=====INSERT NEW CUSTOMER===================================================================
	INSERT IGNORE INTO CTS_DataCenter.CTSCustomer(SubscriberID, CustID, CustSubID, UserName, UserName2, SiteID, Site, RoleID, Currency, CurrencyID
			, SRecommend, MRecommend, Recommend, CreatedDate , RegisterName , CustStatusID , Danger1 ,Danger2 , Danger3 , Danger4 , Danger5, DangerSabaSc, DangerSabaBkb , InsertedTime , ModifiedTime, IsLicensee, IsInternal)
	SELECT    tmpCus.SubscriberID
			, tmpCus.CustID
            , tmpCus.CustSubID
            , tmpCus.UserName
            , tmpCus.UserName2
            , tmpCus.SiteID
            , tmpCus.Site
            , tmpCus.RoleID
            , tmpCus.Currency
            , tmpCus.CurrencyID
            , tmpCus.SRecommend
            , tmpCus.MRecommend
            , tmpCus.Recommend
            , tmpCus.CreatedDate
            , tmpCus.RegisterName
            , tmpCus.CustStatusID
            , tmpCus.Danger1
            , tmpCus.Danger2
            , tmpCus.Danger3
            , tmpCus.Danger4
            , tmpCus.Danger5
			, tmpCus.DangerSabaSc
			, tmpCus.DangerSabaBkb
            , CURRENT_TIMESTAMP(4) AS InsertedTime
            , CURRENT_TIMESTAMP(4) AS ModifiedTime
            , IsLicensee
            , IsInternal
    FROM	Temp_CTSCustomer AS tmpCus
    WHERE	tmpCus.DuplicateType = 0;

	INSERT INTO Temp_Result(CTSCustID,SubscriberID,CustID,UserName,RegisterName,RoleID,CustSubID)
	SELECT	cus.CTSCustID
		,	cus.SubscriberID
    	,	cus.CustID
		,	cus.UserName
    	,	cus.RegisterName
		,	cus.RoleID
    	,	cus.CustSubID
    FROM	Temp_CTSCustomer AS tmpCus
		INNER JOIN 	CTS_DataCenter.CTSCustomer AS cus ON tmpCus.CustID = cus.CustID AND tmpCus.CustSubID = cus.CustSubID; 

	#=====INSERT Agent Credit for CustomerConsiderableDangerQueue====================

	SELECT  GROUP_CONCAT(DISTINCT tmpCus.Recommend) AS CustJson 
	INTO lv_AgentCreditList	
	FROM Temp_CTSCustomer AS tmpCus
	WHERE	tmpCus.DuplicateType = 0 AND tmpCus.IsLicensee = 0; 

	IF lv_AgentCreditList IS NOT NULL THEN        
		CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_CDQueue_Insert(1, lv_AgentCreditList);
    END IF;   

	#=====UPDATE CTSCustomerClassification====================
    UPDATE CTS_DataCenter.CTSCustomerClassification AS cc
    INNER JOIN Temp_Result AS tmpCus ON tmpCus.CustSubID = 0 AND tmpCus.CustID= cc.CustID
    SET		cc.CTSCustID = tmpCus.CTSCustID
		,	cc.SubscriberID = tmpCus.SubscriberID
		,	cc.RoleID = tmpCus.RoleID;
            
	#=====UPDATE CTSCustomerClassification_History====================
    UPDATE CTS_DataCenter.CTSCustomerClassification_History AS ch
    INNER JOIN Temp_Result AS tmpCus ON tmpCus.CustSubID = 0 AND tmpCus.CustID= ch.CustID
    SET		ch.CTSCustID = tmpCus.CTSCustID;

    /* ===> NOT Insert CTSCustID To LOG due to suport trace data team(victoria) 
    #=====UPDATE CTSCustomerClassification_History_Log====================
    UPDATE CTS_DataCenter.CTSCustomerClassification_History_Log AS cl
		INNER JOIN Temp_Result AS tmpCus ON tmpCus.CustSubID = 0 AND tmpCus.CustID= cl.CustID
    SET	cl.CTSCustID = tmpCus.CTSCustID;
    */
    
	#=====UPDATE CTSCustomerClassification====================
    UPDATE CTS_DataCenter.CTSCustomerClassificationAgency AS cc
    INNER JOIN Temp_Result AS tmpCus ON tmpCus.CustSubID = 0 AND tmpCus.CustID= cc.CustID
    SET		cc.CTSCustID = tmpCus.CTSCustID
		,	cc.SubscriberID = tmpCus.SubscriberID
		,	cc.RoleID = tmpCus.RoleID;
            
	#=====UPDATE CTSCustomerClassification_History====================
    UPDATE CTS_DataCenter.CTSCustomerClassificationAgency_History AS ch
    INNER JOIN Temp_Result AS tmpCus ON tmpCus.CustSubID = 0 AND tmpCus.CustID= ch.CustID
    SET		ch.CTSCustID = tmpCus.CTSCustID	
		,	ch.RoleID = tmpCus.RoleID; 
    
    /* ===> NOT Insert CTSCustID To LOG due to suport trace data team(victoria) 
    #=====UPDATE CTSCustomerClassification_History_Log====================
    UPDATE CTS_DataCenter.CTSCustomerClassification_History_Log AS cl
		INNER JOIN Temp_Result AS tmpCus ON tmpCus.CustSubID = 0 AND tmpCus.CustID= cl.CustID
    SET	cl.CTSCustID = tmpCus.CTSCustID;
    */

	SELECT	CTSCustID
		,	SubscriberID
    	,	CustID
		,	UserName
    	,	RegisterName
		,	RoleID
    	,	CustSubID 
	FROM Temp_Result;
  
END$$
DELIMITER ;