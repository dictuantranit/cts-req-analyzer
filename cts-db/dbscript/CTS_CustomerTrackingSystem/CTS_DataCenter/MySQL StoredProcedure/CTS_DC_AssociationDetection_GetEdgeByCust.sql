/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="1"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_AssociationDetection_GetEdgeByCust`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociationDetection_GetEdgeByCust`(
		IN	ip_CTSCustID		BIGINT
	,	IN	ip_CustJson 		JSON
	,   IN  ip_HasDevice		BIT
    ,   IN  ip_HasAI			BIT
    ,   IN  ip_HasIP			BIT
)
    SQL SECURITY INVOKER
sp:BEGIN  
	/*  
		Created:	20221207@Aries.Nguyen
		Task:		Re-arrange type options on Association Detection 
		DB:			CTS_DataCenter
        
		Revisions:
			- 20221207@Aries.Nguyen: 	Created [Redmine ID: #181207]
			- 20230112@Victoria.Le: 	Modify SPs due to restructure AssociationByAI [Redmine ID: #181994]
            - 20230313@Casey.Huynh:		Applied Betting Parten OTGB [Redmine ID: #184791]
			- 20230421@Casey.Huynh: 	Add AssType to AssociationByIP [Redmine ID: #185783]
            
		Param's Explanation (filtered by): 

        Example:
			- CALL CTS_DataCenter.CTS_DC_AssociationDetection_GetEdgeByCust(11140, '[{"CTSCustID":5422,"CustID":169686},{"CTSCustID":5424,"CustID":169689}]' ,1,1,1); SELECT * FROM Temp_Graph;
	*/
	DECLARE CONST_ASSTYPE_BETTINGPATTERN 	INT DEFAULT 2;
	DECLARE CONST_ASSBYAI_ACTIVESTATUS 		INT DEFAULT 1;    
    DECLARE CONST_ASSTYPE_IP 				INT DEFAULT 4;
	DECLARE CONST_ASSBYIP_ACTIVESTATUS 		INT DEFAULT 1;    
	#=============================================================================
    DECLARE CONS_RangeDevice 			BIGINT DEFAULT 10000000000;
	DECLARE CONS_RangeAIGroup 			BIGINT DEFAULT 20000000000;
    DECLARE lv_CustID		 			BIGINT;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustNode;
	CREATE TEMPORARY TABLE 	Temp_CustNode (
			CTSCustID 			BIGINT  PRIMARY KEY 
		,	CustID   			BIGINT	
		,	INDEX 				IX_Temp_CustNode(CustID)
	);  
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustNode_Dup;
	CREATE TEMPORARY TABLE 		Temp_CustNode_Dup (
			CTSCustID		BIGINT UNSIGNED PRIMARY KEY
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Graph;
    CREATE TEMPORARY TABLE 	Temp_Graph (
			OrigID 				BIGINT  
		,	DestID   			BIGINT
		,	AssociationType		SMALLINT 
		,	PRIMARY KEY(OrigID, DestID,AssociationType)
		,	INDEX IX_Temp_Graph(DestID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Transitive;
	CREATE TEMPORARY TABLE 		Temp_Transitive (
			Transitive	BIGINT PRIMARY KEY
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByAI_AssType (
		AssTypeItemValue INT PRIMARY KEY            
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByIP_AssType (
		AssTypeItemValue INT PRIMARY KEY            
	);
    
    #===========GET AssociationByIP status is Applied==============================================   
	INSERT INTO Temp_AssociationByIP_AssType(AssTypeItemValue)
	SELECT atd.AssTypeItemValue
	FROM CTS_DataCenter.AssociationTypeSetting AS atd
	WHERE atd.AssTypeID = CONST_ASSTYPE_IP 
		AND atd.AssTypeItemStatus = CONST_ASSBYIP_ACTIVESTATUS;
    
	#===========GET AssociationByAI status is Applied==============================================    
	INSERT INTO Temp_AssociationByAI_AssType(AssTypeItemValue)
	SELECT atd.AssTypeItemValue
	FROM CTS_DataCenter.AssociationTypeSetting AS atd
	WHERE atd.AssTypeID = CONST_ASSTYPE_BETTINGPATTERN AND atd.AssTypeItemStatus = CONST_ASSBYAI_ACTIVESTATUS; 
                        
    INSERT IGNORE INTO Temp_CustNode(CTSCustID, CustID)
	SELECT 	js.CTSCustID
		, 	js.CustID
	FROM JSON_TABLE(ip_CustJson,
		 "$[*]" COLUMNS(
				CTSCustID 		BIGINT 		PATH "$.CTSCustID"
			,	CustID 			BIGINT 		PATH "$.CustID"
		 )) AS js;
	
    SELECT CustID
    INTO lv_CustID
    FROM CTS_DataCenter.CTSCustomer AS cus
    WHERE cus.CTSCustID = ip_CTSCustID;
    
    INSERT INTO Temp_CustNode_Dup(CTSCustID)
    SELECT CTSCustID
    FROM Temp_CustNode;
    
    /*******************1. Device*************************/
    IF ip_HasDevice = 1 THEN
		DROP TEMPORARY TABLE IF EXISTS Temp_Device;
		CREATE TEMPORARY TABLE 		Temp_Device (
				DCSDeviceID			BIGINT PRIMARY KEY 
			,	IsRoot				BIT DEFAULT 0
            ,	INDEX				IX_Temp_Device_IsRoot(IsRoot)
		);
        
		DROP TEMPORARY TABLE IF EXISTS Temp_Edge;
		CREATE TEMPORARY TABLE 		Temp_Edge (
				CTSCustID		BIGINT 
			,	DCSDeviceID		BIGINT 
			,	PRIMARY KEY		PK_Temp_Edge(CTSCustID, DCSDeviceID)
            ,	INDEX			IX_Temp_Edge_DCSDeviceID(DCSDeviceID)
		);
        
        DROP TEMPORARY TABLE IF EXISTS Temp_DeviceEdge2;
		CREATE TEMPORARY TABLE 		Temp_DeviceEdge2 (
				OrigID			BIGINT 
			,	DestID			BIGINT 
			,	PRIMARY KEY		PK_Temp_DeviceEdge2(OrigID, DestID)
            ,	INDEX			IX_Temp_DeviceEdge2_DestID(DestID)
		);
        
        INSERT IGNORE INTO Temp_Device(DCSDeviceID,IsRoot)
		SELECT 	dv.DCSDeviceID 
			,	1 AS IsRoot
		FROM CTS_DataCenter.AssociationByDevice AS dv 
        WHERE dv.CTSCustID = ip_CTSCustID;
        
        INSERT IGNORE INTO Temp_Device(DCSDeviceID,IsRoot)
		SELECT 	dv.DCSDeviceID 
			,	0 AS IsRoot
		FROM Temp_CustNode AS cus
			INNER JOIN CTS_DataCenter.AssociationByDevice AS dv ON dv.CTSCustID = cus.CTSCustID;  
		
        INSERT IGNORE INTO Temp_Edge(CTSCustID, DCSDeviceID)
        SELECT 	cus.CTSCustID
			,	tmp.DCSDeviceID
		FROM Temp_Device AS tmp
			INNER JOIN CTS_DataCenter.AssociationByDevice AS lv1 ON tmp.DCSDeviceID =  lv1.DCSDeviceID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON lv1.CTSCustID = cus.CTSCustID AND cus.IsInternal = 0;
        ##################################################################################
		#	C1 ----Edge1----> D1 ----Edge2----> C2 ----Edge3----> D2 ----Edge4----> C3   #
        ##################################################################################
        
        #Add Edge 1
        INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  tmp.CTSCustID AS OrigID
			,	(CONS_RangeDevice + tmp.DCSDeviceID) AS DestID
			,	1 AS AssociationType 
		FROM Temp_Edge AS tmp
        WHERE tmp.CTSCustID = ip_CTSCustID;
 
        #Add Edge 2
		INSERT IGNORE INTO Temp_DeviceEdge2(OrigID,DestID)
		SELECT  edge.DCSDeviceID AS OrigID
			,	edge.CTSCustID AS DestID
		FROM Temp_Device AS dv
			INNER JOIN Temp_Edge AS edge ON dv.DCSDeviceID = edge.DCSDeviceID AND edge.CTSCustID != ip_CTSCustID
        WHERE  dv.IsRoot = 1;
        
        INSERT IGNORE INTO Temp_Transitive(Transitive)
        SELECT 	DISTINCT
				DestID
        FROM Temp_DeviceEdge2;
        
        INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT 	(CONS_RangeDevice + OrigID)
			,	DestID
			,	1 AS AssociationType 
		FROM Temp_DeviceEdge2;
		
    END IF;
    /*******************3. AI*************************/
    IF ip_HasAI = 1 THEN
		##################################################################################
		#				C1 ----Edge1----> C2 ----Edge2----> C3 							 #
        ##################################################################################
        DROP TEMPORARY TABLE IF EXISTS Temp_AIEdge1;
		CREATE TEMPORARY TABLE 		Temp_AIEdge1 (
				DestID			BIGINT PRIMARY KEY	
		);
        
        #Add Edge 1
		INSERT IGNORE INTO Temp_AIEdge1(DestID)
		SELECT  cus.CTSCustID AS DestID
		FROM CTS_DataCenter.AssociationByAI AS ai
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ai.ToCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0
		WHERE ai.FromCustID = lv_CustID
			AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt);
        
		#Add Edge 1
        INSERT IGNORE INTO Temp_AIEdge1(DestID)
		SELECT  cus.CTSCustID AS DestID
		FROM CTS_DataCenter.AssociationByAI AS ai
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ai.FromCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0
		WHERE ai.ToCustID = lv_CustID
			AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt);
        
        INSERT IGNORE INTO Temp_Transitive(Transitive)
        SELECT 	DISTINCT
				DestID
        FROM Temp_AIEdge1;
        
        INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
        SELECT	ip_CTSCustID AS OrigID
			,	DestID
            ,	3 AS AssociationType
		FROM Temp_AIEdge1;
        
		/*******************4. Group AI*************************/
		DROP TEMPORARY TABLE IF EXISTS Temp_Group;
		CREATE TEMPORARY TABLE 		Temp_Group (
				GroupID				BIGINT PRIMARY KEY 
			,	IsRoot				BIT DEFAULT 0
            ,	INDEX				IX_Temp_Group_IsRoot(IsRoot)
		);
        
		DROP TEMPORARY TABLE IF EXISTS Temp_GroupEdge;
		CREATE TEMPORARY TABLE 		Temp_GroupEdge (
				CTSCustID		BIGINT 
			,	GroupID			BIGINT 
			,	PRIMARY KEY		PK_Temp_GroupEdge(CTSCustID, GroupID)
            ,	INDEX			IX_Temp_GroupEdge_GroupID(GroupID)
		);
		
        DROP TEMPORARY TABLE IF EXISTS Temp_GroupEdge2;
		CREATE TEMPORARY TABLE 		Temp_GroupEdge2 (
				OrigID			BIGINT 
			,	DestID			BIGINT 
			,	PRIMARY KEY		PK_Temp_GroupEdge2(OrigID, DestID)
            ,	INDEX			IX_Temp_GroupEdge2_DestID(DestID)
		);
        
		INSERT IGNORE INTO Temp_Group(GroupID,IsRoot)
		SELECT 	grp.GroupID 
			,	1 AS IsRoot
		FROM CTS_DataCenter.AssociationGroupByAI AS grp 
        WHERE grp.CustID = lv_CustID;
        
        INSERT IGNORE INTO Temp_Group(GroupID,IsRoot)
		SELECT 	grp.GroupID 
			,	0 AS IsRoot
		FROM Temp_CustNode AS cus
			INNER JOIN CTS_DataCenter.AssociationGroupByAI AS grp ON grp.CustID = cus.CustID;  
		
        INSERT IGNORE INTO Temp_GroupEdge(CTSCustID, GroupID)
        SELECT 	cus.CTSCustID
			,	tmp.GroupID
		FROM Temp_Group AS tmp
			INNER JOIN CTS_DataCenter.AssociationGroupByAI AS grp ON tmp.GroupID =  grp.GroupID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON grp.CustID = cus.CustID AND cus.IsInternal = 0;
            
		##################################################################################
		#	C1 ----Edge1----> G1 ----Edge2----> C2 ----Edge3----> G2 ----Edge4----> C3   #
        ##################################################################################
        
        #Add Edge 1
        INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  tmp.CTSCustID AS OrigID
			,	(CONS_RangeAIGroup + tmp.GroupID) AS DestID
			,	4 AS AssociationType 
		FROM Temp_GroupEdge AS tmp
        WHERE tmp.CTSCustID = ip_CTSCustID;

        #Add Edge 2
        INSERT IGNORE INTO Temp_GroupEdge2(OrigID,DestID)
		SELECT  edge.GroupID AS OrigID
			,	edge.CTSCustID AS DestID
		FROM Temp_Group AS grp
			INNER JOIN Temp_GroupEdge AS edge ON grp.GroupID = edge.GroupID AND edge.CTSCustID != ip_CTSCustID
        WHERE  grp.IsRoot = 1;
        
        INSERT IGNORE INTO Temp_Transitive(Transitive)
        SELECT 	DISTINCT
				DestID
        FROM Temp_GroupEdge2;
        
        INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT 	(CONS_RangeAIGroup + OrigID)
			,	DestID
			,	4 AS AssociationType 
		FROM Temp_GroupEdge2;
    END IF;
    
    /*******************5. IP*************************/
    IF ip_HasIP = 1 THEN
		##################################################################################
		#				C1 ----Edge1----> C2 ----Edge2----> C3 							 #
        ##################################################################################
        DROP TEMPORARY TABLE IF EXISTS Temp_IPEdge1;
		CREATE TEMPORARY TABLE 		Temp_IPEdge1 (
				DestID			BIGINT PRIMARY KEY	
		);

        #Add Edge 1
		INSERT IGNORE INTO Temp_IPEdge1(DestID)
		SELECT  cus.CTSCustID AS DestID
		FROM CTS_DataCenter.AssociationByIP AS ip
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ip.ToCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0
		WHERE ip.FromCustID = lv_CustID
			AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt);
        
		#Add Edge 1
        INSERT IGNORE INTO Temp_IPEdge1(DestID)
		SELECT  cus.CTSCustID AS DestID
		FROM CTS_DataCenter.AssociationByIP AS ip
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ip.FromCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0
		WHERE ip.ToCustID = lv_CustID
			AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt);
        
        INSERT IGNORE INTO Temp_Transitive(Transitive)
        SELECT 	DISTINCT
				DestID
        FROM Temp_IPEdge1;
        
        INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
        SELECT	ip_CTSCustID AS OrigID
			,	DestID
            ,	5 AS AssociationType
        FROM Temp_IPEdge1;
	END IF;
    /*******************1. Device*************************/
    IF ip_HasDevice = 1 THEN
		#Add Edge 3
        INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  edge.CTSCustID  AS OrigID
			,	(CONS_RangeDevice + edge.DCSDeviceID) AS DestID
			,	1 AS AssociationType 
		FROM Temp_Edge AS edge
        WHERE EXISTS (SELECT 1 FROM Temp_Transitive AS tr WHERE edge.CTSCustID = tr.Transitive)
			AND NOT EXISTS (SELECT 1 FROM Temp_Device AS dv WHERE dv.DCSDeviceID = edge.DCSDeviceID AND dv.IsRoot = 1)
			AND edge.CTSCustID != ip_CTSCustID;
        
		#Add Edge 4
		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  (CONS_RangeDevice + edge.DCSDeviceID) AS OrigID
			,	 edge.CTSCustID AS DestID
			,	1 AS AssociationType 
		FROM Temp_Edge AS edge
        WHERE EXISTS (SELECT 1 FROM Temp_CustNode AS cus WHERE cus.CTSCustID = edge.CTSCustID)
			AND NOT EXISTS (SELECT 1 FROM Temp_Device AS dv WHERE dv.DCSDeviceID = edge.DCSDeviceID AND dv.IsRoot = 1)
            AND NOT EXISTS (SELECT 1 FROM Temp_Transitive AS tr WHERE tr.Transitive = edge.CTSCustID);
    END IF;
    /*******************3. AI*************************/
    IF ip_HasAI = 1 THEN
		#Add Edge 2
		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  cus.CTSCustID AS OrigID  
			, 	tmp.CTSCustID AS DestID
			,	3 AS AssociationType
		FROM Temp_CustNode AS tmp 
			INNER JOIN CTS_DataCenter.AssociationByAI AS ai ON ai.FromCustID = tmp.CustID
																AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ai.ToCustID 
															AND cus.CustSubID = 0 
                                                            AND cus.IsInternal = 0 
                                                            AND ai.ToCustID != lv_CustID
															AND ai.FromCustID != lv_CustID
		WHERE EXISTS (SELECT 1 FROM Temp_Transitive AS tr WHERE tr.Transitive = cus.CTSCustID);
		
        #Add Edge 2
		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  cus.CTSCustID AS OrigID  
			, 	tmp.CTSCustID AS DestID
			,	3 AS AssociationType
		FROM Temp_CustNode AS tmp 
			INNER JOIN CTS_DataCenter.AssociationByAI AS ai ON ai.ToCustID = tmp.CustID
																AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ai.FromCustID 
															AND cus.CustSubID = 0 
                                                            AND cus.IsInternal = 0  
                                                            AND ai.FromCustID != lv_CustID
                                                            AND ai.ToCustID != lv_CustID
		WHERE EXISTS (SELECT 1 FROM Temp_Transitive AS tr WHERE tr.Transitive = cus.CTSCustID);
        
        
        #AI Group ----- Add Edge 3
        INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  edge.CTSCustID  AS OrigID
			,	(CONS_RangeAIGroup + edge.GroupID) AS DestID
			,	4 AS AssociationType 
		FROM Temp_GroupEdge AS edge
		WHERE EXISTS (SELECT 1 FROM Temp_Transitive AS tr WHERE edge.CTSCustID = tr.Transitive)
			AND NOT EXISTS (SELECT 1 FROM Temp_Group AS grp WHERE grp.GroupID = edge.GroupID AND grp.IsRoot = 1)
			AND edge.CTSCustID != ip_CTSCustID;
            
            
         #Add Edge 4
		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  (CONS_RangeAIGroup + edge.GroupID) AS OrigID
			,	 edge.CTSCustID AS DestID
			,	4 AS AssociationType 
		FROM Temp_GroupEdge AS edge
        WHERE EXISTS (SELECT 1 FROM Temp_CustNode AS cus WHERE cus.CTSCustID = edge.CTSCustID)
			AND NOT EXISTS (SELECT 1 FROM Temp_Group AS grp WHERE grp.GroupID = edge.GroupID AND grp.IsRoot = 1)
			AND NOT EXISTS (SELECT 1 FROM Temp_Transitive AS tr WHERE tr.Transitive = edge.CTSCustID);
    END IF;
    /*******************5. IP*************************/
    IF ip_HasIP = 1 THEN
		#Add Edge 2
		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  cus.CTSCustID AS OrigID  
			, 	tmp.CTSCustID AS DestID
			,	5 AS AssociationType
		FROM Temp_CustNode AS tmp 
			INNER JOIN CTS_DataCenter.AssociationByIP AS ip ON ip.ToCustID = tmp.CustID AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ip.FromCustID 
															AND cus.CustSubID = 0 
                                                            AND cus.IsInternal = 0
                                                            AND ip.FromCustID != lv_CustID
                                                            AND ip.ToCustID != lv_CustID
		WHERE EXISTS (SELECT 1 FROM Temp_Transitive AS tr WHERE tr.Transitive = cus.CTSCustID);
		
        #Add Edge 2     
		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  cus.CTSCustID AS OrigID  
			, 	tmp.CTSCustID AS DestID
			,	5 AS AssociationType
		FROM Temp_CustNode AS tmp 
			INNER JOIN CTS_DataCenter.AssociationByIP AS ip ON ip.FromCustID = tmp.CustID AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ip.ToCustID 
															AND cus.CustSubID = 0 
                                                            AND cus.IsInternal = 0
                                                            AND ip.ToCustID != lv_CustID
                                                            AND ip.FromCustID != lv_CustID
		WHERE EXISTS (SELECT 1 FROM Temp_Transitive AS tr WHERE tr.Transitive = cus.CTSCustID);
		
    END IF;
END$$

DELIMITER ;
