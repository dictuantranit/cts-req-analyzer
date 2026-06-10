/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_Account_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_Account_Get`(
		IN 	ip_GroupID 			BIGINT UNSIGNED
	,	OUT op_AllCredit		SMALLINT
	,	OUT op_AllLicensee		SMALLINT
    ,	OUT op_Sites			LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/* 
		Created:	20220705@Aries.Nguyen
		Task:		[CTS] Fraud Group Management [Redmine ID: #167748]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20220705@Aries.Nguyen: Created [Redmine ID: #167748]
            - 20220831@Aries.Nguyen: Associated Group Enhancement [Redmine ID: #176991]
        
		Param's Explanation (filtered by):
        
        Example: 
			- CALL CTS_DC_AssociatedGroup_Account_Get(1,@op_AllCredit,@op_AllLicensee,@op_Sites);
	*/
    SELECT 	AllCredit
		,	AllLicensee
        ,	Sites
	INTO
			op_AllCredit
		,	op_AllLicensee
		,	op_Sites
    FROM CTS_DataCenter.AssociatedGroup
    WHERE GroupID = ip_GroupID;
    
    SELECT 	cus.Username
		,  	sta.ItemName AS AccountStatus
        ,  	cus.CreatedDate AS  AccountCreated
        ,	cus.Site
        ,	cus.Currency
        ,	cus.Danger1 AS Ori
        ,   cus.Danger2 AS ABI
		,	(SELECT GROUP_CONCAT(DISTINCT CategoryName  SEPARATOR ', ') 
			 FROM CTS_DataCenter.CTSCustomerClassification AS clss
				 INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON clss.CategoryID = cate.CategoryID
			 WHERE clss.CTSCustID = acc.CTSCustID)  AS Category
		,   acc.Remark
		,	us.UserName AS DetectedBy
        ,	acc.Created AS DetectedDate
    FROM CTS_DataCenter.AssociatedGroupAccount AS acc
		STRAIGHT_JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = acc.CTSCustID
        STRAIGHT_JOIN CTS_DataCenter.StaticList AS sta ON sta.ListID = 1 AND sta.ItemID = cus.CustStatusID
        STRAIGHT_JOIN CTS_Admin.CTSUser AS us ON acc.CreatedBy = us.UserID
    WHERE acc.GroupID = ip_GroupID;
END$$
DELIMITER ;