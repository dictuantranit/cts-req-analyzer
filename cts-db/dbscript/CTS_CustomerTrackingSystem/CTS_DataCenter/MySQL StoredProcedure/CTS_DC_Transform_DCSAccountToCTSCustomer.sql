/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Transform_DCSAccountToCTSCustomer`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Transform_DCSAccountToCTSCustomer`(
		IN ip_AccountList JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20191112@Terry
		Task:		Transform Data
		DB:			CTS_DataCenter
		Original:

		Revisions:
        	- 20191217@CaseyHuynh: Implement LastLoginTime [RedmineID: #125530]
            - 20190319@CaseyHuynh: Update Join LoginName = UserName
            - 20200506@CaseyHuynh: Remove code "add new CTSCustomer" for Not Deposit Account [RedmineID: #133486]
            - 20200526@CaseyHuynh: Update LastLoginTime [RedmineID: #133263]
            - 20201112@CaseyHuynh: GET Lastest Code Move Server P3, update Permission and Add Meta data. Enhance  Transform Retry [RedmineID: #145271]
			- 20201127@CaseyHuynh: Move statement update IsCTSTransformed to the End[RedmineID: #145277]
			- 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]
			- 20210622@Aries.Nguyen: Update coding convention and improve locking [Redmine ID: #157203]

		Param's Explanation (filtered by):                
	*/
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Account;
	CREATE TEMPORARY TABLE Temp_Account(	
			AccountID				BIGINT	UNSIGNED
        ,	LoginName				VARCHAR(100)   	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'    
        ,	SubscriberID			INT
		,	SubscriberType			INT
        ,	LastLoginTime			TIMESTAMP(4)
		,	LoginNameWithPrefix		VARCHAR(100)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        ,	CTSCustID				BIGINT UNSIGNED
		,	PRIMARY KEY			PK_TempAccount_AccountID(AccountID)
		,	UNIQUE KEY			UK_TempAccount_SubscriberIDLoginName(SubscriberID, LoginName)    
    );       

	DROP TEMPORARY TABLE IF EXISTS Temp_CustInfoByUserName2;
	CREATE TEMPORARY TABLE Temp_CustInfoByUserName2(	
			CTSCustID		BIGINT	UNSIGNED
        ,	UserName2		VARCHAR(100)   	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'    
		,	INDEX			UK_Temp_CustInfoByUsername2_UserName2(UserName2)    
    );   

	DROP TEMPORARY TABLE IF EXISTS Temp_CustInfoByUserName;
	CREATE TEMPORARY TABLE Temp_CustInfoByUserName(	
			CTSCustID		BIGINT	UNSIGNED
        ,	UserName		VARCHAR(100)   	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'   
		,	SubscriberID    INT
		,	INDEX			UK_Temp_CustInfoByUserName_UserName(UserName)    
    );
    
	INSERT INTO Temp_Account(AccountID, LoginName, SubscriberID, SubscriberType, LastLoginTime, LoginNameWithPrefix)
	SELECT 	tmpTable.AccountID 
		,	tmpTable.LoginName 
		,	tmpTable.SubscriberID
		,	sub.SubscriberType
		,	tmpTable.LastLoginTime
		,	CONCAT(sub.SubscriberPrefix, tmpTable.LoginName) AS LoginNameWithPrefix
	FROM JSON_TABLE(ip_AccountList,
		 "$[*]" COLUMNS(
				AccountID 					BIGINT 			PATH "$.AccountId"
            ,	LoginName					VARCHAR(100)	PATH "$.LoginName" 
			,	SubscriberID				INT				PATH "$.SubscriberId"
            ,	LastLoginTime				TIMESTAMP(4)	PATH "$.LastLoginTime"
		 )
	) AS tmpTable  
		INNER JOIN 	CTS_Admin.Subscriber AS sub ON tmpTable.SubscriberID = sub.SubscriberID;
    
	 #=============GET CTSCustomerInfo=========================================
	INSERT INTO Temp_CustInfoByUserName2(UserName2,CTSCustID)
	SELECT	acc.LoginNameWithPrefix
		,	cus.CTSCustID
	FROM Temp_Account AS acc
		INNER JOIN	CTS_DataCenter.CTSCustomer AS cus ON acc.LoginNameWithPrefix = cus.UserName2;

    UPDATE Temp_Account AS acc
		INNER JOIN	Temp_CustInfoByUserName2 AS cus ON acc.LoginNameWithPrefix = cus.UserName2
	SET acc.CTSCustID = cus.CTSCustID;

	INSERT INTO Temp_CustInfoByUserName(CTSCustID, UserName, SubscriberID)
	SELECT cus.CTSCustID
		,  cus.Username	
		,  cus.SubscriberID
	FROM Temp_Account AS acc
		INNER JOIN	CTS_DataCenter.CTSCustomer AS cus ON acc.LoginName = cus.Username AND acc.SubscriberID = cus.SubscriberID
	WHERE acc.CTSCustID IS NULL;

	UPDATE Temp_Account AS acc
		INNER JOIN Temp_CustInfoByUserName AS cus ON acc.LoginName = cus.Username AND acc.SubscriberID = cus.SubscriberID
	SET acc.CTSCustID = cus.CTSCustID;        
   
    INSERT IGNORE INTO CTS_DataCenter.CustDCSAccount(CTSCustID, AccountID, SubscriberID, InsertTime)
	SELECT  acc.CTSCustID
			, acc.AccountID
			, acc.SubscriberID 
            , CURRENT_TIMESTAMP(4) AS InsertTime
    FROM 	Temp_Account AS acc
	WHERE 	acc.CTSCustID IS NOT NULL;     
    
    UPDATE DCS_DataCenter.Association AS ass
		INNER JOIN	Temp_Account AS acc ON ass.AccountID = acc.AccountID
	SET ass.IsCTSTransformed = 0
	WHERE acc.CTSCustID IS NOT NULL;    
	
    UPDATE CTS_DataCenter.CTSCustomer AS cus
		INNER JOIN 	Temp_Account AS acc ON cus.CTSCustID = acc.CTSCustID
    SET cus.LastLoginTime = acc.LastLoginTime
    WHERE cus.LastLoginTime < acc.LastLoginTime
		OR cus.LastLoginTime IS NULL;    
    
    UPDATE DCS_DataCenter.Account acc
		INNER JOIN	Temp_Account AS tac ON acc.AccountID = tac.AccountID			
	SET acc.IsCTSTransformed = (CASE WHEN 	tac.CTSCustID IS NOT NULL THEN 1 ELSE -1 END);	

END$$

DELIMITER ;