/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_DetectCD`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_DetectCD`(		
		IN 	ip_Cust	 LONGTEXT
        ,IN ip_IsRescan BIT 
)
SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250725@Winfred.Pham
		Task:	 Get Agent cust List Considerable Danger Queue    
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250725@Winfred.Pham: 	Created [Redmine ID: #219679]
                
		Param's Explanation :
        
		Example:
			CALL CTS_DC_CustClassificationAgency_DetectCD(@ip_BatchSize:=100,OUT op_LastID :=@op_LastID);
	*/
    DECLARE	CONST_AGENCY_CATEID_CD_LOW INT DEFAULT 130100;
    DECLARE	CONST_AGENCY_CATEID_CD_HIGHT INT DEFAULT 135100;
    DECLARE	CONST_PARENTID_VVIP INT DEFAULT 1000;

    IF ip_IsRescan IS NULL THEN
        SET ip_IsRescan = 0;
    END IF;

	DROP TEMPORARY TABLE IF EXISTS Temp_AgentList;
    CREATE TEMPORARY TABLE Temp_AgentList(
			AgentID	BIGINT UNSIGNED PRIMARY KEY
    ); 

	DROP TEMPORARY TABLE IF EXISTS Temp_AgentConsiderableDanger;
    CREATE TEMPORARY TABLE Temp_AgentConsiderableDanger(
			CustID	BIGINT UNSIGNED PRIMARY KEY
        ,   CTSCustID BIGINT UNSIGNED DEFAULT 0
		,	TotalCust	INT UNSIGNED DEFAULT 0
		,	TotalPACust	INT UNSIGNED DEFAULT 0
		,	PAMemberRatio	DECIMAL(5,2) UNSIGNED DEFAULT 0
		,   IsExistingCD   BIT DEFAULT 0 
		,   IsPassRuleRatio  BIT DEFAULT 0 
        ,	INDEX	IX_Temp_AgentConsiderableDanger_CustID(CustID)  
    ); 
	
	SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_AgentList (AgentID) VALUES ('", REPLACE(ip_Cust, ",", "'),('"),"');");
	PREPARE 	stmt1 FROM @sql;
	EXECUTE 	stmt1; 	
     
	INSERT IGNORE INTO Temp_AgentConsiderableDanger (CustID, TotalCust, TotalPACust) 
	SELECT AgentID, COUNT( Distinct cus.CTSCustID) AS TotalCust, 
			SUM(CASE WHEN cate.IsPA > 0 AND cate.IsVVIP = 0 THEN 1 ELSE 0 END) AS TotalPA 
	FROM Temp_AgentList AS tac
	INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.Recommend = tac.AgentID
	LEFT JOIN LATERAL	(SELECT cls.CustID
								, SUM(CASE WHEN ccs.FlowConsiderableDangerScan = 1 THEN 1 ELSE 0 END) AS IsPA 
                                , SUM(CASE WHEN ccs.ParentID = CONST_PARENTID_VVIP THEN 1 ELSE 0 END) AS IsVVIP
							FROM CTS_DataCenter.CTSCustomerClassification AS cls
								INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON cls.CategoryID = ccs.CategoryID
							WHERE cls.CustID = cus.CustID
                            GROUP BY cls.CustID
						) AS cate ON TRUE
	WHERE cus.RoleID = 1
    GROUP BY tac.AgentID;

	UPDATE Temp_AgentConsiderableDanger AS tac
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON tac.CustID = cus.CustID AND cus.IsLicensee = 0 AND cus.RoleID = 2 AND cus.CustSubID = 0
		LEFT JOIN LATERAL (
							SELECT cls.CategoryID
							FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls
								INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cate ON cls.CategoryID = cate.CategoryID AND cate.IsActive = 1
							WHERE cls.CustID = tac.CustID
							ORDER BY  cate.CustomerClassPriority ASC 
									, cls.LastModifiedDate DESC
							LIMIT 1
						) AS cate ON TRUE
	SET tac.IsExistingCD = (CASE WHEN cate.CategoryID IN (CONST_AGENCY_CATEID_CD_LOW,CONST_AGENCY_CATEID_CD_HIGHT) THEN 1 ELSE 0 END)
        ,tac.IsPassRuleRatio = CASE WHEN tac.TotalCust > 0 THEN (CASE WHEN CAST(tac.TotalPACust*100/tac.TotalCust AS DECIMAL(5,2)) >= 50 THEN 1 ELSE 0 END) ELSE 0 END
		,tac.PAMemberRatio = CASE WHEN tac.TotalCust > 0 THEN CAST(tac.TotalPACust*100/tac.TotalCust AS DECIMAL(5,2)) ELSE 0 END
        ,tac.CTSCustID = cus.CTSCustID
  	;
    
    INSERT INTO CTS_DataCenter.Customer_ConsiderableDanger(CustID, CTSCustID, TotalMember, TotalPAMember, PAMemberRatio, InsertedTime)
    SELECT CustID, CTSCustID, TotalCust, TotalPACust, PAMemberRatio, CURRENT_TIMESTAMP(3) AS InsertedTime
    FROM Temp_AgentConsiderableDanger AS tac
    WHERE IsPassRuleRatio = 1;

    INSERT INTO CTS_DataCenter.Customer_ConsiderableDanger_Log(CustID, CTSCustID, TotalMember, TotalPAMember, PAMemberRatio, InsertedTime)
    SELECT CustID, CTSCustID, TotalCust, TotalPACust, PAMemberRatio, CURRENT_TIMESTAMP(3) AS InsertedTime
    FROM Temp_AgentConsiderableDanger AS tac;

    IF ip_IsRescan = 0 THEN
        SELECT CustID	
		,	TotalCust	
		,	TotalPACust	
		,   IsExistingCD  
		,   IsPassRuleRatio
	    FROM Temp_AgentConsiderableDanger AS tac;
    END IF;

END$$
DELIMITER ;