/***STEP 00: PREPARE DATA TEST**************************************************/
# 1. Config Conection client: Right Click on Connection > Select 'Edit Connection' > Select Advance Tab > Add new line with text "OPT_LOCAL_INFILE=1" in "Others" textbox

# 2. SET GLOBAL local_infile=1;

# 3. IMPORT Data:
TRUNCATE TABLE DCS_DataCenter.RawTransaction;
DROP TABLE IF EXISTS DCS_DataCenter.RawTransaction_CSBK;
CREATE TABLE DCS_DataCenter.RawTransaction_CSBK SELECT * FROM DCS_DataCenter.RawTransaction;

LOAD DATA LOCAL INFILE 'D:/SPU/DCS_DataTest/PackDay09_10K.csv'
INTO TABLE DCS_DataCenter.RawTransaction_CSBK
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SET @i=0;
UPDATE  DCS_DataCenter.RawTransaction_CSBK
SET TransId=@i:=@i+1
	,	IsProcessed = 0
    ,	TransStatus = 0
;

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

INSERT IGNORE INTO DCS_DataCenter.RawTransaction SELECT * FROM DCS_DataCenter.RawTransaction_CSBK LIMIT 200;

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



UPDATE DCS_DataCenter.SystemSetting
SET VValue = 0
WHERE VGroup = 'DCS_RawTrans_Transform' AND VName='MinRawTransId';

SELECT * FROM DCS_DataCenter.SystemSetting WHEre VGroup = 'DCS_RawTrans_Transform' AND VName='MinRawTransId';

CALL DCS_DC_Transform_RawTrans_GetPackage(0,10,2)

SELECT * FROM http://spu-main.nexdev.net/quartz/Authenticate/Login?ReturnUrl=%2Fquartz%2F