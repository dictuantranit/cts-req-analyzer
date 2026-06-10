/*
Creator: 	20200603@Harvey
Task:	 	CTS_Schema
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- 20200603@Harvey: Modify for table
		- 20200709@Harvey: Add index
Reviewer:
*/

ALTER TABLE  CTS_DataCenter.CTSCustomer ADD COLUMN RegisterName varchar(50) NULL, ALGORITHM=INSTANT;
ALTER TABLE CTS_DataCenter.CTSCustomer ADD INDEX IX_CTSCustomer_RegisterName (RegisterName);
-- DROP INDEX IX_FullText_CTSCustomer_UserName_UserName2 ON CTS_DataCenter.CTSCustomer;

ALTER TABLE CTS_DataCenter.CTSCustomer ADD INDEX IX_CTSCustomer_RoleID (RoleID);
ALTER TABLE CTS_DataCenter.CTSCustomer ADD INDEX IX_CTSCustomer_SRecommend_RoleID (SRecommend,RoleID);
ALTER TABLE CTS_DataCenter.CustDCSAccount ADD INDEX IX_CustDCSAccount_CTSCustID (CTSCustID);