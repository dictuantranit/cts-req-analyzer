/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_Get`(
		IN ip_CTSCustID 	BIGINT
)
    SQL SECURITY INVOKER
BEGIN
/*
		Created:	20220908@Casey.Huynh
		Task:		Get Cust Classification Details by sport
		DB:			CTS_DataCenter
		Original:
		Revisions: 
				- 20220908@Casey.Huynh: Created [Redmine ID: #176992]
                - 20240321@Thomas.Nguyen: Add logic for Special CC BySport [Redmine ID: #201360]
				- 20251118@Thomas.Nguyen: Get CustomerClass by priority [Redmine ID: #239995]												

		Param's Explanation (filtered by):
        
        Example:
				CALL CTS_DataCenter.CTS_DC_CustClassification_BySport_Get(@CTSCustID:=572272);
*/ 

	WITH CTE_CustSport AS (
		SELECT DISTINCT cls.CustID, cls.SportID
		FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cls
		WHERE cls.CTSCustID = ip_CTSCustID 
			AND NOT EXISTS (SELECT 1 FROM CTS_DataCenter.SpecialCustomerClass_BySport AS sb WHERE sb.CTSCustID = cls.CTSCustID AND sb.SportID = cls.SportID)
	)
    SELECT	cat.SportID
		,	cat.CategoryName
        ,	cat.CustomerClass
    FROM	CTE_CustSport AS cs
	,	LATERAL (
		SELECT clss.SportID, cate.CategoryName, cate.CustomerClass
		FROM CTS_DataCenter.CTSCustomerClassification_BySport AS clss
			INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = clss.CategoryID AND cate.IsActive = 1
		WHERE clss.CustID = cs.CustID AND clss.SportID = cs.SportID
		ORDER BY cate.CustomerClassPriority ASC, clss.LastModifiedDate DESC
		LIMIT 1
	) AS cat
	UNION ALL
	SELECT	sb.SportID
		,	'-' AS CategoryName
        ,	sb.CustomerClass
	FROM CTS_DataCenter.SpecialCustomerClass_BySport AS sb 
	WHERE sb.CTSCustID = ip_CTSCustID;
    
END$$
DELIMITER ;