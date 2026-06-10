/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_RT_RawTrans_Insert`;


CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_RT_RawTrans_Insert`(
	IN ip_RawTransJson LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20190610@Casey.Huynh
	Task : Insert to Raw Table
	DB: FPS_RawTrans
	Original:

	Revisions:
			#1. [20201006@CaseyHuynh][143011]: Move New Server, Move table RawTransaction from DB "DCS_RawTransaction" to "DCS_DataCenter"
            #2. [20201019@CaseyHuynh][143011]:	Move Server, Phase 2
    Reviewer:
	Param's Explanation (filtered by):
	*/

	DROP TEMPORARY TABLE IF EXISTS Temp_Transactions;
	CREATE TEMPORARY TABLE Temp_Transactions
    (
		LoginName					VARCHAR(100) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NOT NULL	
		, SubscriberName			VARCHAR(50) 						NOT NULL
		, TransTime					TIMESTAMP(4)	 					NOT NULL
		, DeviceCode				VARCHAR(32) 						NULL		COMMENT 'Device Inject Code: 32 characters is auto generated'
		, FingerprintCode			VARCHAR(620)						NULL		COMMENT 'Device Fingerprint Codes, the hashcode bases on the set attributes'    
		, FingerprintMoreInfo		VARCHAR(250)						NULL
		, UserAgent					VARCHAR(1000)						NULL
		, IP						VARCHAR(50) 						NULL
        , IPID						DECIMAL(50,0)						NULL
        , Flagged					SMALLINT							NULL
		, PluginID					BIGINT 								NULL	
		, URL						VARCHAR(500) 						NULL
        , `Action`					VARCHAR(100) 						NULL
		, ActionResult				VARCHAR(100) 						NULL
		, InvalidDevice				VARCHAR(1000)						CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NULL
		, TransStatus				BIT(16)								NULL
    );     
		
	INSERT INTO Temp_Transactions
	(	LoginName
		, SubscriberName
		, TransTime
		, DeviceCode
		, FingerprintCode
		, FingerprintMoreInfo
		, UserAgent
		, IP
        , IPID
        , Flagged
		, PluginID
		, URL
        , Action
		, ActionResult
        , InvalidDevice
		, TransStatus
	)
	SELECT
			rt.LoginName
			, rt.SubscriberName
			, rt.TransTime
			, (CASE WHEN rt.DeviceCode IS NULL THEN NULL ELSE rt.DeviceCode END) AS DeviceCode
			, (CASE WHEN rt.FingerprintCode IS NULL OR rt.DeviceCode IS NULL	THEN NULL ELSE rt.FingerprintCode 		END) AS FingerprintCode
			, (CASE WHEN rt.FingerprintMoreInfo IS NULL OR rt.DeviceCode IS NULL THEN NULL ELSE rt.FingerprintMoreInfo	END) AS FingerprintMoreInfo
			, LEFT((CASE WHEN rt.UserAgent IS NULL THEN NULL ELSE rt.UserAgent END),1000) AS UserAgent
			, (CASE WHEN rt.IP IS NULL THEN NULL ELSE rt.IP END) AS IP
            , (CASE WHEN rt.IPID = 0 THEN NULL ELSE rt.IPID END) AS IPID
            , (CASE WHEN rt.Flagged = -1 THEN NULL ELSE rt.Flagged END) AS Flagged
			, (CASE WHEN rt.PluginID = 0 THEN NULL ELSE rt.PluginID END) AS PluginID            
			, (CASE WHEN rt.URL IS NULL THEN NULL ELSE rt.URL END) AS URL
            , (CASE WHEN rt.Action IS NULL THEN NULL ELSE rt.Action END) AS Action
			, (CASE WHEN rt.ActionResult IS NULL THEN NULL ELSE rt.ActionResult END) AS ActionResult
            , LEFT((CASE WHEN rt.InvalidDevice IS NULL THEN NULL ELSE rt.InvalidDevice END),1000) AS InvalidDevice
			, TransStatus
	FROM	JSON_TABLE(
			ip_RawTransJson,
			 "$[*]" COLUMNS(
							  LoginName				VARCHAR(100) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' PATH "$.LoginName"       
							, SubscriberName		VARCHAR(50) 	PATH "$.SubscriberName"   
							, TransTime				TIMESTAMP(4) 	PATH "$.TransTime"
							, DeviceCode			VARCHAR(32)		PATH "$.DeviceCode"
							, FingerprintCode		VARCHAR(620)	PATH "$.FingerprintCode"
							, FingerprintMoreInfo	VARCHAR(250)	PATH "$.FingerprintMoreInfo"
							, UserAgent				TEXT 			PATH "$.UserAgent"
							, IP					VARCHAR(50) 	PATH "$.IP"
                            , IPID					DECIMAL(50,0)	PATH "$.IPId"
                            , Flagged				SMALLINT		PATH "$.Flagged"
							, PluginID				BIGINT 			PATH "$.PluginID"
							, URL					VARCHAR(500) 	PATH "$.URL"
                            , Action				VARCHAR(100)	PATH "$.Action"
							, ActionResult			VARCHAR(100) 	PATH "$.ActionResult"
                            , InvalidDevice			TEXT	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' PATH "$.InvalidDevice"
                            , TransStatus	BIT(16)		 					PATH "$.TransStatus"
							)
		   ) AS  rt; 
	
	INSERT INTO DCS_DataCenter.RawTransaction
	(	LoginName
		, SubscriberName
		, TransTime
		, CreatedDate
		, DeviceCode
		, FingerprintCode
		, FingerprintMoreInfo
		, UserAgent
		, IP
        , IPID
        , Flagged
		, PluginID
		, URL
        , Action
		, ActionResult
        , InvalidDevice
        , TransStatus
	)
	SELECT
		rt.LoginName
		, rt.SubscriberName
		, rt.TransTime
		, DATE(rt.TransTime) AS CreatedDate
		, rt.DeviceCode
		, rt.FingerprintCode
		, rt.FingerprintMoreInfo
		, rt.UserAgent
		, rt.IP
        , rt.IPID
        , rt.Flagged
		, rt.PluginID
		, rt.URL
        , rt.Action
		, rt.ActionResult
        , rt.InvalidDevice
        , rt.TransStatus
	FROM	Temp_Transactions AS rt;
	
    DROP TEMPORARY TABLE IF EXISTS Temp_Transactions;
END$$
DELIMITER ;
