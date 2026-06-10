/*
	Created: 	20200901@Long.Luu
	Task:		Init more categories for General Classification [Redmine ID: #137550]
	DB:			CTS_DataCenter
	Original:
	Revisions:
*/
#####################CTS_DataCenter.CustomerCategory
INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID, CategoryName,CategorySpec,DisplayOrder,CreatedDate)
VALUE(200,'General Normal Account','General Normal Account',3,CURRENT_TIME());

# Auto
INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually, ScanIntervalInSecond)
VALUE(201,'Main New Member','Main New Member',200,1,CURRENT_TIME(),0,0);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually, ScanIntervalInSecond)
VALUE(202,'Main Normal Account','Main Normal Account',200,2,CURRENT_TIME(),0,1209600);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually, ScanIntervalInSecond)
VALUE(203,'Main Smart Punter','Main Smart Punter',200,3,CURRENT_TIME(),0,1209600);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually, ScanIntervalInSecond)
VALUE(204,'Main High Risk Punter','Main High Risk Punter',200,4,CURRENT_TIME(),0,1209600);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually, ScanIntervalInSecond)
VALUE(205,'Main VIP','Main VIP',200,5,CURRENT_TIME(),0,604800);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually, ScanIntervalInSecond)
VALUE(206,'Main Probation','Main Probation',200,6,CURRENT_TIME(),0,1209600);