/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb,ctsAPI,ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_GetCCAndDangerLevel`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_GetCCAndDangerLevel`(
	IN ip_CustIDs LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20220526@Aries.Nguyen	
		Task :		Renovate PA Process
		DB:			CTS_DataCenter  
		Original: 
		Revisions:
			- 20220526@Aries.Nguyen: Created [RedmineID: #172561]
            - 20220628@Aries.Nguyen: Update robot classification rule [Redmine ID: #174430]
			- 20220705@Long.Luu: Support Licensee VIP & BA Categories [Redmine ID: #174219]            
			- 20220817@Long.Luu: Rearrange CC's IDs [Redmine ID: #175698]
            - 20220930@Aries.Nguyen: Renovate Association Detection [RedmineID: #178311]
            - 20240930@Casey.Huynh: Return Agency CC and Danger with RoleID [Redmine ID: #185799]
			- 20241216@Thomas.Nguyen: Change datatype from TEXT to LONGTEXT for ip_CustIDs [Redmine ID: #214655]
			- 20250702@Logan.Nguyen: 	Set to Ori 17-18-19 [Redmine ID: #229875]

        Param's Explanation:     
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_GetCCAndDangerLevel('1,2,1277,555555');
	*/ 
	
    CALL CTS_DataCenter.CTS_DC_Common_GetCCAndDangerLevel(ip_CustIDs);
		
	SELECT 	CustID
		,	RoleID
		,	CategoryID
		,	CustomerClass
        ,	CustomerClassName  
        ,	DangerLevel
        ,	DangerLevelType 
		,	Danger1
    FROM Temp_CustClassificationInfo;
END$$

DELIMITER ;