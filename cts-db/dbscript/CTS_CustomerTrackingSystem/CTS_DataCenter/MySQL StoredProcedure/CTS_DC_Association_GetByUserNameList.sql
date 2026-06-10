/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_Association_GetByUserNameList`;

DELIMITER $$ 
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_GetByUserNameList`(
		IN  ip_UserNameList 	TEXT
	,   IN  ip_HasDevice		BOOLEAN
    ,   IN  ip_HasAI			BOOLEAN
    ,   IN  ip_HasIP			BOOLEAN
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20251031@Thomas.Nguyen
		Task:		Get associated account by list of usernames, return association by each username
		DB:			CTS_DataCenter
		Revisions:
			- 20251031@Thomas.Nguyen: 	Created [Redmine ID: #239956]
            
		Param's Explanation (filtered by):
			- ip_UserNameList: list of usernames
        Example:
			  CALL CTS_DC_Association_GetByUserNameList(@ip_UserNameList:='12BETGBP01001,307HK', @ip_HasDevice:=1, @ip_HasAI:=1, @ip_HasIP:=1);
	
	*/

    DECLARE CONST_ASSTYPE_DEVICE 					INT DEFAULT 1;
    DECLARE CONST_ASSTYPE_BETTINGPATTERN 			INT DEFAULT 2;
    DECLARE CONST_ASSTYPE_IP 						INT DEFAULT 4;
	DECLARE CONST_ASSSTATUS_ACTIVE 					INT DEFAULT 1;    

	DROP TEMPORARY TABLE IF EXISTS Temp_Username;
    CREATE TEMPORARY TABLE Temp_Username(
			Username			VARCHAR(50) PRIMARY KEY
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust(
			CTSCustID			BIGINT UNSIGNED PRIMARY KEY
		,	CustID 				BIGINT UNSIGNED
        ,   INDEX IX_Temp_Cust_CustID(CustID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_Association;
    CREATE TEMPORARY TABLE 		Temp_Association(
			RootCustID 		    BIGINT UNSIGNED
		,	AssCustID 			BIGINT UNSIGNED
        , 	AssociationType		INT
        , 	PRIMARY KEY (RootCustID, AssCustID, AssociationType)
	); 
    
	SET @sql = CONCAT("INSERT INTO Temp_Username (Username) VALUES ('", REPLACE(ip_UserNameList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;

	INSERT INTO Temp_Cust(CTSCustID, CustID)
	SELECT 	cus.CTSCustID
		,	cus.CustID
	FROM CTS_DataCenter.CTSCustomer AS cus
		INNER JOIN Temp_Username AS tmp ON cus.Username = tmp.Username;
    
    /*=================================================GET Association By Device==============================================*/    
	IF ip_HasDevice = 1 THEN
		DROP TEMPORARY TABLE IF EXISTS Temp_CustDevice;
		CREATE TEMPORARY TABLE Temp_CustDevice(
				DCSDeviceID				BIGINT UNSIGNED
			,	CTSCustID				BIGINT UNSIGNED
			,	CustID					BIGINT UNSIGNED
			,	PRIMARY KEY PK_Temp_CustDevice(DCSDeviceID, CTSCustID)
		);

		INSERT INTO Temp_CustDevice(DCSDeviceID, CTSCustID, CustID)
		SELECT 	asDv.DCSDeviceID
			,	tmpCus.CTSCustID
			,	tmpCus.CustID
		FROM  Temp_Cust AS tmpCus
			INNER JOIN CTS_DataCenter.AssociationByDevice AS asDv ON asDv.CTSCustID = tmpCus.CTSCustID;

		DELETE tmpCd
		FROM Temp_CustDevice AS tmpCd
		WHERE NOT EXISTS (
			SELECT 1
			FROM CTS_DataCenter.AssociationByDevice AS asDv	
				INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = asDv.CTSCustID AND cus.CustSubID = 0
			WHERE asDv.DCSDeviceID = tmpCd.DCSDeviceID
				AND asDv.CTSCustID <> tmpCd.CTSCustID
		);

        INSERT IGNORE INTO Temp_Association(RootCustID, AssCustID, AssociationType)
        SELECT DISTINCT  tmpCd.CustID AS RootCustID
            ,	cus.CustID AS AssCustID
            ,	CONST_ASSTYPE_DEVICE AS AssociationType
        FROM Temp_CustDevice AS tmpCd
            INNER JOIN CTS_DataCenter.AssociationByDevice AS asDv ON asDv.DCSDeviceID = tmpCd.DCSDeviceID AND asDv.CTSCustID <> tmpCd.CTSCustID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = asDv.CTSCustID AND cus.CustSubID = 0; 
	END IF;

    /*=================================================GET Association By Betting Pattern ==============================================*/    
	IF ip_HasAI = 1 THEN
		/******************Betting Pattern - Association By AI********************/
		DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_AssType;
		CREATE TEMPORARY TABLE 	Temp_AssociationByAI_AssType (
				AssTypeItemValue	INT PRIMARY KEY            
		);

		INSERT INTO Temp_AssociationByAI_AssType(AssTypeItemValue)
		SELECT ats.AssTypeItemValue
		FROM CTS_DataCenter.AssociationTypeSetting AS ats
		WHERE ats.AssTypeID = CONST_ASSTYPE_BETTINGPATTERN AND ats.AssTypeItemStatus = CONST_ASSSTATUS_ACTIVE;

		INSERT IGNORE INTO Temp_Association(RootCustID, AssCustID, AssociationType)
		SELECT  tmp.CustID AS RootCustID
			,	cus.CustID AS AssCustID
			,	CONST_ASSTYPE_BETTINGPATTERN AS AssociationType
		FROM Temp_Cust AS tmp
			INNER JOIN CTS_DataCenter.AssociationByAI AS asAI ON asAI.FromCustID = tmp.CustID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID  = asAI.ToCustID AND cus.CustSubID = 0
		WHERE EXISTS (SELECT 1 FROM Temp_AssociationByAI_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = asAI.AssType);
		
		INSERT IGNORE INTO Temp_Association(RootCustID, AssCustID, AssociationType)
		SELECT  tmp.CustID AS RootCustID
			,	cus.CustID AS AssCustID
			,	CONST_ASSTYPE_BETTINGPATTERN AS AssociationType
		FROM Temp_Cust AS tmp
			INNER JOIN CTS_DataCenter.AssociationByAI AS asAI ON asAI.ToCustID = tmp.CustID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID  = asAI.FromCustID AND cus.CustSubID = 0
		WHERE EXISTS (SELECT 1 FROM Temp_AssociationByAI_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = asAI.AssType);
		
		/******************Betting Pattern - Group By AI********************/
		DROP TEMPORARY TABLE IF EXISTS Temp_CustGroupByAI;
		CREATE TEMPORARY TABLE Temp_CustGroupByAI(
				GroupID					BIGINT UNSIGNED
			,	CustID					BIGINT UNSIGNED
			,	CTSCustID				BIGINT UNSIGNED			
			,	PRIMARY KEY PK_Temp_CustGroupByAI(GroupID, CustID)
		);

		INSERT INTO Temp_CustGroupByAI(GroupID, CustID, CTSCustID)
		SELECT 	asg.GroupID
			,	tmpCus.CustID
			,	tmpCus.CTSCustID
		FROM  Temp_Cust AS tmpCus
			INNER JOIN CTS_DataCenter.AssociationGroupByAI AS asg ON asg.CustID = tmpCus.CustID;

		DELETE tmpgAI
		FROM Temp_CustGroupByAI AS tmpgAI
		WHERE NOT EXISTS (
			SELECT 1
			FROM CTS_DataCenter.AssociationGroupByAI AS asg	
				INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = asg.CustID AND cus.CustSubID = 0
			WHERE asg.GroupID = tmpgAI.GroupID
				AND asg.CustID <> tmpgAI.CustID
		);

		INSERT IGNORE INTO Temp_Association(RootCustID, AssCustID, AssociationType)
		SELECT DISTINCT tmpgAI.CustID AS RootCustID
			,	cus.CustID AS AssCustID
			,	CONST_ASSTYPE_BETTINGPATTERN AS AssociationType
		FROM Temp_CustGroupByAI AS tmpgAI
			INNER JOIN CTS_DataCenter.AssociationGroupByAI AS asg ON asg.GroupID = tmpgAI.GroupID AND asg.CustID <> tmpgAI.CustID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = asg.CustID AND cus.CustSubID = 0; 
	END IF;
	
    /*=================================================GET Association By IP ==============================================*/    
	IF ip_HasIP = 1 THEN
		DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_AssType;
		CREATE TEMPORARY TABLE 	Temp_AssociationByIP_AssType (
				AssTypeItemValue 	INT PRIMARY KEY            
		);

		INSERT INTO Temp_AssociationByIP_AssType(AssTypeItemValue)
		SELECT ats.AssTypeItemValue
		FROM CTS_DataCenter.AssociationTypeSetting AS ats
		WHERE ats.AssTypeID = CONST_ASSTYPE_IP AND ats.AssTypeItemStatus = CONST_ASSSTATUS_ACTIVE;

		INSERT IGNORE INTO Temp_Association(RootCustID, AssCustID, AssociationType)
		SELECT  tmp.CustID AS RootCustID
			,	cus.CustID AS AssCustID
			,	CONST_ASSTYPE_IP AS AssociationType
		FROM Temp_Cust AS tmp
			INNER JOIN CTS_DataCenter.AssociationByIP AS asIP ON asIP.FromCustID = tmp.CustID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID  = asIP.ToCustID AND cus.CustSubID = 0
		WHERE EXISTS (SELECT 1 FROM Temp_AssociationByIP_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = asIP.AssType);

		INSERT IGNORE INTO Temp_Association(RootCustID, AssCustID, AssociationType)
		SELECT  tmp.CustID AS RootCustID
			,	cus.CustID AS AssCustID
			,	CONST_ASSTYPE_IP AS AssociationType
		FROM Temp_Cust AS tmp
			INNER JOIN CTS_DataCenter.AssociationByIP AS asIP ON asIP.ToCustID = tmp.CustID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID  = asIP.FromCustID AND cus.CustSubID = 0
		WHERE EXISTS (SELECT 1 FROM Temp_AssociationByIP_AssType AS tmpAt WHERE tmpAt.AssTypeItemValue = asIP.AssType);
	END IF;

    SELECT	RootCustID
		,	GROUP_CONCAT(DISTINCT AssCustID SEPARATOR ',') AS AssCustIDList
	FROM Temp_Association
	GROUP BY RootCustID;

END$$
DELIMITER ;