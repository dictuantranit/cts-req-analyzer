/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService,ctsWeb" isFunction="0" isNested="1"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_AssociationDetection_GetGroup`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociationDetection_GetGroup`(
		IN	ip_CTSCustIDs LONGTEXT
)
    SQL SECURITY INVOKER
sp:BEGIN 
	/*  
		Created:	20210326@Aries.Nguyen
		Task:		Get Association Detection
		DB:			CTS_DataCenter
        
		Revisions:
			- 20210720@Aries.Nguyen: Created [Redmine ID: #157086]
            - 20210818@Aries.Nguyen: Exclude Unlink association [Redmine ID: #159708]
			- 20210915@Aries.Nguyen: Remove DeviceAssociationDay table [Redmine ID: #160470]
			- 20220408@Casey.Huynh: Add AssociationGroupByAI [Redmine ID: #171222]
			- 20220705@Aries.Nguyen:  Tuning performance of Association Detection [Redmine ID: #175086]

		Param's Explanation (filtered by):

        Example:
			- CALL CTS_DataCenter.CTS_DC_Association_GetGroupNLevel('257861,11436');
	*/
    DECLARE lv_CTSCustID 	BIGINT;
    DECLARE lv_GroupId 		INT DEFAULT 1;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustInfo;
	CREATE TEMPORARY TABLE 		Temp_CustInfo (
			CTSCustID 			BIGINT UNSIGNED PRIMARY KEY
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE 		Temp_Cust (
			CustID 				BIGINT UNSIGNED 
		,	CTSCustID 			BIGINT UNSIGNED PRIMARY KEY
		,	INDEX 				IX_Temp_Cust_CTSCustID(CustID)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustDevice;
	CREATE TEMPORARY TABLE 		Temp_CustDevice (
			CTSCustID			BIGINT UNSIGNED  
		,	DCSDeviceID  		BIGINT UNSIGNED 
		,	PRIMARY KEY(DCSDeviceID, CTSCustID)
	); 
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Device_Level0;
	CREATE TEMPORARY TABLE 		Temp_Device_Level0 (
			DCSDeviceID		BIGINT PRIMARY KEY
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Graph_Level1;
	CREATE TEMPORARY TABLE 	Temp_Graph_Level1 (
			CTSCustID		BIGINT  
		,	RelationID  	BIGINT
		,	PRIMARY KEY(RelationID, CTSCustID)
		,	INDEX IX_Temp_Graph_Level1(CTSCustID,RelationID)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_AssGroupByAI;
	CREATE TEMPORARY TABLE Temp_AssGroupByAI (
			GroupID BIGINT UNSIGNED
		,	CustID	BIGINT UNSIGNED
		, 	PRIMARY KEY (GroupID,CustID)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_AIGroup_Level0;
	CREATE TEMPORARY TABLE 	Temp_AIGroup_Level0 (
			GroupID		BIGINT UNSIGNED PRIMARY KEY
	);
	  
	DROP TEMPORARY TABLE IF EXISTS Temp_Group;
	CREATE TEMPORARY TABLE 		Temp_Group (
				CustID 				BIGINT  
			,	CTSCustID 			BIGINT  
			,	GroupID 			INT
			,	INDEX			    IX_Temp_Group(CustID)
			,	PRIMARY KEY (CTSCustID)
			
	);

    DROP TEMPORARY TABLE IF EXISTS Temp_GroupCount;
	CREATE TEMPORARY TABLE 	Temp_GroupCount (
				GroupID 	INT
			,	PRIMARY KEY (GroupID)
	);
	
	SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_CustInfo (CTSCustID) VALUES ('", REPLACE(ip_CTSCustIDs, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1;  
		
	INSERT IGNORE INTO Temp_Cust(CTSCustID, CustID)
	SELECT cus.CTSCustID, cus.CustID
	FROM Temp_CustInfo AS tmp
		LEFT JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = tmp.CTSCustID;
		
	INSERT IGNORE INTO Temp_CustDevice(CTSCustID, DCSDeviceID)
	SELECT 	cus.CTSCustID 
		, 	dv.DCSDeviceID
	FROM Temp_Cust AS cus
		INNER JOIN CTS_DataCenter.AssociationByDevice AS dv ON dv.CTSCustID = cus.CTSCustID;    
		
	INSERT INTO Temp_Device_Level0(DCSDeviceID)
	SELECT 	DISTINCT
				DCSDeviceID
	FROM Temp_CustDevice;    
		
	INSERT IGNORE INTO Temp_Graph_Level1(CTSCustID,RelationID)
	SELECT  cus.CTSCustID
		,	(-1) * tmp.DCSDeviceID AS RelationID
	FROM Temp_Device_Level0 AS tmp
		INNER JOIN CTS_DataCenter.AssociationByDevice AS lv1 ON tmp.DCSDeviceID =  lv1.DCSDeviceID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON lv1.CTSCustID = cus.CTSCustID;
	
	INSERT IGNORE INTO Temp_Graph_Level1(CTSCustID, RelationID)
	SELECT  tmp.CTSCustID
		, 	ma.FromCTSCustID AS RelationID
	FROM Temp_Cust AS tmp 
		INNER JOIN CTS_DataCenter.AssociationByManual AS ma ON ma.ToCTSCustID = tmp.CTSCustID;
			
	INSERT IGNORE INTO Temp_Graph_Level1(CTSCustID, RelationID)
	SELECT  tmp.CTSCustID
		, 	ma.ToCTSCustID AS RelationID
	FROM Temp_Cust AS tmp 
		INNER JOIN CTS_DataCenter.AssociationByManual AS ma ON ma.FromCTSCustID  = tmp.CTSCustID;
		
	INSERT IGNORE INTO Temp_Graph_Level1(CTSCustID, RelationID)
	SELECT  tmp.CTSCustID
		, 	cus.CTSCustID AS RelationID
	FROM Temp_Cust AS tmp 
		INNER JOIN CTS_DataCenter.AssociationByAI AS ai ON ai.FromCustID = tmp.CustID
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ai.ToCustID AND cus.CustSubID = 0;
		
	INSERT IGNORE INTO Temp_Graph_Level1(CTSCustID, RelationID)
	SELECT  tmp.CTSCustID
		, 	cus.CTSCustID AS RelationID
	FROM Temp_Cust AS tmp 
		INNER JOIN CTS_DataCenter.AssociationByAI AS ai ON ai.ToCustID = tmp.CustID
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ai.FromCustID AND cus.CustSubID = 0;
	
	INSERT IGNORE INTO Temp_AssGroupByAI(GroupID, CustID)
	SELECT	asg.GroupID 
		,	asg.CustID 
	FROM	Temp_Cust AS cus 
		INNER JOIN CTS_DataCenter.AssociationGroupByAI AS asg ON asg.CustID = cus.CustID;

	INSERT IGNORE INTO Temp_AIGroup_Level0(GroupID)
	SELECT 	GroupID
	FROM Temp_AssGroupByAI;   
		
	INSERT IGNORE INTO Temp_Graph_Level1(CTSCustID, RelationID)
	SELECT  cus.CTSCustID
		, 	(30000000000 + tmp.GroupID) AS RelationID
	FROM Temp_AIGroup_Level0 AS tmp 
		INNER JOIN CTS_DataCenter.AssociationGroupByAI AS asg ON tmp.GroupID = asg.GroupID
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = asg.CustID AND cus.CustSubID = 0;
	
	INSERT IGNORE INTO Temp_Graph_Level1(CTSCustID, RelationID)
	SELECT  tmp.CTSCustID
		, 	cus.CTSCustID  AS RelationID
	FROM Temp_Cust AS tmp 
		INNER JOIN CTS_DataCenter.AssociationByIP AS ip ON ip.FromCustID = tmp.CustID
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ip.ToCustID AND cus.CustSubID = 0;
        
	INSERT IGNORE INTO Temp_Graph_Level1(CTSCustID, RelationID)
	SELECT  tmp.CTSCustID
		, 	cus.CTSCustID  AS RelationID
	FROM Temp_Cust AS tmp 
		INNER JOIN CTS_DataCenter.AssociationByIP AS ip ON ip.ToCustID = tmp.CustID
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ip.FromCustID AND cus.CustSubID = 0;
		
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Graph_Level1_Dup;
	CREATE TEMPORARY TABLE Temp_Graph_Level1_Dup LIKE Temp_Graph_Level1;
	INSERT INTO Temp_Graph_Level1_Dup
	SELECT * FROM Temp_Graph_Level1;
	
	INSERT IGNORE INTO Temp_Graph_Level1
	SELECT RelationID,CTSCustID FROM Temp_Graph_Level1_Dup;

	lp: LOOP 
		SET lv_CTSCustID = NULL;
        
        SELECT CTSCustID
        INTO lv_CTSCustID
		FROM Temp_CustInfo
		LIMIT 1;
        
        IF lv_CTSCustID IS NULL 
        THEN 
            LEAVE lp; 
        END IF;
                         
		INSERT IGNORE INTO Temp_Group(CTSCustID,GroupID)
		WITH RECURSIVE CTE_Group AS ( 
				SELECT lv_CTSCustID AS CTSCustID
				UNION
				SELECT ass.CTSCustID 
				FROM Temp_Graph_Level1  AS ass
					INNER JOIN CTE_Group ON CTE_Group.CTSCustID = ass.RelationID
		) 
		SELECT CTSCustID, lv_GroupId FROM CTE_Group;
        
        DELETE tmp 
        FROM Temp_CustInfo AS tmp
        WHERE  tmp.CTSCustID = lv_CTSCustID
			OR EXISTS (SELECT 1 FROM Temp_Group AS gp WHERE  gp.CTSCustID = tmp.CTSCustID);
            
		SET lv_GroupId = lv_GroupId + 1;
	END LOOP;
     
	DELETE 
	FROM Temp_Group AS grp
	WHERE NOT EXISTS (SELECT 1 FROM Temp_Cust AS tmp WHERE grp.CTSCustID = tmp.CTSCustID);

    INSERT INTO Temp_GroupCount(GroupID)
    SELECT GroupID 
    FROM Temp_Group
    GROUP BY GroupID
    HAVING COUNT(1) = 1;
    
    DELETE 
	FROM Temp_Group AS grp
	WHERE EXISTS (SELECT 1 FROM Temp_GroupCount AS tmp WHERE grp.GroupID = tmp.GroupID);

END$$

DELIMITER ;
