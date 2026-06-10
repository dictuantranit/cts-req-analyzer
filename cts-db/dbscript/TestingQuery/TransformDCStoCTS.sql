# 1-==COUNT RECORD: Expected CTS_DataCenter.CustDCSAccount COUNT = CS_DataCenter.Account COUNT============
SELECT 'CTS_DataCenter.CustDCSAccount' AS 'Summary', 	Count(1) AS 'Count'
FROM	CTS_DataCenter.CustDCSAccount
UNION ALL
SELECT 'CS_DataCenter.Account' AS 'Summary', 	Count(1) AS 'Count'
FROM	DCS_DataCenter.Account;

# 2-==CHECK A: Expected NULL============
SELECT 'DCS_DataCenter.Account NOT EXISTING IN CTS' AS 'Summary', 	ac.AccountID AS 'AccountID'
FROM		DCS_DataCenter.Account ac
LEFT JOIN 	CTS_DataCenter.CustDCSAccount cus
			ON ac.AccountID = cus.AccountID
WHERE		cus.AccountID IS NULL;

# 3-==CHECK A: Expected NULL============
SELECT 	COUNT(DISTINCT CTSCustID)
FROM	CTS_DataCenter.CustDCSAccount
UNION ALL
SELECT	COUNT(1)
FROM	CTS_DataCenter.CTSCustomer;

# 2-==CHECK A: Expected NULL============
SELECT 'DCS_DataCenter.Account NOT EXISTING IN CTS' AS 'Summary', 	ct.CTSCustID AS 'AccountID'
FROM		CTS_DataCenter.CTSCustomer ct
LEFT JOIN 	CTS_DataCenter.CustDCSAccount ac
			ON ct.CTSCustID = ac.CTSCustID
WHERE		ac.CTSCustID IS NULL
LIMIT 10;

SELECT * FROM CTSCustomer;
