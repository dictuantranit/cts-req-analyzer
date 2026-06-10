Insert into CTS_DataCenter.zzzIssueLoginName_CTSCustomer_DuplicateNew
SELECT ct.*
FROM CTS_DataCenter.CTSCustomer ct
INNER JOIN CTS_DataCenter.CTSCustomer dp
			ON ct.UserName = dp.UserName AND ct.UserName2 = dp.UserName2 AND dp.SubscriberID = 102
WHERE 	 ct.SubscriberID = 4428; 
        
DELETE ct
FROM 	CTS_DataCenter.CTSCustomer ct
INNER 	JOIN CTS_DataCenter.zzzIssueLoginName_CTSCustomer_DuplicateNew dp
				ON ct.CTSCustID = dp.CTSCustID;#3552