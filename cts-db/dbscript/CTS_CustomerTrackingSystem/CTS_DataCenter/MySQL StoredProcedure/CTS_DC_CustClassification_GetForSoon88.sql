/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_GetForSoon88`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_GetForSoon88`(
		IN ip_CustIDList			VARCHAR(8000)
	,	IN ip_IsGetAssociation		BOOLEAN
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20201027@Harvey
		Task :		Get Association and Category (support data for Soon88)
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20201027@Harvey: Init SPs. Association: only get association by device
			- 20210317@Irena.Vo: Review logic get data & update syntax. [RedmineID: #151374]
			- 20210715@Aries.Nguyen: Improve locking . Fix get Duplicate Category [Redmine ID: #158262] 
            - 20210722@Irena.Vo: Refactor SP [Redmine ID: 157203]
		Param's Explanation (filtered by):
			- pre-condition: RegisterName is not null & Category is PA, Smart Punter, High Risk Punter. 
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_GetForSoon88('41609149,41611983,41630670', 1);
	*/
	DECLARE	CONST_GROUP_PA 				INT DEFAULT 50;
	DECLARE	CONST_GROUP_NORMAL 			INT DEFAULT 200;
	
	DECLARE CONST_CATEGORY_SMART 		INT DEFAULT 203;
    DECLARE CONST_CATEGORY_HIGHRISK 	INT DEFAULT 204;

	DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
    CREATE TEMPORARY TABLE Temp_Customer (
			CustID 				INT UNSIGNED PRIMARY KEY
		,	CTSCustID			BIGINT	UNSIGNED
		,	RegisterName 		VARCHAR(50)
		,	CategoryName		VARCHAR(50)
        ,	CategoryID			INT
        ,	LastModifiedDate	DATETIME
    );

	DROP TEMPORARY TABLE IF EXISTS Temp_CustID;
    CREATE TEMPORARY TABLE Temp_CustID (
			CustID 			INT 	UNSIGNED PRIMARY KEY
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Result;
    CREATE TEMPORARY TABLE Temp_Result (
			CTSCustID 			BIGINT UNSIGNED 
		,	CTSCustID_Lv1 		BIGINT UNSIGNED DEFAULT 0
        ,   RegisterName 		VARCHAR(50)
		,	CategoryName		VARCHAR(50)
		,	AssRegisterName 	VARCHAR(50)
		,	AssCategoryName		VARCHAR(50)
		,	IsSoon88			BOOLEAN
        ,	CategoryID			INT
        ,	LastModifiedDate	DATETIME
        ,	PRIMARY KEY			PK_Temp_Result(CTSCustID, CTSCustID_Lv1)
    );

    DROP TEMPORARY TABLE IF EXISTS Temp_DevLv1;
    CREATE TEMPORARY TABLE Temp_DevLv1 (
			DCSDeviceID 	BIGINT 	UNSIGNED
		,	CTSCustID		BIGINT	UNSIGNED
    );
    
	SET @sql = CONCAT("INSERT INTO Temp_CustID (CustID) VALUES ('", REPLACE(ip_CustIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;
    
    /* GET CATEGORY LIST FOR SOON88 */
	INSERT INTO Temp_Customer(CustID, CTSCustID, RegisterName,CategoryID, CategoryName, LastModifiedDate)
	SELECT  tcust.CustID
		,	cus.CTSCustID
		,	TRIM(LEADING 'S88' FROM cus.RegisterName)
		,	class.CategoryID
        ,	custCate.CategoryName
        ,	class.LastModifiedDate
	FROM Temp_CustID AS tcust
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tcust.CustID = cus.CustID AND cus.CustSubID = 0
        INNER JOIN CTS_Admin.Subscriber AS sub ON sub.SubscriberID = cus.SubscriberID AND sub.SubscriberName = 'Soon88'
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS class ON tcust.CustID = class.CustID
		INNER JOIN CTS_DataCenter.CustomerCategory AS custCate ON class.CategoryID = custCate.CategoryID
	WHERE	custCate.ParentID = CONST_GROUP_PA
		OR  custCate.CategoryID IN (CONST_CATEGORY_SMART,CONST_CATEGORY_HIGHRISK)
	ON DUPLICATE KEY UPDATE CategoryID = CASE WHEN  Temp_Customer.LastModifiedDate < class.LastModifiedDate THEN class.CategoryID
											  WHEN  Temp_Customer.LastModifiedDate = class.LastModifiedDate 
												AND Temp_Customer.CategoryID < class.CategoryID THEN class.CategoryID
											  ELSE Temp_Customer.CategoryID
										 END,
							LastModifiedDate = CASE WHEN  Temp_Customer.LastModifiedDate < class.LastModifiedDate THEN class.LastModifiedDate
													WHEN  Temp_Customer.LastModifiedDate = class.LastModifiedDate 
														AND Temp_Customer.CategoryID < class.CategoryID THEN class.LastModifiedDate
													ELSE Temp_Customer.LastModifiedDate
											   END,
							CategoryName = CASE WHEN  Temp_Customer.CategoryID = class.CategoryID THEN custCate.CategoryName
												ELSE Temp_Customer.CategoryName
											END;
    
	/* IGNORE CUSTOMER IS NOT IN CTS */
    DELETE FROM Temp_Customer WHERE CTSCustID IS NULL;
    
    /* GET RESULT */
    /* Is remove category */
    IF ip_IsGetAssociation = 0 THEN
		SELECT RegisterName, CategoryName FROM Temp_Customer;
    
	/* Is get category */
    ELSE
		INSERT IGNORE INTO Temp_DevLv1 (CTSCustID, DCSDeviceID)
		SELECT	tcust.CTSCustID
			,	ass.DCSDeviceID
		FROM CTS_DataCenter.AssociationByDevice AS ass
			RIGHT JOIN Temp_Customer AS tcust ON tcust.CTSCustID = ass.CTSCustID; /* Get Association By Device */
        
        INSERT INTO Temp_Result(CTSCustID, RegisterName,CategoryName)
        SELECT	tcust.CTSCustID
			,	tcust.RegisterName
			,	tcust.CategoryName
        FROM Temp_Customer AS tcust 
			INNER JOIN Temp_DevLv1 AS dev ON tcust.CTSCustID = dev.CTSCustID
        WHERE dev.DCSDeviceID IS NULL AND tcust.RegisterName IS NOT NULL; /* For Root Account */
        
        DELETE FROM Temp_DevLv1 WHERE DCSDeviceID IS NULL;
        
        INSERT INTO Temp_Result(CTSCustID, CTSCustID_Lv1, RegisterName,CategoryName, AssRegisterName, AssCategoryName, IsSoon88, CategoryID, LastModifiedDate)
		SELECT 	tcust.CTSCustID
			,	IFNULL(cust.CTSCustID,0)
			,	tcust.RegisterName
            ,	tcust.CategoryName
			,	TRIM(LEADING 'S88' FROM cust.RegisterName) 'AssRegisterName'
			,	CASE 
					WHEN custCate.CategoryID IN (203,204) THEN custCate.CategoryName
					WHEN custCate.ParentID = 50 THEN custCate.CategoryName
					ELSE 'Normal' 
				END 'AssCategoryName'
			,	CASE 
					WHEN sub.SubscriberName = 'Soon88' THEN 1
					ELSE 0
				END 'IsSoon88'
			,	class.CategoryID
            ,	class.LastModifiedDate
		FROM Temp_Customer AS tcust
			INNER JOIN Temp_DevLv1 AS dev ON tcust.CTSCustID = dev.CTSCustID
			LEFT JOIN CTS_DataCenter.AssociationByDevice AS ass ON dev.DCSDeviceID = ass.DCSDeviceID AND dev.CTSCustID <> ass.CTSCustID
			LEFT JOIN CTS_DataCenter.CTSCustomer AS cust ON ass.CTSCustID = cust.CTSCustID
			LEFT JOIN CTS_Admin.Subscriber AS sub ON cust.SubscriberID = sub.SubscriberID
			LEFT JOIN CTS_DataCenter.CTSCustomerClassification AS class ON ass.CTSCustID = class.CTSCustID
			LEFT JOIN CTS_DataCenter.CustomerCategory AS custCate ON class.CategoryID = custCate.CategoryID AND custCate.ParentID IN (CONST_GROUP_PA,CONST_GROUP_NORMAL)
		ON DUPLICATE KEY UPDATE CategoryID = CASE   WHEN  Temp_Result.LastModifiedDate < class.LastModifiedDate THEN class.CategoryID
													WHEN  Temp_Result.LastModifiedDate = class.LastModifiedDate 
														AND Temp_Result.CategoryID < class.CategoryID THEN class.CategoryID
											  ELSE Temp_Result.CategoryID
											  END,
							LastModifiedDate = CASE WHEN  Temp_Result.LastModifiedDate < class.LastModifiedDate THEN class.LastModifiedDate
													WHEN  Temp_Result.LastModifiedDate = class.LastModifiedDate 
														AND Temp_Result.CategoryID < class.CategoryID THEN class.LastModifiedDate
													ELSE Temp_Result.LastModifiedDate
											   END,
							CategoryName = CASE WHEN  Temp_Result.CategoryID = class.CategoryID THEN custCate.CategoryName
												ELSE Temp_Result.CategoryName
											END;
            
		SELECT  DISTINCT
				RegisterName
			,	CategoryName
            ,	AssRegisterName
            ,	AssCategoryName
            ,	IsSoon88
        FROM Temp_Result;
    END IF;
END$$
DELIMITER ;