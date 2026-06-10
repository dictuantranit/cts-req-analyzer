/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassificationAgency_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_Get`(
	IN ip_CTSCustID 		BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20241001@Casey.Huynh	
		Task :		Get information on customer profile of Agency
		DB:			CTS_DataCenter
		
		Revisions:
			- 20241001@Casey.Huynh: Created [Redmine ID: #185799]
			- 20250725@Winfred.Pham:  Get information Considerable Dange for Agent (Redmine ID: #219679)

		Param's Explanation (filtered by):
        
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_Get(114181);

	 */ 	
	DECLARE CONST_AGENCY_PARENTID_PA               INT;
    DECLARE CONST_AGENCY_PARENTID_VVIP      		INT;

	DECLARE lv_LowestParentIDPriority		SMALLINT;

	SET CONST_AGENCY_PARENTID_PA 				    = CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
    SET CONST_AGENCY_PARENTID_VVIP 					= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');

	DROP TEMPORARY TABLE IF EXISTS Temp_LatestRecordOfCategory;
    CREATE TEMPORARY TABLE Temp_LatestRecordOfCategory(
			CategoryID				INT UNSIGNED
		,   CategoryName   			VARCHAR(200) 
        ,	CategoryGroupID   		INT UNSIGNED
		,	CategoryPriority		SMALLINT UNSIGNED
		,	ParentID				INT UNSIGNED
		,	CustomerClassPriority	SMALLINT UNSIGNED
		,	IsProbation				BIT DEFAULT 0
		,	ColorTypeID				TINYINT UNSIGNED
    );
   
	INSERT INTO Temp_LatestRecordOfCategory(CategoryID, CategoryName,CategoryGroupID, CategoryPriority, ParentID, CustomerClassPriority, IsProbation, ColorTypeID)
	SELECT DISTINCT (CASE 
                        WHEN cc.ParentID = CONST_AGENCY_PARENTID_PA THEN cc.CategoryGroupID
                        ELSE cate.CategoryID 
					END)
				,	cc.CategoryName
                ,	cc.CategoryGroupID
				,	cc.CategoryPriority
				,	cc.ParentID
				,	cc.CustomerClassPriority
				,	cc.IsPAProbation AS IsProbation
				,	cc.ColorTypeID
	FROM	CTS_DataCenter.CTSCustomerClassificationAgency AS cate
		INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON cc.CategoryID = cate.CategoryID
    WHERE	cate.CTSCustID = ip_CTSCustID 
        AND cc.IsActive = 1;

	IF EXISTS(SELECT 1 FROM Temp_LatestRecordOfCategory WHERE ParentID = CONST_AGENCY_PARENTID_VVIP) THEN
		DELETE FROM Temp_LatestRecordOfCategory WHERE ParentID <> CONST_AGENCY_PARENTID_VVIP;
	END IF;	

	IF (SELECT COUNT(DISTINCT ParentID) FROM Temp_LatestRecordOfCategory) > 1 THEN
		SELECT MIN(CustomerClassPriority)
		INTO lv_LowestParentIDPriority
		FROM Temp_LatestRecordOfCategory;

		DELETE tmp
		FROM Temp_LatestRecordOfCategory AS tmp
		WHERE tmp.CustomerClassPriority > lv_LowestParentIDPriority;
    END IF;

	IF EXISTS (SELECT 1 FROM CTS_DataCenter.TaggingExclusion WHERE CTSCustID = ip_CTSCustID) THEN 
		SELECT 1 AS IsExcludedTagAssPA;
	ELSE 
		SELECT 0 AS IsExcludedTagAssPA;
	END IF; 

	SELECT	CategoryID
		,	CategoryName
        ,	CategoryGroupID
		,	CASE WHEN ParentID = CONST_AGENCY_PARENTID_VVIP THEN 1 ELSE 0 END AS IsVVIP
		,	CASE WHEN ParentID = CONST_AGENCY_PARENTID_PA THEN 1 ELSE 0 END AS IsPA
		,	ColorTypeID
	FROM Temp_LatestRecordOfCategory;
    
END$$
DELIMITER ;