WITH "jdbc:mysql://10.40.40.58:3306/CTS_DataCenter?user=harvey.vn&password=harvey@1234" as url
CALL apoc.load.jdbc(url,"select * from AssociationByAI where CreatedDate > '2021-03-15' and CreatedDate < '2021-04-15'") YIELD row
MERGE (f:CTSCustomer {CustID: toInteger(row.FromCustID), CustSubID: 0})
MERGE (t:CTSCustomer {CustID: toInteger(row.ToCustID), CustSubID: 0})
MERGE (f)-[r:ASS_BY_AI]->(t)
    ON CREATE SET r.CreatedDate = row.CreatedDate;