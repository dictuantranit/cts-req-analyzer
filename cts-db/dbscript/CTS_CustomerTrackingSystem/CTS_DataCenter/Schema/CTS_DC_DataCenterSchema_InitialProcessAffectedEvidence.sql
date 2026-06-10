/*
Creator: 20200303@CaseyHuynh
Task:	 	ProcessAffectedEvidence
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
        
Reviewer:
*/
SELECT MAX(CTSAssDevID) FROM CTS_DataCenter.AssociationByDevice;

Insert into CTS_DataCenter.ProcessAffectedEvidence(LastCTSAssDevID)
VALUES(2886317);