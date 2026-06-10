/*
Creator: 20191106@CaseyHuynh 
Task:	 	Correct data CTS_customer Missing vs CustDCSAccount
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		
Reviewer:
*/

#1. Delete CustDCSAccount, AssociationByDevice WHICH not existing in DCSAccount (NOT 
DELETE		acc
FROM		CTS_DataCenter.CustDCSAccount AS acc
INNER JOIN	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
			ON acc.CTSCustID = ms.CTSCustID
				AND acc.SubscriberID = ms.SubscriberID
WHERE		ms.LoginName IS NULL; #COUNT = 7934

DELETE		ad
FROM		CTS_DataCenter.AssociationByDevice AS ad
INNER JOIN	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
			ON ad.CTSCustID = ms.CTSCustID
WHERE		ms.LoginName IS NULL; 
