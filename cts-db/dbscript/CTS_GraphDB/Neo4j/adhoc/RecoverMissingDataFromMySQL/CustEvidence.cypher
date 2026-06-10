//WITH "jdbc:mysql://10.18.200.70:3307/CTS_DataCenter?user=harvey.vn&password=1234aa" as url
WITH "jdbc:mysql://10.40.40.58:3306/CTS_DataCenter?user=harvey.vn" as url
CALL apoc.load.jdbc(url,"select * from CustEvidence where CTSCustID > 57757186 and Level = 0") YIELD row
MATCH (n:CTSCustomer {CTSCustID:toInteger(row.CTSCustID)})
MATCH (c:Evidence {EvidenceID:toInteger(row.EvidenceID)})
MERGE (n)-[r:HAS_EVIDENCE]->(c)
    ON CREATE SET r.CreatedDate=datetime(row.CreatedDate)
WITH DISTINCT n
SET n:FlaggedCustomer;