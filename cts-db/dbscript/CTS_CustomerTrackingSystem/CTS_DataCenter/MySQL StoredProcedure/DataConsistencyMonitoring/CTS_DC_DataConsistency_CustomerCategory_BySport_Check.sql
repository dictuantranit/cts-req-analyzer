/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_DataConsistency_CustomerCategory_BySport_Check`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_DataConsistency_CustomerCategory_BySport_Check`(
	IN 	ip_Batchsize		INT
,	IN 	ip_MinCustID		BIGINT
,	OUT	op_NextCustID		BIGINT
)
    SQL SECURITY INVOKER
spc:BEGIN 
	/*
		Created:	20241018@Victoria.Le
		Task :		Identify customers who have incorrect category settings - BySport.
		DB:			CTS_DataCenter

		Revisions:
			- 20241018@Victoria.Le: 	Initial Writing [RedmineID: #212321]
                
        Param's Explanation:
        Example:
			- CALL CTS_DataCenter.CTS_DC_DataConsistency_CustomerCategory_BySport_Check(5000,0,@op_NextCustID);
	*/ 
	
	/*Get value*/
	DECLARE CONST_PARENTID_NORMAL				INT;
	DECLARE lv_MaxCustID						BIGINT;
	
	SET CONST_PARENTID_NORMAL 					= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
	
	DROP TEMPORARY TABLE IF EXISTS Temp_CustCateInfo_BySport;
    CREATE TEMPORARY TABLE Temp_CustCateInfo_BySport (
        	CustID						BIGINT UNSIGNED 
		,	SportID						SMALLINT
		,	ParentID					INT
		,	CategoryID					INT 
		,	PRIMARY KEY (CustID,SportID,ParentID,CategoryID)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustIssue_BySport;
    CREATE TEMPORARY TABLE Temp_CustIssue_BySport (
        	CustID						BIGINT UNSIGNED PRIMARY KEY
	);
    
	/*Start*/
	WITH CTE AS
	(
		SELECT DISTINCT cc.CustID
		FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cc
			INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID = cc.CustID AND cust.CustSubID  = 0
		WHERE cc.CustID	> ip_MinCustID
			AND cc.ParentID = CONST_PARENTID_NORMAL
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
	
	INSERT IGNORE INTO Temp_CustCateInfo_BySport (CustID,SportID,ParentID,CategoryID)
	SELECT 	cc.CustID,cc.SportID,cc.ParentID,cc.CategoryID
	FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cc
		INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID = cc.CustID AND cust.CustSubID  = 0
	WHERE cc.CustID > ip_MinCustID
		AND cc.CustID <= lv_MaxCustID
		AND cc.ParentID = CONST_PARENTID_NORMAL;

	-- Normal: only allow 1 record for each customer and sport
	INSERT IGNORE INTO Temp_CustIssue_BySport(CustID)
	WITH CTE AS
	(
		SELECT 	temp.CustID,temp.SportID,temp.CategoryID
			,	ROW_NUMBER() OVER (PARTITION BY temp.CustID,temp.SportID ORDER BY temp.CategoryID) AS RN
		FROM Temp_CustCateInfo_BySport AS temp
		WHERE temp.ParentID = CONST_PARENTID_NORMAL
		GROUP BY temp.CustID,temp.SportID,temp.CategoryID
	)
	SELECT DISTINCT c.CustID
	FROM CTE AS c
	WHERE c.RN > 1;
	
END$$

DELIMITER ;