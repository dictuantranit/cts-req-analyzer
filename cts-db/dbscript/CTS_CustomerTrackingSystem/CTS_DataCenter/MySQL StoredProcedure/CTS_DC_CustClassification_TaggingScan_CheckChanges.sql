/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb,ctsAPI,ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_TaggingScan_CheckChanges`;

DELIMITER $$
CREATE PROCEDURE `CTS_DC_CustClassification_TaggingScan_CheckChanges`(
		IN ip_TaggingCust JSON
)

    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230817@Jonas.Huynh
        Task :		Check tagging changes 
		DB:			CTS_DataCenter  
		Original: 
		Revisions:
			- 20230817@Jonas.Huynh: Created [RedmineID: #191400]
            - 20240619@Jonas.Huynh: Renovate CC [Redmine ID: #205317] 
            
        Param's Explanation:     
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_TaggingScan_CheckChanges('[{"CustID": "43600692","TaggingID":"1","TaggingType": "1"}]');
	*/ 
    
    DECLARE	CONST_PARENTID_NORMAL 	INT;
    DECLARE	CONST_PARENTID_WRAPPER 	INT;
    
    SET CONST_PARENTID_NORMAL 	= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
    SET CONST_PARENTID_WRAPPER 	= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
    
    DROP TEMPORARY TABLE IF EXISTS Temp_TaggingCust;
    CREATE TEMPORARY TABLE Temp_TaggingCust(
			CustID			BIGINT UNSIGNED PRIMARY KEY,
            TaggingID		SMALLINT,
            TaggingType		SMALLINT
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustCategory;
    CREATE TEMPORARY TABLE Temp_CustCategory(
			CustID				BIGINT UNSIGNED PRIMARY KEY,
            CurrentTaggingID	SMALLINT,
            CurrentTaggingType	SMALLINT
    );
          
	INSERT IGNORE INTO Temp_TaggingCust(CustID,TaggingID,TaggingType)
	SELECT DISTINCT temp.CustID
                ,	IFNULL(temp.TaggingID, -99)
                , 	temp.TaggingType
	 FROM JSON_TABLE(ip_TaggingCust,
		"$[*]" COLUMNS(
				CustID 					BIGINT UNSIGNED		PATH "$.CustID"
            , 	TaggingID				SMALLINT			PATH "$.TaggingID"
            , 	TaggingType				SMALLINT			PATH "$.TaggingType"
		 )) AS 	temp;
    
    INSERT IGNORE INTO Temp_CustCategory(CustID, CurrentTaggingID, CurrentTaggingType)
    SELECT t.CustID
		,	tmplc.TaggingID
        , 	tmplc.TaggingType
    FROM Temp_TaggingCust AS t
		, LATERAL	
			(	SELECT cc.CustID, cc.CategoryID, ca.ParentID, ca.ScanTaggingIntervalInSecond, ca.TaggingID, ca.TaggingType
				FROM CTS_DataCenter.CTSCustomerClassification AS cc 
					INNER JOIN CTS_DataCenter.CustomerCategory AS ca ON ca.CategoryID = cc.CategoryID 
				WHERE t.CustID = cc.CustID 
					AND cc.ParentID <> CONST_PARENTID_WRAPPER
                    AND ca.IsActive = 1
				ORDER BY ca.CategoryPriority ASC, cc.LastModifiedDate DESC
				LIMIT 1
		   ) tmplc 
	WHERE t.CustID = tmplc.CustID
		AND tmplc.ParentID = CONST_PARENTID_NORMAL
        AND tmplc.ScanTaggingIntervalInSecond > 0;
           
	SELECT DISTINCT t.CustID AS CustID
    FROM Temp_TaggingCust AS t
		INNER JOIN Temp_CustCategory AS c ON c.CustID = t.CustID
	WHERE t.TaggingID <> c.CurrentTaggingID 
		OR t.TaggingType <> c.CurrentTaggingType;
    
END$$

DELIMITER ;