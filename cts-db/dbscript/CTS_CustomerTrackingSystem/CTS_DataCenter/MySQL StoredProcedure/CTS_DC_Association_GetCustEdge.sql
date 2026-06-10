/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService,ctsWeb,ctsAPI" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_GetCustEdge`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_GetCustEdge`(
		IN	ip_CustJson 		JSON
	,   IN  ip_HasDevice		BIT
    ,   IN  ip_HasAI			BIT
    ,   IN  ip_HasIP			BIT
)
    SQL SECURITY INVOKER
BEGIN 
	/*  
		Created:	20231117@Victoria.Le
		Task:		Enhance Association Detection
		DB:			CTS_DataCenter
        
		Revisions:
			- 20231117@Victoria.Le: Initial Writing - Renovate Association Detection [Redmine ID: #192172]
		
		---------------------------------------------------------------------------------------------------
		[Before #192172]: CTS_DC_AssociationDetection_GetEdge
			- 20221006@Aries.Nguyen: 	Created [Redmine ID: #178310]
			- 20221025@Aries.Nguyen: 	Tuning performance: Skip the processed trans  [Redmine ID: #179439]
			- 20221205@Aries.Nguyen: 	Re-arrange type options on Association Detection  [Redmine ID: #181207]
			- 20230112@Victoria.Le: 	Modify SPs due to restructure AssociationByAI [Redmine ID: #181994]
			- 20230313@Casey.Huynh:		Applied Betting Parten OTGB [Redmine ID: #184791]
            - 20230421@Casey.Huynh: 	Add AssType to AssociationByIP [Redmine ID: #185783]
			- 20240704@John.Ngo:		Tuning performance: force index Ass by AI, IP  [Redmine ID: #207635]
			- 20240801@John.Ngo: 		Tuning performance: force index Ass by AI, IP  [Redmine ID: #208465]
		

		Param's Explanation (filtered by):

        Example:
			- CALL CTS_DataCenter.CTS_DC_Association_GetCustEdge('1,2,3',1,0,0);
	*/
	DECLARE CONST_ASSTYPE_BETTINGPATTERN 	INT DEFAULT 2;
	DECLARE CONST_ASSBYAI_ACTIVESTATUS 		INT DEFAULT 1;    
	DECLARE CONST_ASSTYPE_IP 				INT DEFAULT 4;
	DECLARE CONST_ASSBYIP_ACTIVESTATUS 		INT DEFAULT 1; 

	DECLARE CONST_RangeDevice				BIGINT DEFAULT 10000000000;
	DECLARE CONST_RangeAIGroup				BIGINT DEFAULT 20000000000;
	#=============================================================================
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustNode;
	CREATE TEMPORARY TABLE 	Temp_CustNode (
			CTSCustID 						BIGINT	PRIMARY KEY 
		,	CustID   						BIGINT	
		,	INDEX IX_Temp_CustNode_CustID (CustID)
	);  
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Graph;
    CREATE TEMPORARY TABLE 	Temp_Graph (
			OrigID 							BIGINT  
		,	DestID   						BIGINT
		,	AssociationType					SMALLINT 
		,	PRIMARY KEY(OrigID,DestID)
		,	INDEX IX_Temp_Graph_DestID (DestID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByAI_AssType (
			AssTypeItemValue 				INT 	PRIMARY KEY            
	);
	
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByIP_AssType (
			AssTypeItemValue 				INT 	PRIMARY KEY            
	);
	#=============================================================================
	
	INSERT INTO Temp_AssociationByAI_AssType(AssTypeItemValue)
	SELECT atd.AssTypeItemValue
	FROM CTS_DataCenter.AssociationTypeSetting AS atd
	WHERE atd.AssTypeID = CONST_ASSTYPE_BETTINGPATTERN AND atd.AssTypeItemStatus = CONST_ASSBYAI_ACTIVESTATUS; 
	
	INSERT INTO Temp_AssociationByIP_AssType(AssTypeItemValue)
    SELECT atd.AssTypeItemValue
    FROM CTS_DataCenter.AssociationTypeSetting AS atd
    WHERE atd.AssTypeID = CONST_ASSTYPE_IP AND atd.AssTypeItemStatus = CONST_ASSBYIP_ACTIVESTATUS; 
	#=============================================================================
	
	INSERT IGNORE INTO Temp_CustNode(CTSCustID, CustID)
	SELECT 	js.CTSCustID
		, 	js.CustID
	FROM JSON_TABLE(ip_CustJson,
					 "$[*]" COLUMNS(
										CTSCustID 		BIGINT 		PATH "$.CTSCustID"
									,	CustID 			BIGINT 		PATH "$.CustID")) AS js;
    
	/*******************AssociationType = 1 >> Device*************************/
    IF ip_HasDevice = 1 THEN
		DROP TEMPORARY TABLE IF EXISTS Temp_Device;
		CREATE TEMPORARY TABLE 	Temp_Device (
				DCSDeviceID			BIGINT 	PRIMARY KEY 
		);
		
		INSERT INTO Temp_Device(DCSDeviceID)
		SELECT	DISTINCT
				dv.DCSDeviceID 
		FROM Temp_CustNode AS cus
			INNER JOIN CTS_DataCenter.AssociationByDevice AS dv ON dv.CTSCustID = cus.CTSCustID; 
        
		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  cus.CTSCustID AS OrigID
			,	(CONST_RangeDevice + tmp.DCSDeviceID) AS DestID
			,	1 AS AssociationType 
		FROM Temp_Device AS tmp
			INNER JOIN CTS_DataCenter.AssociationByDevice AS lv1 ON tmp.DCSDeviceID =  lv1.DCSDeviceID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON lv1.CTSCustID = cus.CTSCustID AND cus.IsInternal = 0;
	END IF;
	
    /*******************AssociationType = 3 >> AI*************************/
    IF ip_HasAI = 1 THEN
		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  tmp.CTSCustID AS OrigID
			, 	cus.CTSCustID AS DestID
			,	3 AS AssociationType
		FROM Temp_CustNode AS tmp 
			INNER JOIN CTS_DataCenter.AssociationByAI AS ai FORCE INDEX (UN_AssociationByAI_FromCustID_ToCustID) ON ai.FromCustID = tmp.CustID 
																AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue 
																					FROM Temp_AssociationByAI_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ai.ToCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0;
			
		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  tmp.CTSCustID AS OrigID
			, 	cus.CTSCustID AS DestID
			,	3 AS AssociationType
		FROM Temp_CustNode AS tmp 
			INNER JOIN CTS_DataCenter.AssociationByAI AS ai FORCE INDEX (IX_AssociationByAI_ToCustID_FromCustID) ON ai.ToCustID = tmp.CustID 
																AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue 
																					FROM Temp_AssociationByAI_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ai.FromCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0;
		
		/*******************AssociationType = 4 >> Group AI*************************/
		DROP TEMPORARY TABLE IF EXISTS Temp_AIGroup;
		CREATE TEMPORARY TABLE 	Temp_AIGroup (
				GroupID			BIGINT  PRIMARY KEY
		);
		
		INSERT INTO Temp_AIGroup(GroupID)
		SELECT	DISTINCT
				asg.GroupID 
		FROM Temp_CustNode AS cus 
			INNER JOIN CTS_DataCenter.AssociationGroupByAI AS asg ON asg.CustID = cus.CustID;  

		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  cus.CTSCustID AS OrigID
			, 	(CONST_RangeAIGroup + tmp.GroupID) AS DestID
			,	4 AS AssociationType
		FROM Temp_AIGroup AS tmp 
			INNER JOIN CTS_DataCenter.AssociationGroupByAI AS asg ON tmp.GroupID = asg.GroupID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = asg.CustID AND cus.CustSubID = 0 AND cus.IsInternal = 0;
		
	END IF;
		
	/*******************AssociationType = 5 >> IP*************************/
	IF ip_HasIP = 1 THEN
		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  tmp.CTSCustID AS OrigID
			, 	cus.CTSCustID AS DestID
			,	5 AS AssociationType
		FROM Temp_CustNode AS tmp 
			INNER JOIN CTS_DataCenter.AssociationByIP AS ip FORCE INDEX (UX_AssociationByIP_FromCustIDToCustIDAssType) ON ip.FromCustID = tmp.CustID 
																AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ip.ToCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0;
			
		INSERT IGNORE INTO Temp_Graph(OrigID,DestID,AssociationType)
		SELECT  tmp.CTSCustID AS OrigID
			, 	cus.CTSCustID AS DestID
			,	5 AS AssociationType
		FROM Temp_CustNode AS tmp 
			INNER JOIN CTS_DataCenter.AssociationByIP AS ip FORCE INDEX (IX_AssociationByIP_ToCustIDFromCustID) ON ip.ToCustID = tmp.CustID 
																AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ip.FromCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0;
		
	END IF;

END$$

DELIMITER ;