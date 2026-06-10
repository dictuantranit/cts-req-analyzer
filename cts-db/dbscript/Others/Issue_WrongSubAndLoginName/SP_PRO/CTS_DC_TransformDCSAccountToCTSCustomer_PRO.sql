CREATE DEFINER=`fps`@`%` PROCEDURE `CTS_DC_TransformDCSAccountToCTSCustomer`(IN ip_AccountList JSON)
BEGIN
	/*
		Created:	20191112@Terry
		Task:		Transform Data
		DB:			CTS_DataCenter
		Original:

		Revisions:
        	#1. [20191217@CaseyHuynh][#125530]: Implement LastLoginTime
            #2. [20190319@CaseyHuynh][IssueCN88]: Update Join LoginName = UserName
            
		Param's Explanation (filtered by):                
	*/
	DECLARE vrDepositSubType TINYINT DEFAULT 1;
    DECLARE vrNOTMainSubType TINYINT DEFAULT 2;

    ### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200) DEFAULT 'CTS_DC_TransformDCSAccountToCTSCustomer' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    SET		vrExecKey = CRC32((UUID_Short()));    
    SET		vrNotes = 'Get Json Data';		
    SET 	vrStepID = 1;
	SET 	vrStartTime = CURRENT_TIMESTAMP(4);  
    
    INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime)
    VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime);
	  
	### PERFORMANCE: END  
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Account;
    
	CREATE TEMPORARY TABLE Temp_Account 
    (	
		AccountID				BIGINT	UNSIGNED
        , LoginName				VARCHAR(100)   	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'    
        , SubscriberID			INT
		, SubscriberType		INT
        , LastLoginTime			TIMESTAMP(4)
		, LoginNameWithPrefix	VARCHAR(100)	CHARACTER SET 'UTF8MB4' COLLATE 'UTF8MB4_UNICODE_CI'
        , CTSCustID				BIGINT UNSIGNED
    , PRIMARY KEY	PK_TempAccount_AccountID(AccountID)
	, UNIQUE KEY	UK_TempAccount_SubscriberIDLoginName(SubscriberID, LoginName)    
    );       
    
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;     

	INSERT INTO Temp_Account(AccountID, LoginName, SubscriberID, SubscriberType, LastLoginTime, LoginNameWithPrefix)
	SELECT 	tmpTable.AccountID 
            , tmpTable.LoginName 
			, tmpTable.SubscriberID
            , sub.SubscriberType
            , tmpTable.LastLoginTime
            , CONCAT(sub.SubscriberPrefix, tmpTable.LoginName) AS LoginNameWithPrefix
	FROM JSON_TABLE(ip_AccountList,
		 "$[*]" COLUMNS(
			  AccountID 				BIGINT 																	PATH "$.AccountId"
            , LoginName					VARCHAR(100) 														  	PATH "$.LoginName" 
			, SubscriberID				INT																		PATH "$.SubscriberId"
            , LastLoginTime				TIMESTAMP(4)															PATH "$.LastLoginTime"
		 )) as tmpTable  
	INNER JOIN 	CTS_Admin.Subscriber AS sub
				ON tmpTable.SubscriberID = sub.SubscriberID;
    
	 #=============GET CTSCustomerInfo=========================================
    UPDATE 		Temp_Account AS tmpTable
	INNER JOIN	CTS_DataCenter.CTSCustomer AS cus
				ON (tmpTable.LoginName = cus.Username
					OR tmpTable.LoginNameWithPrefix = cus.Username2)
	SET 		tmpTable.CTSCustID = cus.CTSCustID;
	
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    
    #=======New Deposit Account that not existing in CTSCustomer
    INSERT IGNORE INTO	CTS_DataCenter.CTSCustomer(SubscriberID, UserName, UserName2, LastLoginTime)
    SELECT		acc.SubscriberID
				, '' AS UserName
				, acc.LoginNameWithPrefix
                , MAX(LastLoginTime)
    FROM 		Temp_Account AS acc
    WHERE		acc.SubscriberType IN (vrDepositSubType, vrNOTMainSubType)
				AND acc.CTSCustID IS NULL
	GROUP BY 	acc.SubscriberID
				, acc.LoginNameWithPrefix;   			

    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  
    
	UPDATE 		Temp_Account AS acc
    INNER JOIN	CTS_DataCenter.CTSCustomer AS cus # USE INDEX(IX_CTSCustomer_UserName_UserName2,IX_CTSCustomer_UserName2)
				ON (acc.LoginName = cus.Username
					OR acc.LoginNameWithPrefix = cus.Username2)
	SET			acc.CTSCustID = cus.CTSCustID
	WHERE		acc.SubscriberType IN (vrDepositSubType, vrNOTMainSubType)
				AND acc.CTSCustID IS NULL;
	
	SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
   
    INSERT IGNORE INTO CTS_DataCenter.CustDCSAccount(CTSCustID, AccountID, SubscriberID, InsertTime)
	SELECT  acc.CTSCustID
			, acc.AccountID
			, acc.SubscriberID 
            , CURRENT_TIMESTAMP(4) AS InsertTime
    FROM 	Temp_Account AS acc
	WHERE acc.CTSCustID IS NOT NULL;       
    
    UPDATE DCS_DataCenter.Account acc
	INNER JOIN	Temp_Account AS tac 
				ON acc.AccountID = tac.AccountID
	SET 	acc.IsCTSTransformed = 1
	WHERE 	tac.CTSCustID IS NOT NULL;
    
	UPDATE DCS_DataCenter.Account acc
	INNER JOIN	Temp_Account AS tac 
				ON acc.AccountID = tac.AccountID
	SET 	acc.IsCTSTransformed = (CASE WHEN acc.IsCTSTransformed = -1 THEN -2 ELSE -1 END)
	WHERE 	tac.CTSCustID IS NULL;
 
		
	#=======================    
	### PERFORMANCE
	SET	vrEndTime = CURRENT_TIMESTAMP(4);	
    
	SELECT 	Count(1), Min(tas.AccountID), Max(tas.AccountID)
    INTO	vrTotalRecord, vrFromID, vrToID
    FROM	Temp_Account AS tas;    
    
    UPDATE	DCS_DataCenter.zzTracePerformance AS z
    SET		z.EndTime = vrEndTime
			, z.Duration = TIMESTAMPDIFF(MICROSECOND, vrStartTime, vrEndTime)
            , z.TotalRecord = vrTotalRecord
            , z.FromID = vrFromID
            , z.ToID		= vrToID
    WHERE	z.ExecKey = vrExecKey  AND z.StepID = vrStepID;
    ### PERFORMANCE: END
END
