/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `Adhoc_HF115554_RescanMemberGroup`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `Adhoc_HF115554_RescanMemberGroup`(	
) 
    SQL SECURITY INVOKER
sp : BEGIN
	/* 
		Created:	20241219@Casey.Huynh
		Task:		Scan Member  [Redmine ID: #215554]
		DB:			CTS_DataCenter
		Original:

		Revisions:
            - 20241219@Casey.Huynh: Created [Redmine ID: #215554]

		Param's Explanation (filtered by):

		Example:
			- CALL  Adhoc_HF115554_RescanMemberGroup();
	*/
	DECLARE CONST_ASSTYPE_BETTINGPATTERN 	INT DEFAULT 2;
	DECLARE CONST_ASSBYAI_ACTIVESTATUS 		INT DEFAULT 1;
	DECLARE CONST_ASSTYPE_IP 				INT DEFAULT 4;
	DECLARE CONST_ASSBYIP_ACTIVESTATUS 		INT DEFAULT 1;
    
    #=================================================
    DECLARE lv_HasDevice		BIT;
	DECLARE lv_HasIP			BIT;
    DECLARE lv_HasAI			BIT;
    
    DECLARE lv_ScanGroupID INT;
    DECLARE lv_ScanCreated DATETIME;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE 		Temp_Cust (
			CTSCustID 			BIGINT UNSIGNED PRIMARY KEY
		,	CustID 				BIGINT UNSIGNED
		,	AddGroupDate 		DATETIME
        ,	INDEX 				IX_Temp_Cust_CustID(CustID)
	);
    
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustDetected;
	CREATE TEMPORARY TABLE 		Temp_CustDetected (
			CTSCustID 			BIGINT UNSIGNED PRIMARY KEY
        ,   AssType				TINYINT #1 Device, 2: AI, 3:GroupAi, 4:IP
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Device;
	CREATE TEMPORARY TABLE 	Temp_Device (
			DCSDeviceID			BIGINT PRIMARY KEY
		,	AddGroupDate 		DATETIME	
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AIGroup;
	CREATE TEMPORARY TABLE 	Temp_AIGroup (
			GroupID				BIGINT UNSIGNED PRIMARY KEY
		,	AddGroupDate 		DATETIME
	);
    
    #=============================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByAI_AssType (
			AssTypeItemValue INT PRIMARY KEY            
	);
	#=============================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByIP_AssType (
			AssTypeItemValue INT PRIMARY KEY            
	);

    #===========GET AssociationByIP status is Applied==============================================    
    INSERT INTO Temp_AssociationByIP_AssType(AssTypeItemValue)
    SELECT atd.AssTypeItemValue
    FROM CTS_DataCenter.AssociationTypeSetting AS atd
    WHERE atd.AssTypeID = CONST_ASSTYPE_IP AND atd.AssTypeItemStatus = CONST_ASSBYIP_ACTIVESTATUS; 
    
    #===========GET AssociationByAI status is Applied==============================================    
    INSERT INTO Temp_AssociationByAI_AssType(AssTypeItemValue)
    SELECT atd.AssTypeItemValue
    FROM CTS_DataCenter.AssociationTypeSetting AS atd
    WHERE atd.AssTypeID = CONST_ASSTYPE_BETTINGPATTERN AND atd.AssTypeItemStatus = CONST_ASSBYAI_ACTIVESTATUS; 
    
    SELECT gp.GroupID, gp.Created
    INTO lv_ScanGroupID,  lv_ScanCreated
    FROM CTS_DataCenter.Adhoc_HF215554_AssociatedGroupAccount_Group AS gp
	WHERE gp.ProcessStatus = 0
    ORDER BY gp.GroupID ASC, gp.Created ASC
    LIMIT 1;
    
   WHILE lv_ScanGroupID IS NOT NULL
   DO
		TRUNCATE TABLE Temp_Cust;
        TRUNCATE TABLE Temp_CustDetected;
        
		SELECT 	HasDevice
			,	HasIP
			,	HasAI
		INTO 	lv_HasDevice
			,	lv_HasIP
			,	lv_HasAI
		FROM  CTS_DataCenter.AssociatedGroup AS ag
		WHERE ag.GroupID = lv_ScanGroupID
		LIMIT 1;

		
		INSERT INTO Temp_Cust(CTSCustID, CustID, AddGroupDate)
		SELECT 	acc.CTSCustID
			,	cus.CustID
			,	acc.Created
		FROM CTS_DataCenter.AssociatedGroupAccount AS acc
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON acc.CTSCustID = cus.CTSCustID
		WHERE acc.GroupID = lv_ScanGroupID
			AND Created = lv_ScanCreated;

		/**************************Device*******************************/
		DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByDevice;
		CREATE TEMPORARY TABLE Temp_AssociationByDevice(
				DCSDeviceID BIGINT
			,	CTSCustID BIGINT
			,	PRIMARY KEY (DCSDeviceID,CTSCustID)
		);

		IF lv_HasDevice = 1 THEN
			
			INSERT IGNORE INTO Temp_AssociationByDevice(CTSCustID,DCSDeviceID)
			SELECT 	dv.CTSCustID
				,	dv.DCSDeviceID
			FROM Temp_Cust AS tmp 
				INNER JOIN CTS_DataCenter.AssociationByDevice AS dv ON  dv.CTSCustID = tmp.CTSCustID;
			
			INSERT IGNORE INTO Temp_CustDetected(CTSCustID, AssType)
			SELECT 	dv.CTSCustID
				,	1 AS AssType
			FROM  Temp_AssociationByDevice AS dv
			WHERE EXISTS (	SELECT 1
							FROM CTS_DataCenter.AssociationByDevice AS lv1  
								INNER JOIN CTS_DataCenter.Adhoc_HF215554_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = lv1.CTSCustID
							WHERE dv.DCSDeviceID = lv1.DCSDeviceID)
			;
				
		END IF;

		IF lv_HasAI = 1 THEN

			/**************************AI*******************************/
			INSERT IGNORE INTO Temp_CustDetected(CTSCustID,AssType)
			SELECT  tmp.CTSCustID, 2
			FROM Temp_Cust AS tmp 
				INNER JOIN CTS_DataCenter.AssociationByAI AS ai ON tmp.CustID = ai.FromCustID            
			WHERE EXISTS (SELECT 1
							FROM CTS_DataCenter.CTSCustomer AS cus
								INNER JOIN CTS_DataCenter.Adhoc_HF215554_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = cus.CTSCustID
							WHERE cus.CustID = ai.ToCustID AND cus.CustSubID = 0 AND cus.RoleID = 1)
				AND EXISTS (SELECT 1 FROM Temp_AssociationByAI_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = ai.AssType);
			
			INSERT IGNORE INTO Temp_CustDetected(CTSCustID, AssType)
			SELECT tmp.CTSCustID, 3
			FROM Temp_Cust AS tmp 
				INNER JOIN CTS_DataCenter.AssociationByAI AS ai ON tmp.CustID = ai.ToCustID            
			WHERE EXISTS (SELECT 1
							FROM CTS_DataCenter.CTSCustomer AS cus
								INNER JOIN CTS_DataCenter.Adhoc_HF215554_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = cus.CTSCustID
							WHERE cus.CustID = ai.FromCustID AND cus.CustSubID = 0 AND cus.RoleID = 1)
				AND EXISTS (SELECT 1 FROM Temp_AssociationByAI_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = ai.AssType);
				
			/**************************AI Group*******************************/
			DROP TEMPORARY TABLE IF EXISTS Temp_AssociationGroupByAI;
			CREATE TEMPORARY TABLE Temp_AssociationGroupByAI(
					GroupID INT
				,	CustID BIGINT
				,	CTSCustID BIGINT
				
				,	PRIMARY KEY (GroupID,CTSCustID)
			);
			
			INSERT IGNORE INTO Temp_AssociationGroupByAI(GroupID, CustID, CTSCustID)
			SELECT 	dv.GroupID
				,	dv.CustID
				,	tmp.CTSCustID
			FROM Temp_Cust AS tmp 
				INNER JOIN CTS_DataCenter.AssociationGroupByAI AS dv ON dv.CustID = tmp.CustID
			; 
			
			INSERT IGNORE INTO Temp_CustDetected(CTSCustID, AssType)
			SELECT	tmp.CTSCustID, 4
			FROM	Temp_AssociationGroupByAI AS tmp
			WHERE EXISTS (	SELECT 1
							FROM CTS_DataCenter.AssociationGroupByAI AS lv1
								INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = lv1.CustID AND cus.CustSubID = 0 AND cus.RoleID = 1
								INNER JOIN CTS_DataCenter.Adhoc_HF215554_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = cus.CTSCustID
							WHERE tmp.GroupID = lv1.GroupID)
			;
			
		END IF;

		/**************************IP*******************************/
		IF lv_HasIP = 1 THEN
			INSERT IGNORE INTO Temp_CustDetected(CTSCustID, AssType)
			SELECT  tmp.CTSCustID, 5
			FROM Temp_Cust AS tmp 
				INNER JOIN CTS_DataCenter.AssociationByIP AS ai ON tmp.CustID = ai.FromCustID            
			WHERE EXISTS (SELECT 1
							FROM CTS_DataCenter.CTSCustomer AS cus
								INNER JOIN CTS_DataCenter.Adhoc_HF215554_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = cus.CTSCustID
							WHERE cus.CustID = ai.ToCustID AND cus.CustSubID = 0 AND cus.RoleID = 1)
				AND EXISTS (SELECT 1 FROM Temp_AssociationByIP_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = ai.AssType);
			
			INSERT IGNORE INTO Temp_CustDetected(CTSCustID, AssType)
			SELECT tmp.CTSCustID , 6
			FROM Temp_Cust AS tmp 
				INNER JOIN CTS_DataCenter.AssociationByIP AS ai ON tmp.CustID = ai.ToCustID            
			WHERE EXISTS (SELECT 1
							FROM CTS_DataCenter.CTSCustomer AS cus
								INNER JOIN CTS_DataCenter.Adhoc_HF215554_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = cus.CTSCustID
							WHERE cus.CustID = ai.FromCustID AND cus.CustSubID = 0 AND cus.RoleID = 1)
				AND EXISTS (SELECT 1 FROM Temp_AssociationByIP_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = ai.AssType);
		END IF;
        
		INSERT INTO CTS_DataCenter.Adhoc_HF215554_AssociatedGroupAccount_Target(GroupID,CTSCustID,IsAuto,Remark,Created,CreatedBy,LastModifiedDate,LastModifiedBy,IsScaned)
		SELECT ass.GroupID, ass.CTSCustID, ass.IsAuto, ass.Remark, ass.Created, ass.CreatedBy, ass.LastModifiedDate, ass.LastModifiedBy, 1
		FROM Temp_CustDetected AS tmp
			INNER JOIN CTS_DataCenter.AssociatedGroupAccount AS ass ON ass.CTSCustID = tmp.CTSCustID 
		WHERE ass.GroupID = lv_ScanGroupID AND ass.Created = lv_ScanCreated;
		
		UPDATE CTS_DataCenter.Adhoc_HF215554_AssociatedGroupAccount_Group AS up
        SET ProcessStatus = 1
		WHERE GroupID = lv_ScanGroupID
			AND Created = lv_ScanCreated;		

		SELECT gp.GroupID, gp.Created
		INTO lv_ScanGroupID, lv_ScanCreated
		FROM CTS_DataCenter.Adhoc_HF215554_AssociatedGroupAccount_Group AS gp
        WHERE gp.ProcessStatus = 0
		ORDER BY gp.GroupID ASC, gp.Created ASC
		LIMIT 1;

	END WHILE;	
END$$
DELIMITER ;
CALL Adhoc_HF115554_RescanMemberGroup();
#SELECT * FROM Adhoc_HF215554_AssociatedGroupAccount_Target WHERE IsScaned = 1;
#SHOW processlist;
