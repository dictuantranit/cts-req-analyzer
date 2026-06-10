/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transform_Transaction_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transform_Transaction_Insert`(
        IN ip_FromTransID   BIGINT UNSIGNED
    ,   IN ip_ToTransID     BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20190730@Casey.Huynh
	    Task : Insert Transaction
	    DB: DCS_Extra
	    Original:

	    Revisions:
		    - 20191217@CaseyHuynh: Implement LastLoginTime [RedmineID: #125530]
            - 20200416@Terry: Archive Completed RawTransaction to DCS_Extra.ProcessedTransaction.
		    - 20200506@CaseyHuynh: Not Deposit Account. Insert Ignore On Duplicate, Update (LastLoginTime, IsCTSTransfromed). Remove code "INSERT IGNORE INTO DCS_Extra.TransactionIP_TransformTemp" [RedmineID: #133486]
		    - 20200515@CaseyHuynh: Update LastLoginTime [RedmineID: #133263]
            - 20200918@CaseyHuynh: Change column TransID to RawTransID [RedmineID: #137963]
            - 20201006@CaseyHuynh: Move New Server, Move table RawTransaction from DB "DCS_RawTransaction" to "DCS_Extra" [RedmineID: #143011]
            - 20201019@CaseyHuynh: Move Server, Phase 2	 [RedmineID: #143011]
            - 20201112@CaseyHuynh: GET Lastest Code Move Server P3, update Permission and Add Meta data, Update login Retry for unsuccsess Transform (-1,-2,-3) (SET IsCTSTransformed = 0 instead of -1) [RedmineID: #145271]
		    - 20201119@CaseyHuynh: Enhance New Retry transform association/account Flow, change log to CTS_Log DB [RedmineID: #145271]
		    - 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]
            - 20210622@Aries.Nguyen: Update coding convention and improve locking [Redmine ID: #157203]
			- 20211129@Casey.Huynh: Remove FingerprintMoreInfo Column [Redmine ID: #165167]
			- 20230323@Terry.Nguyen: Get InsertTime from RawTransaction [Redmine Id: #185185]
			- 20230426@Jonathan.Doan: Get BotDetectionValue from RawTransaction [Redmine ID: #186644]
            - 2023292023@Casey.Huynh: CTMAX, Velki, Remove insert into CTSCustomerLastLoginTimeProcess and enhance Performance [RedmineID: #190118]
            - 20230809@Jonathan.Doan: Add more field for IP detail [RedmineID: #192402]
            
	    Param's Explanation (filtered by):
		Example:
			CALL DCS_ET_Transform_Transaction_Insert(1,200);
    */
	DECLARE		lv_SysMinCreatedDate	DATETIME;    

    DROP TEMPORARY TABLE IF EXISTS Temp_RawTransaction;
	CREATE TEMPORARY TABLE IF NOT EXISTS Temp_RawTransaction (
		    TransID					BIGINT UNSIGNED NOT NULL
		,   LoginName				VARCHAR(100)  CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI' NOT NULL
		,   TransTime				TIMESTAMP(4) NOT NULL
		,   SubscriberID			INT 				
        ,   AccountID				BIGINT	UNSIGNED 	
        ,   SubscriberType		    TINYINT	UNSIGNED	
        ,   URLDetails			    VARCHAR(250)		
		,   URLID					INT					
		,   DeviceCode			    VARCHAR(32) COMMENT 'Trans Device Code'
        ,   UserAgentKey			VARCHAR(32)			
		,   IP					    VARCHAR(50) 		
        ,   IPID					DECIMAL(50,0)			
		,   ActionResultID		    INT					
		,   Flagged				    SMALLINT COMMENT 'captcha & browserless'
		,   PluginID				BIGINT 				
		,   TransStatus			    BIT(16) 			
		,   CreatedDate			    DATETIME COMMENT 'Date Only' 
		,   InsertTime			    TIMESTAMP(4) 		
        ,   FingerprintCode		    VARCHAR(620)
        ,   BotDetectionValue		BIT(20)
        ,   BotComponentID			BIGINT UNSIGNED
        ,   IPInfoID				INT
        
		,	PRIMARY KEY (TransID)
        ,	INDEX IX_Temp_RawTransaction_SubscriberID_LoginName(SubscriberID, LoginName)
        ,	INDEX IX_Temp_RawTransaction_AccountID(AccountID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_RawTransactionInfo;
	CREATE TEMPORARY TABLE  Temp_RawTransactionInfo(
		    TransID		    BIGINT UNSIGNED NOT NULL
		,   URLID			INT 
        ,   AccountID		BIGINT	UNSIGNED
        
        ,   PRIMARY KEY (TransID)
    );

	DROP TEMPORARY TABLE IF EXISTS Temp_LastLoginTime;
    CREATE TEMPORARY TABLE Temp_LastLoginTime(
		    SubscriberID	INT
        ,   AccountID		BIGINT UNSIGNED
        ,   LastLoginTime	TIMESTAMP(4)
    );
   
    SELECT DATE(VValue)
    INTO lv_SysMinCreatedDate
    FROM DCS_Extra.SystemSetting 
    WHERE ID = 2;

	INSERT INTO Temp_RawTransaction(TransID, LoginName, TransTime, SubscriberID, SubscriberType, DeviceCode , URLDetails, UserAgentKey, IP, IPID, ActionResultID, Flagged, PluginID, TransStatus, CreatedDate, FingerprintCode, BotDetectionValue, BotComponentID, IPInfoID)
	SELECT  rt.TransID
	    ,   rt.LoginName
        ,   rt.TransTime
        ,   su.SubscriberID
        ,   su.SubscriberType        
        ,   rt.DeviceCode
        ,   rt.URL
        ,   MD5(LOWER(rt.UserAgent))
        ,   rt.IP
        ,   rt.IPID
        ,   ar.ActionResultID
        ,   rt.Flagged
        ,   rt.PluginID
        ,   rt.TransStatus
        ,   rt.CreatedDate
        ,   rt.FingerprintCode
        ,   rt.BotDetectionValue
        ,   rt.BotComponentID
        ,   rt.IPInfoID
	FROM DCS_Extra.RawTransaction AS rt
        INNER JOIN	DCS_Extra.Subscriber AS su ON	rt.SubscriberName = su.SubscriberName
	    INNER JOIN	DCS_Extra.ActionResult AS ar ON	rt.Action = ar.Action AND IFNULL(rt.ActionResult,'') = ar.ActionResult
	WHERE   rt.IsProcessed = 0
	    AND rt.TransID BETWEEN ip_FromTransID AND ip_ToTransID
        AND rt.CreatedDate 	>=	lv_SysMinCreatedDate;

    #===INSERT SUBCRIBERURL    
    INSERT IGNORE INTO DCS_Extra.URL(URLDetails, SubscriberID, CreatedDate)
	SELECT	trt.URLDetails
        ,   trt.SubscriberID
        ,   MIN(trt.CreatedDate)
	FROM Temp_RawTransaction AS trt
	GROUP BY trt.SubscriberID
        ,    trt.URLDetails;    
    
    #=============ACCOUNT=============================
    # Update Exsting AccountID to Temp_Transaction
    INSERT INTO Temp_RawTransactionInfo(TransID, AccountID, URLID)
    SELECT  trt.TransID
        ,   ac.AccountID
        ,   ur.URLID
    FROM Temp_RawTransaction AS trt
        INNER JOIN	DCS_Extra.Account AS ac ON trt.SubscriberID = ac.SubscriberID  AND trt.LoginName = ac.LoginName
	    LEFT JOIN	DCS_Extra.URL	AS ur ON trt.URLDetails = ur.URLDetails;
    
    UPDATE Temp_RawTransaction AS trt
        INNER JOIN	Temp_RawTransactionInfo AS info ON trt.TransID = info.TransID  
    SET     trt.AccountID = info.AccountID
	    ,   trt.URLID = info.URLID;  
        
	# Insert New Account
    INSERT IGNORE INTO DCS_Extra.Account(LoginName, SubscriberID, SubscriberType, CreatedDate, InsertTime, CreatedTime, LastLoginTime)
    SELECT  trt.LoginName
	    ,   trt.SubscriberID
	    ,   trt.SubscriberType
	    ,   MIN(trt.CreatedDate)
	    ,   CURRENT_TIMESTAMP(4) AS InsertTime
        ,   MIN(trt.TransTime) AS CreatedTime
        ,   MAX(trt.TransTime) AS LastLoginTime
    FROM Temp_RawTransaction AS trt
    WHERE trt.AccountID IS NULL
    GROUP BY trt.SubscriberID
        ,    trt.LoginName
        ,    trt.SubscriberType;
    
    # Update AccountID to Temp_Transaction
    INSERT INTO Temp_RawTransactionInfo(TransID, AccountID, URLID)
    SELECT  trt.TransID
        ,   ac.AccountID
        ,   ur.URLID
    FROM Temp_RawTransaction AS trt
        INNER JOIN	DCS_Extra.Account AS ac ON trt.SubscriberID = ac.SubscriberID  AND trt.LoginName = ac.LoginName
	    LEFT JOIN	DCS_Extra.URL	AS ur ON trt.URLDetails = ur.URLDetails
	WHERE trt.AccountID IS NULL;
	
    UPDATE Temp_RawTransaction AS trt
        INNER JOIN	Temp_RawTransactionInfo AS info ON trt.TransID = info.TransID  
    SET     trt.AccountID = info.AccountID
	    ,   trt.URLID = info.URLID
	WHERE trt.AccountID IS NULL;  
    
    #Remove Temp Trans If AccountID Is NULL
    DELETE 	trt
    FROM	Temp_RawTransaction AS trt
    WHERE 	trt.AccountID IS NULL;       
      
    INSERT INTO Temp_LastLoginTime(SubscriberID, AccountID, LastLoginTime)   
    SELECT  acc.SubscriberID
        ,   acc.AccountID
        ,   tac.LastLoginTime
    FROM DCS_Extra.Account 	AS acc
        INNER JOIN (SELECT trt.AccountID, MAX(trt.TransTime) AS LastLoginTime FROM Temp_RawTransaction AS trt GROUP BY trt.AccountID) AS tac ON	acc.AccountID = tac.AccountID
    WHERE tac.LastLoginTime > acc.LastLoginTime;    

    INSERT INTO DCS_Extra.AccountLastLoginTimeProcess(AccountID, LastLoginTime)
    SELECT  tll.AccountID
        ,   tll.LastLoginTime
    FROM Temp_LastLoginTime AS tll;

    INSERT IGNORE INTO  DCS_Extra.Transaction(RawTransID, LoginName, TransTime, SubscriberID, AccountID, URLID, UserAgentKey , IP, IPID, ActionResultID, Flagged, PluginID, TransStatus, CreatedDate, InsertTime, DeviceCode, FingerprintCode, BotDetectionValue, BotComponentID, IPInfoID)
   	SELECT  trt.TransID
	    ,   trt.LoginName
        ,   trt.TransTime                
	    ,   trt.SubscriberID
        ,   trt.AccountID
	    ,   trt.URLID
        ,   trt.UserAgentKey
        ,   trt.IP
        ,   trt.IPID
        ,   trt.ActionResultID
	    ,   trt.Flagged
        ,   trt.PluginID
        ,   trt.TransStatus				
	    ,   trt.CreatedDate                
        ,   CURRENT_TIMESTAMP(4) AS InsertTime
        ,   trt.DeviceCode
        ,   trt.FingerprintCode
        ,   trt.BotDetectionValue
        ,   trt.BotComponentID
        ,   trt.IPInfoID
	FROM Temp_RawTransaction AS trt;	
    #================================================================
    
	INSERT IGNORE INTO DCS_Extra.ProcessedTransaction( LoginName, SubscriberName, TransTime, CreatedDate, DeviceCode, FingerprintCode, UserAgent , IP, IPID, Flagged, PluginID, URL, Action, ActionResult, InvalidDevice, TransStatus, IsProcessed, TransID, InsertTime, BotDetectionValue, BotComponentID, IPInfoID)
	SELECT  rt.LoginName
        ,   rt.SubscriberName
        ,   rt.TransTime
        ,   rt.CreatedDate
        ,   rt.DeviceCode
        ,   rt.FingerprintCode
        ,   rt.UserAgent
	    ,   rt.IP
        ,   rt.IPID
        ,   rt.Flagged
        ,   rt.PluginID
        ,   rt.URL
        ,   rt.Action
        ,   rt.ActionResult
        ,   rt.InvalidDevice
        ,   rt.TransStatus
        ,   rt.IsProcessed
        ,   rt.TransID
		,	rt.InsertTime
		,	rt.BotDetectionValue
		,	rt.BotComponentID
        ,   rt.IPInfoID
	FROM DCS_Extra.RawTransaction AS rt
	    INNER JOIN	Temp_RawTransaction	AS tmp_rm ON	rt.TransID = tmp_rm.TransID AND rt.CreatedDate = tmp_rm.CreatedDate;
        
	DELETE rt
	FROM DCS_Extra.RawTransaction AS rt
	    INNER JOIN	Temp_RawTransaction	AS tmp_rm ON rt.TransID = tmp_rm.TransID AND rt.CreatedDate = tmp_rm.CreatedDate;
    
END$$
DELIMITER ;
