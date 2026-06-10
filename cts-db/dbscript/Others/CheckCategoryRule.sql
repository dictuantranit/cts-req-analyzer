SELECT * FROM  CTS_DataCenter.CTSCustomerClassification; WHERE CustID =1287 ;
SELECT * FROM  CTS_DataCenter.CTSCustomerClassification_History; WHERE CustID =1287;
CALL CTS_DataCenter.CTS_DC_GetCustomerClassificationIntervalScan(12,2);
CALL CTS_DataCenter.CTS_DC_GetCustomerClassificationIntervalScan_Complete('[{"CustId": 1438,"SportGroupId":1}]');
CALL CTS_DataCenter.CTS_DC_AddCTSCustomerClassification(1287,31,130,9,'1,2,3','Casey Huynh Add meo', 123, @meo);
;

SELECT @meo;
 INSERT INTO CTS_DataCenter.CTSCustomerClassification_History(CustID, CTSCustID, CategoryID
					,SportGroupID ,LastModifiedDate, LastModifiedBy, LastScannedDate, ActionType, IsAuto)
	SELECT 	1287
		, 	31
        , 	130
        , 	s.SportGroupID
        , 	vr_CurrentTime
        , 	ip_CreatedBy
        , 	DATE(vr_CurrentTime)
        ,	0 AS ActionType # Add Action
        ,	0 AS IsAuto
    FROM tempSportGroupID AS s;


SELECT * FROM tempSportGroupID;
SELECT @meo;
CREATE PROCEDURE `CTS_DataCenter`.`CTS_DC_AddCTSCustomerClassification`(
		IN ip_CustID			BIGINT UNSIGNED
	, 	IN ip_CTSCustID			BIGINT UNSIGNED	
    ,	IN ip_SubscriberID		INT
	,	IN ip_CategoryID		SMALLINT
    , 	IN ip_SportGroupIDList 	VARCHAR(50)
    , 	IN ip_Remark 			VARCHAR(300)
	,	IN ip_CreatedBy 		INT
    
    , 	OUT op_ErrorMessage 	VARCHAR(200)
)

TRUNCATE TABLE CTSCustomerClassification;
TRUNCATE TABLE CTSCustomerClassification_History;

CALL CTS_DC_AutoTagCustomerClassification('[{"CustId": 1438, "SportGroupId": 0, "CategoryId": 2, "CreatedTime": "2020-06-05", "TurnoverRM": 0, "WinlossRM": 0, "BetCount": 0, "ActiveDays": 10}]');
CALL CTS_DC_AutoTagCustomerClassification('[{"CustId": 1438, "SportGroupId": 0, "CategoryId": 0, "CreatedTime": "2020-06-05", "TurnoverRM": 0, "WinlossRM": 0, "BetCount": 0, "ActiveDays": 10}]');
CALL CTS_DC_AutoTagCustomerClassification('[{"CustId": 1438, "SportGroupId": 1, "CategoryId": 7, "CreatedTime": "2020-06-05", "TurnoverRM": 1000, "WinlossRM": 1100, "BetCount": 100, "ActiveDays": 10}]');
CALL CTS_DC_AutoTagCustomerClassification('[{"CustId": 1438, "SportGroupId": 1, "CategoryId": 7, "CreatedTime": "2020-06-05", "TurnoverRM": 1000, "WinlossRM": 1100, "BetCount": 100, "ActiveDays": 10}]');
CALL CTS_DC_AutoTagCustomerClassification('[{"CustId": 1438, "SportGroupId": 0, "CategoryId": 2, "CreatedTime": "2020-06-05", "TurnoverRM": 1000, "WinlossRM": 1100, "BetCount": 100, "ActiveDays": 10}]');
CALL CTS_DC_AutoTagCustomerClassification('[{"CustId": 1438, "SportGroupId": 0, "CategoryId": 0, "CreatedTime": "2020-06-05", "TurnoverRM": 1000, "WinlossRM": 1100, "BetCount": 100, "ActiveDays": 10}]');
CALL CTS_DC_AutoTagCustomerClassification('[{"CustId": 1438, "SportGroupId": 1, "CategoryId": 5, "CreatedTime": "2020-06-05", "TurnoverRM": 1000, "WinlossRM": 1100, "BetCount": 100, "ActiveDays": 10}]');
CALL CTS_DC_AutoTagCustomerClassification('[{"CustId": 1438, "SportGroupId": 2, "CategoryId": 5, "CreatedTime": "2020-06-05", "TurnoverRM": 1000, "WinlossRM": 1100, "BetCount": 100, "ActiveDays": 10}]');
CALL CTS_DC_AutoTagCustomerClassification('[{"CustId": 1438, "SportGroupId": 1, "CategoryId": 6, "CreatedTime": "2020-06-05", "TurnoverRM": 1000, "WinlossRM": 1100, "BetCount": 100, "ActiveDays": 10}]');

SELECT * FROM Temp_NewClassification;   

SELECT *
FROM  CTSCustomerClassification
WHERE CustID = 1438;

SELECT *
FROM  CTSCustomerClassification_History
WHERE CustID = 1438;

SELECT *
FROM CustomerCategory;

SELECT *
FROM CTS_DataCenter.CTSCustomer
WHERE	RoleID = 1 ;