/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_AssociationDetection_GetDetail`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociationDetection_GetDetail`(
		IN	ip_CTSCustID 				BIGINT UNSIGNED
	,	IN	ip_ListCTSCustID 			LONGTEXT
	,   IN  ip_HasDevice				BIT
    ,   IN  ip_HasAI					BIT
    ,   IN  ip_HasIP					BIT 
    ,	IN	ip_HasAgent 				BIT 
)
    SQL SECURITY INVOKER
sp:BEGIN 
	/*  
		Created:	20220727@Aries.Nguyen
		Task:		[CTS] Enhance Association Detection
		DB:			CTS_DataCenter
        
		Revisions:
			- 20220727@Aries.Nguyen: Created [Redmine ID: #175701]
			- 20221205@Aries.Nguyen: Re-arrange type options on Association Detection  [Redmine ID: #181207]
			- 20241217@Victoria.Le:  Super/Master Direct Member [Redmine ID: #214585]

		Param's Explanation (filtered by):

        Example:
			- CALL CTS_DataCenter.CTS_DC_AssociationDetection_GetDetail(1,'1,2',1,1,1,1,1);
	*/
	DECLARE CONST_RangeDevice 				BIGINT DEFAULT 10000000000;
	DECLARE CONST_Batchsize 				BIGINT DEFAULT 1000000;
	DECLARE CONST_ROLEID_MEMBER				TINYINT DEFAULT 1;
	DECLARE CONST_DIRECT_MEMBER_MASTER      INT DEFAULT -3;
	DECLARE CONST_DIRECT_MEMBER_SUPER       INT DEFAULT -4;

    DECLARE lv_CTSCustIDs 			JSON;
    DECLARE lv_UplineCTSCustIDs		JSON;
    DECLARE lv_CustID 				INT;
    DECLARE lv_RoleID 				INT;
    DECLARE lv_Username 			VARCHAR(50);
    DECLARE lv_UplineCustID 		INT;
    DECLARE lv_UplineCTSCustID 		BIGINT UNSIGNED;
    DECLARE lv_UplineUsername 		VARCHAR(50);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE 		Temp_Cust (
			CTSCustID			BIGINT UNSIGNED PRIMARY KEY
		,	CustID 				INT UNSIGNED
        ,	Username			VARCHAR(50)
		,	Recommend			INT
		,	MRecommend			INT
		,	SRecommend			INT
		,	UplineCustID		INT
        ,	RoleID				INT
        ,	INDEX IX_Temp_Cust_CustID(CustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust_Dup;
	CREATE TEMPORARY TABLE 		Temp_Cust_Dup (
			CTSCustID		BIGINT UNSIGNED PRIMARY KEY
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Upline;
	CREATE TEMPORARY TABLE 	Temp_Upline (
			CTSCustID 			BIGINT  PRIMARY KEY 
        ,	UplineCustID		INT
        ,	Username			VARCHAR(50)
        ,	INDEX IX_Temp_Upline_UplineCustID(UplineCustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Upline_Dup;
	CREATE TEMPORARY TABLE 	Temp_Upline_Dup (
			CTSCustID 			BIGINT  PRIMARY KEY 
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_GraphOrig;
    CREATE TEMPORARY TABLE 	Temp_GraphOrig (
			OrigID 				BIGINT  
		,	DestID   			BIGINT
		,	AssociationType		SMALLINT 
		,	PRIMARY KEY(OrigID, DestID,AssociationType)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
    CREATE TEMPORARY TABLE 	Temp_Association (
			CTSCustID 				BIGINT  
		,	Transitive   			BIGINT
		,	AssociationType1		SMALLINT 
        ,	AssociationType2		SMALLINT 
        ,	PRIMARY KEY(CTSCustID, Transitive, AssociationType1, AssociationType2)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_UplineAssociation;
    CREATE TEMPORARY TABLE 	Temp_UplineAssociation (
			CTSCustID 				BIGINT  
		,	Transitive   			BIGINT
		,	AssociationType1		SMALLINT 
        ,	AssociationType2		SMALLINT 
        ,	PRIMARY KEY(CTSCustID, Transitive, AssociationType1, AssociationType2)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Level1;
    CREATE TEMPORARY TABLE 	Temp_Level1 (
			CTSCustID 				BIGINT  PRIMARY KEY
		,	AssociationType			VARCHAR(100) 
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Level2;
    CREATE TEMPORARY TABLE 	Temp_Level2 (
			CTSCustID 				BIGINT  PRIMARY KEY
		,	Transitive				BIGINT
		,	AssociationType1		VARCHAR(100) 
        ,	AssociationType2		VARCHAR(100) 
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_UplineLevel1;
    CREATE TEMPORARY TABLE 	Temp_UplineLevel1 (
			CTSCustID 				BIGINT  PRIMARY KEY
		,	AssociationType			VARCHAR(100) 
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_UplineLevel2;
    CREATE TEMPORARY TABLE 	Temp_UplineLevel2 (
			CTSCustID 				BIGINT  PRIMARY KEY
		,	Transitive				BIGINT
		,	AssociationType1		VARCHAR(100) 
        ,	AssociationType2		VARCHAR(100) 
	);
   
    DROP TEMPORARY TABLE IF EXISTS Temp_UplineResult;
	CREATE TEMPORARY TABLE 		Temp_UplineResult (
			CTSCustID				BIGINT UNSIGNED PRIMARY KEY
		,	CustID					INT UNSIGNED
		,	Username				VARCHAR(50)
		,	UplineUsername			VARCHAR(50)	
        ,	TransitiveCTSCustID		BIGINT
        ,	TransitiveUsername		VARCHAR(50)
		,	AssociationType1		VARCHAR(100) 
        ,	AssociationType2		VARCHAR(100) 
	);

    INSERT IGNORE INTO Temp_Cust(CTSCustID, CustID, Username, RoleID, Recommend, MRecommend, SRecommend, UplineCustID)
	SELECT 	cus.CTSCustID
		, 	cus.CustID
        ,	cus.Username
		,	cus.RoleID
        ,	cus.Recommend	
		,	cus.MRecommend	
		,	cus.SRecommend
		,	CASE WHEN cus.RoleID = CONST_ROLEID_MEMBER AND cus.Recommend = CONST_DIRECT_MEMBER_SUPER THEN cus.SRecommend
				 WHEN cus.RoleID = CONST_ROLEID_MEMBER AND cus.Recommend = CONST_DIRECT_MEMBER_MASTER THEN cus.MRecommend
				 ELSE cus.Recommend END AS UplineCustID
	FROM JSON_TABLE(CONCAT('[',ip_ListCTSCustID,']'),'$[*]' COLUMNS(NESTED PATH '$' COLUMNS (CTSCustID BIGINT UNSIGNED PATH '$'))) AS tmp
		LEFT JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = tmp.CTSCustID;
	
    INSERT INTO Temp_Cust_Dup(CTSCustID)
    SELECT CTSCustID
    FROM Temp_Cust;
    
    SELECT 	CustID
		,	Username
        ,	CASE WHEN RoleID = CONST_ROLEID_MEMBER AND Recommend = CONST_DIRECT_MEMBER_SUPER THEN SRecommend
				 WHEN RoleID = CONST_ROLEID_MEMBER AND Recommend = CONST_DIRECT_MEMBER_MASTER THEN MRecommend
				 ELSE Recommend END AS UplineCustID
        ,	RoleID
	INTO 	lv_CustID
		,	lv_Username
        ,	lv_UplineCustID
        ,	lv_RoleID
    FROM CTS_DataCenter.CTSCustomer 
    WHERE CTSCustID = ip_CTSCustID;
    
    SELECT 	CTSCustID
		,	Username
	INTO 	lv_UplineCTSCustID
		,	lv_UplineUsername
    FROM CTS_DataCenter.CTSCustomer 
    WHERE CustID = lv_UplineCustID
		AND CustSubID = 0;
	
	INSERT IGNORE INTO Temp_Upline(CTSCustID, Username, UplineCustID)
    SELECT 	cus.CTSCustID
		,	cus.Username
        ,	tmp.UplineCustID
    FROM Temp_Cust AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmp.UplineCustID 
														AND cus.IsInternal = 0
                                                        AND cus.CustSubID = 0
                                                        AND tmp.UplineCustID != lv_UplineCustID;
	INSERT IGNORE INTO Temp_Upline_Dup(CTSCustID)
    SELECT CTSCustID
    FROM Temp_Upline;
    
    WITH CTE AS (
		SELECT 	DISTINCT
				CTSCustID
			,	CustID
        FROM Temp_Cust
    )
    SELECT JSON_ARRAYAGG(JSON_OBJECT('CTSCustID', CTSCustID ,'CustID', CustID)) AS CustJson
	INTO lv_CTSCustIDs	
    FROM CTE;
    
    CALL CTS_DataCenter.CTS_DC_AssociationDetection_GetEdgeByCust(ip_CTSCustID,lv_CTSCustIDs,ip_HasDevice,ip_HasAI,ip_HasIP);
	
    INSERT INTO Temp_GraphOrig(OrigID, DestID, AssociationType)
	SELECT 	OrigID
		,	DestID
        ,	AssociationType
    FROM Temp_Graph 
    WHERE	OrigID = ip_CTSCustID;
    
    INSERT IGNORE INTO Temp_Association(CTSCustID, Transitive, AssociationType1, AssociationType2)
    WITH RECURSIVE CTE_Group AS ( 
				SELECT 	DestID     #CAST(CONCAT(OrigID, ' -> ', DestID) AS CHAR(2000)) AS CurPath
                    , 	CASE WHEN DestID < CONST_RangeDevice THEN DestID ELSE 0 END AS Transitive
                    ,	CASE WHEN DestID < CONST_RangeDevice THEN AssociationType ELSE 0 END AS AssociationType1
                    ,	0 AS AssociationType2
                FROM Temp_GraphOrig
				UNION 
                SELECT 	grp.DestID       #CONCAT(CTE_Group.CurPath, ' -> ', grp.DestID)
                    ,	CASE WHEN grp.DestID > CONST_RangeDevice OR CTE_Group.Transitive != 0 THEN CTE_Group.Transitive
							 ELSE grp.DestID END AS Transitive
					,   CASE WHEN  CTE_Group.AssociationType1 > 0 THEN CTE_Group.AssociationType1  
                             WHEN  CTE_Group.AssociationType1 = 0 AND  grp.DestID < CONST_RangeDevice THEN grp.AssociationType 
							 ELSE 0 
                             END AS AssociationType1
				    ,   CASE WHEN grp.DestID < CONST_RangeDevice AND CTE_Group.AssociationType1 > 0 THEN grp.AssociationType 
							 ELSE 0 
							 END AS AssociationType2
				FROM Temp_Graph  AS grp
					INNER JOIN CTE_Group ON grp.OrigID = CTE_Group.DestID
				LIMIT CONST_Batchsize
	) 
	SELECT 	cte.DestID
		,	cte.Transitive
        ,	cte.AssociationType1
        ,	cte.AssociationType2
	FROM CTE_Group AS cte
	WHERE EXISTS (SELECT 1 FROM Temp_Cust_Dup AS tmp WHERE tmp.CTSCustID = cte.DestID);
    
    IF ip_HasAgent = 1 AND lv_RoleID = 1 THEN
		TRUNCATE TABLE Temp_GraphOrig;
        
		SELECT 	JSON_ARRAYAGG(JSON_OBJECT('CTSCustID', CTSCustID ,'CustID', NULL)) AS CustJson
		INTO lv_UplineCTSCustIDs
		FROM Temp_Upline;
		
        CALL CTS_DataCenter.CTS_DC_AssociationDetection_GetEdgeByCust(lv_UplineCTSCustID,lv_UplineCTSCustIDs,1,0,0);
        
        INSERT INTO Temp_GraphOrig(OrigID, DestID, AssociationType)
		SELECT 	OrigID
			,	DestID
			,	AssociationType
		FROM Temp_Graph 
		WHERE	OrigID = lv_UplineCTSCustID;
        
        INSERT IGNORE INTO Temp_UplineAssociation(CTSCustID, Transitive, AssociationType1, AssociationType2)
		WITH RECURSIVE CTE_Group AS ( 
					SELECT 	DestID     #CAST(CONCAT(OrigID, ' -> ', DestID) AS CHAR(2000)) AS CurPath
						, 	0 AS Transitive
						,	 CASE WHEN DestID < CONST_RangeDevice THEN AssociationType 
								  ELSE 0 
							 END AS AssociationType1
						,	0 AS AssociationType2
					FROM Temp_GraphOrig
					UNION 
					SELECT 	grp.DestID       #CONCAT(CTE_Group.CurPath, ' -> ', grp.DestID)
						,	CASE WHEN grp.DestID > CONST_RangeDevice  OR CTE_Group.Transitive != 0 THEN CTE_Group.Transitive
								 ELSE grp.DestID END AS Transitive
						,   CASE WHEN  CTE_Group.AssociationType1 > 0 THEN CTE_Group.AssociationType1  
								 WHEN  CTE_Group.AssociationType1 = 0 AND  grp.DestID < CONST_RangeDevice THEN grp.AssociationType 
								 ELSE 0 
								 END AS AssociationType1
						,   CASE WHEN grp.DestID < CONST_RangeDevice AND CTE_Group.AssociationType1 > 0 THEN grp.AssociationType 
								 ELSE 0 
								 END AS AssociationType2
					FROM Temp_Graph  AS grp
						INNER JOIN CTE_Group ON grp.OrigID = CTE_Group.DestID
					LIMIT CONST_Batchsize
		) 
		SELECT 	cte.DestID
			,	cte.Transitive 
			,	cte.AssociationType1
			,	cte.AssociationType2
		FROM CTE_Group AS cte
		WHERE EXISTS (SELECT 1 FROM Temp_Upline_Dup AS tmp WHERE tmp.CTSCustID = cte.DestID);
        
        INSERT INTO Temp_UplineLevel1(CTSCustID,AssociationType)
		SELECT 	lv1.CTSCustID
			,	GROUP_CONCAT(DISTINCT CASE WHEN lv1.AssociationType1 = 1 THEN "Device"
										   WHEN lv1.AssociationType1 = 2 THEN "Manual"
										   WHEN lv1.AssociationType1 IN (3,4) THEN "Betting Pattern"
										   WHEN lv1.AssociationType1 = 5 THEN "IP" 
									   END) AS AssociationType
		FROM Temp_UplineAssociation AS lv1
		WHERE lv1.AssociationType1 != 0
			AND lv1.AssociationType2 = 0
		GROUP BY lv1.CTSCustID;
        
        INSERT IGNORE INTO Temp_UplineLevel2(CTSCustID,Transitive,AssociationType1,AssociationType2)
		SELECT 	cus.CTSCustID
			,	lv2.Transitive
			,	CASE WHEN lv2.AssociationType1 = 1 THEN "Device"
					 WHEN lv2.AssociationType1 IN (3,4) THEN "Betting Pattern"
					 WHEN lv2.AssociationType1 = 5 THEN "IP" 
				END AS AssociationType1
			,	CASE WHEN lv2.AssociationType2 = 1 THEN "Device"
					 WHEN lv2.AssociationType2 IN (3,4) THEN "Betting Pattern"
					 WHEN lv2.AssociationType2 = 5 THEN "IP" 
				END AS AssociationType2
		FROM Temp_Upline AS cus,
			LATERAL(SELECT 	tmp.Transitive
						,	tmp.AssociationType1
						,	tmp.AssociationType2
					FROM Temp_UplineAssociation AS tmp 
					WHERE tmp.CTSCustID = cus.CTSCustID
						AND tmp.AssociationType1 != 0
						AND tmp.AssociationType2 != 0
					ORDER BY tmp.Transitive ASC
						,	 tmp.AssociationType1 ASC
						,	 tmp.AssociationType1 ASC
					LIMIT 1) AS lv2
		WHERE NOT EXISTS (SELECT 1 FROM Temp_UplineLevel1 AS lv1 WHERE cus.CTSCustID = lv1.CTSCustID);
		
		INSERT IGNORE INTO Temp_UplineLevel2(CTSCustID,Transitive,AssociationType1,AssociationType2)
		SELECT 	CTSCustID
			,	0 AS Transitive
			,	AssociationType AS AssociationType1
			,	"" AS AssociationType2
		FROM Temp_UplineLevel1;
        
		INSERT IGNORE INTO Temp_UplineResult( CTSCustID,CustID,Username,UplineUsername,TransitiveCTSCustID,TransitiveUsername,AssociationType1,AssociationType2)
        SELECT 	cus.CTSCustID
			,	cus.CustID 
			,	cus.Username
			,	re.Username AS UplineUsername
            ,	transitive.CTSCustID AS TransitiveCTSCustID
            ,	transitive.Username AS TransitiveUsername
			,	lv.AssociationType1
            ,	lv.AssociationType2
		FROM Temp_UplineLevel2 AS lv
			INNER JOIN Temp_Upline AS re ON re.CTSCustID = lv.CTSCustID
			INNER JOIN Temp_Cust AS cus ON cus.UplineCustID = re.UplineCustID AND cus.RoleID = 1
			LEFT JOIN CTS_DataCenter.CTSCustomer AS transitive ON transitive.CTSCustID = lv.Transitive;

    END IF;
   
    INSERT INTO Temp_Level1(CTSCustID,AssociationType)
    SELECT 	lv1.CTSCustID
		,	GROUP_CONCAT(DISTINCT CASE WHEN lv1.AssociationType1 = 1 THEN "Device"
									   WHEN lv1.AssociationType1 = 2 THEN "Manual"
									   WHEN lv1.AssociationType1 IN (3,4) THEN "Betting Pattern"
									   WHEN lv1.AssociationType1 = 5 THEN "IP" 
								   END) AS AssociationType
    FROM Temp_Association AS lv1
    WHERE lv1.AssociationType1 != 0
		AND lv1.AssociationType2 = 0
	GROUP BY lv1.CTSCustID;
    
    INSERT IGNORE INTO Temp_Level2(CTSCustID,Transitive,AssociationType1,AssociationType2)
    SELECT 	cus.CTSCustID
		,	lv2.Transitive
        ,	CASE WHEN lv2.AssociationType1 = 1 THEN "Device"
				 WHEN lv2.AssociationType1 IN (3,4) THEN "Betting Pattern"
				 WHEN lv2.AssociationType1 = 5 THEN "IP" 
			END AS AssociationType1
		,	CASE WHEN lv2.AssociationType2 = 1 THEN "Device"
				 WHEN lv2.AssociationType2 IN (3,4) THEN "Betting Pattern"
				 WHEN lv2.AssociationType2 = 5 THEN "IP" 
			END AS AssociationType2
    FROM Temp_Cust AS cus,
		LATERAL(SELECT 	tmp.Transitive
					,	tmp.AssociationType1
                    ,	tmp.AssociationType2
			    FROM Temp_Association AS tmp 
                WHERE tmp.CTSCustID = cus.CTSCustID
					AND tmp.AssociationType1 != 0
					AND tmp.AssociationType2 != 0
				ORDER BY tmp.Transitive ASC
					,	 tmp.AssociationType1 ASC
                    ,	 tmp.AssociationType1 ASC
				LIMIT 1) AS lv2
	WHERE NOT EXISTS (SELECT 1 FROM Temp_Level1 AS lv1 WHERE cus.CTSCustID = lv1.CTSCustID);
    
    INSERT INTO Temp_Level2(CTSCustID,Transitive,AssociationType1,AssociationType2)
    SELECT 	CTSCustID
		,	0 AS Transitive
        ,	AssociationType AS AssociationType1
        ,	"" AS AssociationType2
    FROM Temp_Level1;
    
    SELECT 	ip_CTSCustID AS FromCTSCustID
		,	lv_CustID AS FromCustID
        ,	lv_Username AS FromUsername
        ,	lv_UplineUsername AS FromAgentUsername
        
        ,	lv.CTSCustID AS ToCTSCustID
        ,	cus.CustID AS ToCustID
        ,	cus.Username AS ToUsername
        ,	re.Username AS ToAgentUsername
        
        ,	lv.AssociationType1
        ,	lv.AssociationType2
        ,	"" AS AgentAssociationType1
        ,	"" AS AgentAssociationType2
        
        ,	lv.Transitive AS TransitiveCTSCustID
        ,	transitive.Username AS TransitiveUsername	
    FROM Temp_Level2 AS lv
		LEFT JOIN Temp_Cust AS cus ON cus.CTSCustID = lv.CTSCustID
        LEFT JOIN Temp_Upline AS re ON re.CTSCustID = lv.CTSCustID
        LEFT JOIN CTS_DataCenter.CTSCustomer AS transitive ON transitive.CTSCustID = lv.Transitive
	 
	UNION ALL
    
    SELECT	ip_CTSCustID AS FromCTSCustID
		,	lv_CustID AS FromCustID
        ,	lv_Username AS FromUsername
        ,	lv_UplineUsername AS FromAgentUsername
        
        ,	ag.CTSCustID AS ToCTSCustID
        ,	ag.CustID AS ToCustID
        ,	ag.Username AS ToUsername
        ,	ag.UplineUsername AS ToAgentUsername
        
        ,	"" AS AssociationType1
        ,	"" AS AssociationType2
        ,	ag.AssociationType1 AS AgentAssociationType1
        ,	ag.AssociationType2 AS AgentAssociationType2
        
        ,	ag.TransitiveCTSCustID
        ,	ag.TransitiveUsername	
    FROM Temp_UplineResult AS ag;

END$$

DELIMITER ;
