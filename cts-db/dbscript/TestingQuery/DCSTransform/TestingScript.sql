/***STEP 00: PREPARE DATA TEST**************************************************/
# 1. Config Conection client: Right Click on Connection > Select 'Edit Connection' > Select Advance Tab > Add new line with text "OPT_LOCAL_INFILE=1" in "Others" textbox

# 2. SET GLOBAL local_infile=1;

# 3. IMPORT Data:
TRUNCATE TABLE DCS_DataCenter.RawTransaction;
DROP TABLE IF EXISTS DCS_DataCenter.RawTransaction_CSBK;
CREATE TABLE DCS_DataCenter.RawTransaction_CSBK SELECT * FROM DCS_DataCenter.RawTransaction;

LOAD DATA LOCAL INFILE 'D:/SPU/DCS_DataTest/PackDay08_10K.csv'
INTO TABLE DCS_DataCenter.RawTransaction
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'D:/SPU/DCS_DataTest/PackDay09_10K.csv'
INTO TABLE DCS_DataCenter.RawTransaction_CSBK
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
*/
ALTER TABLE DCS_DataCenter.Transaction AUTO_INCREMENT = 1000000001;


SET @i=2000000000;
UPDATE  DCS_DataCenter.RawTransaction_CSBK
SET TransId=@i:=@i+1
	,	IsProcessed = 0
    ,	TransStatus = 0
;

SELECT  * FROM DCS_DataCenter.RawTransaction_CSBK 
WHERE 	TransID IN (2000000004,2000000238);

UPDATE 	DCS_DataCenter.RawTransaction_CSBK
SET 	LoginName = 'Vào Bờ'
WHERE 	TransID IN (2000000238);

UPDATE 	DCS_DataCenter.RawTransaction_CSBK
SET 	TransStatus = 8
WHERE 	TransID IN (2000000004,2000000238);

DROP TEMPORARY TABLE URL_Testing;
CREATE TEMPORARY TABLE URL_Testing(ID INT PRIMARY KEY AUTO_INCREMENT, P1 INT, P2 INT, SubscriberName VARCHAR(200)
,  URL Varchar(500), NewURL Varchar(500), Part1 Varchar(500), Part2 VARCHAR(500),  Part3 VARCHAR(500));

INSERT INTO URL_Testing(URL,SubscriberName)
SELECT DISTINCT URL, LOWER(SubscriberName) FROM DCS_DataCenter.RawTransaction_CSBK;

SELECT DISTINCT(INSTR(URL, '//')) FROM URL_Testing t;

UPDATE URL_Testing 
SET P1 = INSTR(URL, '//')+2;

UPDATE URL_Testing 
SET P2 = (CASE WHEN (LOCATE('/',URL,INSTR(URL, '//')+3)) = 0 THEN LENGTH(URL) 
			ELSE LOCATE('/',URL,INSTR(URL, '//')+3) END );

UPDATE URL_Testing 
SET Part2 = MID(URL, P1, P2-P1);

UPDATE URL_Testing 
SET Part1 = CONCAT(SubscriberName,'.Testing.Page',ID,'.com');

UPDATE URL_Testing 
SET NewURL = REPLACE(URL,Part2,Part1);

UPDATE URL_Testing 
SET NewURL = REPLACE(NewURL,'Fps','New');

SELECT t.* FROM URL_Testing t;

UPDATE DCS_DataCenter.RawTransaction_CSBK b
INNER JOIN URL_Testing t ON b.URL = t.URL
SET b.URL = t.NewURL;

SELECT INSTR(URL, '//')+2 AS P1, (CASE WHEN (LOCATE('/',URL,INSTR(URL, '//')+3)) = 0 THEN LENGTH(URL) END ) AS P2, MID(URL, INSTR(URL, '//')+2, LOCATE('/',URL,INSTR(URL, '//')+3)- INSTR(URL, '//')-2),  t.* FROM URL_Testing t ORDER BY P1 DESC;

SELECT * FROM DCS_DataCenter.RawTransaction_CSBK b;

SELECT COUNT(DISTINCT(URL)) FROM DCS_DataCenter.RawTransaction_CSBK ORDER BY URL;
SELECT URL, COUNT(1) A FROM DCS_DataCenter.RawTransaction_CSBK GROUP BY URL ORDER BY A DESC;

DROP TEMPORARY TABLE IF EXISTS TempLoginName;
CREATE TEMPORARY TABLE TempLoginName(ID INT auto_increment primary key, SubscriberName Varchar(50), SubscriberID INT, LoginName Varchar(50), NewName Varchar(50));

INSERT INTO TempLoginName(LoginName, SubscriberName)
SELECT DISTINCT LoginName, SubscriberName  FROM DCS_DataCenter.RawTransaction_CSBK ;

UPDATE TempLoginName l
INNER JOIN CTS_Admin.Subscriber s on l.SubscriberName = s.SubscriberName
SET l.SubscriberID = s.SubscriberID;

SELECT * FROM TempLoginName;
SELECT * FROM DCS_DataCenter.RawTransaction_CSBK ;

CREATE TEMPORARY TABLE TempLoginName_V1 SELECT * from TempLoginName;

ALTER  TABLE TempLoginName_V1 ADD NUM INT;

ALTER  TABLE TempLoginName_V1 ADD CTSRegisterName VARCHAR(50);


TRUNCATE TABLE TempLoginName_V1;
INSERT INTO TempLoginName_V1
seleCT *, ROW_NUMBER() OVER(PARTITION BY SubscriberID)
fROM TempLoginName;

DROP TEMPORARY TABLE IF EXISTS TempMappingCust;
CREATE TEMPORARY TABLE TempMappingCust(CTSCustID BIGINT UNSIGNED, SubscriberID INT, SubscriberName VARCHAR(50), UserName VARCHAR(50), RegisterName VARCHAR(50))
;
INSERT INTO TempMappingCust(CTSCustID,SubscriberID, UserName, RegisterName)
SELECT CTSCustID,SubscriberID, UserName, IFNULL(RegisterName,UserName)
FROM CTS_DataCenter.CTSCustomer 
WHERE SubscriberID IS NOT NULL
ORDER BY RAND () LIMIT 50000;

alter TABLE TempMappingCust drop NUM ;
CREATE TEMPORARY TABLE TempMappingCust_V1 SELECt * FROM TempMappingCust;

truncate TABLE TempMappingCust_V1;

iNSERT INTO TempMappingCust_V1
seleCT *, ROW_NUMBER() OVER(PARTITION BY SubscriberID)
fROM TempMappingCust;

ALTER TABLE TempLoginName_V1 ADD INDEX A(SubscriberID,NUM);
ALTER TABLE TempLoginName_V1 ADD INDEX B(SubscriberName,LoginName);
ALTER TABLE TempMappingCust_V1 ADD INDEX B(SubscriberID,NUM);
ALTER TABLE RawTransaction_CSBK ADD INDEX A(SubscriberName,LoginName);

SELECT * FROM TempLoginName_V1 as a
INNER JOIN TempMappingCust_V1 b on a.SubscriberID = b.SubscriberID and a.NUM=b.NUM;

update TempLoginName_V1 as a
INNER JOIN TempMappingCust_V1 b on a.SubscriberID = b.SubscriberID and a.NUM=b.NUM
SET a.CTSRegisterName = b.RegisterName;


UPDATE DCS_DataCenter.RawTransaction_CSBK b
INNER JOIN TempLoginName_V1 as a ON a.LoginName = b.LoginName and a.SubscriberName = b.SubscriberName
SET b.LoginName = IFNULL(a.CTSRegisterName,b.LoginName);

SELECT * FROM DCS_DataCenter.RawTransaction_CSBK b WHERE TransStatus = 8;

/***STEP 02: RESET Data************************************************************
#======RAW Trans===============================
TRUNCATE TABLE DCS_DataCenter.RawTransaction;
TRUNCATE TABLE DCS_DataCenter.ProcessedTransaction;
#======Transaction===============================
TRUNCATE TABLE DCS_DataCenter.Account;
TRUNCATE TABLE DCS_DataCenter.ActionResult;
TRUNCATE TABLE DCS_DataCenter.UserAgent;
TRUNCATE TABLE DCS_DataCenter.Browser;
TRUNCATE TABLE DCS_DataCenter.OS;
TRUNCATE TABLE DCS_DataCenter.URL ;
TRUNCATE TABLE DCS_DataCenter.Transaction;
#======Device===============================
TRUNCATE TABLE DCS_DataCenter.Device;
TRUNCATE TABLE DCS_DataCenter.DeviceCode;
TRUNCATE TABLE DCS_DataCenter.Association;
TRUNCATE TABLE DCS_DataCenter.Transaction07;

INSERT INTO DCS_DataCenter.RawTransaction SELECT * FROM DCS_DataCenter.RawTransaction_CSBK LIMIT 200;

SELECT * FROM DCS_DataCenter.RawTransaction ;
RawTransaction_CSBK
#====UPDATE SYSTEM PARAMETER===========================================
# Transform RawTransaction table to Transaction table (Proceess Account, UserAgent, OS, URL, Browser, Action Result)
UPDATE DCS_DataCenter.SystemSetting
SET VValue = 0
WHERE VGroup = 'DCS_RawTrans_Transform' AND VName='MinRawTransId';

# Transform Trasaction table to Transaction07 table (Process Device and Association)
UPDATE DCS_DataCenter.SystemSetting
SET VValue = 0
WHERE VGroup = 'DCS_Device_Transform' AND VName='MinTransId';

UPDATE DCS_DataCenter.SystemSetting
SET VValue = '2020-01-01'
WHERE VGroup = 'DCS_Device_Transform' AND VName='MinCreatedDate';
#===================================================================*/
#*******START SERVICE**********

#====Verify Data===========================================
#*****CHECK COUNT*******************************************
#******CASE 01: CHECK TRANSACTION
SELECT @CountTotal:=COUNT(1) FROM RawTransaction_CSBK; #EXPECTED: 90000
SELECT COUNT(1) FROM  RawTransaction WHERE IsProcessed<>-1; #EXPECTED: 0
SELECT @CountRaw:=COUNT(1) FROM RawTransaction;#EXPECTED: 1388
SELECT @CountProcessed:=COUNT(1) FROM ProcessedTransaction; #EXPECTED: 18612
SELECT @CountTransaction:=COUNT(1) FROM Transaction; #EXPECTED: 0
SELECT @CountTransaction07:=COUNT(1) FROM Transaction07; #EXPECTED: 18612
SELECT @CountProcessed -  @CountTransaction07; #EXPECTED: 0
SELECT @CountTotal - (@CountRaw + @CountTransaction07);#EXPECTED: 0

#******CASE 03: CHECK Account;
SELECT @CountAccount:=COUNT(1) FROM DCS_DataCenter.Account; #EXPECTED: 15973
SELECT @CountAccountProcessedTrans:=COUNT(DISTINCT LoginName, SubscriberName) FROM DCS_DataCenter.ProcessedTransaction; #EXPECTED: 15973
SELECT @CountAccountTransaction07:=COUNT(DISTINCT AccountID) FROM DCS_DataCenter.Transaction07; #EXPECTED: 15973

#******CASE 03: CHECK UserAgent;
SELECT @CountUserAgent:=COUNT(DISTINCT LOWER(UserAgent)) FROM DCS_DataCenter.RawTransaction_CSBK; #EXPECTED: 5907
SELECT @CountUserAgent:=COUNT(DISTINCT LOWER(UserAgent)) FROM DCS_DataCenter.UserAgent; #EXPECTED: 5876
SELECT @CountUserRawTransaction:=COUNT(DISTINCT Lower(UserAgent)) FROM DCS_DataCenter.RawTransaction; #EXPECTED: 972
SELECT @CountUserAgentProcessedTrans:=COUNT(DISTINCT LOWER(UserAgent)) FROM DCS_DataCenter.ProcessedTransaction; #EXPECTED: 5314
SELECT @CountUserAgentTransaction07:=COUNT(DISTINCT UserAgentKey) FROM DCS_DataCenter.Transaction07; #EXPECTED: 5314
SELECT @CountUserRawTransaction + @CountUserAgentProcessedTrans;

#******CASE 03: CHECK DEVICE***************

SELECT count(DISTINCT(UserAgent))
FROM (Select LOWER(UserAgent) AS UserAgent FROM DCS_DataCenter.RawTransaction
		UNION Select LOWER(UserAgent) UserAgent FROM  DCS_DataCenter.ProcessedTransaction) A; #5907

#******CASE 03: CHECK DEVICE
SELECT @CountDevice:=COUNT(1) FROM DCS_DataCenter.Device; #EXPECTED: 13384
SELECT @CountDeviceCode:= COUNT(1) FROM DCS_DataCenter.DeviceCode; #EXPECTED: 13385
SELECT @CountDeviceTrans07:= COUNT(DISTINCT DeviceID) FROM DCS_DataCenter.Transaction07; #13385
SELECT @CountDeviceCodeTrans07:= COUNT(DISTINCT DeviceCodeID) FROM DCS_DataCenter.Transaction07;  #EXPECTED: 13637
SELECT @CountDeviceProcessedTrans:= COUNT(DISTINCT DeviceCode) FROM DCS_DataCenter.ProcessedTransaction; #EXPECTED: 13637
 
#======Transaction===============================
SELECT * FROM  	DCS_DataCenter.Account;
SELECT * FROM  	DCS_DataCenter.ActionResult;
SELECT * FROM 	DCS_DataCenter.UserAgent;
SELECT * FROM  	DCS_DataCenter.Browser;
SELECT * FROM  	DCS_DataCenter.OS;
SELECT * FROM  	DCS_DataCenter.URL ORDER BY URLID DESC;
SELECT * FROM  	DCS_DataCenter.Transaction;
#======Device===============================
SELECT * FROM 	DCS_DataCenter.Device;
SELECT * FROM  	DCS_DataCenter.DeviceCode;
SELECT * FROM  	DCS_DataCenter.Association;
SELECT * FROM 	DCS_DataCenter.Transaction07;



	SELECT * FROM DCS_DataCenter.SystemSetting ;WHERE VName = 'MinCreatedDate';
	CALL DCS_DC_Transform_Device_GetPackage(100,2);

SELECT * FROM 

SELECT r.TransID, r.* FROM DCS_DataCenter.RawTransaction r;

/********************/
SELECT * FROM DCS_DataCenter.TransfromLog;
CALL 

UPDATE DCS_DataCenter.SystemSetting
SET VValue = 0
WHERE VGroup = 'DCS_RawTrans_Transform' AND VName='MinRawTransId';

SELECT * FROM DCS_DataCenter.SystemSetting WHEre VGroup = 'DCS_RawTrans_Transform' AND VName='MinRawTransId';

CALL DCS_DataCenter.DCS_DC_Transform_RawTrans_GetPackage(0,10,2);



SELECT * FROM http://spu-main.nexdev.net/quartz/Authenticate/Login?ReturnUrl=%2Fquartz%2F