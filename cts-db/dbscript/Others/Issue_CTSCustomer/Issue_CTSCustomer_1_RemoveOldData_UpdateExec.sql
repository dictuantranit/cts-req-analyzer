/*
Creator: 20191106@CaseyHuynh 
Task:	 	Correct data CTS_customer Missing vs CustDCSAccount
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		
Reviewer:
*/
#Backup Data
CREATE TABLE IF NOT EXISTS CTS_Adhoc.zzzIssueCustMissing_AssociationByDevice_bk(
		CTSAssDevID		BIGINT	UNSIGNED AUTO_INCREMENT
		, CTSCustID		BIGINT	UNSIGNED
		, DCSDeviceID	BIGINT
		, SubscriberID	INT
		, CreatedTime	TIMESTAMP(4)
		, InsertTime	TIMESTAMP(4)
		, PRIMARY KEY	PK_AssociationByDevice_CTSAssDevID(CTSAssDevID)
        , UNIQUE KEY	IX_AssociationByDevice_CTSCustID_DCSDeviceID(CTSCustID, DCSDeviceID)
        , INDEX			IX_AssociationByDevice_SubscriberID_DeviceID(SubscriberID, DCSDeviceID)
	) ENGINE=INNODB AUTO_INCREMENT=1;
    
CREATE TABLE IF NOT EXISTS CTS_Adhoc.zzzIssueCustMissing_CustDCSAccount_bk(
		CTSCustID			BIGINT	UNSIGNED
		, AccountID			BIGINT	UNSIGNED
		, SubscriberID		INT
		, InsertTime		TIMESTAMP(4)
		, PRIMARY KEY		PK_CustDCSAccount_AccountID(AccountID)  
        
		, INDEX	IX_CustDCSAccount_SubscriberID_CTSCustID(SubscriberID,CTSCustID)
	) ENGINE=INNODB  AUTO_INCREMENT=1;
    
#1.1 Backup
Insert into CTS_Adhoc.zzzIssueCustMissing_CustDCSAccount_bk
SELECT		acc.*
FROM		CTS_DataCenter.CustDCSAccount AS acc
INNER JOIN	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
			ON acc.AccountID = ms.AccountID
WHERE		ms.LoginName IS NULL; #3997

SELECT COUNT(DISTINCT	acc.AccountID)
FROM		CTS_DataCenter.CustDCSAccount AS acc
INNER JOIN	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
			ON (acc.CTSCustID = ms.CTSCustID
				AND acc.SubscriberID = ms.SubscriberID)
WHERE		ms.LoginName IS NULL;


#1. Delete CustDCSAccount, AssociationByDevice WHICH not existing in DCSAccount (NOT 
DELETE		acc
FROM		CTS_DataCenter.CustDCSAccount AS acc
INNER JOIN	CTS_Adhoc.zzzIssueCustMissing_CustDCSAccount_bk AS ms
			ON acc.AccountID = ms.AccountID;

/*
DELETE		acc
FROM		CTS_DataCenter.CustDCSAccount AS acc
INNER JOIN	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
			ON acc.CTSCustID = ms.CTSCustID
				AND acc.SubscriberID = ms.SubscriberID
WHERE		ms.LoginName IS NULL; #COUNT = 7934
*/

#TRUNCATE TABLE CTS_Adhoc.zzzIssueCustMissing_AssociationByDevice_bk;
INSERT IGNORE INTO CTS_Adhoc.zzzIssueCustMissing_AssociationByDevice_bk
SELECT		ad.*
FROM		CTS_DataCenter.AssociationByDevice AS ad
INNER JOIN	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
			ON ad.CTSCustID = ms.CTSCustID
WHERE		ms.LoginName IS NULL; #4815


DELETE		ad
FROM		CTS_DataCenter.AssociationByDevice AS ad
INNER JOIN	CTS_Adhoc.zzzIssueCustMissing_AssociationByDevice_bk AS ms
			ON ad.CTSAssDevID = ms.CTSAssDevID;

# Restore CTS_DataCenter.AssociationByDevice AS ad IF Existing IN CustDCSAccount
INSERT IGNORE INTO CTS_DataCenter.AssociationByDevice
SELECT  	bk.*
FROM 		CTS_Adhoc.zzzIssueCustMissing_AssociationByDevice_bk AS bk
INNER JOIN  CTS_DataCenter.CustDCSAccount AS cda
WHERE		bk.CTSCustID = cda.CTSCustID
			AND bk.SubscriberID = cda.SubscriberID
            ; # COUNT 4826
