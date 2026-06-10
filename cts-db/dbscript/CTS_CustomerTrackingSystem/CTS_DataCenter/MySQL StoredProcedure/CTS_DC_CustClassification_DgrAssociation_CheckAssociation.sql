/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_DgrAssociation_CheckAssociation`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_CustClassification_DgrAssociation_CheckAssociation`(
		IN ip_BatchSize INT 
	,	OUT op_LastScannedID BIGINT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20241203@Thomas.Nguyen
		Task:
		DB: CTS_DataCenter
		Original:
		Revisions:
			- 20241203@Thomas.Nguyen: 	Created [Redmine ID: #214353]

		Param's Explanation (filtered by):    
			CALL CTS_DC_CustClassification_DgrAssociation_CheckAssociation(5000,@op_LastScannedID)
	*/ 
    DECLARE	CONST_CATEID_NEW		    INT;
	DECLARE	CONST_PARENTID_WRAPPER		INT;
	DECLARE CONST_ROLEID_MEMBER			SMALLINT DEFAULT 1;
    DECLARE lv_LastScannedID 			BIGINT;

    SET CONST_CATEID_NEW			    = CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_NEW');
	SET CONST_PARENTID_WRAPPER			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');

	DROP TEMPORARY TABLE IF EXISTS Temp_CustDeviceOrg;
	CREATE TEMPORARY TABLE Temp_CustDeviceOrg(
			ID						BIGINT
		,	CTSCustID				BIGINT UNSIGNED
		,	DCSDeviceID				BIGINT
		,	PRIMARY KEY(ID)
        ,   KEY IX_Temp_CustDeviceOrg_DCSDeviceID_CTSCustID (DCSDeviceID, CTSCustID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_CustDevice;
	CREATE TEMPORARY TABLE Temp_CustDevice(
			CTSCustID				BIGINT UNSIGNED
		,	DCSDeviceID				BIGINT
		,	PRIMARY KEY(CTSCustID, DCSDeviceID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_CustNewCateByDevice;
	CREATE TEMPORARY TABLE Temp_CustNewCateByDevice(
			CustID				BIGINT UNSIGNED
		,	DCSDeviceID			BIGINT
		,	PRIMARY KEY(DCSDeviceID, CustID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_CustPSRCateByDevice;
	CREATE TEMPORARY TABLE Temp_CustPSRCateByDevice(
			CTSCustID				BIGINT UNSIGNED
		,	DCSDeviceID				BIGINT
		,	PRIMARY KEY(DCSDeviceID, CTSCustID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_Device;
	CREATE TEMPORARY TABLE Temp_Device(
			DCSDeviceID				BIGINT
		,	PRIMARY KEY(DCSDeviceID)
	);

    SELECT ParameterValue 
    INTO lv_LastScannedID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 184;

	INSERT IGNORE INTO Temp_CustDeviceOrg (ID, CTSCustID, DCSDeviceID)
	SELECT dp.ID, dp.CTSCustID, dp.DCSDeviceID
	FROM CTS_DataCenter.DangerousAssociation_DevicePool AS dp
	WHERE dp.ID > lv_LastScannedID
	ORDER BY dp.ID ASC
	LIMIT ip_BatchSize;

	INSERT IGNORE INTO Temp_CustDevice (CTSCustID, DCSDeviceID)
	SELECT tmp.CTSCustID, tmp.DCSDeviceID
	FROM Temp_CustDeviceOrg AS tmp
	WHERE tmp.DCSDeviceID IS NOT NULL;

	INSERT IGNORE INTO Temp_CustDevice (CTSCustID, DCSDeviceID)
	SELECT tmp.CTSCustID, dv.DCSDeviceID
	FROM Temp_CustDeviceOrg AS tmp
		INNER JOIN CTS_DataCenter.AssociationByDevice AS dv	ON dv.CTSCustID = tmp.CTSCustID
	WHERE tmp.DCSDeviceID IS NULL;

	INSERT IGNORE INTO Temp_Device (DCSDeviceID)
	SELECT DISTINCT DCSDeviceID
	FROM Temp_CustDevice;

	INSERT IGNORE INTO Temp_CustNewCateByDevice (CustID, DCSDeviceID)
	SELECT cate.CustID, tmp.DCSDeviceID
	FROM Temp_Device AS tmp
		INNER JOIN CTS_DataCenter.AssociationByDevice AS dv ON dv.DCSDeviceID = tmp.DCSDeviceID
		,   LATERAL
				(
					SELECT cls.CustID, cls.CategoryID
					FROM CTS_DataCenter.CTSCustomerClassification AS cls
						INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cls.CategoryID = cat.CategoryID AND cat.IsActive = 1
					WHERE cls.CTSCustID = dv.CTSCustID AND cls.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY  cat.CustomerClassPriority ASC 
							, cls.LastModifiedDate DESC
					LIMIT 1
				) AS cate
	WHERE cate.CategoryID = CONST_CATEID_NEW;

	INSERT IGNORE INTO Temp_CustPSRCateByDevice (CTSCustID, DCSDeviceID)
	SELECT dv.CTSCustID, tmp.DCSDeviceID
	FROM Temp_Device AS tmp
		INNER JOIN CTS_DataCenter.AssociationByDevice AS dv ON dv.DCSDeviceID = tmp.DCSDeviceID
		,   LATERAL
				(
					SELECT cls.CTSCustID, cls.CategoryID
					FROM CTS_DataCenter.CTSCustomerClassification AS cls
						INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cls.CategoryID = cat.CategoryID AND cat.IsActive = 1
					WHERE cls.CTSCustID = dv.CTSCustID AND cls.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY  cat.CustomerClassPriority ASC 
							, cls.LastModifiedDate DESC
					LIMIT 1
				) AS cate
		INNER JOIN CTS_DataCenter.CustomerCategorySettings AS st ON st.CategoryID = cate.CategoryID AND st.CategoryID <> CONST_CATEID_NEW AND st.FlowNormalDgrAssociation = 1;

	SELECT MAX(ID)
	INTO op_LastScannedID
	FROM Temp_CustDeviceOrg;

	SET op_LastScannedID = IFNULL(op_LastScannedID, lv_LastScannedID);

	/*Return*/
	SELECT DISTINCT tcn.CustID
	FROM Temp_CustNewCateByDevice AS tcn
		INNER JOIN Temp_CustPSRCateByDevice AS tcd
			ON tcn.DCSDeviceID = tcd.DCSDeviceID;

END$$
DELIMITER ;