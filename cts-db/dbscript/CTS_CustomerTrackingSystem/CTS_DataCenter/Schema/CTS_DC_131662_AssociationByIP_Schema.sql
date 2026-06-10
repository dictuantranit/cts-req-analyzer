/*
Creator: 20210315@Long.Luu
Task:	 	CTS_Schema
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- 20210315@Long.Luu: Manage Association By IP[Redmine ID: #131662]
Reviewer:
*/

CREATE TABLE IF NOT EXISTS CTS_DataCenter.AssociationByIP(
  `FromCustID` 	BIGINT UNSIGNED NOT NULL,
  `ToCustID` 	BIGINT UNSIGNED NOT NULL,
  `CreatedDate` DATE DEFAULT NULL,
  PRIMARY KEY (`FromCustID`,`ToCustID`),
  KEY `IX_AssociationByIP_ToCustID` (`ToCustID`),
  KEY `IX_AssociationByIP_CreatedDate` (`CreatedDate`)
) ENGINE=InnoDB;

