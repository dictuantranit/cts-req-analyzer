/*
Creator: 20191106@CaseyHuynh 
Task:	 	Correct data CTS_customer Missing vs CustDCSAccount
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		
Reviewer:
*/
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  
#2.1 Update NewCTSCustID
UPDATE		CTS_DataCenter.CustDCSAccount AS acc
INNER JOIN	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
			ON acc.CTSCustID = ms.CTSCustID
				AND acc.SubscriberID = ms.SubscriberID
SET			acc.CTSCustID = ms.NewCTSCustID                
WHERE		ms.NewCTSCustID > 0;

# 2.2 UPDATE AssociationByDevice Table
CTSAssDevID, CTSCustID , DCSDeviceID, SubscriberID, CreatedTime, InsertTime
1			1			1001 --> old
2			1			1002   ---> old Will duplicate
3			2			1002
4			2			1003


# 2.2.1 Get Duplicate AssociationByDevice
CTSAssDevID, CTSCustID , DCSDeviceID, SubscriberID, CreatedTime, InsertTime
1			 	2			 1001 	---> 
2				2			 1002   ---> old -->

INSERT INTO CTS_Adhoc.zzzIssueCustMissing_AssociationByDevice_UpdateDuplicate(CTSAssDevID, CTSCustID, OldCTSCustID, DCSDeviceID, SubscriberID, CreatedTime, InsertTime)
SELECT 		DISTINCT ad.CTSAssDevID,  ms.NewCTSCustID, ad.CTSCustID, ad.DCSDeviceID, ad.SubscriberID, ad.CreatedTime, ad.InsertTime
FROM 		CTS_DataCenter.AssociationByDevice AS ad
INNER JOIN	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
			ON ad.CTSCustID = ms.CTSCustID
WHERE		ms.NewCTSCustID > 0;

# 2.2.2 Get Exclude  'CTSAssDevID' for Duplicate if update
SELECT 	DISTINCT dup.CTSAssDevID
FROM		CTS_Adhoc.zzzIssueCustMissing_AssociationByDevice_UpdateDuplicate AS dup
INNER JOIN 	CTS_DataCenter.AssociationByDevice AS ad
			ON dup.CTSCustID = ad.CTSCustID
				AND dup.DCSDeviceID = ad.DCSDeviceID;

CTSAssDevID, CTSCustID , DCSDeviceID, SubscriberID, CreatedTime, InsertTime
1			 	2			 1001 	---> 
2				2			 1002   ---> Found CTSAssDevID = 2 (exclude data then update)

# 2.2.2 UPDATE AssociationByDevice Table (exclude the 2.2.2 'CTSAssDevID')
UPDATE		CTS_DataCenter.AssociationByDevice AS ad
INNER JOIN	CTS_DataCenter.zzzIssueCustMissing_CustDCSAccount AS ms
			ON ad.CTSCustID = ms.CTSCustID
SET			ad.CTSCustID = ms.NewCTSCustID                
WHERE		ms.NewCTSCustID > 0
            AND ad.CTSAssDevID NOT IN <>>>>
            ;
            
# 2.2.3 REMOVE AssociationByDevice Duplicate
DELETE  ad
FROM 	CTS_DataCenter.AssociationByDevice AS ad
WHERE	ad.CTSAssDevID  IN <>>>>>;