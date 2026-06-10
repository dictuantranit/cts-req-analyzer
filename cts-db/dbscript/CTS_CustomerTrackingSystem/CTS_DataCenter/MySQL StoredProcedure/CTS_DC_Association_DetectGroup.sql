/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_Association_DetectGroup`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_DetectGroup`(
		IN	ip_CTSCustIDs				LONGTEXT
	,	IN	ip_Device 					JSON 
	,	IN	ip_AI    					JSON 
	,	IN	ip_IP    					JSON 
	,   IN  ip_Agent            		JSON 
	,	IN	ip_SharedIP					JSON 
	,	IN	ip_SharedMatches 			JSON 
	, 	IN	ip_IsGetLogTransInfo 		BIT
)
    SQL SECURITY INVOKER
BEGIN 
	/*  
		Created:	20231117@Victoria.Le
		Task:		Enhance Association Detection
		DB:			CTS_DataCenter
        
		Revisions:
			- 20231117@Victoria.Le: Initial Writing - Renovate Association Detection [Redmine ID: #192172]
			- 20240319@Casey.Huynh: Classify Danger Score [Redmine ID: #201358]
			- 20240425@Thomas.Nguyen: Classify Initial Group Betting - Add SportGroupID = 150 [Redmine ID: #200854]
            - 20240628@Thomas.Nguyen: Renovate CC phase 2 - Remove hardcode ParentID and return ColorTypeID [Redmine ID: #205317]
			- 20240923@Jonas.Huynh: Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]	
			- 20240930@Casey.Huynh: Agent CC [Redmine ID: #185799]
			- 20241217@Victoria.Le: Super/Master Direct Member [Redmine ID: #214585]
			- 20250915@Thomas.Nguyen: Add LastModifiedDate to Temp_CustCategory2 [Redmine ID: #237405]
			- 20250923@Thomas.Nguyen: Add MB App Log Transaction info [Redmine ID: #239121]
		
		---------------------------------------------------------------------------------------------------
		[Before #192172]: CTS_DC_AssociationDetection_DetectGroup 
			- 20220727@Aries.Nguyen: Created [Redmine ID: #175701]
            - 20220907@Aries.Nguyen: CTS - Association Detection - Display in correct CC [Redmine ID: #177559]
            - 20220930@Aries.Nguyen: Renovate Association Detection [RedmineID: #178311]
            - 20221101@Aries.Nguyen: Return IsLicensee value [RedmineID: #178311]
            - 20221107@Aries.Nguyen: Missing Agent info [RedmineID: #180181]
            - 20221205@Aries.Nguyen: Re-arrange type options on Association Detection  [Redmine ID: #181207]
			- 20231116@Thomas.Nguyen: Return more Log Transaction info on Association Detection  [Redmine ID: #196362]

		Param's Explanation (filtered by):

        Example:
			CALL CTS_DC_Association_DetectGroup('2551030,2551022', '[]', '[{"O":2551030,"D":2551022,"A":3},{"O":2551022,"D":2551030,"A":3}]', '[]', '[{"O":2551030,"D":2551022,"A":0}]', '[]', '[]', true);

	*/
	DECLARE	CONST_PARENTID_WRAPPER 				INT;
    DECLARE CONST_ROLEID_MEMBER					SMALLINT DEFAULT 1;
	DECLARE CONST_ROLEID_AGENT					SMALLINT DEFAULT 2;
    DECLARE CONST_ROLEID_MASTER					SMALLINT DEFAULT 3;
    DECLARE CONST_ROLEID_SUPER					SMALLINT DEFAULT 4;
	DECLARE CONST_DIRECT_MEMBER_MASTER      	INT DEFAULT -3;
	DECLARE CONST_DIRECT_MEMBER_SUPER       	INT DEFAULT -4;
    

    DECLARE lv_OrigID 							BIGINT;
    DECLARE lv_GroupID 							BIGINT DEFAULT 1;
    DECLARE lv_CustIDs 							LONGTEXT;
	DECLARE lv_CTSCustIDs 						LONGTEXT;
    DECLARE lv_Count 							INT;
    DECLARE lv_FromDate							DATE;
	DECLARE lv_ToDate							DATE;
	DECLARE lv_SubSourceID_DirectAPI			TINYINT DEFAULT 1;
	DECLARE lv_SubSourceID_OddsFeed				TINYINT DEFAULT 2;

	SET CONST_PARENTID_WRAPPER 				    = CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');

	DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE	Temp_Cust (
			RowNumber			INT UNSIGNED AUTO_INCREMENT PRIMARY KEY
		,	CTSCustID			BIGINT UNSIGNED 
		,	CustID 				INT UNSIGNED
		,	Username			VARCHAR(50)
		,	CustStatus			VARCHAR(50)
		,	Recommend			INT
		,	MRecommend			INT
		,	SRecommend			INT
		,	Danger1				TINYINT
		,	Danger2				TINYINT
		,	Danger3				TINYINT
		,	Danger4				TINYINT
		,	Danger5				TINYINT
		,	RoleID				TINYINT
		,	CreatedDate			DATETIME
		,   IsLicensee      	BIT 
		,	Processed 			BIT DEFAULT 0
		,	SubscriberID		INT
		,	UplineCustID		INT
		,	INDEX IX_Temp_Cust_CustID (CustID)
		,	INDEX IX_Temp_Cust_Processed (Processed)
        ,	INDEX IX_Temp_Cust_RoleID (RoleID)
		,	UNIQUE IX_Temp_Cust_CTSCustID (CTSCustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust_Dup;
	CREATE TEMPORARY TABLE	Temp_Cust_Dup (
			CTSCustID			BIGINT UNSIGNED  PRIMARY KEY
		,	CustID 				BIGINT UNSIGNED
        ,	INDEX IX_Temp_Cust(CustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Upline;
	CREATE TEMPORARY TABLE 	Temp_Upline (
			CTSCustID  			BIGINT  UNSIGNED PRIMARY KEY 
        ,	CustID				INT UNSIGNED
        ,	Username			VARCHAR(50)
        ,	Evidence			LONGTEXT
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustAssociationType;
	CREATE TEMPORARY TABLE	Temp_CustAssociationType (
			CTSCustID			BIGINT UNSIGNED PRIMARY KEY
		,	AssociationType 	VARCHAR(100) DEFAULT ''
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_DestIDCount;
	CREATE TEMPORARY TABLE 	Temp_DestIDCount (
			DestID 				BIGINT
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_GroupResult;
	CREATE TEMPORARY TABLE 		Temp_GroupResult (
			CTSCustID 			BIGINT PRIMARY KEY	
		,	GroupID 			BIGINT
		,	INDEX IX_Temp_GroupResult_GroupID (GroupID)
	);
        
    DROP TEMPORARY TABLE IF EXISTS Temp_GroupID;
	CREATE TEMPORARY TABLE	Temp_GroupID (
			GroupID 			BIGINT PRIMARY KEY	
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_NodeCTSCustID;
	CREATE TEMPORARY TABLE	Temp_NodeCTSCustID (
			CTSCustID 			BIGINT PRIMARY KEY
	);

    DROP TEMPORARY TABLE IF EXISTS Temp_Graph;
	CREATE TEMPORARY TABLE 	Temp_Graph (
			OrigID 				BIGINT  
		,	DestID   			BIGINT
        ,	HasDevice			BIT DEFAULT 0
        ,	HasAI				BIT DEFAULT 0
        ,	HasAIGroup			BIT DEFAULT 0
        ,	HasIP				BIT DEFAULT 0
        ,	HasAgent			BIT DEFAULT 0
        ,	HasSharedIP			BIT DEFAULT 0
        ,	HasSharedMatches	BIT DEFAULT 0
		,	PRIMARY KEY(OrigID, DestID)
		,	INDEX IX_Temp_Graph_DestID_OrigID (DestID,OrigID)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustLogTransInfo;
	CREATE TEMPORARY TABLE	Temp_CustLogTransInfo (
			CTSCustID 						BIGINT UNSIGNED PRIMARY KEY
		,	CountLogin						INT DEFAULT 0
        ,	CountBotTrans					INT DEFAULT 0
        ,	CountInvalidBrowserTrans		INT DEFAULT 0
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustCategory;
	CREATE TEMPORARY TABLE	Temp_CustCategory (
			CustID 					BIGINT UNSIGNED
		,	CategoryID				INT UNSIGNED
        ,	CustomerClassPriority	SMALLINT
		,	ParentID				INT UNSIGNED
		,	CategoryName			VARCHAR(50)
		,	ColorTypeID				TINYINT
		,	PRIMARY KEY(CustID, CategoryID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_CustCategory2;
	CREATE TEMPORARY TABLE	Temp_CustCategory2 (
			CustID 					BIGINT UNSIGNED
		,	CategoryID				INT UNSIGNED
        ,	CustomerClassPriority	SMALLINT
		,	ParentID				INT UNSIGNED
		,	CategoryName			VARCHAR(50)
		,	ColorTypeID				TINYINT
		,	LastModifiedDate		DATETIME
		,	PRIMARY KEY(CustID, CategoryID)
	);

    /*****************************Extract Data From Input**************************************************/
    INSERT IGNORE INTO Temp_Cust(CTSCustID,CustID,RoleID,Username,CustStatus,Danger1,Danger2,Danger3,Danger4,Danger5,CreatedDate,Processed,IsLicensee,SubscriberID,Recommend,MRecommend,SRecommend,UplineCustID)
	SELECT 	tmp.CTSCustID
		, 	cus.CustID
        , 	cus.RoleID
        ,	cus.Username
        ,	sta.ItemName AS CustStatus
        ,	cus.Danger1
        ,	cus.Danger2
        ,	cus.Danger3
        ,	cus.Danger4
        ,	cus.Danger5
        ,	cus.CreatedDate
        ,	CASE WHEN cus.CTSCustID IS NULL OR cus.IsInternal = 1 THEN 1 ELSE 0 END AS Processed
        ,   cus.IsLicensee
        ,	cus.SubscriberID
        ,	cus.Recommend
        ,	cus.MRecommend
        ,	cus.SRecommend
		,	CASE WHEN cus.RoleID = CONST_ROLEID_MEMBER THEN
					CASE WHEN cus.Recommend = CONST_DIRECT_MEMBER_SUPER THEN cus.SRecommend
						 WHEN cus.Recommend = CONST_DIRECT_MEMBER_MASTER THEN cus.MRecommend
						 ELSE cus.Recommend END
				 ELSE 0 END AS UplineCustID
	FROM JSON_TABLE(CONCAT('[',ip_CTSCustIDs,']'),'$[*]' COLUMNS(NESTED PATH '$' COLUMNS (CTSCustID BIGINT UNSIGNED PATH '$'))) AS tmp
		LEFT JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = tmp.CTSCustID  
        LEFT JOIN CTS_DataCenter.StaticList AS sta ON sta.ListID = 1 AND sta.ItemID = cus.CustStatusID;

    INSERT IGNORE INTO Temp_Cust_Dup(CTSCustID,CustID)
    SELECT 	CTSCustID
		,	CustID
    FROM Temp_Cust
    WHERE Processed = 0;

	INSERT IGNORE INTO Temp_Upline(CTSCustID,CustID,Username,Evidence)
	SELECT 	cus.CTSCustID
		,	cus.CustID
		,	cus.Username
		,	(SELECT GROUP_CONCAT(DISTINCT ' ',ev.EvidenceCode) 
			FROM CTS_DataCenter.CustEvidence AS ce  
				LEFT JOIN CTS_DataCenter.Evidence AS ev ON ev.EvidenceID = ce.EvidenceID
			WHERE cus.CTSCustID = ce.CTSCustID) AS Evidence
	FROM Temp_Cust AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmp.UplineCustID 
														AND cus.IsInternal = 0
														AND cus.CustSubID = 0
	WHERE tmp.RoleID = CONST_ROLEID_MEMBER
			AND tmp.IsLicensee = 0;

	INSERT IGNORE INTO Temp_Graph(OrigID,DestID,HasDevice)
    SELECT 	js.OrigID
		,	js.DestID
        ,	1
	FROM JSON_TABLE(ip_Device,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
	)) AS js;
	
	INSERT INTO Temp_Graph(OrigID,DestID,HasDevice)
    SELECT 	js.DestID
		,	js.OrigID
        ,	1
	FROM JSON_TABLE(ip_Device,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
	)) AS js
	ON DUPLICATE KEY UPDATE HasDevice = 1;

	INSERT INTO Temp_Graph(OrigID,DestID,HasAI,HasAIGroup)
    SELECT 	js.OrigID
		,	js.DestID
        ,	CASE WHEN js.AssociationType = 3 THEN 1 ELSE 0 END AS HasAI
        ,	CASE WHEN js.AssociationType = 4 THEN 1 ELSE 0 END AS HasAIGroup
	FROM JSON_TABLE(ip_AI,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
								,	AssociationType		INT			PATH "$.A"
	)) AS js
    ON DUPLICATE KEY UPDATE HasAI = CASE WHEN js.AssociationType = 3 THEN 1 ELSE HasAI END
                        ,   HasAIGroup = CASE WHEN js.AssociationType = 4 THEN 1 ELSE HasAIGroup END;
						
	INSERT INTO Temp_Graph(OrigID,DestID,HasAI,HasAIGroup)
    SELECT 	js.DestID
		,	js.OrigID
        ,	CASE WHEN js.AssociationType = 3 THEN 1 ELSE 0 END AS HasAI
        ,	CASE WHEN js.AssociationType = 4 THEN 1 ELSE 0 END AS HasAIGroup
	FROM JSON_TABLE(ip_AI,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
								,	AssociationType		INT			PATH "$.A"
	)) AS js
    ON DUPLICATE KEY UPDATE HasAI = CASE WHEN js.AssociationType = 3 THEN 1 ELSE HasAI END
                        ,   HasAIGroup = CASE WHEN js.AssociationType = 4 THEN 1 ELSE HasAIGroup END;

    INSERT INTO Temp_Graph(OrigID,DestID,HasIP)
    SELECT 	js.OrigID
		,	js.DestID
        ,	1
	FROM JSON_TABLE(ip_IP,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
	)) AS js
    ON DUPLICATE KEY UPDATE HasIP = 1;
	
	INSERT INTO Temp_Graph(OrigID,DestID,HasIP)
    SELECT 	js.DestID
		,	js.OrigID
        ,	1
	FROM JSON_TABLE(ip_IP,
					"$[*]" COLUMNS( OrigID 				BIGINT 		PATH "$.O"                
								,	DestID				BIGINT 		PATH "$.D"
	)) AS js
    ON DUPLICATE KEY UPDATE HasIP = 1;

	INSERT INTO Temp_Graph(OrigID,DestID,HasAgent) 
    SELECT 	js.OrigID
		,	js.DestID
        ,	1
	FROM JSON_TABLE(ip_Agent,
		"$[*]" COLUMNS( OrigID 			BIGINT 		PATH "$.O"                
					,	DestID			BIGINT 		PATH "$.D"
	)) AS js
    ON DUPLICATE KEY UPDATE HasAgent = 1;
	
	INSERT INTO Temp_Graph(OrigID,DestID,HasAgent) 
    SELECT 	js.DestID
		,	js.OrigID
        ,	1
	FROM JSON_TABLE(ip_Agent,
		"$[*]" COLUMNS( OrigID 			BIGINT 		PATH "$.O"                
					,	DestID			BIGINT 		PATH "$.D"
	)) AS js
    ON DUPLICATE KEY UPDATE HasAgent = 1;
	
	INSERT INTO Temp_Graph(OrigID,DestID,HasSharedIP)  
	SELECT 	js.OrigID 
		,	js.DestID
		,	1
	FROM JSON_TABLE(ip_SharedIP,
		"$[*]" COLUMNS( OrigID 		BIGINT 		PATH "$.O"                
					,	DestID		BIGINT 		PATH "$.D"
	)) AS js
	ON DUPLICATE KEY UPDATE HasSharedIP = 1;
	
	INSERT INTO Temp_Graph(OrigID,DestID,HasSharedIP)  
	SELECT 	js.DestID 
		,	js.OrigID
		,	1
	FROM JSON_TABLE(ip_SharedIP,
		"$[*]" COLUMNS( OrigID 		BIGINT 		PATH "$.O"                
					,	DestID		BIGINT 		PATH "$.D"
	)) AS js
	ON DUPLICATE KEY UPDATE HasSharedIP = 1;

	INSERT INTO Temp_Graph(OrigID,DestID,HasSharedMatches)  
	SELECT 	js.OrigID 
		,	js.DestID
		,	1
	FROM JSON_TABLE(ip_SharedMatches,
		"$[*]" COLUMNS( OrigID 		BIGINT 		PATH "$.O"                
					,	DestID		BIGINT 		PATH "$.D"
	)) AS js
	ON DUPLICATE KEY UPDATE HasSharedMatches = 1;
	
	INSERT INTO Temp_Graph(OrigID,DestID,HasSharedMatches)  
	SELECT 	js.DestID 
		,	js.OrigID
		,	1
	FROM JSON_TABLE(ip_SharedMatches,
		"$[*]" COLUMNS( OrigID 		BIGINT 		PATH "$.O"                
					,	DestID		BIGINT 		PATH "$.D"
	)) AS js
	ON DUPLICATE KEY UPDATE HasSharedMatches = 1;

    /*****************************Merge Group**************************************************/
    lp: LOOP 
		SET lv_OrigID = NULL;
        
        SELECT CTSCustID
        INTO lv_OrigID
		FROM Temp_Cust
        WHERE Processed = 0
		LIMIT 1;
        
        IF lv_OrigID IS NULL 
        THEN 
            LEAVE lp; 
        END IF;
        
        UPDATE Temp_Cust AS tmp
        SET tmp.Processed = 1
        WHERE  tmp.CTSCustID = lv_OrigID;
						 
		INSERT IGNORE INTO Temp_NodeCTSCustID(CTSCustID)
		WITH RECURSIVE CTE_Group AS ( 
			SELECT lv_OrigID AS OrigID
			UNION
			SELECT grp.OrigID 
			FROM Temp_Graph AS grp
				INNER JOIN CTE_Group ON CTE_Group.OrigID = grp.DestID
		) 
		SELECT OrigID
		FROM CTE_Group AS cte
		WHERE EXISTS (SELECT 1 FROM Temp_Cust AS tmp WHERE tmp.CTSCustID = cte.OrigID);
            
		SELECT 	COUNT(1)
        INTO 	lv_Count
        FROM Temp_NodeCTSCustID;
        
        IF lv_Count IS NULL OR lv_Count = 1 THEN
			TRUNCATE TABLE Temp_NodeCTSCustID;
        END IF;
        
        INSERT IGNORE INTO Temp_GroupID(GroupID)
        SELECT 	DISTINCT 
				gr.GroupID
        FROM Temp_GroupResult AS gr
		WHERE EXISTS (SELECT 1 FROM Temp_NodeCTSCustID AS tmp WHERE gr.CTSCustID = tmp.CTSCustID);
        
        IF EXISTS (SELECT 1 FROM Temp_GroupID) THEN
			UPDATE Temp_GroupResult AS gr
            SET gr.GroupID = lv_GroupID
            WHERE EXISTS (SELECT 1 FROM Temp_GroupID AS tmp WHERE gr.GroupID = tmp.GroupID);
        END IF;
        
        INSERT IGNORE Temp_GroupResult(CTSCustID,GroupID)
        SELECT 	CTSCustID
            ,	lv_GroupID
        FROM Temp_NodeCTSCustID;
        
        UPDATE Temp_Cust AS tmp
        SET tmp.Processed = 1
        WHERE  EXISTS (SELECT 1 FROM Temp_GroupResult AS gp WHERE  gp.CTSCustID = tmp.CTSCustID);
        
        SET lv_GroupID = lv_GroupID + 1;
        TRUNCATE TABLE Temp_NodeCTSCustID;
        TRUNCATE TABLE Temp_GroupID;
	END LOOP;

    /*****************************Handle AssociationType Info**************************************************/
    INSERT INTO Temp_DestIDCount(DestID)
    SELECT grp.DestID
    FROM Temp_Graph AS grp
    WHERE EXISTS (SELECT 1 
					FROM Temp_Cust AS cus 
					WHERE cus.CTSCustID = grp.OrigID 
						AND (grp.HasDevice = 1 OR grp.HasAIGroup = 1 OR grp.HasAgent = 1 ))
    GROUP BY DestID
    HAVING COUNT(1) > 1;
	
	INSERT IGNORE INTO Temp_CustAssociationType(CTSCustID, AssociationType)
    SELECT 	cus.CTSCustID , 'Device'
    FROM Temp_Cust AS cus
    WHERE EXISTS (	SELECT 1 
					FROM Temp_Graph AS grp 
						INNER JOIN Temp_DestIDCount AS des ON grp.DestID = des.DestID
					WHERE cus.CTSCustID = grp.OrigID AND grp.HasDevice = 1);
					
	INSERT INTO Temp_CustAssociationType(CTSCustID, AssociationType)
    SELECT 	cus.CTSCustID, 'Agent'
    FROM Temp_Cust AS cus
    WHERE EXISTS (	SELECT 1 
					FROM Temp_Graph AS grp 
						INNER JOIN Temp_DestIDCount AS des ON grp.DestID = des.DestID
					WHERE cus.CTSCustID = grp.OrigID AND grp.HasAgent = 1)
	ON DUPLICATE KEY UPDATE AssociationType = CONCAT(AssociationType, ", Agent");
	
    INSERT INTO Temp_CustAssociationType(CTSCustID, AssociationType)
    WITH CTE AS (SELECT cus.CTSCustID
					,	CONCAT(IF(MAX(HasAI) =1, ", Betting Pattern","")
                              ,IF(MAX(HasIP) =1, ", IP","")
                              ,IF(MAX(HasSharedIP) =1, ", IP(last3days)","")
                              ,IF(MAX(HasSharedMatches) =1, ", Match","")) AS AssociationTypeStr
				FROM Temp_Cust AS cus
					INNER JOIN Temp_Graph AS grp ON cus.CTSCustID = grp.OrigID AND (grp.HasDevice = 0 OR grp.HasAIGroup = 0 OR grp.HasAgent = 0)
                    INNER JOIN Temp_Cust_Dup AS dup ON dup.CTSCustID = grp.DestID
				GROUP BY cus.CTSCustID)
	SELECT CTE.CTSCustID, SUBSTR(CTE.AssociationTypeStr, 2)
    FROM CTE
    ON DUPLICATE KEY UPDATE AssociationType = CONCAT(AssociationType, CTE.AssociationTypeStr);
    
    INSERT INTO Temp_CustAssociationType(CTSCustID, AssociationType)
    SELECT 	cus.CTSCustID, 'Betting Pattern' 
    FROM Temp_Cust AS cus
    WHERE EXISTS (	SELECT 1 
					FROM Temp_Graph AS grp 
						INNER JOIN Temp_DestIDCount AS des ON grp.DestID = des.DestID
					WHERE cus.CTSCustID = grp.OrigID AND grp.HasAIGroup = 1)
	ON DUPLICATE KEY UPDATE AssociationType = CASE WHEN AssociationType LIKE '%Betting Pattern%' THEN AssociationType
												   ELSE CONCAT(AssociationType,', Betting Pattern') END;
	
	IF (ip_IsGetLogTransInfo IS TRUE)
    THEN
        SET lv_ToDate	= CURRENT_DATE();
        SET lv_FromDate = DATE_ADD(lv_ToDate, INTERVAL -90 DAY);
        
        DROP TEMPORARY TABLE IF EXISTS Temp_CustAccountID;
        CREATE TEMPORARY TABLE Temp_CustAccountID(
				AccountID					BIGINT UNSIGNED PRIMARY KEY 
			,	CTSCustID					BIGINT UNSIGNED 
			,	INDEX IX_Temp_CustAccountID_CTSCustID (CTSCustID)
        );
		
        DROP TEMPORARY TABLE IF EXISTS Temp_LoginTransactionSummary;
        CREATE TEMPORARY TABLE Temp_LoginTransactionSummary(
                    ID			BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT
                ,   AccountID	BIGINT UNSIGNED
                ,	TotalTrans	INT UNSIGNED
                ,	Flagged		SMALLINT
                ,	INDEX IX_Temp_LoginTransactionSummary_AccountID (AccountID)
        );
        
        DROP TEMPORARY TABLE IF EXISTS Temp_CustAccLogTransInfo;
        CREATE TEMPORARY TABLE 		Temp_CustAccLogTransInfo (
                AccountID					BIGINT UNSIGNED PRIMARY KEY
            ,	CTSCustID 					BIGINT UNSIGNED
            ,	CountLogin					INT DEFAULT 0
            ,	CountBotTrans				INT DEFAULT 0
            ,	CountInvalidBrowserTrans	INT DEFAULT 0
            ,	INDEX IX_Temp_CustAccLogTransInfo_CTSCustID (CTSCustID)
        );

        INSERT INTO Temp_CustAccountID(CTSCustID, AccountID)
        SELECT tmp.CTSCustID, acc.AccountID
        FROM Temp_Cust AS tmp
            INNER JOIN CTS_DataCenter.CustDCSAccount AS acc ON acc.CTSCustID = tmp.CTSCustID
            LEFT JOIN CTS_Admin.Subscriber AS sub ON sub.SubscriberID = tmp.SubscriberID AND sub.SubscriberSourceID IN (lv_SubSourceID_DirectAPI, lv_SubSourceID_OddsFeed)
        WHERE sub.SubscriberSourceID IS NULL;

        INSERT INTO Temp_LoginTransactionSummary(AccountID, TotalTrans, Flagged)
        SELECT tmp.AccountID, ls.TotalTrans, ls.Flagged
        FROM Temp_CustAccountID AS tmp
			INNER JOIN DCS_DataTrace.LoginTransactionSummary AS ls ON ls.AccountID = tmp.AccountID 
		WHERE ls.TransDate BETWEEN lv_FromDate AND lv_ToDate;

        INSERT INTO Temp_CustAccLogTransInfo(CTSCustID, AccountID)
        SELECT tmp.CTSCustID, tmp.AccountID
        FROM Temp_CustAccountID AS tmp;
        
        UPDATE Temp_CustAccLogTransInfo AS tmp
        SET tmp.CountLogin = IFNULL((SELECT SUM(sm.TotalLogin)
                                    FROM DCS_DataCenter.SumAccountLogin AS sm
                                    WHERE sm.AccountID = tmp.AccountID AND sm.TransDate BETWEEN lv_FromDate AND lv_ToDate
                                    GROUP BY sm.AccountID),0);

        UPDATE Temp_CustAccLogTransInfo AS tmp
        SET tmp.CountLogin = IFNULL((SELECT SUM(ls.TotalTrans) 
                                    FROM Temp_LoginTransactionSummary AS ls
                                    WHERE ls.AccountID = tmp.AccountID
                                    GROUP BY ls.AccountID),tmp.CountLogin);
        
        WITH CTETransInfo AS (
			SELECT 	ls.AccountID
				,	SUM(CASE WHEN st.GroupID = 2 THEN ls.TotalTrans ELSE 0 END) AS CountInvalidBrowserTrans
				,	SUM(CASE WHEN st.GroupID = 3 THEN ls.TotalTrans ELSE 0 END) AS CountBotTrans
			FROM Temp_LoginTransactionSummary AS ls
				INNER JOIN DCS_DataCenter.StaticList AS st ON st.ItemID = ls.Flagged AND st.ListID = 1
				INNER JOIN Temp_CustAccountID AS tmpcust ON tmpcust.AccountID = ls.AccountID
			GROUP BY ls.AccountID
        )
        UPDATE Temp_CustAccLogTransInfo AS tmp
            INNER JOIN CTETransInfo AS tc ON tc.AccountID = tmp.AccountID
        SET 	tmp.CountBotTrans = tc.CountBotTrans
            , 	tmp.CountInvalidBrowserTrans = tc.CountInvalidBrowserTrans
        WHERE tc.CountBotTrans <> 0 OR tc.CountInvalidBrowserTrans <> 0;
        
        INSERT INTO Temp_CustLogTransInfo(CTSCustID, CountLogin, CountBotTrans, CountInvalidBrowserTrans)
		SELECT 	ct.CTSCustID
			, 	SUM(IFNULL(ct.CountLogin,0))
			, 	SUM(IFNULL(ct.CountBotTrans,0))
			, 	SUM(IFNULL(ct.CountInvalidBrowserTrans,0))
		FROM Temp_CustAccLogTransInfo AS ct
		GROUP BY ct.CTSCustID;

		/********* Get MB Account Log Transaction info *********/
		SELECT GROUP_CONCAT(DISTINCT CTSCustID) 
		INTO lv_CTSCustIDs
		FROM Temp_Cust;

		CALL CTS_DataCenter.CTSDCS_DC_CustInfo_AccountCustMapping(lv_CTSCustIDs);
		
		TRUNCATE TABLE Temp_CustAccountID;
		INSERT INTO Temp_CustAccountID(CTSCustID, AccountID)
		SELECT tmp.CTSCustID, tmp.MBAccountID
		FROM Temp_CustDCSMBAccount AS tmp
			LEFT JOIN CTS_Admin.Subscriber AS sub ON sub.SubscriberID = tmp.SubscriberID AND sub.SubscriberSourceID IN (lv_SubSourceID_DirectAPI, lv_SubSourceID_OddsFeed)
        WHERE sub.SubscriberSourceID IS NULL;

		TRUNCATE TABLE Temp_LoginTransactionSummary;
		INSERT INTO Temp_LoginTransactionSummary(AccountID, TotalTrans, Flagged)
        SELECT tmp.AccountID, ls.TotalTrans, ls.FlaggedGroupID AS Flagged
        FROM Temp_CustAccountID AS tmp
			INNER JOIN DCS_DataTrace.MBLoginTransactionSummary AS ls ON ls.MBAccountID = tmp.AccountID 
		WHERE ls.TransDate BETWEEN lv_FromDate AND lv_ToDate;
        
		TRUNCATE TABLE Temp_CustAccLogTransInfo;
        INSERT INTO Temp_CustAccLogTransInfo(CTSCustID, AccountID)
        SELECT tmp.CTSCustID, tmp.AccountID
        FROM Temp_CustAccountID AS tmp;

        UPDATE Temp_CustAccLogTransInfo AS tmp
        SET tmp.CountLogin = IFNULL((SELECT SUM(ls.TotalTrans) 
                                    FROM Temp_LoginTransactionSummary AS ls
                                    WHERE ls.AccountID = tmp.AccountID
                                    GROUP BY ls.AccountID),tmp.CountLogin);

		WITH CTETransInfo AS (
			SELECT 	ls.AccountID
				,	SUM(CASE WHEN ls.Flagged = 2 THEN ls.TotalTrans ELSE 0 END) AS CountInvalidBrowserTrans
				,	SUM(CASE WHEN ls.Flagged = 3 THEN ls.TotalTrans ELSE 0 END) AS CountBotTrans
			FROM Temp_LoginTransactionSummary AS ls
				INNER JOIN Temp_CustAccountID AS tmpcust ON tmpcust.AccountID = ls.AccountID
			GROUP BY ls.AccountID
        )
        UPDATE Temp_CustAccLogTransInfo AS tmp
            INNER JOIN CTETransInfo AS tc ON tc.AccountID = tmp.AccountID
        SET 	tmp.CountBotTrans = tc.CountBotTrans
            , 	tmp.CountInvalidBrowserTrans = tc.CountInvalidBrowserTrans
        WHERE tc.CountBotTrans <> 0 OR tc.CountInvalidBrowserTrans <> 0;

        INSERT INTO Temp_CustLogTransInfo(CTSCustID, CountLogin, CountBotTrans, CountInvalidBrowserTrans)
		WITH CTE_CustAccLogTransInfo AS (
			 SELECT	ct.CTSCustID
				, 	SUM(IFNULL(ct.CountLogin,0)) AS TotalCountLogin
				, 	SUM(IFNULL(ct.CountBotTrans,0)) AS TotalCountBotTrans
				, 	SUM(IFNULL(ct.CountInvalidBrowserTrans,0)) AS TotalCountInvalidBrowserTrans
			FROM Temp_CustAccLogTransInfo AS ct
			GROUP BY ct.CTSCustID
        )
		SELECT CTSCustID, TotalCountLogin, TotalCountBotTrans, TotalCountInvalidBrowserTrans
        FROM CTE_CustAccLogTransInfo AS ca
		ON DUPLICATE KEY UPDATE CountLogin = CountLogin + ca.TotalCountLogin
			,	CountBotTrans = CountBotTrans + ca.TotalCountBotTrans
			,	CountInvalidBrowserTrans = CountInvalidBrowserTrans + ca.TotalCountInvalidBrowserTrans;
		
    END IF;
    
	INSERT IGNORE INTO Temp_CustCategory(CustID, CategoryID, ParentID, CategoryName, ColorTypeID, CustomerClassPriority)
	SELECT	cus.CustID
		,	cat.CategoryID
		,	cat.ParentID
		,	cat.CategoryName
		,	cat.ColorTypeID
        ,	cat.CustomerClassPriority
	FROM Temp_Cust AS cus
	,	LATERAL (	SELECT cus.CustID, clss.ParentID
					FROM CTS_DataCenter.CTSCustomerClassification AS clss
						INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = clss.CategoryID AND cat.IsActive = 1
					WHERE clss.CustID = cus.CustID AND clss.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY cat.CustomerClassPriority ASC, clss.LastModifiedDate DESC
					LIMIT 1	) AS tmpcls
	INNER JOIN CTS_DataCenter.CTSCustomerClassification AS clss	ON clss.CustID = tmpcls.CustID AND clss.ParentID = tmpcls.ParentID
	INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = clss.CategoryID
	WHERE cus.RoleID = CONST_ROLEID_MEMBER;
    
    #==================CATEGORY FOR AGENCY==========================================
	INSERT IGNORE INTO Temp_CustCategory(CustID, CategoryID, ParentID, CategoryName, ColorTypeID, CustomerClassPriority)
	SELECT	cus.CustID
		,	cat.CategoryID
		,	cat.ParentID
		,	cat.CategoryName
		,	cat.ColorTypeID
		,	cat.CustomerClassPriority
	FROM Temp_Cust AS cus
	,	LATERAL (	SELECT cus.CustID, clss.ParentID
					FROM CTS_DataCenter.CTSCustomerClassificationAgency AS clss
						INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cat.CategoryID = clss.CategoryID AND cat.IsActive = 1
					WHERE clss.CustID = cus.CustID AND clss.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY cat.CustomerClassPriority ASC, clss.LastModifiedDate DESC
					LIMIT 1	) AS tmpcls
		INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS clss	ON clss.CustID = tmpcls.CustID AND clss.ParentID = tmpcls.ParentID
		INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cat ON cat.CategoryID = clss.CategoryID
	WHERE cus.RoleID IN (CONST_ROLEID_AGENT, CONST_ROLEID_MASTER,CONST_ROLEID_SUPER);
    
    INSERT INTO Temp_CustCategory2(CustID, CategoryID, ParentID, CategoryName, ColorTypeID, CustomerClassPriority, LastModifiedDate)
	SELECT	tmp.CustID
		,	tmp.CategoryID
		,	tmp.ParentID
		,	tmp.CategoryName
		,	tmp.ColorTypeID
		,	tmp.CustomerClassPriority
		,	clss.LastModifiedDate
    FROM Temp_CustCategory AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS clss ON clss.CustID = tmp.CustID AND clss.CategoryID = tmp.CategoryID;

	INSERT INTO Temp_CustCategory2(CustID, CategoryID, ParentID, CategoryName, ColorTypeID, CustomerClassPriority, LastModifiedDate)
	SELECT	tmp.CustID
		,	tmp.CategoryID
		,	tmp.ParentID
		,	tmp.CategoryName
		,	tmp.ColorTypeID
		,	tmp.CustomerClassPriority
		,	clss.LastModifiedDate
    FROM Temp_CustCategory AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS clss ON clss.CustID = tmp.CustID AND clss.CategoryID = tmp.CategoryID;
	
    /*****************************Handle CustomerClass Info**************************************************/
    SELECT GROUP_CONCAT(DISTINCT CustID) 
    INTO lv_CustIDs
    FROM Temp_Cust;
    
    CALL CTS_DataCenter.CTS_DC_Common_GetCCAndDangerLevel(lv_CustIDs);
    
    #==================CATEGORY FOR MEMBER==========================================
    
    SELECT 	cus.RowNumber 
		,	grp.GroupID
        ,	asTy.AssociationType
        
		,	cus.CTSCustID
        ,	cus.CustID
        ,	cus.Username
        ,	cus.CustStatus
        ,	cus.Danger1
        ,	cus.Danger2
        ,	cus.Danger3
        ,	cus.Danger4
        ,	cus.Danger5
        ,	cus.IsLicensee
        ,	cus.CreatedDate
        
        ,	re.CTSCustID AS AgentCTSCustID
        ,	re.Username AS AgentUsername
        ,	re.Evidence AS AgentEvidence
        
        ,	(SELECT GROUP_CONCAT(DISTINCT ' ',ev.EvidenceCode) 
			 FROM CTS_DataCenter.CustEvidence AS ce  
				LEFT JOIN CTS_DataCenter.Evidence AS ev ON ev.EvidenceID = ce.EvidenceID
             WHERE cus.CTSCustID = ce.CTSCustID) AS Evidence
        
        , 	TRIM(GROUP_CONCAT(DISTINCT ' ',cat.CategoryName)) AS CustomerCategory
        ,	TRIM(GROUP_CONCAT(DISTINCT cat.CategoryID)) AS CategoryIDs
        ,	TRIM(GROUP_CONCAT(DISTINCT cat.ParentID)) AS ParentIDs
        ,	(SELECT clss.ColorTypeID	
			 FROM Temp_CustCategory2 AS clss
			 WHERE clss.CustID = cus.CustID
			 ORDER BY clss.CustomerClassPriority ASC, clss.LastModifiedDate DESC
			 LIMIT 1) AS ColorTypeID
        ,	cusclss.CustomerClass
        ,	cti.CountBotTrans AS BotTransSum
        ,	ROUND((cti.CountBotTrans/cti.CountLogin)*100,2) AS BotTransPercentage
		,	cti.CountInvalidBrowserTrans AS InvalidBrowserInfoTransSum
        ,	ROUND((cti.CountInvalidBrowserTrans/cti.CountLogin)*100,2) AS InvalidBrowserInfoTransPercentage
    FROM Temp_Cust AS cus
		LEFT JOIN Temp_GroupResult AS grp ON cus.CTSCustID = grp.CTSCustID
        LEFT JOIN Temp_CustClassificationInfo AS cusclss ON cus.CustID = cusclss.CustID
        LEFT JOIN Temp_CustAssociationType AS asTy ON cus.CTSCustID = asTy.CTSCustID
        LEFT JOIN Temp_Upline AS re ON cus.UplineCustID = re.CustID
        LEFT JOIN Temp_CustCategory AS cat ON cat.CustID = cus.CustID
        LEFT JOIN Temp_CustLogTransInfo AS cti ON cti.CTSCustID = cus.CTSCustID
	GROUP BY cus.RowNumber 
		,	grp.GroupID
		,	cus.CTSCustID
		,	cus.CustID
		,	cus.Username
		,	cus.CustStatus
		,	cusclss.CustomerClass
		,	cus.Danger1
		,	cus.Danger2
		,	cus.Danger3
		,	cus.Danger4
		,	cus.Danger5
		,	cus.IsLicensee
		,	cus.CreatedDate
		,	re.CTSCustID
		,	re.Username
		,	re.Evidence
		,	cti.CountBotTrans
		,	cti.CountInvalidBrowserTrans
		,	cti.CountLogin;
END$$

DELIMITER ;

