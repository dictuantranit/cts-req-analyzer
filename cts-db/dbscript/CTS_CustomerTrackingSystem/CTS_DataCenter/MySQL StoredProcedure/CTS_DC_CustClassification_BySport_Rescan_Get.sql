/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb,ctsService,ctsAPI" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_CustClassification_BySport_Rescan_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_Rescan_Get`(
		IN ip_CustInfoList	LONGTEXT
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20251113@Winfred.pham
		Task :		Renovate PA Process by sport
		DB:			CTS_DataCenter 
		Original: 
		Revisions:  
			- 20251113@Winfred.pham: Created [Redmine ID: #239955]

        Param's Explanation:

		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_BySport_Rescan_Get('[{"CustID":1, "SportID": 145}]');
	*/ 
    DECLARE	CONST_PARENTID_PA								INT;
    DECLARE CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL			INT;
	DECLARE	CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY		INT;
      
	DECLARE CONST_CREATEDBY_STARIXITID				INT DEFAULT 10278938;
    
    SET CONST_PARENTID_PA 								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL');
	SET CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY		= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY');

    DROP TEMPORARY TABLE IF EXISTS Temp_CustSport;
    CREATE TEMPORARY TABLE Temp_CustSport(
			CustID		BIGINT UNSIGNED
        ,	SportID 	SMALLINT UNSIGNED
        ,	PRIMARY KEY (CustID, SportID)
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustInfo;    
	CREATE TEMPORARY TABLE Temp_CustInfo (	  
			CTSCustID		BIGINT UNSIGNED  
        ,   CustID			BIGINT UNSIGNED 
        ,	SportID 	    SMALLINT UNSIGNED
        , 	SubscriberID	INT 
        ,	IsLicensee		BIT 
		,	PRIMARY KEY(CustID, SportID)
     ); 
         
    DROP TEMPORARY TABLE IF EXISTS Temp_CustCategory;    
	CREATE TEMPORARY TABLE Temp_CustCategory (	  
			CTSCustID				BIGINT UNSIGNED
        ,   CustID					BIGINT UNSIGNED
        ,	SportID 	            SMALLINT UNSIGNED 
        ,	CategoryID              INT  
		, 	SubscriberID			INT UNSIGNED
        ,	IsLicensee				BIT
		,	Remark				    VARCHAR(500)
        ,   CreatedBy               INT UNSIGNED
        ,   CreatedDate        		DATETIME(3)
        ,   LastModifiedDate        DATETIME(3)
		,	InputFlowID	 			INT
		,	PRIMARY KEY(CustID, SportID, CategoryID)
	);  

    INSERT IGNORE INTO Temp_CustSport(CustID, SportID)
	SELECT	infoList.CustID
		, 	infoList.SportID
	FROM JSON_TABLE(ip_CustInfoList,
		 "$[*]" COLUMNS(
				CustID	    BIGINT UNSIGNED	PATH "$.CustID" 
			, 	SportID		BIGINT UNSIGNED	PATH "$.SportID" )
	) AS infoList;
     
    INSERT  INTO Temp_CustInfo(CTSCustID,CustID,SubscriberID,IsLicensee, SportID)
    SELECT 	cus.CTSCustID
		,	cus.CustID	 
		, 	cus.SubscriberID	 
        ,	cus.IsLicensee	
        ,    tmp.SportID
    FROM Temp_CustSport AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmp.CustID 
			AND cus.CustSubID = 0 
			AND cus.IsInternal = 0;
    /***********************Check PA from main table ****************************/   
    INSERT IGNORE INTO Temp_CustCategory(CTSCustID, CustID, SportID, CategoryID, SubscriberID, IsLicensee, Remark, CreatedBy,  CreatedDate, LastModifiedDate, InputFlowID)
    SELECT tmp.CTSCustID					        AS CTSCustID
		,	tmp.CustID						        AS CustID
        ,   tmp.SportID					            AS SportID
        ,	CASE WHEN cate.IsPAProbation THEN cate.RelevantCategoryID ELSE s.CategoryID END AS CategoryID
        ,	tmp.SubscriberID				        AS SubscriberID
		,	tmp.IsLicensee					        AS IsLicensee
        ,	s.Remark						        AS Remark
        ,	NULL		 					        AS CreatedBy
        ,	s.CreatedDate 					        AS CreatedDate
        ,	s.LastModifiedDate 				        AS LastModifiedDate
        ,   CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY	AS InputFlowID
    FROM Temp_CustInfo AS tmp    
		STRAIGHT_JOIN CTS_DataCenter.CTSCustomerClassification_BySport AS s USE INDEX (PRIMARY) ON s.CustID = tmp.CustID AND s.ParentID = CONST_PARENTID_PA AND s.sportID = tmp.SportID
		INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = s.CategoryID
	ON DUPLICATE KEY UPDATE  Remark = CASE WHEN  s.LastModifiedDate < Temp_CustCategory.LastModifiedDate THEN s.Remark ELSE Temp_CustCategory.Remark END
						,	LastModifiedDate = CASE WHEN s.LastModifiedDate < Temp_CustCategory.LastModifiedDate THEN s.LastModifiedDate ELSE Temp_CustCategory.LastModifiedDate END
                        ,	CreatedDate = CASE WHEN s.CreatedDate < Temp_CustCategory.CreatedDate THEN s.CreatedDate ELSE Temp_CustCategory.CreatedDate END; 
	/***********************Return****************************/ 
	SELECT cust.CTSCustID
		,	cust.CustID
		, 	cc.CategoryID
        ,	cat.CategoryName
		, 	cc.SubscriberID
		, 	cc.IsLicensee
		, 	cc.Remark
		, 	CASE WHEN cc.CreatedBy IS NULL THEN CONST_CREATEDBY_STARIXITID ELSE cc.CreatedBy END AS CreatedBy
        ,	cc.CreatedDate
		, 	cc.LastModifiedDate
		, 	CASE WHEN cc.CategoryID IS NULL THEN CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL ELSE cc.InputFlowID END AS InputFlowID
        ,   cust.SportID
	FROM Temp_CustInfo AS cust
		LEFT JOIN Temp_CustCategory AS cc ON cc.CustID = cust.CustID
        LEFT JOIN CTS_DataCenter.CustomerCategory AS cat ON cc.CategoryID = cat.CategoryID
	;
    
END$$

DELIMITER ;


