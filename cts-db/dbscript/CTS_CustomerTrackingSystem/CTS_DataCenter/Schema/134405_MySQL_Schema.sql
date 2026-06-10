/*
Creator: 	20200603@Casey.Huynh
Task:	 	CTS_Schema
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
	[20200612@Casey.Huynh][135324]: 
		+ Alter Table CTSCustomerClassification, add column LastScannedDate
		+ Alter table CTS_DataCenter.CustomerCategory: Add ScanIntervalInSecond
		+ Re-Design Table CTS_DataCenter.CustomerCategory_History
		+ Add table CTS_DataCenter.CTSCustomerClassification_ScanStatus
Reviewer:
*/
CREATE TABLE CTS_DataCenter.CTSCustomerClassification_ScanStatus
(
	ScanTime		DATETIME
    , LastCustID	BIGINT UNSIGNED
    , ScanStatus	TINYINT				# 0-Inprogress, 1-Done
    
    ,PRIMARY KEY	PK_CTSCustomerClassification_ScanStatus_ScannedTime(ScanTime)
);

INSERT INTO CTS_DataCenter.CTSCustomerClassification_ScanStatus(ScanTime, LastCustID, ScanStatus)
VALUES('2020-05-17', LastCustID, 1);
/***************************************************************/
ALTER TABLE CTS_DataCenter.CTSCustomerClassification
ADD COLUMN LastScannedDate DATETIME;

ALTER TABLE CTS_DataCenter.CTSCustomerClassification
ADD COLUMN 	CustID	INT UNSIGNED;

ALTER TABLE CTS_DataCenter.CTSCustomerClassification
ADD INDEX IX_CTSCustomerClassification_LastScannedDate(LastScannedDate);

ALTER TABLE CTS_DataCenter.CTSCustomerClassification
ADD INDEX IX_CTSCustomerClassification_CategoryID(CategoryID);

ALTER TABLE CTS_DataCenter.CTSCustomerClassification
ADD INDEX IX_CTSCustomerClassification_CustID(CustID);

ALTER TABLE	CTS_DataCenter.CustomerCategory
ADD COLUMN  ScanIntervalInSecond BIGINT;

DROP TABLE CTS_DataCenter.CTSCustomerClassification_History;
CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSCustomerClassification_History (
		ID					BIGINT UNSIGNED AUTO_INCREMENT
	,	CustID				BIGINT UNSIGNED
    ,  	CTSCustID			BIGINT UNSIGNED
	, 	CategoryID			SMALLINT UNSIGNED
    ,	SportGroupID		SMALLINT UNSIGNED
    , 	LastModifiedDate	DATETIME
    ,	LastModifiedBy		INT UNSIGNED
    ,	IsAuto				BIT
    , 	PRIMARY KEY			PK_CTSCustomerClassificationHistory_ID(ID)
	, 	INDEX				IX_CTSCustomerClassificationHistory_CustIDSportGroupID(CustID, SportGroupID)
    ,	INDEX				IX_CTSCustomerClassificationHistory_LastModifiedDate(LastModifiedDate)
) ENGINE=INNODB AUTO_INCREMENT=1;

/************Initial CustomerCategory.SecondSchedule***************/
INSERT INTO CTS_DataCenter.CustomerCategory(CategoryID, CategoryName, CategorySpec, ParentID, DisplayOrder, IsActive, CreatedDate, IsUsedManually)
VALUES(10, 'Probation', 'Probation', 1, 9, 1, Current_Date(), 0);

UPDATE CTS_DataCenter.CustomerCategory
SET IntervalScanSecond = 	(CASE	WHEN CategoryID = 4 	THEN 1209600	#Normal Member 2 week
									WHEN CategoryID = 5 	THEN 604800		#VIP 1 week
									WHEN CategoryID = 6 	THEN 604800		#Smart Punter 1 week
									WHEN CategoryID = 7 	THEN 604800		#High Risk Punter 1 week
									WHEN CategoryID = 10 	THEN 604800		#Probation 1 week
							END
						);

