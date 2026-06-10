/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsAPI" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_Category_Get4CustomerClass`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Category_Get4CustomerClass`()
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20201216@Long.Luu	
		Task :		Get CTSCustomer Categories which have Customer Class
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20201216@Long.Luu [Redmine ID: #132623]: Created 
            - 20230403@Jonas.Huynh [Redmine ID: #186271]: Support LAP  (ClassName) 
            - 20230517@Jonas.Huynh [Redmine ID: #188388]: Support TW BI (SabaRiskLevel) 
			- 20231219@Long.Luu: Support more languages for CustomerClass [Redmine ID: #198364]
            - 20240628@Thomas.Nguyen: Renovate CC phase 2 [Redmine ID: #205317]

		Param's Explanation:
	*/ 
    
	SELECT DISTINCT c.CategoryName
				, 	c.CategoryNameCN
				, 	c.CustomerClass
                , 	c.CustomerClassName		
                , 	c.CustomerClassNameCN
                , 	c.CategoryNameCN3
                , 	c.CategoryNameTHB
                , 	c.CategoryNameIND
                , 	c.Ext_SabaIntelligentRiskLevel		AS SabaRiskLevel
                ,	c.Ext_SabaIntelligentRiskLevelTCN	AS SabaRiskLevelTCN
                ,	c.Ext_SabaIntelligentRiskLevelSCN	AS SabaRiskLevelSCN
                ,	c.Ext_SabaIntelligentRiskLevelCN3	AS SabaRiskLevelCN3
                ,	c.Ext_SabaIntelligentRiskLevelTHB	AS SabaRiskLevelTHB
                ,	c.Ext_SabaIntelligentRiskLevelIND	AS SabaRiskLevelIND
	FROM CTS_DataCenter.CustomerCategory AS c
	WHERE c.IsActive = 1
		AND c.CategoryNameCN IS NOT NULL 
        AND c.CategoryNameCN <> "" 
        AND CustomerClass IS NOT NULL
	ORDER BY c.CustomerClass ASC;
    
END$$

DELIMITER ;