/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb,ctsAPI,ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_BySport_GetCC`;

DELIMITER $$
CREATE PROCEDURE `CTS_DC_CustClassification_BySport_GetCC`(
	IN ip_Custs JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20220909@Harvey.Nguyen	
		Task :		Get lastest Classification
		DB:			CTS_DataCenter  
		Original: 
		Revisions:
			- 20220909@Harvey.Nguyen: Created [RedmineID: #176992]
            - 20230725@Jonas.Huynh: Renovate BySport [Redmine ID: #189875]
            - 20240319@Thomas.Nguyen: Add logic for Special CC BySport [Redmine ID: #201360]
			- 20240628@Thomas.Nguyen: Renovate CC phase 2 [Redmine ID: #205317]
            - 20251118@Thomas.Nguyen: Get CustomerClass by priority [Redmine ID: #239995]

        Param's Explanation:     
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_BySport_GetCC('[{"CustID": "1", "SportGroup":43}]');
	*/ 
	DECLARE CONST_PARENTID_WRAPPER 							INT;
	DECLARE CONST_CATEID_SPECIALCC 							INT;

	SET CONST_PARENTID_WRAPPER								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
	SET CONST_CATEID_SPECIALCC								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_SPECIALCC');

    DROP TEMPORARY TABLE IF EXISTS Temp_CustInfo;
    CREATE TEMPORARY TABLE 		Temp_CustInfo (
        	CustID		BIGINT UNSIGNED
		,	SportGroup	SMALLINT UNSIGNED	
        ,	PRIMARY KEY (CustID, SportGroup)
    );    

    INSERT IGNORE INTO Temp_CustInfo (CustID, SportGroup)
    SELECT DISTINCT tmp.CustID
                , 	tmp.SportGroup
	 FROM JSON_TABLE(ip_Custs,
		"$[*]" COLUMNS(
				CustID 				BIGINT UNSIGNED		PATH "$.CustID"	
            , 	SportGroup			SMALLINT UNSIGNED	PATH "$.SportGroup"		
		 )) AS 	tmp;              
  
  	-- Get CustomerClass by priority
	SELECT	tmp.CustID
		,	tmp.SportGroup AS SportID
		,	COALESCE(sb.CustomerClass, clss.CustomerClass, -1) AS CustomerClass
	FROM Temp_CustInfo AS tmp
		LEFT JOIN CTS_DataCenter.SpecialCustomerClass_BySport AS sb ON sb.CustID = tmp.CustID AND sb.SportID = tmp.SportGroup
		LEFT JOIN LATERAL (
			SELECT cate.CustomerClass
			FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cls
				INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = cls.CategoryID AND cate.IsActive = 1
			WHERE cls.CustID = tmp.CustID AND cls.SportID = tmp.SportGroup AND cls.ParentID <> CONST_PARENTID_WRAPPER AND cls.CategoryID <> CONST_CATEID_SPECIALCC
			ORDER BY cate.CustomerClassPriority ASC, cls.LastModifiedDate DESC
			LIMIT 1
		) AS clss ON TRUE;

END$$

DELIMITER ;