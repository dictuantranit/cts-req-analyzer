/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_GetByCustID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_GetByCustID`(
	IN ip_ListCustID LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210526@Long.Luu
		Task :		Get Customer's Site and Danger level
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20210526@Long.Luu: 		Created [Redmine ID: 152883]
			- 	20210720@Long.Luu: 		Change datatype from varchar(8k) to longtext [Redmine ID: 152883]
            -	20211213@Casey.Huynh: 	Enhance MM, return result (remove Danger Level) [Redmine ID: 165606]
            - 	20221118@Aries.Nguyen: 	Support suspicious Irrigation in Match Monitor [Redmine ID: #179499]
			- 	20230118@Victoria.Le: 	Return ParentID & TaggingType to definite whether Customer is Problem Account/Normal Categories links with PA [RedmineID: #181995]
			-	20240628@Thomas.Nguyen: Renovate CC phase 2 - Return IsPA and IsNormalLinkedPA [Redmine ID: #205317]

		Param's Explanation (filtered by):
        		
		Example:
			-	CALL CTS_DC_CustInfo_GetByCustID('1,2,987385,8498955,21007469,1295,916740,2812695');;
	*/
    DECLARE	CONST_PARENTID_PA 					INT;
	DECLARE	CONST_PARENTID_NORMAL 				INT;
	DECLARE	CONST_BIZCATEGROUPID_NORMAL			INT;

	SET CONST_PARENTID_PA 				    	= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_PARENTID_NORMAL 					= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
	SET CONST_BIZCATEGROUPID_NORMAL 			= CTS_DC_CategoryTypeParent_Get ('CONST_BIZCATEGROUPID_NORMAL');
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustID;
    CREATE TEMPORARY TABLE Temp_CustID(
		CustID 	BIGINT UNSIGNED
	);

	SET @sql = CONCAT("INSERT INTO Temp_CustID(CustID) VALUES ('", REPLACE(ip_ListCustID, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    CALL CTS_DataCenter.CTS_DC_Common_GetCCAndDangerLevel(ip_ListCustID);
    
    SELECT	t.CustID
		,	c.CTSCustID
		,	c.UserName
		,	c.SubscriberID
		, 	s.SubscriberName
		, 	c.Site
		,	c.Currency
		,	CASE WHEN s.SubscriberType = 0 THEN 'C' ELSE 'L' END AS SubscriberType
        ,	clss.CustomerClass
		,	CASE WHEN clss.ParentID = CONST_PARENTID_PA AND cat.BusinessCategoryGroupID <> CONST_BIZCATEGROUPID_NORMAL THEN 1 ELSE 0 END AS IsPA
		,	CASE WHEN clss.ParentID = CONST_PARENTID_NORMAL AND clss.TaggingType = 1 THEN 1 ELSE 0 END AS IsNormalLinkedPA
	FROM Temp_CustID AS t 
		INNER JOIN CTS_DataCenter.CTSCustomer AS c ON t.CustID = c.CustID AND CustSubID = 0
		INNER JOIN CTS_Admin.Subscriber AS s ON c.SubscriberID	= s.SubscriberID
        LEFT JOIN Temp_CustClassificationInfo AS clss ON t.CustID = clss.CustID
        LEFT JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = clss.CategoryID AND cat.IsActive = 1;      
END$$

DELIMITER ;