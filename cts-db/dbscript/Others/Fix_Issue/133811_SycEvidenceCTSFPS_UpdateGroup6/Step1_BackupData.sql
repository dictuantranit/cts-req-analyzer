/*
Creator: 20200512@CaseyHuynh
Task:	 	BackupData
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- [20200512@CaseyHuynh][#133811]: Update EvidenceGroup 6
        
Reviewer:
*/

/*******************************************************************/
CREATE TABLE  CTS_Adhoc.CS133811_Evidence_bk
SELECT * FROM CTS_DataCenter.Evidence; 


/*******************************************************************/
CREATE TABLE  CTS_Adhoc.CS133811_CustEvidence_bk
SELECT * FROM CTS_DataCenter.CustEvidence; 
