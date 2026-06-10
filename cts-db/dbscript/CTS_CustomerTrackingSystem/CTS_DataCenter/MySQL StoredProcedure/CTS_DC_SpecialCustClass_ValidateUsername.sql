/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
USE CTS_DataCenter;
DROP PROCEDURE IF EXISTS `CTS_DC_SpecialCustClass_ValidateUsername`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_SpecialCustClass_ValidateUsername`(
		IN ip_ActionType	TINYINT
	,	IN ip_ListUser 		JSON	
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20240314@Thomas.Nguyen
		Task:		Validate a list of usernames for adding/removing special CC[Redmine ID: #201360]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20240314@Thomas.Nguyen: 		Created [Redmine ID: #201360]
			- 20240618@Victoria.Le: 		Initial Writing [Redmine ID: #205317]
		
		Param's Explanation (filtered by):   
            - ip_ActionType: 0: Add, 2: Remove
		Example:			
			- CALL CTS_DataCenter.CTS_DC_SpecialCustClass_ValidateUsername(0,'[{"Username":"member11","SportID":1}]');
	*/
    
	DECLARE CONST_CATEID_VVIP				INT;
	SET CONST_CATEID_VVIP 					= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_VVIP');

    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust(
			Username 	    VARCHAR(50)
		,	CTSCustID	    BIGINT UNSIGNED
		,	CustID		    BIGINT UNSIGNED
		,	SportID		    SMALLINT UNSIGNED
		,	SubscriberID	INT
		,	IsLicenseeVIP	TINYINT
		,	IsExistedCust   BIT
		,	ValidatedID	    TINYINT /* 0: not existed in CTS, 1: valid, 2: not a member, 3: marked VVIP, 4: marked Special CC*/
		,	PRIMARY KEY (Username,SportID)
		,	KEY IX_Temp_Cust_CTSCustID_SportID (CTSCustID, SportID)
		,	KEY IX_Temp_Cust_IsExistedCust_ValidatedID_SportID (IsExistedCust, ValidatedID, SportID)
	);
    
	INSERT IGNORE INTO Temp_Cust(Username,CTSCustID,CustID,SportID,SubscriberID,IsLicenseeVIP,IsExistedCust,ValidatedID)
	SELECT	tmp.Username
		,	cus.CTSCustID
		,	cus.CustID
		,	tmp.SportID
		,	cus.SubscriberID
		,	cus.IsLicenseeVIP
		,	CASE WHEN cus.CTSCustID IS NOT NULL THEN 1 ELSE 0 END AS IsExistedCust
		,	CASE	WHEN cus.CTSCustID IS NULL THEN 0
					WHEN cus.RoleID <> 1 THEN 2 ELSE 1 END AS ValidatedID
	FROM JSON_TABLE(ip_ListUser, 
						'$[*]' COLUMNS (Username	VARCHAR(50)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'	PATH '$.Username'
									,	SportID		SMALLINT UNSIGNED   PATH '$.SportID' 
								)) AS tmp
		LEFT JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.UserName = tmp.UserName;

	UPDATE Temp_Cust AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.UserName2 = tmp.UserName
	SET		tmp.CTSCustID = cus.CTSCustID
		,	tmp.CustID = cus.CustID
		,	tmp.SubscriberID = cus.SubscriberID
		,	tmp.IsLicenseeVIP = cus.IsLicenseeVIP
		,	tmp.IsExistedCust = 1
		,	tmp.ValidatedID = CASE WHEN cus.RoleID <> 1 THEN 2 ELSE 1 END
	WHERE tmp.IsExistedCust = 0;

	UPDATE Temp_Cust AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS class ON class.CTSCustID = tmp.CTSCustID 
	SET tmp.ValidatedID	= 3
	WHERE tmp.IsExistedCust = 1 AND tmp.ValidatedID = 1 AND tmp.SportID = 0 AND class.CategoryID = CONST_CATEID_VVIP;
	
	UPDATE Temp_Cust AS tmp
		INNER JOIN CTS_DataCenter.SpecialCustomerClass AS scc ON scc.CTSCustID = tmp.CTSCustID
	SET tmp.ValidatedID = 4
	WHERE tmp.IsExistedCust = 1 AND tmp.ValidatedID = 1 AND tmp.SportID = 0 AND scc.CreatedFromFunction = 1;

	UPDATE Temp_Cust AS tmp
		INNER JOIN CTS_DataCenter.SpecialCustomerClass_BySport AS sbs ON sbs.CTSCustID = tmp.CTSCustID AND sbs.SportID = tmp.SportID
	SET tmp.ValidatedID = 4
	WHERE tmp.IsExistedCust = 1 AND tmp.ValidatedID = 1 AND tmp.SportID <> 0;

	SELECT	tmp.Username
		,	tmp.CTSCustID
		,	tmp.CustID
		,	tmp.SportID
		,	tmp.SubscriberID
		,	tmp.IsLicenseeVIP
		,	tmp.ValidatedID
		,	CASE WHEN tmp.IsExistedCust = 1 AND ((ip_ActionType = 0 AND tmp.ValidatedID = 1) OR (ip_ActionType = 2 AND tmp.ValidatedID = 4)) THEN 1 ELSE 0 END IsValid
	FROM Temp_Cust AS tmp;

END$$
DELIMITER ;