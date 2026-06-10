/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_InitialSmart_BySport_Insert`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_InitialSmart_BySport_Insert`(
		IN 	ip_CustInfo		JSON
)
SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250908@Logan.Nguyen
		Task:	 	Customer Initial Smart B - Insert data after getting from TW
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250908@Logan.Nguyen: Created [Redmine ID: #237405]
				
		Example:
			CALL CTS_DC_CustClassification_InitialSmart_BySport_Insert (@ip_CustInfo:='[{"CustID":1275, "SportType":2, "Probability":0.1419399977,"PredictTime":"2024-05-30T03:02:26"},{"CustID":1277,"Probability":0.7015600204,"PredictTime":"2024-05-30T03:03:26"},{"CustID":1280,"Probability":0.7505900264,"PredictTime":"2024-05-31T03:02:26"},{"CustID":1282,"Probability":0.7498900294,"PredictTime":"2024-05-30T07:02:26"}]');
	*/
	DECLARE lv_CreatedDate DATETIME(3);
	DECLARE	CONST_SPORTTYPE_GENARAL		 		INT DEFAULT 0;
	DECLARE	CONST_SPORTTYPE_SOCCER		 		INT DEFAULT 1;
	DECLARE	CONST_SPORTTYPE_BASKETBALL			INT DEFAULT 2;
    
	SET lv_CreatedDate = CURRENT_TIMESTAMP(3);


	DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
	CREATE TEMPORARY TABLE Temp_Customer(
			CustID 				BIGINT UNSIGNED NOT NULL 
        ,   SportType           INT
		,   Probability 		DECIMAL(8,4)
		,   SourceCreatedDate 	DATETIME(3)
		,	PRIMARY KEY (CustID, SportType)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_ExistedCust;
	CREATE TEMPORARY TABLE Temp_ExistedCust(
			CustID 				BIGINT UNSIGNED NOT NULL 
        ,   SportType           INT
		,	PRIMARY KEY (CustID, SportType)
	);

	INSERT IGNORE INTO Temp_Customer(CustID, SportType, Probability, SourceCreatedDate)
    SELECT	tmp.CustID
		,	tmp.SportType
		,	tmp.Probability
		,	tmp.SourceCreatedDate
    FROM JSON_TABLE(ip_CustInfo,
                        "$[*]" COLUMNS (CustID          			BIGINT			UNSIGNED	PATH "$.CustID"
									,	SportType					INT							PATH "$.SportType"
									,	Probability					DECIMAL(8,4)				PATH "$.Probability"
                                    ,   SourceCreatedDate		    DATETIME(3)					PATH "$.PredictTime"                                           
                                )) AS tmp;

	INSERT IGNORE INTO Temp_ExistedCust(CustID, SportType)
	SELECT	tmp.CustID
		,	tmp.SportType
	FROM CTS_DataCenter.Customer_InitialSmart_BySport AS cs
		INNER JOIN Temp_Customer AS tmp	ON tmp.CustID = cs.CustID AND cs.SportType = tmp.SportType;

	INSERT INTO CTS_DataCenter.Customer_InitialSmart_BySport_Log (CustID, SportType, Probability, SourceCreatedDate, InsertedTime)
	SELECT	tmp.CustID
		,	tmp.SportType
		,	tmp.Probability
		,	tmp.SourceCreatedDate
        ,   lv_CreatedDate
	FROM Temp_Customer AS tmp
		LEFT JOIN Temp_ExistedCust AS tec ON tmp.CustID = tec.CustID AND tec.SportType = tmp.SportType 
	WHERE tec.CustID IS NOT NULL OR tmp.SportType NOT IN (CONST_SPORTTYPE_GENARAL,CONST_SPORTTYPE_SOCCER,CONST_SPORTTYPE_BASKETBALL);

    INSERT IGNORE INTO CTS_DataCenter.Customer_InitialSmart_BySport (CustID, SportType, Probability, SourceCreatedDate, InsertedTime)
    SELECT	tmp.CustID
		,	tmp.SportType
		,	tmp.Probability
		,	tmp.SourceCreatedDate
        ,   lv_CreatedDate
	FROM Temp_Customer AS tmp
	WHERE tmp.SportType IN (CONST_SPORTTYPE_GENARAL,CONST_SPORTTYPE_SOCCER,CONST_SPORTTYPE_BASKETBALL);
	
	SELECT tec.CustID, tec.SportType
	FROM Temp_ExistedCust AS tec;

END$$
DELIMITER ;