/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_DataConsistency_CustomerCategory_General_Check`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_DataConsistency_CustomerCategory_General_Check`(
	IN 	ip_Batchsize		INT
,	IN 	ip_MinCustID		BIGINT
,	OUT	op_NextCustID		BIGINT
)
    SQL SECURITY INVOKER
spc:BEGIN 
	/*
		Created:	20241018@Victoria.Le
		Task :		Identify customers who have incorrect category settings.
		DB:			CTS_DataCenter

		Revisions:
			- 20241018@Victoria.Le: 	Initial Writing [RedmineID: #212321]
                
        Param's Explanation:
        Example:
			- CALL CTS_DataCenter.CTS_DC_DataConsistency_CustomerCategory_General_Check(5000,0,@op_NextCustID);
	*/ 
	
	/*Get value*/
	DECLARE CONST_PARENTID_PA					INT;
	DECLARE CONST_PARENTID_NORMAL				INT;
	DECLARE	CONST_CATEID_VVIP					INT;
	DECLARE	CONST_CATEID_LICVIPSUSPICIOUS		INT;
	DECLARE	CONST_CATEID_LICVIPDANGEROUS		INT;

	DECLARE lv_MaxCustID						BIGINT;
	
	SET CONST_PARENTID_PA 						= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_PARENTID_NORMAL 					= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
	SET CONST_CATEID_VVIP	 					= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_VVIP');
	SET CONST_CATEID_LICVIPSUSPICIOUS			= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPSUSPICIOUS');
	SET CONST_CATEID_LICVIPDANGEROUS			= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPDANGEROUS');
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustCateInfo;
    CREATE TEMPORARY TABLE Temp_CustCateInfo (
        	CustID						BIGINT UNSIGNED 
		,	ParentID					INT
		,	CategoryID					INT        
		,	IsPAProbation 				TINYINT(1) DEFAULT 0
		,	IsKeepOldCateID				TINYINT(1) DEFAULT 0
		,	IsVVIP						TINYINT(1) DEFAULT 0
		,	IsPA						TINYINT(1) DEFAULT 0
		,	IsWrapper					TINYINT(1) DEFAULT 0
		,	PRIMARY KEY (CustID,ParentID,CategoryID)
    );
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustVVIP;
    CREATE TEMPORARY TABLE Temp_CustVVIP (
        	CustID						BIGINT UNSIGNED PRIMARY KEY
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustIssue;
    CREATE TEMPORARY TABLE Temp_CustIssue (
        	CustID						BIGINT UNSIGNED PRIMARY KEY
	);
    
	/*Start*/
	WITH CTE AS
	(
		SELECT DISTINCT cc.CustID
		FROM CTS_DataCenter.CTSCustomerClassification AS cc
			INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID = cc.CustID AND cust.CustSubID  = 0
		WHERE cc.CustID	> ip_MinCustID
		ORDER BY cc.CustID
		LIMIT ip_Batchsize
	)
	SELECT MAX(CustID)
	INTO lv_MaxCustID
	FROM CTE;
	
	IF lv_MaxCustID IS NULL THEN
		SET op_NextCustID = 0;
		LEAVE spc;
	ELSE
		SET op_NextCustID = lv_MaxCustID;
	END IF;
	
	INSERT IGNORE INTO Temp_CustCateInfo (CustID,ParentID,CategoryID,IsPAProbation,IsKeepOldCateID,IsVVIP,IsPA,IsWrapper)
	SELECT 	cc.CustID,cc.ParentID,cc.CategoryID,cate.IsPAProbation,cs.IsKeepOldCateID
		,	CASE WHEN cc.CategoryID = CONST_CATEID_VVIP THEN 1 ELSE 0 END AS IsVVIP
		,	CASE WHEN cc.ParentID = CONST_PARENTID_PA THEN 1 ELSE 0 END AS IsPA
		,	CASE WHEN cc.CategoryID IN (CONST_CATEID_LICVIPSUSPICIOUS,CONST_CATEID_LICVIPDANGEROUS) THEN 1 ELSE 0 END AS IsWrapper
	FROM CTS_DataCenter.CTSCustomerClassification AS cc
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID = cc.CustID AND cust.CustSubID  = 0
		INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = cc.CategoryID 
		INNER JOIN CTS_DataCenter.CustomerCategorySettings AS cs ON cs.CategoryID = cate.CategoryID 
	WHERE cc.CustID > ip_MinCustID
		AND cc.CustID <= lv_MaxCustID;
		
	DROP TEMPORARY TABLE IF EXISTS Temp_CustCateInfo_Dup;
	CREATE TEMPORARY TABLE Temp_CustCateInfo_Dup AS 
		SELECT CustID,ParentID,CategoryID,IsPAProbation,IsKeepOldCateID,IsVVIP,IsPA,IsWrapper
		FROM Temp_CustCateInfo;

	INSERT INTO Temp_CustVVIP (CustID)
	SELECT DISTINCT CustID
	FROM Temp_CustCateInfo
	WHERE IsVVIP = 1;

	-- 1. VVIP: only allow exists IsKeepOldCateID = 1 with CategoryID <> VVIP
	INSERT IGNORE INTO Temp_CustIssue(CustID)
	SELECT DISTINCT temp.CustID
	FROM Temp_CustCateInfo AS temp
		INNER JOIN Temp_CustVVIP AS vvip ON vvip.CustID = temp.CustID
	WHERE temp.IsVVIP = 0
		AND temp.IsKeepOldCateID = 0;

	-- 2.1. PA/LicVIP: only one value on one flag for one customer
	INSERT IGNORE INTO Temp_CustIssue(CustID)
	WITH CTE AS
	(
		SELECT 	temp.CustID,temp.IsPAProbation
			,	ROW_NUMBER() OVER (PARTITION BY temp.CustID ORDER BY temp.IsPAProbation) AS RN
		FROM Temp_CustCateInfo AS temp
			LEFT JOIN Temp_CustVVIP AS vvip ON vvip.CustID = temp.CustID
		WHERE temp.IsVVIP = 0 AND (temp.IsPA = 1 OR temp.IsWrapper = 1)
			AND vvip.CustID IS NULL
		GROUP BY temp.CustID,temp.IsPAProbation
	)
	SELECT DISTINCT c.CustID
	FROM CTE AS c
	WHERE c.RN > 1;
	
	-- 2.2. PA: only allow exists IsKeepOldCateID = 1
	INSERT IGNORE INTO Temp_CustIssue(CustID)
	WITH CTE AS
	(
		SELECT DISTINCT temp.CustID
		FROM Temp_CustCateInfo AS temp
			LEFT JOIN Temp_CustVVIP AS vvip ON vvip.CustID = temp.CustID
		WHERE temp.IsVVIP = 0 AND temp.IsPA = 1
			AND vvip.CustID IS NULL
	)
	SELECT DISTINCT temp.CustID
	FROM Temp_CustCateInfo_Dup AS temp
		INNER JOIN CTE AS c ON c.CustID = temp.CustID
	WHERE temp.ParentID = CONST_PARENTID_NORMAL
		AND temp.IsKeepOldCateID = 0;

	-- 3. Normal: only allow 1 record for each customer
	INSERT IGNORE INTO Temp_CustIssue(CustID)
	WITH CTE AS
	(
		SELECT 	temp.CustID,temp.CategoryID
			,	ROW_NUMBER() OVER (PARTITION BY temp.CustID ORDER BY temp.CategoryID) AS RN
		FROM Temp_CustCateInfo AS temp
		WHERE temp.ParentID = CONST_PARENTID_NORMAL
		GROUP BY temp.CustID,temp.CategoryID
	)
	SELECT DISTINCT c.CustID
	FROM CTE AS c
	WHERE c.RN > 1;
	
END$$

DELIMITER ;