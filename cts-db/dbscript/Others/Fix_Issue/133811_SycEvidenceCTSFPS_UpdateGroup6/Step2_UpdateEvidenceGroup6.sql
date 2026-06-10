/*
Creator: 20200512@CaseyHuynh
Task:	 	Update Evidence Group 6
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- [20200512@CaseyHuynh][#133811]: Update EvidenceGroup 6
        
Reviewer:
*/
#=======UPDATE Evidence Group 6 #=====================================
UPDATE CTS_DataCenter.Evidence
SET EvidenceName  = (CASE 	WHEN EvidenceCode IN ('6.1','6.11','6.21') THEN 'Group Betting'
							WHEN EvidenceCode IN ('6.2','6.12') THEN 'Fixed Game'
                            WHEN EvidenceCode IN ('6.3','6.13') THEN 'Arbitrage'
							WHEN EvidenceCode IN ('6.4','6.14') THEN 'Hedging'
                            WHEN EvidenceCode IN ('6.5','6.15') THEN 'Irrigation Bet'
                            WHEN EvidenceCode IN ('6.6','6.16') THEN 'System Formula Bet'
                            WHEN EvidenceCode IN ('6.7') THEN 'danger 7'
                            WHEN EvidenceCode IN ('6.8') THEN 'danger 8'
                            WHEN EvidenceCode IN ('6.9') THEN 'danger 9'
                            WHEN EvidenceCode IN ('6.10') THEN 'danger 10'
                            WHEN EvidenceCode IN ('6.17') THEN 'AB Bet'
                            WHEN EvidenceCode IN ('6.18') THEN 'Bonus Hunter'
                            WHEN EvidenceCode IN ('6.19') THEN 'danger 19'
                            WHEN EvidenceCode IN ('6.20') THEN 'danger 20'
                            ELSE EvidenceName
					END)
WHERE EvidenceGroupID = 6; 

INSERT INTO CTS_DataCenter.Evidence(EvidenceGroupID, EvidenceCode, EvidenceName,  EvidenceDesc, OrderNo, CreatedDate, CreatedBy, IsActive)
VALUES (6	,'6.22'	,'Fixed Game'	,''	,22	,'2020-05-12'	,0	,1)
,(6	,'6.23'	,'Arbitrage'	,''	,23	,'2020-05-12'	,0	,1)
,(6	,'6.24'	,'Hedging'	,''	,24	,'2020-05-12'	,0	,1)
,(6	,'6.25'	,'Irrigation Bet'	,''	,25	,'2020-05-12'	,0	,1)
,(6	,'6.26'	,'System Formula Bet'	,''	,26	,'2020-05-12'	,0	,1)
,(6	,'6.27'	,'AB Bet'	,''	,27	,'2020-05-12'	,0	,1)
,(6	,'6.28'	,'Bonus Hunter'	,''	,28	,'2020-05-12'	,0	,1)
,(6	,'6.29'	,'danger 29'	,''	,29	,'2020-05-12'	,0	,1)
,(6	,'6.30'	,'danger 30'	,''	,30	,'2020-05-12'	,0	,1);


SELECT * FROM CTS_DataCenter.Evidence;