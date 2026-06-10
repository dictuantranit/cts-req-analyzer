//WITH "jdbc:mysql://10.18.200.70:3307/CTS_DataCenter?user=harvey.vn&password=1234aa" as url
WITH "jdbc:mysql://10.40.40.58:3306/CTS_DataCenter?user=harvey.vn" as url
CALL apoc.load.jdbc(url,"select * from CTSCustomer where CTSCustID > 57757186") YIELD row
MERGE (n:CTSCustomer {CTSCustID:toInteger(row.CTSCustID)})
    ON CREATE SET n.CustID=toInteger(row.CustID)
        , n.RegisterName=row.RegisterName
        , n.Username=row.UserName
        , n.Username2=row.UserName2
        , n.CustSubID=row.CustSubID
WITH n,row
MATCH (s:Subscriber {SubscriberID:toInteger(row.SubscriberID)})
WHERE row.SubscriberID > 0
MERGE (n)-[r:BELONG_TO_SUB]->(s)
    ON CREATE SET r.CreatedDate=datetime(row.CreatedDate)
WITH n,row
MERGE (s:StaticList {ItemID:row.CustStatusID, ListID: 1})
MERGE (n)-[r:HAS_STATUS]-(s)
    ON CREATE SET r.CreatedDate=datetime(row.CreatedDate)