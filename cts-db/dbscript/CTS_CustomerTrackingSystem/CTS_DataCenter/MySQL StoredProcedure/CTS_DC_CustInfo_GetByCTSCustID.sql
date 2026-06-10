/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_GetByCTSCustID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_GetByCTSCustID`(
	IN ip_CTSCustID BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
/*
	Created:	20191217@Marcus
	Task :		Get LastLoginTime 
	DB:			CTS_DataCenter
	Original:
	Revisions:
		- 20191217@Marcus: 			Created
		- 20210121@John.Ngo: 		Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
		- 20210423@Casey.Huynh: 	Get cust status and Danger from CTS instead of MainDB [Redmine ID: #152259] 
		- 20220523@Aries.Nguyen: 	Return IsLicensee, IsInternal  [Redmine ID: #152259] 
		- 20220707@Long.Luu: 		Return Licensee VIP & BA info [Redmine ID: 174219]
		- 20221227@Victoria.Le: 	Return SiteName info [Redmine ID: #181993]
		- 20230516@Victoria.Le: 	Return DangerousScore [Redmine ID: #186191]
		- 20230911@Victoria.Le: 	Return SubscriberSourceID [Redmine ID: #193044]

	Param's Explanation (filtered by):
*/
    
	SELECT	cus.CustID
		,	cus.SubscriberID
		,	sub.SubscriberName
		,	CASE WHEN mnsub.SubscriberID IS NOT NULL THEN mnsub.SubscriberSourceID ELSE NULL END AS SubscriberSourceID
        ,	sub.SiteName
		,	cus.CustSubID
		,	cus.LastLoginTime
		,	cus.UserName
        ,	cus.UserName2
		,	cus.CreatedDate
		,	cus.RoleID	
		, 	cus.CustStatusID
		, 	CASE WHEN st.ItemID IS NULL THEN 'N/A' ELSE st.ItemName END AS CustStatusName
		, 	cus.Danger1
		, 	cus.Danger2
		, 	cus.Danger3
		,	cus.IsInternal 
		,	cus.IsLicensee
        ,	cus.IsLicenseeVIP
        ,	cus.IsLicenseeBA
		,	CASE WHEN cds.DangerousScore IS NOT NULL THEN (cds.DangerousScore * 100) ELSE NULL END AS DangerousScore
	FROM	CTS_DataCenter.CTSCustomer AS cus
		INNER JOIN	CTS_DataCenter.MappingSubscriberSite AS sub ON cus.SubscriberID	= sub.SubscriberID AND cus.SiteID = sub.SiteID
		LEFT JOIN 	CTS_Admin.Subscriber AS mnsub ON mnsub.SubscriberID = sub.SubscriberID
		LEFT JOIN	CTS_DataCenter.StaticList AS st ON st.ListID = 1 AND cus.CustStatusID = st.ItemID
		LEFT JOIN	CTS_DataCenter.Customer_DangerousScore AS cds ON cds.CustID = cus.CustID
	WHERE	cus.CTSCustID = ip_CTSCustID;          
	
END$$
DELIMITER ;