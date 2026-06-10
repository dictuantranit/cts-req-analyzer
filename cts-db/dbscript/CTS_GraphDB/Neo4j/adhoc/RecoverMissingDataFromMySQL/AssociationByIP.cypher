WITH "jdbc:mysql://10.18.200.70:3307/CTS_DataCenter?user=harvey.vn&password=1234aa" as url
//WITH "jdbc:mysql://10.40.40.58:3306/CTS_DataCenter?user=harvey.vn&password=harvey@1234" as url
CALL apoc.load.jdbc(url,"select * from AssociationByIP") YIELD row
MERGE (f:CTSCustomer {CustID: toInteger(row.FromCustID)})
MERGE (t:CTSCustomer {CustID: toInteger(row.ToCustID)})
MERGE (f)-[r:ASS_BY_IP]->(t)
    ON CREATE SET r.CreatedDate = datetime(row.CreatedDate)