/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_Association_GetDirectCustEdge`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_GetDirectCustEdge`(
		IN	ip_CTSCustIDs 		LONGTEXT
	,   IN  ip_HasDevice		BOOLEAN
    ,   IN  ip_HasAI			BOOLEAN
    ,   IN  ip_HasIP			BOOLEAN
)
    SQL SECURITY INVOKER
BEGIN 
	/*  
		Created:	20240415@Casey.Huynh
		Task:		Get
		DB:			CTS_DataCenter
        
		Revisions:
			- 20240415@Casey.Huynh: Created [Redmine ID: #203319]
			- 20240801@John.Ngo: 	Tuning performance: force index Ass by AI, IP  [Redmine ID: #208465]
		
        Param's Explanation (filtered by):	
            
		Example:
			CALL CTS_DC_Association_GetDirectCustEdge('1,2,3,4,5,6,7',1,1,1);

	*/
	DECLARE CONST_ASSOCIATIONTYPE_DEVICE	TINYINT DEFAULT 1; #AssociationByDevice
    DECLARE CONST_ASSOCIATIONTYPE_AI		TINYINT DEFAULT 2; #AssociationByAI
    DECLARE CONST_ASSOCIATIONTYPE_IP		TINYINT DEFAULT 3; #AssociationByIP

	DECLARE CONST_ASSTYPE_BETTINGPATTERN 		INT DEFAULT 2;
    DECLARE CONST_ASSTYPE_IP			 		INT DEFAULT 4;
	DECLARE CONST_ACTIVESTATUS 			INT DEFAULT 1;
    #=============================================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_CustNode;
	CREATE TEMPORARY TABLE 		Temp_CustNode (
			CTSCustID 			BIGINT UNSIGNED 
		 ,	CustID 				BIGINT UNSIGNED PRIMARY KEY
		 ,	INDEX IX_Temp_CustNode_CTSCustID(CTSCustID)
	);
    
	#=============================================================================
	DROP TEMPORARY TABLE IF EXISTS Temp_Graph;
    CREATE TEMPORARY TABLE 	Temp_Graph (
			OrigCustID 		BIGINT UNSIGNED
		,	DestCustID   	BIGINT UNSIGNED
		,	PRIMARY KEY PK_Temp_Graph_OrigCustID_DestCustID(OrigCustID, DestCustID)
	);
	
    #=============================================================================
	INSERT INTO Temp_CustNode(CTSCustID,CustID)
	SELECT 	DISTINCT
			cus.CTSCustID
		, 	cus.CustID
	FROM JSON_TABLE(CONCAT('[',ip_CTSCustIDs,']'),
							'$[*]' COLUMNS(NESTED PATH '$' COLUMNS (CTSCustID BIGINT UNSIGNED PATH '$'))) AS tmp
	INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = tmp.CTSCustID;
    
	#=============================================================================    
    IF ip_HasDevice = 1 THEN
    
        DROP TEMPORARY TABLE IF EXISTS Temp_CustDevice;
		CREATE TEMPORARY TABLE 	Temp_CustDevice (
				CTSCustID		BIGINT UNSIGNED
			,	CustID			INT
			,   DCSDeviceID		BIGINT UNSIGNED
			
			,	PRIMARY KEY PK_Temp_CustDevice_DCSDeviceID_CTSCustID(DCSDeviceID, CTSCustID)
		);

		DROP TEMPORARY TABLE IF EXISTS Temp_CustDevice2;
		CREATE TEMPORARY TABLE Temp_CustDevice2 (
				CTSCustID		BIGINT UNSIGNED
			,	CustID			INT
			,   DCSDeviceID		BIGINT UNSIGNED
			
			,	PRIMARY KEY PK_Temp_CustDevice2_DCSDeviceID_CTSCustID(DCSDeviceID, CTSCustID)
		);
		
		DROP TEMPORARY TABLE IF EXISTS Temp_DeviceOneCust;
		CREATE TEMPORARY TABLE Temp_DeviceOneCust(
				DCSDeviceID  BIGINT UNSIGNED PRIMARY KEY
		);
        
		#=============================================================================        
		INSERT IGNORE INTO Temp_CustDevice(CTSCustID, CustID, DCSDeviceID)
		SELECT 	tmpCn.CTSCustID 
			,	tmpCn.CustID
			, 	dv.DCSDeviceID
		FROM Temp_CustNode AS tmpCn
		INNER JOIN CTS_DataCenter.AssociationByDevice AS dv ON dv.CTSCustID = tmpCn.CTSCustID;

		INSERT INTO Temp_DeviceOneCust(DCSDeviceID)
		SELECT 	DCSDeviceID
		FROM Temp_CustDevice 
		GROUP BY DCSDeviceID
        HAVING COUNT(1) = 1;

		DELETE tmp
		FROM Temp_CustDevice AS tmp
		WHERE tmp.DCSDeviceID IN (SELECT DCSDeviceID FROM Temp_DeviceOneCust);
		
		INSERT INTO Temp_CustDevice2(CTSCustID, CustID, DCSDeviceID)
		SELECT	tmpCd.CTSCustID
			,	tmpCd.CustID
			,	tmpCd.DCSDeviceID
        FROM Temp_CustDevice AS tmpCd;

		INSERT IGNORE INTO Temp_Graph(OrigCustID, DestCustID)
		SELECT LEAST(tmpDv.CustID,tmpDv2.CustID)
			,  GREATEST(tmpDv.CustID,tmpDv2.CustID)
		FROM Temp_CustDevice AS tmpDv
			INNER JOIN Temp_CustDevice2 AS tmpDv2 ON tmpDv2.DCSDeviceID = tmpDv.DCSDeviceID AND tmpDv.CTSCustID != tmpDv2.CTSCustID;
		
        DROP TABLE Temp_CustDevice;
        DROP TABLE Temp_CustDevice2;
        DROP TABLE Temp_DeviceOneCust;
        
    END IF;
    
    IF(ip_HasAI = 1 OR ip_HasIP = 1) THEN
		DROP TEMPORARY TABLE IF EXISTS Temp_CustNode2;
		CREATE TEMPORARY TABLE Temp_CustNode2(
				CTSCustID 	BIGINT UNSIGNED 
			 ,	CustID 		BIGINT UNSIGNED PRIMARY KEY
		); 
        
        INSERT INTO Temp_CustNode2(CTSCustID, CustID)
        SELECT 	tmpCd.CTSCustID
			,	tmpCd.CustID 
		FROM Temp_CustNode AS tmpCd;    
    
		IF ip_HasAI= 1 THEN
		
			DROP TEMPORARY TABLE IF EXISTS Temp_GraphByAI_AssType;
			CREATE TEMPORARY TABLE 	Temp_GraphByAI_AssType (
				AssTypeItemValue INT PRIMARY KEY            
			);       
			
			INSERT INTO Temp_GraphByAI_AssType(AssTypeItemValue)
			SELECT atd.AssTypeItemValue
			FROM CTS_DataCenter.AssociationTypeSetting AS atd
			WHERE atd.AssTypeID = CONST_ASSTYPE_BETTINGPATTERN AND atd.AssTypeItemStatus = CONST_ACTIVESTATUS; 

			INSERT IGNORE INTO Temp_Graph(OrigCustID, DestCustID)
			SELECT	LEAST(tmpCd.CustID,ltr.CustID)
				,	GREATEST(tmpCd.CustID,ltr.CustID)
			FROM Temp_CustNode AS tmpCd
				,	LATERAL (	SELECT tmpCd2.CTSCustID, tmpCd2.CustID
								FROM CTS_DataCenter.AssociationByAI AS ai FORCE INDEX (IX_AssociationByAI_ToCustID_FromCustID)
									INNER JOIN Temp_CustNode2 AS tmpCd2 ON ai.ToCustID = tmpCd2.CustID
                                WHERE ai.FromCustID = tmpCd.CustID AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_GraphByAI_AssType AS tmpAt)
							) AS ltr;
            
			INSERT IGNORE INTO Temp_Graph(OrigCustID, DestCustID)
			SELECT	LEAST(tmpCd.CustID,ltr.CustID)
				,	GREATEST(tmpCd.CustID,ltr.CustID)
			FROM Temp_CustNode AS tmpCd
				,	LATERAL (	SELECT tmpCd2.CTSCustID, tmpCd2.CustID
								FROM CTS_DataCenter.AssociationByAI AS ai FORCE INDEX (UN_AssociationByAI_FromCustID_ToCustID)
									INNER JOIN Temp_CustNode2 AS tmpCd2 ON ai.FromCustID = tmpCd2.CustID
                                WHERE ai.ToCustID = tmpCd.CustID AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_GraphByAI_AssType AS tmpAt)
							) AS ltr;
		END IF;
		
		IF ip_HasIP= 1 THEN
        
			DROP TEMPORARY TABLE IF EXISTS Temp_GraphByIP_AssType;
			CREATE TEMPORARY TABLE 	Temp_GraphByIP_AssType (
				AssTypeItemValue INT PRIMARY KEY            
			);       
			
			INSERT INTO Temp_GraphByIP_AssType(AssTypeItemValue)
			SELECT atd.AssTypeItemValue
			FROM CTS_DataCenter.AssociationTypeSetting AS atd
			WHERE atd.AssTypeID = CONST_ASSTYPE_IP AND atd.AssTypeItemStatus = CONST_ACTIVESTATUS; 

			INSERT IGNORE INTO Temp_Graph(OrigCustID, DestCustID)
			SELECT	LEAST(tmpCd.CustID,ltr.CustID)
				,	GREATEST(tmpCd.CustID,ltr.CustID)
			FROM Temp_CustNode AS tmpCd
				,	LATERAL (	SELECT tmpCd2.CTSCustID, tmpCd2.CustID
								FROM CTS_DataCenter.AssociationByIP AS ip FORCE INDEX (IX_AssociationByIP_ToCustIDFromCustID)
									INNER JOIN Temp_CustNode2 AS tmpCd2 ON ip.ToCustID = tmpCd2.CustID
                                WHERE ip.FromCustID = tmpCd.CustID AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_GraphByIP_AssType AS tmpAt)
							) AS ltr;
                            
			INSERT IGNORE INTO Temp_Graph(OrigCustID, DestCustID)
			SELECT	LEAST(tmpCd.CustID,ltr.CustID)
				,	GREATEST(tmpCd.CustID,ltr.CustID)
			FROM Temp_CustNode AS tmpCd
				,	LATERAL (	SELECT tmpCd2.CTSCustID, tmpCd2.CustID
								FROM CTS_DataCenter.AssociationByIP AS ip FORCE INDEX (UX_AssociationByIP_FromCustIDToCustIDAssType)
									INNER JOIN Temp_CustNode2 AS tmpCd2 ON ip.FromCustID = tmpCd2.CustID
                                WHERE ip.ToCustID = tmpCd.CustID AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_GraphByIP_AssType AS tmpAt)
							) AS ltr;            
		END IF;
    END IF;
    
	SELECT 	OrigCustID 
		,	DestCustID
    FROM Temp_Graph;
	
END$$

DELIMITER ;