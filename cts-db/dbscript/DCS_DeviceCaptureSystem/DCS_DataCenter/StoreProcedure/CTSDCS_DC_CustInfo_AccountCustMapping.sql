/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTSDCS_DC_CustInfo_AccountCustMapping`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTSDCS_DC_CustInfo_AccountCustMapping`(
        IN ip_CTSCustIDs LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250922@Thomas.Nguyen
		Task:	 	Get Cust DCS MB Account by CTSCustIDs
		Server:  	CTSMain
		DBName:		DCS_DataCenter

		Revisions: 
				- 20250922@Thomas.Nguyen: Created [Redmine ID: #239121]

		Example:
			CALL DCS_DataCenter.CTSDCS_DC_CustInfo_AccountCustMapping('21735,21736');
	*/

    DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
    CREATE TEMPORARY TABLE Temp_Customer(
			CTSCustID			BIGINT UNSIGNED PRIMARY KEY
        ,   UserName		    VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'   
        ,   UserName2			VARCHAR(50) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,   SubscriberID		INT
        ,   SubscriberPrefix	VARCHAR(30)
    );

    DROP TEMPORARY TABLE IF EXISTS Temp_CustDCSMBAccount;
    CREATE TEMPORARY TABLE Temp_CustDCSMBAccount(
			CTSCustID			BIGINT UNSIGNED
        ,	MBAccountID			BIGINT UNSIGNED
        ,	SubscriberID		INT
        ,	LastLoginTime		DATETIME(4)
        ,	PRIMARY KEY (CTSCustID, MBAccountID)
    );
    
    INSERT IGNORE INTO Temp_Customer (CTSCustID, UserName, UserName2, SubscriberID, SubscriberPrefix)
    SELECT	cus.CTSCustID
        ,	cus.UserName
        ,	cus.UserName2
        ,	cus.SubscriberID
        ,	sub.SubscriberPrefix
    FROM JSON_TABLE(REPLACE(JSON_ARRAY(ip_CTSCustIDs), ',', '","'), 
						'$[*]' COLUMNS (CTSCustID BIGINT UNSIGNED PATH '$')
					) AS tmp
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = tmp.CTSCustID
        INNER JOIN CTS_Admin.Subscriber AS sub ON sub.SubscriberID = cus.SubscriberID;

    INSERT INTO Temp_CustDCSMBAccount(CTSCustID, MBAccountID, SubscriberID, LastLoginTime)
    SELECT	tmp.CTSCustID
        ,	acc.ID AS MBAccountID
        ,	tmp.SubscriberID
        ,	acc.LastLoginTime
    FROM Temp_Customer AS tmp
        INNER JOIN DCS_DataCenter.MBAccount AS acc ON acc.SubscriberID = tmp.SubscriberID AND CONCAT(tmp.SubscriberPrefix, acc.LoginName) = tmp.UserName2;
    
    INSERT INTO Temp_CustDCSMBAccount(CTSCustID, MBAccountID, SubscriberID, LastLoginTime)
    SELECT	tmp.CTSCustID
        ,	acc.ID AS MBAccountID
        ,	tmp.SubscriberID
        ,	acc.LastLoginTime
    FROM Temp_Customer AS tmp
        INNER JOIN DCS_DataCenter.MBAccount AS acc ON acc.SubscriberID = tmp.SubscriberID AND acc.LoginName = tmp.UserName;

END$$	
DELIMITER ;
