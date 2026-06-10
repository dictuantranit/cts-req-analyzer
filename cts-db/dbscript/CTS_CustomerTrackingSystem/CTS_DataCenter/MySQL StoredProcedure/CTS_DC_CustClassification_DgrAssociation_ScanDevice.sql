/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_DgrAssociation_ScanDevice`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DataCenter`.`CTS_DC_CustClassification_DgrAssociation_ScanDevice`(
		IN ip_BatchSize INT 
	,	OUT op_LastCTSAssDevID BIGINT
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
			CALL CTS_DC_CustClassification_DgrAssociation_ScanDevice_xpre(5000,@op_LastCTSAssDevID)
	*/ 
	DECLARE	CONST_PARENTID_WRAPPER		INT;
	DECLARE CONST_ROLEID_MEMBER			SMALLINT DEFAULT 1;
    DECLARE lv_LastCTSAssDevID 			BIGINT;

	SET CONST_PARENTID_WRAPPER			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');

	DROP TEMPORARY TABLE IF EXISTS Temp_CustDevice;
	CREATE TEMPORARY TABLE Temp_CustDevice(
			CTSAssDevID				BIGINT
		,	CTSCustID				BIGINT UNSIGNED
		,	DCSDeviceID				BIGINT
		,	PRIMARY KEY(CTSAssDevID)
        ,   KEY IX_Temp_CustDevice_CTSCustID (CTSCustID)
	);

	DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE Temp_Cust(
			CTSCustID				BIGINT UNSIGNED
		,	PRIMARY KEY(CTSCustID)	
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustDgrAssociation;
	CREATE TEMPORARY TABLE 		Temp_CustDgrAssociation (
			CTSCustID			BIGINT UNSIGNED
		,	PRIMARY KEY(CTSCustID)
	);  

    SELECT ParameterValue 
    INTO lv_LastCTSAssDevID 
    FROM CTS_DataCenter.SystemParameter 
    WHERE ParameterID = 183;

	INSERT IGNORE INTO Temp_CustDevice (CTSAssDevID, CTSCustID, DCSDeviceID)
	SELECT dv.CTSAssDevID, dv.CTSCustID, dv.DCSDeviceID
	FROM CTS_DataCenter.AssociationByDevice AS dv
	WHERE dv.CTSAssDevID > lv_LastCTSAssDevID
	ORDER BY dv.CTSAssDevID ASC
	LIMIT ip_BatchSize;

	INSERT IGNORE INTO Temp_Cust (CTSCustID)
	SELECT DISTINCT tmp.CTSCustID
	FROM Temp_CustDevice AS tmp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CTSCustID = tmp.CTSCustID
	WHERE cus.RoleID = CONST_ROLEID_MEMBER AND cus.IsInternal = 0;

	INSERT IGNORE INTO Temp_CustDgrAssociation(CTSCustID)
	SELECT tmp.CTSCustID
	FROM Temp_Cust AS tmp
		,	LATERAL
				(
					SELECT cls.CustID, cls.CategoryID
					FROM CTS_DataCenter.CTSCustomerClassification AS cls
						INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cls.CategoryID = cate.CategoryID AND cate.IsActive = 1
					WHERE cls.CTSCustID = tmp.CTSCustID AND cls.ParentID <> CONST_PARENTID_WRAPPER
					ORDER BY  cate.CustomerClassPriority ASC 
							, cls.LastModifiedDate DESC
					LIMIT 1
				) AS cate
	INNER JOIN CTS_DataCenter.CustomerCategorySettings AS st ON st.CategoryID = cate.CategoryID AND st.FlowNormalDgrAssociation = 1;

	SELECT MAX(CTSAssDevID)
	INTO op_LastCTSAssDevID
	FROM Temp_CustDevice;

	SET op_LastCTSAssDevID = IFNULL(op_LastCTSAssDevID, lv_LastCTSAssDevID);

    /*Return*/
    SELECT DISTINCT tmp.CTSCustID, tcd.DCSDeviceID
    FROM Temp_Cust AS tmp
        INNER JOIN Temp_CustDevice AS tcd ON tcd.CTSCustID = tmp.CTSCustID
        LEFT JOIN Temp_CustDgrAssociation AS cda ON cda.CTSCustID = tmp.CTSCustID
    WHERE cda.CTSCustID IS NOT NULL
        OR NOT EXISTS (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassification AS cls WHERE cls.CTSCustID = tmp.CTSCustID AND cls.ParentID <> CONST_PARENTID_WRAPPER);

END$$
DELIMITER ;