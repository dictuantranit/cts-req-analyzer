/*
Creator: 20200416@Long.Luu
Task:	 	CTS_Schema
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- 20200416@Long.Luu: Manage Association [Redmine ID: #131506]
Reviewer:
*/

CREATE TABLE IF NOT EXISTS CTS_DataCenter.AssociationByManual (
	FromSubscriberID		INT		UNSIGNED
	, FromCTSCustID			BIGINT	UNSIGNED
	, ToSubscriberID		INT		UNSIGNED
	, ToCTSCustID			BIGINT	UNSIGNED
	, Remark				VARCHAR(500) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
	, CreatedDate			DATETIME
    , CreatedBy				BIGINT
	, PRIMARY KEY	PK_AssociationByManual_FromCustIDToCustID(FromCTSCustID, ToCTSCustID)
	, INDEX			IX_AssociationByManual_ToCTSCustID(ToCTSCustID)
    , INDEX			IX_AssociationByManual_FromSubscriberIDToSubscriberID(FromSubscriberID, ToSubscriberID)
	, INDEX			IX_AssociationByManual_CreatedDate(CreatedDate)
) ENGINE=INNODB AUTO_INCREMENT=1;

CREATE TABLE IF NOT EXISTS CTS_DataCenter.AssociationRemove (
	FromSubscriberID		INT		UNSIGNED
	, FromCTSCustID			BIGINT	UNSIGNED
	, ToSubscriberID		INT		UNSIGNED
	, ToCTSCustID			BIGINT	UNSIGNED
	, Remark				VARCHAR(500) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
	, CreatedDate			DATETIME
    , CreatedBy				BIGINT
	, PRIMARY KEY	PK_AssociationRemove_FromCustIDToCustID(FromCTSCustID, ToCTSCustID)
	, INDEX			IX_AssociationRemove_ToCTSCustID(ToCTSCustID)
	, INDEX			IX_AssociationRemove_FromSubscriberIDToSubscriberID(FromSubscriberID, ToSubscriberID)
	, INDEX			IX_AssociationRemove_CreatedDate(CreatedDate)
) ENGINE=INNODB AUTO_INCREMENT=1;


