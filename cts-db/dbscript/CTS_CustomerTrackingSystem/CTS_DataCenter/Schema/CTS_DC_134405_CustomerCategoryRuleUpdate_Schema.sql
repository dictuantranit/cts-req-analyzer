/*
Creator:	20200602@Long.Luu
Task:	 	CTS_Schema
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- 20200602@Long.Luu: Adding schema [Redmine ID: #134405]
Reviewer:
*/

CREATE TABLE [dbo].[CustomerClassification_Parameter](
	[DataId]			SMALLINT NOT NULL PRIMARY KEY,
	[DataDescription]	VARCHAR(200) NOT NULL,
	[DataType]			VARCHAR(20) NOT NULL,
	[Value]				VARCHAR(200) NOT NULL
)

GO

INSERT INTO [dbo].[CustomerClassification_Parameter](DataId, DataDescription, DataType, [Value])
VALUES(1,'Get datetime for picking up the latest customer changes','VARCHAR(20)','2020-01-01');

CREATE TABLE [dbo].[CustomerClassification_VIPMonitor](
	[CustId]				INT NOT NULL,
	[SportId]				SMALLINT NOT NULL,
	[LastScanTicketCount]	INT,
	[LastScanDate]			DATETIME
	PRIMARY KEY (CustId, SportId)
)

GO
