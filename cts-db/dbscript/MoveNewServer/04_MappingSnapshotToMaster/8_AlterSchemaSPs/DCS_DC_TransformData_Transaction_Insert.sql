DELIMITER $$

DROP PROCEDURE IF EXISTS DCS_DataCenter.DCS_DC_TransformData_Transaction_Insert$$

CREATE DEFINER=`fps`@`%` PROCEDURE DCS_DataCenter.DCS_DC_TransformData_Transaction_Insert(IN ip_FromTransID BIGINT, IN ip_ToTransID BIGINT)
BEGIN
/*
	Created: 20190730@Casey.Huynh
	Task : Insert Transaction
	DB: DCS_DataCenter
	Original:

	Revisions:
		#1. [20191217@CaseyHuynh][#125530]: Implement LastLoginTime 
        #2. [20200416@Terry]: Archive Completed RawTransaction to DCS_DataCenter.ProcessedTransaction.
		#3. [20200506@CaseyHuynh][133486]: Not Deposit Account
				+ Insert Ignore On Duplicate, Update (LastLoginTime, IsCTSTransfromed)
                 + Remove code "INSERT IGNORE INTO DCS_DataCenter.TransactionIP_TransformTemp"
		#4. [20200515@CaseyHuynh][133263]: Update LastLoginTime
        #5  [20200918@CaseyHuynh][137963]: Change column TransID to RawTransID
        #6. [20201006@CaseyHuynh][143011]: Move New Server, Move table RawTransaction from DB "DCS_RawTransaction" to "DCS_DataCenter"
        #7. [20201019@CaseyHuynh][143011]:	Move Server, Phase 2	
    Reviewer:
		#1 [Name]: New
	Param's Explanation (filtered by):
*/
	DECLARE		SysMinCreatedDate	DATETIME;
    
	### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200) DEFAULT 'DCS_DC_TransformData_Transaction_Insert' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    SET		vrExecKey = CRC32((UUID_Short()));    
    SET		vrNotes = 'Insert Transaction';		
    SET 	vrStepID = 1;
    SET 	vrStartTime = CURRENT_TIMESTAMP(4);
    
    INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime, FromID, ToID)
    VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime, ip_FromTransID, ip_ToTransID);
	
	### PERFORMANCE: END  

    # =================================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_RawTransaction;
	CREATE TEMPORARY TABLE IF NOT EXISTS Temp_RawTransaction (
		TransID					BIGINT UNSIGNED NOT NULL
		, LoginName				VARCHAR(100)  CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NOT NULL
		, TransTime				TIMESTAMP(4) 		NOT NULL
		, SubscriberID			INT NULL			NULL	
        , AccountID				BIGINT	UNSIGNED 	NULL
        , SubscriberType		TINYINT	UNSIGNED	NULL
        , URLDetails			VARCHAR(250)		NULL
		, URLID					INT					NULL
		, DeviceCode			VARCHAR(32) 		NULL COMMENT 'Trans Device Code'
        , UserAgentKey			VARCHAR(32)			NULL
		, IP					VARCHAR(50) 		NULL
        , IPID					DECIMAL(50,0)		NULL	
		, ActionResultID		INT					NULL
		, Flagged				SMALLINT 			NULL COMMENT 'captcha & browserless'
		, PluginID				BIGINT 				NULL
		, TransStatus			BIT(16) 			NULL
		, CreatedDate			DATETIME 			NULL COMMENT 'Date Only' NOT NULL
		, InsertTime			TIMESTAMP(4) 		NULL
        , FingerprintCode		VARCHAR(620)
        , FingerprintMoreInfo	TEXT	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
	);
    # =================================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_Account;
	CREATE TEMPORARY TABLE  Temp_Account(
		LoginName				VARCHAR(100) CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NOT NULL
		, SubscriberID			INT NULL
        , SubscriberType		TINYINT	UNSIGNED	NULL
    );
    SET SysMinCreatedDate = (SELECT DATE(VValue) FROM DCS_DataCenter.SystemSetting WHERE VGroup = "DCS_Device_Transform" AND VName = "MinCreatedDate");  
	INSERT INTO Temp_RawTransaction(TransID, LoginName, TransTime, SubscriberID, SubscriberType, DeviceCode
			, URLDetails, UserAgentKey, IP, IPID, ActionResultID, Flagged, PluginID, TransStatus, CreatedDate, FingerprintCode, FingerprintMoreInfo)
	SELECT  rt.TransID
			, rt.LoginName
            , rt.TransTime
            , su.SubscriberID
            , su.SubscriberType        
            , rt.DeviceCode
            , rt.URL
            , MD5(LOWER(rt.UserAgent))
            , rt.IP
            , rt.IPID
            , ar.ActionResultID
            , rt.Flagged
            , rt.PluginID
            , rt.TransStatus
            , rt.CreatedDate
            , rt.FingerprintCode
            , rt.FingerprintMoreInfo
	FROM		DCS_DataCenter.RawTransaction AS rt
    INNER JOIN	CTS_Admin.Subscriber AS su
				ON	rt.SubscriberName = su.SubscriberName
	INNER JOIN	DCS_DataCenter.ActionResult AS ar
				ON	rt.Action = ar.Action
					AND IFNULL(rt.ActionResult,'') = ar.ActionResult
	WHERE		rt.IsProcessed = 0
				AND rt.TransID BETWEEN ip_FromTransID AND ip_ToTransID
                AND rt.CreatedDate 	>=	SysMinCreatedDate;
 
    	
    #===INSERT SUBCRIBERURL    
    INSERT IGNORE INTO DCS_DataCenter.URL(URLDetails, SubscriberID, CreatedDate)
	SELECT		trt.URLDetails
                , trt.SubscriberID
                , MIN(trt.CreatedDate)
	FROM		Temp_RawTransaction AS trt
	GROUP BY	trt.SubscriberID, trt.URLDetails;    

    
	# Insert New Account
    INSERT IGNORE INTO DCS_DataCenter.Account(LoginName, SubscriberID, SubscriberType, CreatedDate, InsertTime, CreatedTime, LastLoginTime)
    SELECT		trt.LoginName
				, trt.SubscriberID
				, trt.SubscriberType
				, MIN(trt.CreatedDate)
				, CURRENT_TIMESTAMP(4)		AS InsertTime
                , MIN(trt.TransTime) 		AS CreatedTime
                , MAX(trt.TransTime)		AS LastLoginTime
    FROM		Temp_RawTransaction AS trt 
    GROUP BY	trt.SubscriberID, trt.SubscriberType, trt.LoginName
    ON DUPLICATE KEY UPDATE IsCTSTransformed = (CASE WHEN IsCTSTransformed = -3 THEN -1 END );
    
    # Update AccountID to Temp_Transaction
    UPDATE 		Temp_RawTransaction AS trt
    INNER JOIN	DCS_DataCenter.Account AS ac
				ON 	trt.SubscriberID = ac.SubscriberID 
					AND trt.LoginName = ac.LoginName
	LEFT JOIN	DCS_DataCenter.URL	AS ur
				ON	trt.URLDetails = ur.URLDetails
    SET			trt.AccountID = ac.AccountID
				, trt.URLID = ur.URLID;   
    
    #Remove Temp Trans If AccountID Is NULL
    DELETE 	trt
    FROM	Temp_RawTransaction AS trt
    WHERE 	trt.AccountID IS NULL;    
    
    UPDATE 		DCS_DataCenter.Association AS ass
    INNER JOIN	(SELECT DISTINCT AccountID FROM Temp_RawTransaction trt) AS trtAcc
				ON ass.AccountID = trtAcc.AccountID
    INNER JOIN	DCS_DataCenter.Account AS acc
				ON ass.AccountID = acc.AccountID
	SET			ass.IsCTSTransformed = -1
    WHERE		acc.IsCTSTransformed = -1;		
    
	
    DROP TEMPORARY TABLE IF EXISTS Temp_LastLoginTime;
    CREATE TEMPORARY TABLE Temp_LastLoginTime
    (
		SubscriberID	INT
        , AccountID		BIGINT UNSIGNED
        , LastLoginTime	TIMESTAMP(4)
    );
   
    INSERT INTO Temp_LastLoginTime(SubscriberID, AccountID, LastLoginTime)   
    SELECT 		acc.SubscriberID, acc.AccountID, tac.LastLoginTime
    FROM		DCS_DataCenter.Account 	AS acc
    INNER JOIN	(SELECT		trt.AccountID
							, MAX(trt.TransTime) 	AS LastLoginTime
				 FROM		Temp_RawTransaction 	AS trt
                 GROUP BY	trt.AccountID) AS tac
				ON	acc.AccountID = tac.AccountID
    WHERE		tac.LastLoginTime > acc.LastLoginTime;    

    INSERT INTO DCS_DataCenter.LastLoginTime_TransformTemp(CTSCustID, LastLoginTime)
    SELECT 		cus.CTSCustID
				, MAX(lgn.LastLoginTime)
    FROM		Temp_LastLoginTime AS lgn
    INNER JOIN  CTS_DataCenter.CustDCSAccount AS cus
				ON lgn.AccountID = cus.AccountID
	GROUP BY 	cus.CTSCustID;    
	
    UPDATE		DCS_DataCenter.Account 	AS acc
    INNER JOIN	Temp_LastLoginTime	AS tll
				ON acc.AccountID = tll.AccountID
	SET			acc.LastLoginTime = tll.LastLoginTime;    

    INSERT IGNORE INTO  DCS_DataCenter.Transaction(RawTransID, LoginName, TransTime, SubscriberID, AccountID, URLID, UserAgentKey
						, IP, IPID, ActionResultID, Flagged, PluginID, TransStatus, CreatedDate, InsertTime, DeviceCode, FingerprintCode, FingerprintMoreInfo)
   	SELECT 		trt.TransID
				, trt.LoginName
                , trt.TransTime                
				, trt.SubscriberID
                , trt.AccountID
				, trt.URLID
                , trt.UserAgentKey
                , trt.IP
                , trt.IPID
                , trt.ActionResultID
				, trt.Flagged
                , trt.PluginID
                , trt.TransStatus				
				, trt.CreatedDate                
                , CURRENT_TIMESTAMP(4) 	AS InsertTime
                , trt.DeviceCode
                , FingerprintCode
                , FingerprintMoreInfo
	FROM		Temp_RawTransaction AS trt;	

    #================================================================
	INSERT IGNORE INTO DCS_DataCenter.ProcessedTransaction(
				LoginName, SubscriberName, TransTime, CreatedDate, DeviceCode, FingerprintCode, FingerprintMoreInfo, UserAgent
				, IP, IPID, Flagged, PluginID, URL, Action, ActionResult, InvalidDevice, TransStatus, IsProcessed, TransID)
	SELECT		rt.LoginName, rt.SubscriberName, rt.TransTime, rt.CreatedDate, rt.DeviceCode, rt.FingerprintCode, rt.FingerprintMoreInfo, rt.UserAgent
				, rt.IP, rt.IPID, rt.Flagged, rt.PluginID, rt.URL, rt.Action, rt.ActionResult, rt.InvalidDevice, rt.TransStatus, rt.IsProcessed, rt.TransID
	FROM 		DCS_DataCenter.RawTransaction AS rt
	INNER JOIN	Temp_RawTransaction	AS tmp_rm
				ON	rt.TransID = tmp_rm.TransID
				AND rt.CreatedDate = tmp_rm.CreatedDate;

        
	DELETE		rt
	FROM 		DCS_DataCenter.RawTransaction AS rt
	INNER JOIN	Temp_RawTransaction	AS tmp_rm
				ON	rt.TransID = tmp_rm.TransID
					AND rt.CreatedDate = tmp_rm.CreatedDate;
    
	#=================================================================	
  
	### PERFORMANCE
	SET	vrEndTime = CURRENT_TIMESTAMP(4);
    
	UPDATE DCS_DataCenter.zzTracePerformance AS z 
	SET 
		z.EndTime = vrEndTime,
		z.Duration = TIMESTAMPDIFF(MICROSECOND,
			vrStartTime,
			vrEndTime)
	WHERE
		z.ExecKey = vrExecKey
			AND z.StepID = z.StepID;
    ### PERFORMANCE: END    
END$$
DELIMITER ;
