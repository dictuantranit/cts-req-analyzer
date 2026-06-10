/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_Association_Agent_GetCustEdge`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_Agent_GetCustEdge`(
		IN	ip_CTSCustIDs 		LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN 
	/*  
		Created:	20231117@Victoria.Le
		Task:		Enhance Association Detection
		DB:			CTS_DataCenter
        
		Revisions:
			- 20231117@Victoria.Le: Initial Writing - Renovate Association Detection [Redmine ID: #192172]
			- 20241217@Victoria.Le: Super/Master Direct Member [Redmine ID: #214585]
		
		---------------------------------------------------------------------------------------------------
		[Before #192172]: CTS_DC_AssociationDetection_Agent_Detect 
			- 20220727@Aries.Nguyen: Created [Redmine ID: #175701]
            - 20221205@Aries.Nguyen: Re-arrange type options on Association Detection  [Redmine ID: #181207]

		Param's Explanation (filtered by):

        Example:
			- CALL CTS_DataCenter.CTS_DC_Association_Agent_GetCustEdge('1,2,3');
	*/
	DECLARE CONST_AGENT_RANGE 				BIGINT DEFAULT 3000000000;
	DECLARE lv_GroupID 						BIGINT DEFAULT CONST_AGENT_RANGE;
	DECLARE CONST_ROLEID_MEMBER				TINYINT DEFAULT 1;
	DECLARE CONST_DIRECT_MEMBER_MASTER      INT DEFAULT -3;
	DECLARE CONST_DIRECT_MEMBER_SUPER       INT DEFAULT -4;

	DECLARE lv_UplineJson 					JSON;
	DECLARE lv_OrigID 						BIGINT;
	DECLARE lv_Count 						INT;
	
	#=============================================================================	
	DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE 	Temp_Cust (
			CTSCustID 				BIGINT  PRIMARY KEY 
		,	CustID   				INT	
        ,	Recommend				INT
		,	MRecommend				INT
		,	SRecommend				INT
		,	UplineCustID			INT
		,	INDEX Temp_Cust_CustID (CustID)
        ,	INDEX Temp_Cust_UplineCustID(UplineCustID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_Upline;
	CREATE TEMPORARY TABLE 	Temp_Upline (
			CTSCustID 				BIGINT  PRIMARY KEY 
        ,	CustID					INT
        ,	Processed 				BIT 	DEFAULT 0
        ,	INDEX IX_Temp_Upline_CustID(CustID)
        ,	INDEX IX_Temp_Upline_Processed(Processed)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_GroupResult;
	CREATE TEMPORARY TABLE	Temp_GroupResult (
			CTSCustID 				BIGINT PRIMARY KEY	
		,	GroupID 				BIGINT
		,	INDEX IX_Temp_GroupResult_GroupID (GroupID)
	);
        
    DROP TEMPORARY TABLE IF EXISTS Temp_GroupID;
	CREATE TEMPORARY TABLE	Temp_GroupID (
			GroupID 				BIGINT PRIMARY KEY	
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_NodeCTSCustID;
	CREATE TEMPORARY TABLE	Temp_NodeCTSCustID (
			CTSCustID 				BIGINT PRIMARY KEY
	);

	#=============================================================================	
	INSERT IGNORE INTO Temp_Cust(CTSCustID,CustID,Recommend,MRecommend,SRecommend,UplineCustID)
	SELECT 	cus.CTSCustID
		, 	cus.CustID
        ,	cus.Recommend
        ,	cus.MRecommend
        ,	cus.SRecommend
		,	CASE WHEN cus.Recommend = CONST_DIRECT_MEMBER_SUPER THEN cus.SRecommend
				 WHEN cus.Recommend = CONST_DIRECT_MEMBER_MASTER THEN cus.MRecommend
				 ELSE cus.Recommend END AS UplineCustID
	FROM JSON_TABLE(CONCAT('[',ip_CTSCustIDs,']'),
							'$[*]' COLUMNS(NESTED PATH '$' COLUMNS (CTSCustID BIGINT UNSIGNED PATH '$'))) AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = tmp.CTSCustID 
														AND cus.IsInternal = 0
                                                        AND cus.RoleID = CONST_ROLEID_MEMBER
                                                        AND cus.IsLicensee = 0;

	INSERT IGNORE INTO Temp_Upline(CTSCustID,CustID)
	SELECT 	cus.CTSCustID
		,	cus.CustID
	FROM Temp_Cust AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tmp.UplineCustID 
														AND cus.IsInternal = 0
														AND cus.CustSubID = 0;

	WITH CTE AS (
		SELECT DISTINCT 
				CTSCustID
			,	CustID
		FROM Temp_Upline
	)
	SELECT JSON_ARRAYAGG(JSON_OBJECT('CTSCustID', CTSCustID ,'CustID', CustID)) AS CustJson
	INTO lv_UplineJson
	FROM CTE;
	
	CALL CTS_DataCenter.CTS_DC_Association_GetCustEdge(lv_UplineJson,1,0,0);
		
	DROP TEMPORARY TABLE IF EXISTS Temp_Graph_Dup;
	CREATE TEMPORARY TABLE Temp_Graph_Dup LIKE Temp_Graph;
	INSERT INTO Temp_Graph_Dup SELECT * FROM Temp_Graph;
	
	INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
	SELECT 	DestID 
		,	OrigID
		,	AssociationType
	FROM Temp_Graph_Dup;

	lp: LOOP 
		SET lv_OrigID = NULL;
		
		SELECT CTSCustID
        INTO lv_OrigID
		FROM Temp_Upline
        WHERE Processed = 0
		LIMIT 1;
		
		IF lv_OrigID IS NULL 
        THEN 
            LEAVE lp; 
        END IF;
        
		UPDATE Temp_Upline AS tmp
        SET tmp.Processed = 1
        WHERE tmp.CTSCustID = lv_OrigID;
        
		INSERT IGNORE INTO Temp_NodeCTSCustID(CTSCustID)
		WITH RECURSIVE CTE_Group AS ( 
			SELECT lv_OrigID AS OrigID
			UNION
			SELECT grp.OrigID 
			FROM Temp_Graph  AS grp
				INNER JOIN CTE_Group ON CTE_Group.OrigID = grp.DestID
		) 
		SELECT cte.OrigID
        FROM CTE_Group AS cte
        WHERE EXISTS (SELECT 1 FROM Temp_Upline AS tmp WHERE tmp.CTSCustID = cte.OrigID);
        
		SELECT COUNT(1)
        INTO lv_Count
        FROM Temp_NodeCTSCustID;
		
		IF lv_Count IS NULL OR lv_Count = 1 THEN
			TRUNCATE TABLE Temp_NodeCTSCustID;
        END IF;
		
		INSERT IGNORE INTO Temp_GroupID(GroupID)
        SELECT DISTINCT 
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
		
		UPDATE Temp_Upline AS tmp
        SET tmp.Processed = 1
        WHERE  EXISTS (SELECT 1 FROM Temp_GroupResult AS gp WHERE  gp.CTSCustID = tmp.CTSCustID);
        
		SET lv_GroupID = lv_GroupID + 1;
		
        TRUNCATE TABLE Temp_NodeCTSCustID;
        TRUNCATE TABLE Temp_GroupID;
	
	END LOOP;

    /*******************Return Data*************************/
	SELECT 	cus.CTSCustID AS OrigID
        ,	grp.GroupID AS DestID
    FROM Temp_GroupResult AS grp
		INNER JOIN Temp_Upline AS re ON re.CTSCustID = grp.CTSCustID
        INNER JOIN Temp_Cust AS cus ON re.CustID = cus.UplineCustID;
	
END$$

DELIMITER ;