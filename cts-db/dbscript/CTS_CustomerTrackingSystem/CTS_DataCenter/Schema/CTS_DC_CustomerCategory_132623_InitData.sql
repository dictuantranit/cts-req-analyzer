/*
Creator: 20200423@Long.Luu
Task:	 	Customer Category
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- 20200423@Long.Luu: Created [#132623]
Reviewer:
*/

#####################CTS_DataCenter.SportGroup
INSERT INTO CTS_DataCenter.SportGroup(SportGroupName,MainDBSportID,DisplayOrder,CreatedDate)
VALUES('Soccer',1,1,CURRENT_TIME());

INSERT INTO CTS_DataCenter.SportGroup(SportGroupName,MainDBSportID,DisplayOrder,CreatedDate)
VALUES('Basketball',2,2,CURRENT_TIME());

INSERT INTO CTS_DataCenter.SportGroup(SportGroupName,DisplayOrder,CreatedDate)
VALUES('Other-Sports',3,CURRENT_TIME());

INSERT INTO CTS_DataCenter.SportGroup(SportGroupName,MainDBSportID,DisplayOrder,CreatedDate)
VALUES('E-Sports',43,4,CURRENT_TIME());

INSERT INTO CTS_DataCenter.SportGroup(SportGroupName,DisplayOrder,CreatedDate)
VALUES('Non-Sports',5,CURRENT_TIME());

#####################CTS_DataCenter.CustomerCategory
INSERT INTO CTS_DataCenter.CustomerCategory (CategoryName,CategorySpec,DisplayOrder,CreatedDate)
VALUE('Normal Account','Normal Account Group',1,CURRENT_TIME());

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate)
VALUE('New Member','New Member',1,1,CURRENT_TIME());

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate)
VALUE('VVIP','VVIP',1,2,CURRENT_TIME());

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate)
VALUE('Normal Member','Normal Member',1,3,CURRENT_TIME());

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate)
VALUE('VIP','VIP',1,4,CURRENT_TIME());

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate)
VALUE('Smart Punter','Smart Punter',1,5,CURRENT_TIME());

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate)
VALUE('High Risk Punter','High Risk Punter',1,6,CURRENT_TIME());

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate)
VALUE('Lucky Punter','Lucky Punter',1,7,CURRENT_TIME());

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate)
VALUE('Limited Punter','Limited Punter',1,8,CURRENT_TIME());

#####################CTS_Admin.LogType
INSERT INTO CTS_Admin.LogType (LogTypeName,LogTypeDescription)
VALUE('Insert Customer Category','Insert Customer Category');

INSERT INTO CTS_Admin.LogType (LogTypeName,LogTypeDescription)
VALUE('Update Customer Category','Update Customer Category');

INSERT INTO CTS_Admin.LogType (LogTypeName,LogTypeDescription)
VALUE('Delete Customer Category','Delete Customer Category');


