/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_Get`(
	IN ip_CTSCustID 		BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200423@Long.Luu	
		Task :		Get CTSCustomer Category
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20200423@Long.Luu [Redmine ID: #132623]: Created 
            - 20200608@Casey.Huynh: Enhance SP
            - 20200701@Casey.Huynh[135324]: Chagne Flow and Store more Info
					+ Remove rule "hide VIP IF has SmartPunter/Highrisk
            - 20200820@Roger.Le [Redmine ID: #139969]: New Column "Next Scan Date" for Customer Category
            - 20200903@Long.Luu [Redmine ID: #137550]: Get for both General & Detailed Categories
            - 20200908@Irena.Vo [Redmine ID: #141020]: Get for VVIP. VVIP -> PA -> Detailed & General. Add VVIP (General)
            - 20201006@Irena.Vo [Redmine ID: #141930]: Rollback logic get IsUsedManually for lastest category & enhance logic get.
            - 20201014-20201023@Irena.Vo [Redmine ID: #141756]: Enhance logic show Evidence Category & Normal Category. Add New General  
			- 20201202@Lex.Khuat: Disable detail categories & clean up wrong syntax [Redmine ID: #145954]
            - 20210114@Irena.Vo: Update logic SP for Get Category List & PIN. Return CategoryID [RedmineID: #145951]
            - 20210226@Jonas.Huynh: Update for Get status for tagging by association with PA [RedmineID: #150454]
			- 20210318@Irena.Vo: Update get CategoryID for color [RedmineID: #150457]
            - 20210525@Irena.Vo: Change col name PinCustomerCategory, TaggingExclusion: CustID -> CTSCustID [RedmineID: #152965] 
			- 20210622@Aries.Nguyen: Update coding convention  [Redmine ID: #157203]
			- 20211115@Irena.Vo: Re-priortize Robot and other PA categories  [Redmine ID: #164344]
			- 20220328@Aries.Nguyen: Add new category/class for PA Probation [Redmine ID: #170468]
			- 20220531@Aries.Nguyen: Renovate process PA [Redmine ID: #172561]
            - 20240318@Casey.Huynh: Classify Danger Score [Redmine ID: #201358]
            - 20240424@Thomas.Nguyen: Classify initial group betting - Add ParentID = 150 [Redmine ID: #200854]
			- 20240628@Thomas.Nguyen: Renovate CC phase 2 - Remove hardcode, PinCustomerCategory and return more IsVVIP, IsPA, IsPotentialPA, ColorTypeID [Redmine ID: #205317]
			- 20240923@Jonas.Huynh:	Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]	
			- 20250915@Thomas.Nguyen: Add LastModifiedDate to Temp_LatestRecordOfCategory [Redmine ID: #237405]
            
		Param's Explanation:
        
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_Get('25');
            
            SELECT T
	 */ 	
	DECLARE CONST_PARENTID_PA               INT;
    DECLARE CONST_PARENTID_POTENTIALPA      INT;
	DECLARE CONST_PARENTID_NORMAL      		INT;
    DECLARE CONST_PARENTID_VVIP      		INT;
	DECLARE CONST_CATEID_VVIP				INT;
	DECLARE CONST_BIZCATEGROUPID_NORMAL		INT;

	DECLARE lv_LowestParentIDPriority		SMALLINT;

	SET CONST_PARENTID_PA 				    = CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
    SET CONST_PARENTID_POTENTIALPA 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_POTENTIALPA');
	SET CONST_PARENTID_NORMAL 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
    SET CONST_PARENTID_VVIP 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_VVIP');
	SET CONST_CATEID_VVIP 					= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_VVIP');
	SET CONST_BIZCATEGROUPID_NORMAL 		= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_NORMAL');
    
	DROP TEMPORARY TABLE IF EXISTS Temp_LatestRecordOfCategory;
    CREATE TEMPORARY TABLE Temp_LatestRecordOfCategory(
			CategoryID					INT UNSIGNED
		,   CategoryName   				VARCHAR(200) 
        ,	CategoryGroupID   			INT UNSIGNED
        ,	BusinessCategoryGroupID 	INT UNSIGNED
		,	CategoryPriority			SMALLINT UNSIGNED
		,	ParentID					INT UNSIGNED
		,	CustomerClassPriority		SMALLINT UNSIGNED
		,	IsProbation					BIT DEFAULT 0
		,	ColorTypeID					TINYINT UNSIGNED
		,	LastModifiedDate			DATETIME
    );
   
	INSERT INTO Temp_LatestRecordOfCategory(CategoryID, CategoryName, CategoryGroupID, BusinessCategoryGroupID, CategoryPriority, ParentID, CustomerClassPriority, IsProbation, ColorTypeID, LastModifiedDate)
	SELECT DISTINCT (CASE 
                        WHEN cc.ParentID = CONST_PARENTID_PA AND cc.BusinessCategoryGroupID <> CONST_BIZCATEGROUPID_NORMAL THEN cc.CategoryGroupID
                        ELSE cate.CategoryID 
					END)
				,	cc.CategoryName
                ,	cc.CategoryGroupID
                ,	cc.BusinessCategoryGroupID
				,	cc.CategoryPriority
				,	cc.ParentID
				,	cc.CustomerClassPriority
				,	cc.IsPAProbation AS IsProbation
				,	cc.ColorTypeID
				,	cate.LastModifiedDate
	FROM	CTS_DataCenter.CTSCustomerClassification AS cate
		INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cate.CategoryID
    WHERE	cate.CTSCustID = ip_CTSCustID 
		AND cc.ParentID IN (CONST_PARENTID_PA, CONST_PARENTID_NORMAL, CONST_PARENTID_POTENTIALPA, CONST_PARENTID_VVIP)
        AND cc.IsActive = 1;

	IF EXISTS(SELECT 1 FROM Temp_LatestRecordOfCategory WHERE ParentID = CONST_PARENTID_VVIP) THEN
		DELETE FROM Temp_LatestRecordOfCategory WHERE ParentID <> CONST_PARENTID_VVIP;
	END IF;	

	IF (SELECT COUNT(DISTINCT ParentID) FROM Temp_LatestRecordOfCategory) > 1 THEN
		SELECT MIN(ParentID)
		INTO lv_LowestParentIDPriority
		FROM Temp_LatestRecordOfCategory;

		DELETE tmp
		FROM Temp_LatestRecordOfCategory AS tmp
		WHERE tmp.ParentID > lv_LowestParentIDPriority;
    END IF;

	IF EXISTS (SELECT 1 FROM CTS_DataCenter.TaggingExclusion WHERE CTSCustID = ip_CTSCustID) THEN 
		SELECT 1 AS IsExcludedTagAssPA;
	ELSE 
		SELECT 0 AS IsExcludedTagAssPA;
	END IF; 

	SELECT	CategoryID
		,	CategoryName
        ,	CategoryGroupID
		,	CASE WHEN CategoryID = CONST_CATEID_VVIP THEN 1 ELSE 0 END AS IsVVIP
		,	CASE WHEN ParentID = CONST_PARENTID_PA AND BusinessCategoryGroupID <> CONST_BIZCATEGROUPID_NORMAL THEN 1 ELSE 0 END AS IsPA
        ,	CASE WHEN ParentID = CONST_PARENTID_PA THEN 1 ELSE 0 END AS IsMultiplePA
		,	ColorTypeID
        ,	CategoryPriority
		,	LastModifiedDate
	FROM Temp_LatestRecordOfCategory;
END$$
DELIMITER ;