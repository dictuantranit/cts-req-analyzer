/*
Creator: 	20200713@Long.Luu
Task:	 	Customer Category data
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- 20200713@Long.Luu: Created [#136640]
Reviewer:
*/

#####################CTS_DataCenter.CustomerCategory
INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID, CategoryName,CategorySpec,DisplayOrder,CreatedDate)
VALUE(50,'Problem Account','Problem Account Group',2,CURRENT_TIME());

# Auto
INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(51,'Abnormal','Abnormal',50,27,CURRENT_TIME(),0);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(52,'Group Betting','Group Betting',50,28,CURRENT_TIME(),0);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(53,'Hedging','Hedging',50,29,CURRENT_TIME(),0);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(54,'Arbitrage','Arbitrage',50,30,CURRENT_TIME(),0);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(55,'Fixed Game','Fixed Game',50,31,CURRENT_TIME(),0);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(56,'AB Bet','AB Bet',50,32,CURRENT_TIME(),0);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(57,'Robot Betting','Robot Betting',50,36,CURRENT_TIME(),0);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(58,'Irrigation Bet','Irrigation Bet',50,37,CURRENT_TIME(),0);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(59,'System Formula Bet','System Formula Bet',50,38,CURRENT_TIME(),0);


# Manual
INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(151,'Abnormal(M)','Abnormal(M)',50,101,CURRENT_TIME(),1);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(152,'Group Betting(M)','Group Betting(M)',50,102,CURRENT_TIME(),1);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(153,'Hedging(M)','Hedging(M)',50,103,CURRENT_TIME(),1);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(154,'Arbitrage(M)','Arbitrage(M)',50,104,CURRENT_TIME(),1);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(155,'Fixed Game(M)','Fixed Game(M)',50,105,CURRENT_TIME(),1);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(156,'AB Bet(M)','AB Bet(M)',50,106,CURRENT_TIME(),1);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(157,'Robot Betting(M)','Robot Betting(M)',50,107,CURRENT_TIME(),1);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(158,'Irrigation Bet(M)','Irrigation Bet(M)',50,108,CURRENT_TIME(),1);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(159,'System Formula Bet(M)','System Formula Bet(M)',50,109,CURRENT_TIME(),1);

INSERT INTO CTS_DataCenter.CustomerCategory (CategoryID,CategoryName,CategorySpec,ParentID,DisplayOrder,CreatedDate,IsUsedManually)
VALUE(160,'Others(M)','Others(M)',50,255,CURRENT_TIME(),1);


