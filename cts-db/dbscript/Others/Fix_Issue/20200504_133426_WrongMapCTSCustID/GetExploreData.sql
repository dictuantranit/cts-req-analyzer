	/*
		Created:	20200515@CaseyHuynh	
		Task :		GET ExploreData
		DB:			CTS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
UPDATE CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cda
INNER JOIN CTS_DataCenter.CTSCustomer AS cus
			ON cda.cdaCTSCustID = cus.CTSCustID
SET cda.currency = cus.currencyid;


SELECT processType, count(1)
FROM   CTS_Adhoc.cs133426_AssociationByDevice_Remove
GROUP BY processType
ORDER BY processType;

SELECT processType, Currency
FROM   CTS_Adhoc.cs133426_CustDCSAccountWrongSub
WHERE processType IN (0,4)
Group BY processType, Currency;

SELECT processType, count(1)
FROM   CTS_Adhoc.cs133426_CustDCSAccountWrongSub
GROUP BY processType
ORDER BY processType;

INSERT INTO CTS_Adhoc.cs133426_AssociationByDevice_Remove
SELECT 		ass.*, 20
FROM 		CTS_DataCenter.AssociationByDevice AS ass
INNER JOIN	CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cda
			ON cda.NewCTSCustID = ass.CTSCustID
WHERE		cda.processType = 2;

#Step 9:
INSERT INTO CTS_Adhoc.cs133426_AssociationByDevice_Remove
SELECT 		ass.*, cda.processType
FROM 		CTS_DataCenter.AssociationByDevice AS ass
INNER JOIN	CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cda
			ON cda.cdaCTSCustID = ass.CTSCustID;
#=========================================================================
#STEP 8; 493
UPDATE CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cda
INNER JOIN CTS_DataCenter.CTSCustomer AS cus
		ON cda.accLoginName = cus.UserName
SET		cda.NewCTSCustID = cus.CTSCustID
		, cda.NewSubscriberID = cus.SubscriberID
        , cda.NewMapBy = 4 #mapping by userName BUT NOT SUB
        , cda.processType = 4
WHERE cda.processType = 0;

#STEP 7; 0
UPDATE CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cda
INNER JOIN CTS_DataCenter.CTSCustomer AS cus
ON		cda.accLoginName = cus.UserName
		AND cda.cdaSubscriberID = cus.SubscriberID
SET		cda.NewCTSCustID = cus.CTSCustID
		, cda.NewSubscriberID = cus.SubscriberID
        , cda.NewMapBy = 3 #mapping by userName AND SUB
        , cda.processType = 3
WHERE 	 cda.processType = 0;

#STEP7: 692
UPDATE 		CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cda
INNER JOIN 	CTS_DataCenter.CTSCustomer AS cus
			ON cda.accLoginNameWithPrefix = cus.UserName2
SET		cda.NewCTSCustID = cus.CTSCustID
		, cda.NewSubscriberID = cus.SubscriberID
        , cda.NewMapBy = 2 # MAP NEWCTSCust by USERNAME2
        , cda.processType = 2
WHERE 	cda.processType = 0; 


#STEP 5; 421
UPDATE 	CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cda
SET		cda.processType = 1 # EXCLUDE - INDO LOGIN ISSUE
WHERE 	cdaSubscriberID IN (13658,13659)
		OR cusSubscriberID IN (13658,13659)
		AND cda.processType = 0;


#STEP 5 - 5
UPDATE 	CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cda
SET		cda.processType = -3 #Remove NOT FOUND IN DCS.ACCOUNT
WHERE 	accAccountID IS NULL; 

#Step 4 - 6214
UPDATE CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cda
INNER JOIN DCS_DataCenter.Account AS acc
			ON cda.cdaAccountID = acc.AccountID
            AND cda.cdaSubscriberID = acc.SubscriberID
SET cda.accLoginName = acc.LoginName
	,cda.accLoginNameWithPrefix = CONCAT(cda.cdaSubscriberPrefix, acc.LoginName)
    ,accAccountID = acc.AccountID;

#STEP 3; 859
UPDATE CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cda
SET		cda.processType = -2   # Remove NEw Deposit
WHERE 	cusCustID IS NULL
        AND cda.processType = 0;
;

#STEP 2; #3724
UPDATE CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cda
SET		cda.processType = -1   # Remove (CTMAX)
WHERE 	cda.cdaSubscriberID IN (2328, 2367) 
        AND cda.processType = 0;
;

# Step 1; 6208
SELECT *
FROM 	CTS_Adhoc.cs133426_CustDCSAccountWrongSub
ORDER BY cdaAccountID Desc;
WHERE 	cdaCTSCustID IN (36146026,89758);

TRUNCATE TABLE CTS_Adhoc.cs133426_CustDCSAccountWrongSub;
INSERT INTO CTS_Adhoc.cs133426_CustDCSAccountWrongSub(
					cdaCTSCustID, cdaAccountID, cdaSubscriberID, cdaInsertTime
                    , cdaSubscriberType, cdaSubscriberPrefix
					#, cusSubscriberID, cusCustID, cusCustSubID, cusUserName, cusUserName2)
                    , cusSubscriberID, cusSubscriberType, cusSubscriberPrefix, cusCustID, cusCustSubID, cusUserName, cusUserName2)
        SELECT 		cda.CTSCustID
					, cda.AccountID
                    , cda.SubscriberID
                    , cda.InsertTime
                    , subcda.SubscriberType		AS cdaSubscriberType
                    , subcda.SubscriberPrefix	AS cdaSubscriberPrefix
					, cus.SubscriberID
                    , subcus.SubscriberType		AS cusSubscriberType
                    , subcus.SubscriberPrefix	AS cusSubscriberPrefix
                    , cus.CustID
                    , cus.CustSubID
                    , cus.UserName
                    , cus.UserName2
        FROM		CTS_DataCenter.CustDCSAccount 	AS cda
        LEFT JOIN 	CTS_DataCenter.CTSCustomer	AS cus
					ON cda.CTSCustID = cus.CTSCustID
		LEFT JOIN	CTS_Admin.Subscriber AS subcda
					ON cda.SubscriberID = subcda.SubscriberID        
		LEFT JOIN	CTS_Admin.Subscriber AS subcus
					ON cus.SubscriberID = subcus.SubscriberID
		WHERE		cda.SubscriberID != cus.SubscriberID;
        
        
        SELECT * 
        FROM 	CTS_Admin.Subscriber AS subcda
        WHERE SubscriberID IN(6, 2, 130, 168);
	*/;
