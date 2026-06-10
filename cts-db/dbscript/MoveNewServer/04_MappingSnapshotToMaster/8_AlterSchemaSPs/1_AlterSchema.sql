/*
	Created: 20201005@Casey.Huynh
	Task : Change Definition for DeviceCode, FingerprintCode, FingerprintMoreInfo, UserAgent, InvalidDevice
	DB: DCS_DataCenter
	Original:

	Revisions:

    Reviewer:
		#1 [Name]: New
	Param's Explanation (filtered by):
*/
ALTER TABLE DCS_DataCenter.RawTransaction
MODIFY 		DeviceCode 			VARCHAR(32) NULL
, MODIFY  	FingerprintCode 	VARCHAR(620) NULL
, MODIFY	FingerprintMoreInfo VARCHAR(250) NULL
, MODIFY	InvalidDevice 		VARCHAR(1000)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NULL
, MODIFY	UserAgent			VARCHAR(1000) NULL
;

ALTER TABLE DCS_DataCenter.ProcessedTransaction
MODIFY 		DeviceCode 			VARCHAR(32) NULL
, MODIFY  	FingerprintCode 	VARCHAR(620) NULL
, MODIFY	FingerprintMoreInfo VARCHAR(250) NULL
, MODIFY	InvalidDevice 		VARCHAR(1000)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NULL
, MODIFY	UserAgent			VARCHAR(1000) NULL
;

ALTER TABLE DCS_DataCenter.Transaction
MODIFY  	FingerprintCode 	VARCHAR(620) NULL
, MODIFY	FingerprintMoreInfo VARCHAR(250) NULL
;

ALTER TABLE DCS_DataCenter.UserAgent
MODIFY	UserAgent			VARCHAR(10000) NULL
