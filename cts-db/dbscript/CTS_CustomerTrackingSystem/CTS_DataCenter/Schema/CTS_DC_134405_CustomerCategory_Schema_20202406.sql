/*
		Created:	20200624@Casey.Huynh
		Task :		Chagne History Store
		DB:			CTS_DataCenter
		Original: 
		Revisions:
		Param's Explanation:
	*/ 
DROP TABLE  CTS_DataCenter.CTSCustomerClassification_History;
CREATE TABLE IF NOT EXISTS CTS_DataCenter.CTSCustomerClassification_History (
		ID					BIGINT UNSIGNED AUTO_INCREMENT
	,	CustID				BIGINT UNSIGNED
    ,  	CTSCustID			BIGINT UNSIGNED
	, 	CategoryID			SMALLINT UNSIGNED
    ,	SportGroupID		SMALLINT UNSIGNED
    , 	LastModifiedDate	DATETIME
    ,	LastModifiedBy		INT UNSIGNED
    , 	TurnoverRM			DECIMAL(20,4)
    , 	WinlossRM			DECIMAL(20,4)
    , 	BetCount			BIGINT
	, 	ActiveDays			INT
    ,	ActionType			TINYINT
    ,	IsAuto				BIT
    , 	InsertDate			DATETIME
    , 	PRIMARY KEY			PK_CTSCustomerClassificationHistory_ID(ID)
	, 	INDEX				IX_CTSCustomerClassificationHistory_CustIDSportGroupID(CustID, SportGroupID)
    ,	INDEX				IX_CTSCustomerClassificationHistory_LastModifiedDate(LastModifiedDate)
) ENGINE=INNODB AUTO_INCREMENT=1;