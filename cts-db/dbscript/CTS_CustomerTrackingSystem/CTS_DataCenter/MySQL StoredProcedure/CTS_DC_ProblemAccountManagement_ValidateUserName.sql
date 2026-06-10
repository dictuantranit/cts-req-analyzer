/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_ProblemAccountManagement_ValidateUserName`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_ProblemAccountManagement_ValidateUserName`(
		IN	ip_UserNames		LONGTEXT
)
SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20220518@Casey.Huynh
		Task:		Get Category Filter for Problem Account Management page
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20220307@Irena.Vo: 		Created [Redmine ID: #159014]
            - 20220518@Casey.Huynh: 	Renovate PA Process [Redmine ID: #172561]
			- 20240703@Victoria.Le: 	Renovate CC phase 2 - Remove Table PinCustomerCategory  [Redmine ID: #205317]
            - 20241016@Casey.Huynh: 	Agency CC, Check VVIP Seperate Member and Agency [Redmine ID: #185799]
			- 20241217@Tony.Nguyen:		Remove Recommend [Redmine ID: #214585]
            
		Param's Explanation (filtered by):
        Example:
			CALL CTS_DC_ProblemAccountManagement_ValidateUserName('338HK,338HK,188HK,SMMH,djjdhdh,078HK,078HKSub01,BODOGACCAUD,BODOGACCUS$88,SA-SD$CashOut'); #--> Return Error
			CALL CTS_DC_ProblemAccountManagement_ValidateUserName('338HK,338HK,188HK,SMMH,078HK');# --> Pass validate username
	*/

	DECLARE CONST_PARENTID_VVIP 		INT;	
    DECLARE CONST_AGENCY_PARENTID_VVIP 	INT;	

	SET CONST_PARENTID_VVIP 		= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_VVIP');
    SET CONST_AGENCY_PARENTID_VVIP	= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');

	DROP TEMPORARY TABLE IF EXISTS Temp_UserName;
	CREATE TEMPORARY TABLE Temp_UserName( 	 			
			UserName				VARCHAR(50)        
        ,	PRIMARY KEY 			PK_Temp_UserName_UserName (UserName)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_DuplicatedUserName;
	CREATE TEMPORARY TABLE Temp_DuplicatedUserName( 	 
			UserName				VARCHAR(50)
        ,	INDEX 					IX_Temp_DuplicatedUserName_UserName (UserName)
	);
	
    DROP TEMPORARY TABLE IF EXISTS Temp_ExistedCustomer;
	CREATE TEMPORARY TABLE Temp_ExistedCustomer(		
			UserName				VARCHAR(50)
        ,	CTSCustID 				BIGINT UNSIGNED
        ,	RoleID					SMALLINT
        ,	CustID					BIGINT UNSIGNED
        ,   CustSubID				SMALLINT
        ,	SiteID					INT
        ,	IsLicensee				BIT /* 0: Credit,  1: Licensee */
        ,	IsInternal				BIT 
        ,	SubscriberID			INT UNSIGNED
		,	ErrorMsg 				VARCHAR(100)
        ,	PRIMARY KEY				PK_Temp_ExistedCustomer_UserName(UserName)
        ,	INDEX					IX_Temp_ExistedCustomer_CTSCustID(CTSCustID)
	);
 
    /*1. Receive UserName List */
    SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_UserName (UserName) VALUES ('", REPLACE(ip_UserNames, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;    

	/*3. Get Existed Customers */
	INSERT IGNORE INTO Temp_ExistedCustomer(CTSCustID, UserName, RoleID, CustID, CustSubID, SiteID, SubscriberID, IsLicensee, ErrorMsg)
    SELECT 	c.CTSCustID
		,	u.UserName
        , 	c.RoleID
        ,	c.CustID
        ,	c.CustSubID
        ,	c.SiteID
        ,	c.SubscriberID
		,	c.IsLicensee
        ,	(CASE WHEN c.UserName IS NULL THEN 'Invalid Username' 
				  WHEN c.CustSubID <> 0 THEN 'Sub Account'
                  WHEN (c.IsLicensee = 1 AND c.RoleID > 1) THEN 'Upline Licensee Account'
                  WHEN (c.IsInternal = 1) THEN 'Internal Account'
                  WHEN (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassification AS cls WHERE cls.CTSCustID = c.CTSCustID AND cls.ParentID = CONST_PARENTID_VVIP) IS NOT NULL 
						OR (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls WHERE cls.CTSCustID = c.CTSCustID AND cls.ParentID = CONST_AGENCY_PARENTID_VVIP) IS NOT NULL
                        THEN 'VVIP'
                  ELSE NULL
			END) AS ErrorMsg
	FROM Temp_UserName AS u
		LEFT JOIN CTS_DataCenter.CTSCustomer AS c ON u.UserName = c.UserName;
   
    IF EXISTS (SELECT 1 FROM Temp_ExistedCustomer WHERE ErrorMsg IS NOT NULL) THEN
		SELECT UserName, ErrorMsg 
        FROM Temp_ExistedCustomer WHERE ErrorMsg IS NOT NULL;
    ELSE                
		SELECT 		ec.CTSCustID
				,	ec.SubscriberID                
                ,	ec.RoleID AS RoleID
                ,	ec.CustID AS CustID
				,	u.UserName AS UserName
                , 	ec.IsLicensee
		FROM Temp_UserName AS u
			INNER JOIN Temp_ExistedCustomer AS ec ON ec.UserName = u.UserName;
    END IF;
END$$
DELIMITER ;