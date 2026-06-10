/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_InitialSmart_Insert`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_InitialSmart_Insert`(
		IN 	ip_CustInfo 		JSON
)
SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20240530@Thomas.Nguyen
		Task:	 	Customer Initial Smart - Insert data after getting from TW
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20240530@Thomas.Nguyen: 	Created [Redmine ID: #199345]
				- 20240628@Thomas.Nguyen:	Renovate CC phase 2 - Update datatype of Probability [Redmine ID: #205317]
				- 20250922@Logan.Nguyen: 	Adjust Performance Calculation Logic for Initial Smart - CC2700 - Initial Smart (Losing) - CC2701 [Redmine ID: #239118]

		Example:
			CALL CTS_DC_CustClassification_InitialSmart_Insert (@ip_CustInfo:='[{"CustID":1275,"Probability":0.1419399977,"PredictTime":"2024-05-30T03:02:26"},{"CustID":1277,"Probability":0.7015600204,"PredictTime":"2024-05-30T03:03:26"},{"CustID":1280,"Probability":0.7505900264,"PredictTime":"2024-05-31T03:02:26"},{"CustID":1282,"Probability":0.7498900294,"PredictTime":"2024-05-30T07:02:26"}]');
	*/
	DECLARE lv_CreatedDate DATETIME(3);

	DECLARE	CONST_SPORTTYPE_SOCCER INT DEFAULT 1;
	
	SET lv_CreatedDate = CURRENT_TIMESTAMP(3);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
	CREATE TEMPORARY TABLE Temp_Customer(
			CustID 				BIGINT NOT NULL PRIMARY KEY
		,   Probability 		DECIMAL(8,2)
		,   SourceCreatedDate 	DATETIME(3)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_ExistedCust;
	CREATE TEMPORARY TABLE Temp_ExistedCust(
			CustID 				BIGINT NOT NULL PRIMARY KEY
	);

	INSERT IGNORE INTO Temp_Customer(CustID, Probability, SourceCreatedDate)
    SELECT	tmp.CustID
		,	tmp.Probability
		,	tmp.SourceCreatedDate
    FROM JSON_TABLE(ip_CustInfo,
                        "$[*]" COLUMNS (CustID          			BIGINT			UNSIGNED	PATH "$.CustID"
									,	Probability					DECIMAL(8,2)				PATH "$.Probability"
                                    ,   SourceCreatedDate		    DATETIME(3)					PATH "$.PredictTime"                                           
                                )) AS tmp;

	INSERT IGNORE INTO Temp_ExistedCust(CustID)
	SELECT tmp.CustID
	FROM CTS_DataCenter.Customer_InitialSmart_BySport AS cs
		INNER JOIN Temp_Customer AS tmp	ON tmp.CustID = cs.CustID AND cs.SportType = 1;

	IF EXISTS (	SELECT 1 FROM Temp_ExistedCust) THEN
		INSERT INTO CTS_DataCenter.Customer_InitialSmart_BySport_Log (CustID, SportType, Probability, SourceCreatedDate, InsertedTime)
		SELECT	tmp.CustID
			,	CONST_SPORTTYPE_SOCCER AS SportType
			,	tmp.Probability
			,	tmp.SourceCreatedDate
            ,   lv_CreatedDate
		FROM Temp_ExistedCust AS tec
			INNER JOIN Temp_Customer AS tmp ON tmp.CustID = tec.CustID;
	END IF;

    INSERT IGNORE INTO CTS_DataCenter.Customer_InitialSmart_BySport (CustID, SportType, Probability, SourceCreatedDate, InsertedTime)
    SELECT	tmp.CustID
		,	CONST_SPORTTYPE_SOCCER AS SportType
		,	tmp.Probability
		,	tmp.SourceCreatedDate
        ,   lv_CreatedDate
	FROM Temp_Customer AS tmp;
	
	SELECT tec.CustID
	FROM Temp_ExistedCust AS tec;

END$$
DELIMITER ;