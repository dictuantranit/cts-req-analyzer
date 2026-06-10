/*
Creator: 20191106@CaseyHuynh
Task:	 	Create Initial Data EvidenceGroup
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- [20200123@CaseyHuynh][#127571]: Created
        
Reviewer:
*/

INSERT INTO CTS_DataCenter.EvidenceGroup (EvidenceGroupID, EvidenceGroupName, IsActive, OrderNo, EvidenceGroupDesc, CreatedDate, CreatedBy)
VALUES(1	,'Financial'	,1	,1	,''	,'2020-01-22'	,0)
	,(2	,'Cheating'	,1	,2	,''	,'2020-01-22'	,0)
	,(3	,'Misconduct'	,1	,3	,''	,'2020-01-22'	,0)
	,(4	,'Identity Theft'	,1	,4	,''	,'2020-01-22'	,0)
	,(5	,'Monitoring'	,1	,5	,''	,'2020-01-22'	,0)
	,(6	,'Soccer Fraud'	,1	,6	,''	,'2020-01-22'	,0)
	,(7	,'Other Sports Fraud'	,1	,7	,''	,'2020-01-22'	,0)
	,(99,'Miscellaneous'	,1	,99	,''	,'2020-01-22'	,0)