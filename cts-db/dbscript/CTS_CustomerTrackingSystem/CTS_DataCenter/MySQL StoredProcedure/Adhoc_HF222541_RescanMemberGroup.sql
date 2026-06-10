/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `Adhoc_HF222541_RescanMemberGroup`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `Adhoc_HF222541_RescanMemberGroup`(	
) 
    SQL SECURITY INVOKER
sp : BEGIN
	/* 
		Created:	20250520@Thomas.Nguyen
		Task:		Scan Member  [Redmine ID: #222541]
		DB:			CTS_DataCenter
		Original:

		Revisions:
            - 20250520@Thomas.Nguyen: Created [Redmine ID: #222541]

		Param's Explanation (filtered by):

		Example:
			- CALL  Adhoc_HF222541_RescanMemberGroup();
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
		,	IsIgnored			TINYINT DEFAULT 0
        ,	INDEX 				IX_Temp_Cust_CustID_IsIgnored(CustID, IsIgnored)
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
    FROM CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Group AS gp
	WHERE gp.ProcessStatus = 0
    ORDER BY gp.GroupID ASC, gp.Created ASC
    LIMIT 1;
    
   WHILE lv_ScanGroupID IS NOT NULL
   DO
		TRUNCATE TABLE Temp_Cust;
        TRUNCATE TABLE Temp_CustDetected;
        
		SELECT 	HasDevice
			,	1 AS HasIP
			,	HasAI
		INTO 	lv_HasDevice
			,	lv_HasIP
			,	lv_HasAI
		FROM  CTS_DataCenter.AssociatedGroup AS ag
		WHERE ag.GroupID = lv_ScanGroupID
		LIMIT 1;
		
		INSERT INTO Temp_Cust(CTSCustID, CustID, AddGroupDate, IsIgnored)
		SELECT 	acc.CTSCustID
			,	cus.CustID
			,	acc.Created
			,	CASE WHEN acc.IsAuto = 0 THEN 1 ELSE 0 END AS IsIgnored
		FROM CTS_DataCenter.AssociatedGroupAccount AS acc
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON acc.CTSCustID = cus.CTSCustID
		WHERE acc.GroupID = lv_ScanGroupID
			AND Created = lv_ScanCreated;

		INSERT INTO CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Target(GroupID,CTSCustID,IsAuto,Remark,Created,CreatedBy,LastModifiedDate,LastModifiedBy,IsScaned)
		SELECT ass.GroupID, ass.CTSCustID, ass.IsAuto, ass.Remark, ass.Created, ass.CreatedBy, ass.LastModifiedDate, ass.LastModifiedBy, 1
		FROM CTS_DataCenter.AssociatedGroupAccount AS ass
		WHERE ass.GroupID = lv_ScanGroupID AND ass.Created = lv_ScanCreated AND ass.IsAuto = 0;

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
				INNER JOIN CTS_DataCenter.AssociationByDevice AS dv ON  dv.CTSCustID = tmp.CTSCustID
			WHERE tmp.IsIgnored = 0;
			
			INSERT IGNORE INTO Temp_CustDetected(CTSCustID, AssType)
			SELECT 	dv.CTSCustID
				,	1 AS AssType
			FROM  Temp_AssociationByDevice AS dv
			WHERE EXISTS (	SELECT 1
							FROM CTS_DataCenter.AssociationByDevice AS lv1  
								INNER JOIN CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = lv1.CTSCustID AND tg.GroupID = lv_ScanGroupID
							WHERE dv.DCSDeviceID = lv1.DCSDeviceID)
			;
				
			UPDATE Temp_Cust AS tmp
				INNER JOIN Temp_CustDetected AS tmpd ON tmp.CTSCustID = tmpd.CTSCustID
			SET tmp.IsIgnored = 1
			WHERE tmp.IsIgnored = 0;
		END IF;

		IF lv_HasAI = 1 THEN

			/**************************AI*******************************/
			INSERT IGNORE INTO Temp_CustDetected(CTSCustID,AssType)
			SELECT  tmp.CTSCustID, 2
			FROM Temp_Cust AS tmp 
				INNER JOIN CTS_DataCenter.AssociationByAI AS ai ON tmp.CustID = ai.FromCustID            
			WHERE EXISTS (SELECT 1
							FROM CTS_DataCenter.CTSCustomer AS cus
								INNER JOIN CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = cus.CTSCustID AND tg.GroupID = lv_ScanGroupID
							WHERE cus.CustID = ai.ToCustID AND cus.CustSubID = 0 AND cus.RoleID = 1)
				AND EXISTS (SELECT 1 FROM Temp_AssociationByAI_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = ai.AssType)
				AND tmp.IsIgnored = 0;
			
			UPDATE Temp_Cust AS tmp
				INNER JOIN Temp_CustDetected AS tmpd ON tmp.CTSCustID = tmpd.CTSCustID
			SET tmp.IsIgnored = 1
			WHERE tmp.IsIgnored = 0;

			INSERT IGNORE INTO Temp_CustDetected(CTSCustID, AssType)
			SELECT tmp.CTSCustID, 3
			FROM Temp_Cust AS tmp 
				INNER JOIN CTS_DataCenter.AssociationByAI AS ai ON tmp.CustID = ai.ToCustID            
			WHERE EXISTS (SELECT 1
							FROM CTS_DataCenter.CTSCustomer AS cus
								INNER JOIN CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = cus.CTSCustID AND tg.GroupID = lv_ScanGroupID
							WHERE cus.CustID = ai.FromCustID AND cus.CustSubID = 0 AND cus.RoleID = 1)
				AND EXISTS (SELECT 1 FROM Temp_AssociationByAI_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = ai.AssType)
				AND tmp.IsIgnored = 0;

			UPDATE Temp_Cust AS tmp
				INNER JOIN Temp_CustDetected AS tmpd ON tmp.CTSCustID = tmpd.CTSCustID
			SET tmp.IsIgnored = 1
			WHERE tmp.IsIgnored = 0;

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
			WHERE tmp.IsIgnored = 0
			; 
			
			INSERT IGNORE INTO Temp_CustDetected(CTSCustID, AssType)
			SELECT	tmp.CTSCustID, 4
			FROM	Temp_AssociationGroupByAI AS tmp
			WHERE EXISTS (	SELECT 1
							FROM CTS_DataCenter.AssociationGroupByAI AS lv1
								INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = lv1.CustID AND cus.CustSubID = 0 AND cus.RoleID = 1
								INNER JOIN CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = cus.CTSCustID AND tg.GroupID = lv_ScanGroupID
							WHERE tmp.GroupID = lv1.GroupID)
			;
			
			UPDATE Temp_Cust AS tmp
				INNER JOIN Temp_CustDetected AS tmpd ON tmp.CTSCustID = tmpd.CTSCustID
			SET tmp.IsIgnored = 1
			WHERE tmp.IsIgnored = 0;
		END IF;

		/**************************IP*******************************/
		IF lv_HasIP = 1 THEN
			INSERT IGNORE INTO Temp_CustDetected(CTSCustID, AssType)
			SELECT  tmp.CTSCustID, 5
			FROM Temp_Cust AS tmp 
				INNER JOIN CTS_DataCenter.AssociationByIP AS ai ON tmp.CustID = ai.FromCustID            
			WHERE EXISTS (SELECT 1
							FROM CTS_DataCenter.CTSCustomer AS cus
								INNER JOIN CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = cus.CTSCustID AND tg.GroupID = lv_ScanGroupID
							WHERE cus.CustID = ai.ToCustID AND cus.CustSubID = 0 AND cus.RoleID = 1)
				AND EXISTS (SELECT 1 FROM Temp_AssociationByIP_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = ai.AssType)
				AND tmp.IsIgnored = 0;
			
			UPDATE Temp_Cust AS tmp
				INNER JOIN Temp_CustDetected AS tmpd ON tmp.CTSCustID = tmpd.CTSCustID
			SET tmp.IsIgnored = 1
			WHERE tmp.IsIgnored = 0;

			INSERT IGNORE INTO Temp_CustDetected(CTSCustID, AssType)
			SELECT tmp.CTSCustID , 6
			FROM Temp_Cust AS tmp 
				INNER JOIN CTS_DataCenter.AssociationByIP AS ai ON tmp.CustID = ai.ToCustID            
			WHERE EXISTS (SELECT 1
							FROM CTS_DataCenter.CTSCustomer AS cus
								INNER JOIN CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Target AS tg ON tg.CTSCustID = cus.CTSCustID AND tg.GroupID = lv_ScanGroupID
							WHERE cus.CustID = ai.FromCustID AND cus.CustSubID = 0 AND cus.RoleID = 1)
				AND EXISTS (SELECT 1 FROM Temp_AssociationByIP_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = ai.AssType)
				AND tmp.IsIgnored = 0;

			UPDATE Temp_Cust AS tmp
				INNER JOIN Temp_CustDetected AS tmpd ON tmp.CTSCustID = tmpd.CTSCustID
			SET tmp.IsIgnored = 1
			WHERE tmp.IsIgnored = 0;
		END IF;
        
		INSERT INTO CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Target(GroupID,CTSCustID,IsAuto,Remark,Created,CreatedBy,LastModifiedDate,LastModifiedBy,IsScaned)
		SELECT ass.GroupID, ass.CTSCustID, ass.IsAuto, ass.Remark, ass.Created, ass.CreatedBy, ass.LastModifiedDate, ass.LastModifiedBy, 1
		FROM Temp_CustDetected AS tmp
			INNER JOIN CTS_DataCenter.AssociatedGroupAccount AS ass ON ass.CTSCustID = tmp.CTSCustID 
		WHERE ass.GroupID = lv_ScanGroupID AND ass.Created = lv_ScanCreated;
		
		UPDATE CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Group AS up
        SET ProcessStatus = 1
		WHERE GroupID = lv_ScanGroupID
			AND Created = lv_ScanCreated;		

		IF EXISTS (	SELECT 1 
					FROM CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Group AS gp
					WHERE gp.ProcessStatus = 0) THEN

			SELECT gp.GroupID, gp.Created
			INTO lv_ScanGroupID, lv_ScanCreated
			FROM CTS_DataCenter.Adhoc_HF222541_AssociatedGroupAccount_Group AS gp
			WHERE gp.ProcessStatus = 0
			ORDER BY gp.GroupID ASC, gp.Created ASC
			LIMIT 1;
		ELSE
			SET lv_ScanGroupID = NULL;
			SET lv_ScanCreated = NULL;
		END IF;


	END WHILE;	
END$$
DELIMITER ;

