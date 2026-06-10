/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsAPI" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_GetByCustID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_GetByCustID`(
		IN	ip_CustID 			BIGINT
	,   IN  ip_HasDevice		BIT
    ,   IN  ip_HasAI			BIT
    ,   IN  ip_HasIP			BIT
)
    SQL SECURITY INVOKER
BEGIN 
	/*  
		Created:	20240122@Victoria.Le
		Task:		Get Association Detection - Top N members with have Last Ticket Date within 90 days
		DB:			CTS_DataCenter
        
		Revisions:
			- 20240122@Victoria.Le: Initial Writing[Redmine ID: #198742]
			- 20250103@Casey.Huynh: Tunning Performance [Redmine ID: #216376]

		Param's Explanation (filtered by):

        Example:
			- CALL CTS_DataCenter.CTS_DC_Association_GetByCustID(1275,1,0,0);
	*/
	
	DECLARE CONST_ASSTYPE_BETTINGPATTERN 	INT DEFAULT 2;
	DECLARE CONST_ASSBYAI_ACTIVESTATUS 		INT DEFAULT 1;    
	DECLARE CONST_ASSTYPE_IP 				INT DEFAULT 4;
	DECLARE CONST_ASSBYIP_ACTIVESTATUS 		INT DEFAULT 1; 
	
	DECLARE lv_Today 						DATETIME DEFAULT CURRENT_DATE();
	DECLARE lv_TakeDay 						INT DEFAULT 90;
	DECLARE lv_LastTicketDate_Valid			DATETIME;
	DECLARE lv_BatchSize					INT DEFAULT 50;
	#=============================================================================
	
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE 		Temp_Cust (
			CTSCustID 			BIGINT UNSIGNED 
		 ,	CustID 				BIGINT UNSIGNED PRIMARY KEY
		 ,	INDEX IX_Temp_Cust_CTSCustID(CTSCustID)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Association;
	CREATE TEMPORARY TABLE 		Temp_Association (
			CTSCustID_1 		BIGINT UNSIGNED DEFAULT 0
		 , 	CustID_1 			BIGINT UNSIGNED DEFAULT 0
		 ,	CTSCustID_2 	    BIGINT UNSIGNED DEFAULT 0
		 ,  CustID_2 	    	BIGINT UNSIGNED DEFAULT 0
		 ,  AssociationType		SMALLINT
		 ,	INDEX IX_Temp_Association_CTSCustID1_CTSCustID2(CTSCustID_1,CTSCustID_2)
		 ,	INDEX IX_Temp_Association_CustID1_CustID2(CustID_1,CustID_2)
         ,	INDEX IX_Temp_Association_CustID2(CustID_2)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustAssociation;
	CREATE TEMPORARY TABLE 		Temp_CustAssociation (
			CTSCustID 			BIGINT UNSIGNED PRIMARY KEY
		 ,	CustID 				BIGINT UNSIGNED 
		 ,	INDEX IX_Temp_CustAssociation_CustID(CustID)
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustAssociation_LastTicketDate_Valid;
	CREATE TEMPORARY TABLE 		Temp_CustAssociation_LastTicketDate_Valid (
			CTSCustID 			BIGINT UNSIGNED PRIMARY KEY
		 ,	CustID 				BIGINT UNSIGNED 
		 ,	LastTicketDate		DATETIME
		 ,	INDEX IX_Temp_CustAss_LTD_CustID(CustID)
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
	
	SET	lv_LastTicketDate_Valid = DATE_SUB(lv_Today, INTERVAL lv_TakeDay DAY);
	
	INSERT INTO Temp_AssociationByAI_AssType(AssTypeItemValue)
	SELECT atd.AssTypeItemValue
	FROM CTS_DataCenter.AssociationTypeSetting AS atd
	WHERE atd.AssTypeID = CONST_ASSTYPE_BETTINGPATTERN AND atd.AssTypeItemStatus = CONST_ASSBYAI_ACTIVESTATUS; 
	
	INSERT INTO Temp_AssociationByIP_AssType(AssTypeItemValue)
    SELECT atd.AssTypeItemValue
    FROM CTS_DataCenter.AssociationTypeSetting AS atd
    WHERE atd.AssTypeID = CONST_ASSTYPE_IP AND atd.AssTypeItemStatus = CONST_ASSBYIP_ACTIVESTATUS; 
	#=============================================================================
	
	INSERT IGNORE INTO Temp_Cust(CTSCustID, CustID)
	SELECT CTSCustID, CustID
	FROM CTS_DataCenter.CTSCustomer
	WHERE CustID = ip_CustID
		AND IsInternal = 0;
	
	/*******************AssociationType = 1 >> Device*************************/
    IF ip_HasDevice = 1 THEN
		DROP TEMPORARY TABLE IF EXISTS Temp_Device;
		CREATE TEMPORARY TABLE 	Temp_Device (
				DCSDeviceID			BIGINT 	PRIMARY KEY 
		);
		
		DROP TEMPORARY TABLE IF EXISTS Temp_CustDevice;
		CREATE TEMPORARY TABLE 		Temp_CustDevice (
				CTSCustID			BIGINT UNSIGNED  
			 ,	DCSDeviceID  		BIGINT UNSIGNED 
			 ,	PRIMARY KEY(DCSDeviceID, CTSCustID)
		);
		
		DROP TEMPORARY TABLE IF EXISTS Temp_DeviceCust_Group;
		CREATE TEMPORARY TABLE 		Temp_DeviceCust_Group (
				DCSDeviceID  		BIGINT UNSIGNED PRIMARY KEY
			 ,	TotalCust			INT
		);
		
		INSERT INTO Temp_Device(DCSDeviceID)
		SELECT	DISTINCT
				dv.DCSDeviceID 
		FROM Temp_Cust AS cus
			INNER JOIN CTS_DataCenter.AssociationByDevice AS dv ON dv.CTSCustID = cus.CTSCustID; 
	
		INSERT IGNORE INTO Temp_CustDevice(CTSCustID, DCSDeviceID)
		SELECT 	cus.CTSCustID
			, 	tmp.DCSDeviceID
		FROM Temp_Device AS tmp
			INNER JOIN CTS_DataCenter.AssociationByDevice AS lv1 ON tmp.DCSDeviceID =  lv1.DCSDeviceID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON lv1.CTSCustID = cus.CTSCustID AND cus.IsInternal = 0;
			
		INSERT INTO Temp_DeviceCust_Group(DCSDeviceID, TotalCust)
		SELECT 	DCSDeviceID
			, 	COUNT(1) AS TotalCust
		FROM Temp_CustDevice 
		GROUP BY DCSDeviceID;

		DELETE tmp
		FROM Temp_CustDevice AS tmp
		WHERE tmp.DCSDeviceID IN (SELECT DCSDeviceID FROM Temp_DeviceCust_Group WHERE TotalCust = 1);
		
		DROP TEMPORARY TABLE IF EXISTS Temp_CustDevice_Duplicate;
		CREATE TEMPORARY TABLE Temp_CustDevice_Duplicate LIKE Temp_CustDevice;
		
		INSERT INTO Temp_CustDevice_Duplicate 
		SELECT * FROM Temp_CustDevice;
		
		INSERT IGNORE INTO Temp_Association(CTSCustID_1, CTSCustID_2, AssociationType)
		SELECT DISTINCT dv.CTSCustID,  dv1.CTSCustID  , 1
		FROM Temp_CustDevice AS dv
			INNER JOIN Temp_Cust AS tmp ON dv.CTSCustID = tmp.CTSCustID
			INNER JOIN Temp_CustDevice_Duplicate AS dv1 ON dv.DCSDeviceID = dv1.DCSDeviceID AND dv.CTSCustID != dv1.CTSCustID;
			
	END IF;
	
    /*******************AssociationType = 3 >> AI*************************/
    IF ip_HasAI = 1 THEN
		INSERT IGNORE INTO Temp_Association(CustID_1, CustID_2, AssociationType)
		SELECT	tmp.CustID,  ai.ToCustID, 3
		FROM Temp_Cust AS tmp
			INNER JOIN CTS_DataCenter.AssociationByAI AS ai ON ai.FromCustID = tmp.CustID
																AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue 
																					FROM Temp_AssociationByAI_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ai.ToCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0;

		INSERT IGNORE INTO Temp_Association(CustID_1, CustID_2, AssociationType)
		SELECT	tmp.CustID,  ai.FromCustID, 3
		FROM Temp_Cust AS tmp 
			INNER JOIN CTS_DataCenter.AssociationByAI AS ai ON ai.ToCustID = tmp.CustID
																AND ai.AssType IN (SELECT tmpAt.AssTypeItemValue 
																					FROM Temp_AssociationByAI_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ai.FromCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0;
		
		/*******************AssociationType = 4 >> Group AI*************************/
		DROP TEMPORARY TABLE IF EXISTS Temp_AIGroup;
		CREATE TEMPORARY TABLE 	Temp_AIGroup (
				GroupID			BIGINT  PRIMARY KEY
		);
		
		DROP TEMPORARY TABLE IF EXISTS Temp_CustAIGroup;
		CREATE TEMPORARY TABLE 		Temp_CustAIGroup (
				CustID				BIGINT UNSIGNED  
			 ,	GroupID  			BIGINT UNSIGNED 
			 ,	PRIMARY KEY(GroupID, CustID)
		);
		
		DROP TEMPORARY TABLE IF EXISTS Temp_AIGroupCust_Group;
		CREATE TEMPORARY TABLE 		Temp_AIGroupCust_Group (
				GroupID		  		BIGINT UNSIGNED PRIMARY KEY
			 ,	TotalCust			INT
		);
		
		INSERT INTO Temp_AIGroup(GroupID)
		SELECT	DISTINCT asg.GroupID 
		FROM Temp_Cust AS cus 
			INNER JOIN CTS_DataCenter.AssociationGroupByAI AS asg ON asg.CustID = cus.CustID;  
		
		INSERT IGNORE INTO Temp_CustAIGroup(CustID, GroupID)
		SELECT 	cus.CustID 
			, 	asg.GroupID
		FROM Temp_AIGroup AS tmp 
			INNER JOIN CTS_DataCenter.AssociationGroupByAI AS asg ON tmp.GroupID = asg.GroupID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = asg.CustID AND cus.CustSubID = 0 AND cus.IsInternal = 0;
			
		INSERT INTO Temp_AIGroupCust_Group(GroupID, TotalCust)
		SELECT 	GroupID
			, 	COUNT(1) AS TotalCust
		FROM Temp_CustAIGroup 
		GROUP BY GroupID;
		
		DELETE tmp
		FROM Temp_CustAIGroup AS tmp
		WHERE tmp.GroupID IN (SELECT GroupID FROM Temp_AIGroupCust_Group WHERE TotalCust = 1);
		
		DROP TEMPORARY TABLE IF EXISTS Temp_CustAIGroup_Duplicate;
		CREATE TEMPORARY TABLE Temp_CustAIGroup_Duplicate LIKE Temp_CustAIGroup;
		
		INSERT INTO Temp_CustAIGroup_Duplicate 
		SELECT * FROM Temp_CustAIGroup;
		
		INSERT IGNORE INTO Temp_Association(CustID_1, CustID_2, AssociationType)
		SELECT DISTINCT asg.CustID,  asg1.CustID  , 4
		FROM Temp_CustAIGroup AS asg
			INNER JOIN Temp_CustAIGroup_Duplicate AS asg1 ON asg.GroupID = asg1.GroupID AND asg.CustID != asg1.CustID;
			
	END IF;
		
	/*******************AssociationType = 5 >> IP*************************/
	IF ip_HasIP = 1 THEN
		INSERT IGNORE INTO Temp_Association(CustID_1, CustID_2, AssociationType)
		SELECT	tmp.CustID,  ip.ToCustID, 5
		FROM Temp_Cust AS tmp
			INNER JOIN CTS_DataCenter.AssociationByIP AS ip ON ip.FromCustID = tmp.CustID
																AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue 
																					FROM Temp_AssociationByIP_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ip.ToCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0;

		INSERT IGNORE INTO Temp_Association(CustID_1, CustID_2, AssociationType)
		SELECT	tmp.CustID,  ip.FromCustID, 5
		FROM Temp_Cust AS tmp 
			INNER JOIN CTS_DataCenter.AssociationByIP AS ip ON ip.ToCustID = tmp.CustID
																AND ip.AssType IN (SELECT tmpAt.AssTypeItemValue 
																					FROM Temp_AssociationByIP_AssType AS tmpAt)
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = ip.FromCustID AND cus.CustSubID = 0 AND cus.IsInternal = 0;
		
	END IF;
	
	UPDATE Temp_Association AS ass
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ass.CustID_1 = cus.CustID
	SET ass.CTSCustID_1 = cus.CTSCustID
	WHERE ass.CTSCustID_1 = 0;
	
	UPDATE Temp_Association AS ass
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ass.CustID_2 = cus.CustID
	SET ass.CTSCustID_2 = cus.CTSCustID
	WHERE ass.CTSCustID_2 = 0;

	UPDATE Temp_Association AS ass
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ass.CTSCustID_1 = cus.CTSCustID
	SET ass.CustID_1 = cus.CustID
	WHERE ass.CustID_1 = 0;

	UPDATE Temp_Association AS ass
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ass.CTSCustID_2 = cus.CTSCustID
	SET ass.CustID_2 = cus.CustID
	WHERE ass.CustID_2 = 0;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Association_Duplicate;
	CREATE TEMPORARY TABLE Temp_Association_Duplicate LIKE Temp_Association;
	
	INSERT INTO Temp_CustAssociation (CTSCustID, CustID)
	SELECT DISTINCT CTSCustID_2, CustID_2
	FROM Temp_Association
	WHERE CustID_1 = ip_CustID AND CustID_2 != ip_CustID
	UNION
	SELECT DISTINCT CTSCustID_1, CustID_1
	FROM Temp_Association_Duplicate
	WHERE CustID_1 != ip_CustID AND CustID_2 = ip_CustID;
	
	INSERT INTO Temp_CustAssociation_LastTicketDate_Valid (CTSCustID, CustID, LastTicketDate)
	SELECT cass.CTSCustID, cass.CustID, ar.LastTicketDate
	FROM Temp_CustAssociation AS cass
		INNER JOIN CTS_Archive.CTSCustomerAssociationStatus AS ar ON ar.CTSCustID = cass.CTSCustID
	WHERE ar.LastTicketDate IS NOT NULL 
		AND ar.LastTicketDate >= lv_LastTicketDate_Valid
	ORDER BY ar.LastTicketDate DESC
	LIMIT lv_BatchSize;
		
	DROP TEMPORARY TABLE IF EXISTS Temp_CustAss_LastTD_Valid_Dup;
	CREATE TEMPORARY TABLE Temp_CustAss_LastTD_Valid_Dup LIKE Temp_CustAssociation_LastTicketDate_Valid;

	
	SELECT 	ass.CustID_2 AS CustID
		, 	ass.AssociationType AS AssociationTypeID
		, 	CASE WHEN ass.AssociationType = 1 THEN 'Device'
				 WHEN ass.AssociationType = 3 OR ass.AssociationType = 4 THEN 'Betting Pattern'
				 WHEN ass.AssociationType = 5 THEN 'IP' END AS AssociationTypeName
		,	ltd.LastTicketDate AS LastTicketDate
	FROM Temp_Association AS ass
		INNER JOIN Temp_CustAssociation_LastTicketDate_Valid AS ltd ON ass.CustID_1 = ip_CustID AND ltd.CustID = ass.CustID_2
	UNION
	SELECT 	ass.CustID_2 AS CustID
		, 	ass.AssociationType AS AssociationTypeID
		, 	CASE WHEN ass.AssociationType = 1 THEN 'Device'
				 WHEN ass.AssociationType = 3 OR ass.AssociationType = 4 THEN 'Betting Pattern'
				 WHEN ass.AssociationType = 5 THEN 'IP' END AS AssociationTypeName
		,	ltd.LastTicketDate AS LastTicketDate
	FROM Temp_Association_Duplicate AS ass
		INNER JOIN Temp_CustAss_LastTD_Valid_Dup AS ltd ON ass.CustID_2 = ip_CustID AND ltd.CustID = ass.CustID_1;
		
END$$

DELIMITER ;