/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_IsAssociatedHedgingCustByCustIDList`;
DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_IsAssociatedHedgingCustByCustIDList`(
		IN	ip_CustIDList	LONGTEXT
	,	OUT	op_IsHedging	TINYINT
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20220113@Casey.Huynh
		Task :		Check CustList has any Association with a Hedging Cust
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20210526@Casey.Huynh: 	Created (MatchMonitor Rule) [Redmine ID: 166986]
			- 20220226@Casey.Huynh: 	Created (MatchMonitor Rule) [Redmine ID: 166986]
			- 20220422@Irena.Vo: 		Mapping Is Hedging Reason (MM) from table CustomerCategory [Redmine ID: #170468]
			- 20230112@Victoria.Le: 	Modify SPs due to restructure AssociationByAI [Redmine ID: #181994]
            - 20230313@Casey.Huynh:		Applied Betting Parten OTGB [Redmine ID: #184791]
			- 20230421@Casey.Huynh: 	Add AssType to AssociationByIP [Redmine ID: #185783]
			- 20240703@Victoria.Le		Renovate CC Phase2 [Redmine ID: #205317]
            - 20241016@Casey.Huynh: 	Agency CC, AssociationByDevice Seperate Member and Agency [Redmine ID: #185799]
		Param's Explanation (filtered by):			
        Example:
			CALL CTS_DC_Association_IsAssociatedHedgingCustByCustIDList('169686,169689,894977,65391526', @op_IsHedging); SELECT @op_IsHedging;           
	*/
	DECLARE CONST_ASSTYPE_BETTINGPATTERN 	INT DEFAULT 2;
	DECLARE CONST_ASSBYAI_ACTIVESTATUS 		INT DEFAULT 1;    
	DECLARE CONST_ASSTYPE_IP 				INT DEFAULT 4;
	DECLARE CONST_ASSBYIP_ACTIVESTATUS 		INT DEFAULT 1;
	
	DECLARE CONST_PARENTID_PA 				INT;
	DECLARE CONST_PARENTID_VVIP				INT;
	DECLARE CONST_PARENTID_WRAPPER			INT;
    
    DECLARE CONST_AGENCY_PARENTID_PA 				INT;
	DECLARE CONST_AGENCY_PARENTID_VVIP				INT;
    
	SET CONST_PARENTID_PA 					= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_PARENTID_VVIP					= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_VVIP');
	SET CONST_PARENTID_WRAPPER				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_WRAPPER');
    
    SET CONST_AGENCY_PARENTID_PA 			= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
	SET CONST_AGENCY_PARENTID_VVIP			= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');
	#=============================================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_InputCust;
	CREATE TEMPORARY TABLE 		Temp_InputCust (
			CustID 	BIGINT UNSIGNED PRIMARY KEY
	);    
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE 		Temp_Cust (
			CTSCustID 			BIGINT UNSIGNED 
		 ,	CustID 				BIGINT UNSIGNED PRIMARY KEY
		 ,	INDEX IX_Temp_Cust_CTSCustID(CTSCustID)
	); 
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByDevice;
    CREATE TEMPORARY TABLE Temp_AssociationByDevice(
			DeviceID	BIGINT UNSIGNED
		,	CTSCustID	BIGINT UNSIGNED
        
        ,	PRIMARY KEY	PK_Temp_Association(DeviceID, CTSCustID)    
        ,	INDEX IX_Temp_AssociationByDevice_CTSCustID(CTSCustID)    
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Device;
    CREATE TEMPORARY TABLE Temp_Device(
		DeviceID	BIGINT UNSIGNED PRIMARY KEY
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Association;
    CREATE TEMPORARY TABLE Temp_Association(
			FromCTSCustID	BIGINT UNSIGNED
		,	ToCTSCustID		BIGINT UNSIGNED
        
		,	PRIMARY KEY	PK_Temp_Association(FromCTSCustID,ToCTSCustID)
        ,	INDEX	IX_Temp_Association(FromCTSCustID,ToCTSCustID)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationRemove;
    CREATE TEMPORARY TABLE Temp_AssociationRemove(
			FromCTSCustID	BIGINT UNSIGNED
		,	ToCTSCustID		BIGINT UNSIGNED
        
        ,	PRIMARY KEY	IX_Temp_AssociationRemove_FromCTSCustID(FromCTSCustID,ToCTSCustID)
	);   

	DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByAI_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByAI_AssType (
		AssTypeItemValue INT PRIMARY KEY            
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByIP_AssType;
	CREATE TEMPORARY TABLE 	Temp_AssociationByIP_AssType (
		AssTypeItemValue INT PRIMARY KEY            
	);
    
    #===========GET AssociationByIP status is Applied==============================================   
	INSERT INTO Temp_AssociationByIP_AssType(AssTypeItemValue)
	SELECT atd.AssTypeItemValue
	FROM CTS_DataCenter.AssociationTypeSetting AS atd
	WHERE atd.AssTypeID = CONST_ASSTYPE_IP 
		AND atd.AssTypeItemStatus = CONST_ASSBYIP_ACTIVESTATUS;
        
	#===========GET AssociationByAI status is Applied==============================================    
	INSERT INTO Temp_AssociationByAI_AssType(AssTypeItemValue)
	SELECT atd.AssTypeItemValue
	FROM CTS_DataCenter.AssociationTypeSetting AS atd
	WHERE atd.AssTypeID = CONST_ASSTYPE_BETTINGPATTERN AND atd.AssTypeItemStatus = CONST_ASSBYAI_ACTIVESTATUS; 
       
    SET @sql = CONCAT("INSERT IGNORE INTO Temp_InputCust(CustID) VALUES ('", REPLACE(ip_CustIDList, ",", "'),('"),"');");
	PREPARE stmt1 FROM @sql;
	EXECUTE stmt1;

	INSERT INTO Temp_Cust(CustID, CTSCustID) 
	SELECT	tmpIc.CustID
		,	cus.CTSCustID
	FROM Temp_InputCust AS tmpIc
		LEFT JOIN CTS_DataCenter.CTSCustomer AS cus ON tmpIc.CustID = cus.CustID AND cus.CustSubID = 0;  

    #=======CHECK AssociationByIP====================================
	WITH CTE_Latest AS
	(
		SELECT DISTINCT ma.ToCustID AS CustID, ltc.ParentID
		FROM Temp_Cust AS tmpCus
			INNER JOIN CTS_DataCenter.AssociationByIP AS ma ON ma.FromCustID = tmpCus.CustID AND ma.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt)
			LEFT JOIN CTS_DataCenter.AssociationRemove AS ar ON ma.FromCustID = ar.LeastCustID AND ar.LeastCustSubID = 0 AND ma.ToCustID = ar.GreatestCustID AND ar.GreatestCustSubID = 0
			,	LATERAL (
							SELECT cc.CategoryID, cc.ParentID
							FROM CTS_DataCenter.CTSCustomerClassification AS cla 
								INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
							WHERE cla.CustID = ma.ToCustID
								AND cc.ParentID <> CONST_PARENTID_WRAPPER
							ORDER BY cc.CustomerClassPriority ASC, cla.LastModifiedDate DESC
							LIMIT 1
						) AS ltc
		WHERE tmpCus.CTSCustID IS NOT NULL AND ar.LeastCustID IS NULL
	)
	SELECT 1
	INTO op_IsHedging
	FROM CTE_Latest AS temp
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cla ON cla.CustID = temp.CustID
		INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
	WHERE temp.ParentID <> CONST_PARENTID_VVIP
		AND cc.ParentID = CONST_PARENTID_PA AND cc.IsHedgingReasonMM = 1
	LIMIT 1;

	IF op_IsHedging IS NOT NULL THEN 
		LEAVE sp;
	END IF;
	
	WITH CTE_Latest AS
	(
		SELECT DISTINCT ma.FromCustID AS CustID, ltc.ParentID
		FROM Temp_Cust AS tmpCus
			INNER JOIN CTS_DataCenter.AssociationByIP AS ma ON ma.ToCustID = tmpCus.CustID AND ma.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt)
				LEFT JOIN CTS_DataCenter.AssociationRemove AS ar ON ma.FromCustID = ar.LeastCustID AND ar.LeastCustSubID = 0 AND ma.ToCustID = ar.GreatestCustID AND ar.GreatestCustSubID = 0
			,	LATERAL (
							SELECT cc.CategoryID, cc.ParentID
							FROM CTS_DataCenter.CTSCustomerClassification AS cla 
								INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
							WHERE cla.CustID = ma.FromCustID
								AND cc.ParentID <> CONST_PARENTID_WRAPPER
							ORDER BY cc.CustomerClassPriority ASC, cla.LastModifiedDate DESC
							LIMIT 1
						) AS ltc
		WHERE tmpCus.CTSCustID IS NOT NULL AND ar.LeastCustID IS NULL
	)
	SELECT 1
	INTO op_IsHedging
	FROM CTE_Latest AS temp
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cla ON cla.CustID = temp.CustID
		INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
	WHERE temp.ParentID <> CONST_PARENTID_VVIP
		AND cc.ParentID = CONST_PARENTID_PA AND cc.IsHedgingReasonMM = 1
	LIMIT 1;

	IF op_IsHedging IS NOT NULL THEN 
		LEAVE sp;
	END IF;
	
	#=======CHECK AssociationByAI====================================
	WITH CTE_Latest AS
	(
		SELECT DISTINCT ma.ToCustID AS CustID, ltc.ParentID
		FROM Temp_Cust AS tmpCus
			INNER JOIN CTS_DataCenter.AssociationByAI AS ma ON ma.FromCustID = tmpCus.CustID AND ma.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt)
			LEFT JOIN CTS_DataCenter.AssociationRemove AS ar ON ma.FromCustID = ar.LeastCustID AND ar.LeastCustSubID = 0 AND ma.ToCustID = ar.GreatestCustID AND ar.GreatestCustSubID = 0
			,	LATERAL (
							SELECT cc.CategoryID, cc.ParentID
							FROM CTS_DataCenter.CTSCustomerClassification AS cla 
								INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
							WHERE cla.CustID = ma.ToCustID
								AND cc.ParentID <> CONST_PARENTID_WRAPPER
							ORDER BY cc.CustomerClassPriority ASC, cla.LastModifiedDate DESC
							LIMIT 1
						) AS ltc
		WHERE tmpCus.CTSCustID IS NOT NULL AND ar.LeastCustID IS NULL
	)
	SELECT 1
	INTO op_IsHedging
	FROM CTE_Latest AS temp
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cla ON cla.CustID = temp.CustID
		INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
	WHERE temp.ParentID <> CONST_PARENTID_VVIP
		AND cc.ParentID = CONST_PARENTID_PA AND cc.IsHedgingReasonMM = 1
	LIMIT 1;

	IF op_IsHedging IS NOT NULL THEN 
		LEAVE sp;
	END IF;
	
	WITH CTE_Latest AS
	(
		SELECT DISTINCT ma.FromCustID AS CustID, ltc.ParentID
		FROM Temp_Cust AS tmpCus
			INNER JOIN CTS_DataCenter.AssociationByAI AS ma ON ma.ToCustID = tmpCus.CustID AND ma.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt)
				LEFT JOIN CTS_DataCenter.AssociationRemove AS ar ON ma.FromCustID = ar.LeastCustID AND ar.LeastCustSubID = 0 AND ma.ToCustID = ar.GreatestCustID AND ar.GreatestCustSubID = 0
			,	LATERAL (
							SELECT cc.CategoryID, cc.ParentID
							FROM CTS_DataCenter.CTSCustomerClassification AS cla 
								INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
							WHERE cla.CustID = ma.FromCustID
								AND cc.ParentID <> CONST_PARENTID_WRAPPER
							ORDER BY cc.CustomerClassPriority ASC, cla.LastModifiedDate DESC
							LIMIT 1
						) AS ltc
		WHERE tmpCus.CTSCustID IS NOT NULL AND ar.LeastCustID IS NULL
	)
	SELECT 1
	INTO op_IsHedging
	FROM CTE_Latest AS temp
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cla ON cla.CustID = temp.CustID
		INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
	WHERE temp.ParentID <> CONST_PARENTID_VVIP
		AND cc.ParentID = CONST_PARENTID_PA AND cc.IsHedgingReasonMM = 1
	LIMIT 1;

	IF op_IsHedging IS NOT NULL THEN 
		LEAVE sp;
	END IF;
    
    #=======CHECK AssociationGroupByAI====================================
    DROP TEMPORARY TABLE IF EXISTS Temp_AssGroupByAI;
	CREATE TEMPORARY TABLE Temp_AssGroupByAI (
			GroupID 	BIGINT UNSIGNED
		,	CustID		BIGINT UNSIGNED
		
		, 	PRIMARY KEY (GroupID,CustID)
        ,	INDEX IX_Temp_AssGroupByAI_CustID(CustID)
	);
    
    INSERT INTO Temp_AssGroupByAI(GroupID, CustID)
    SELECT DISTINCT asg.GroupID
		,	asg.CustID
    FROM Temp_Cust AS tmpCus
		INNER JOIN CTS_DataCenter.AssociationGroupByAI AS asg ON tmpCus.CustID = asg.CustID ;


	WITH CTE_Latest AS
	(
		SELECT DISTINCT ma.CustID AS CustID, ltc.ParentID
		FROM Temp_AssGroupByAI AS tmpCus
			INNER JOIN CTS_DataCenter.AssociationGroupByAI AS ma ON ma.CustID <> tmpCus.CustID AND ma.GroupID = tmpCus.GroupID
				LEFT JOIN CTS_DataCenter.AssociationRemove AS ar ON LEAST(ma.CustID,tmpCus.CustID) = ar.LeastCustID AND ar.LeastCustSubID = 0 AND GREATEST(ma.CustID,tmpCus.CustID) = ar.GreatestCustID AND ar.GreatestCustSubID = 0
			,	LATERAL (
							SELECT cc.CategoryID, cc.ParentID
							FROM CTS_DataCenter.CTSCustomerClassification AS cla 
								INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
							WHERE cla.CustID = ma.CustID
								AND cc.ParentID <> CONST_PARENTID_WRAPPER
							ORDER BY cc.CustomerClassPriority ASC, cla.LastModifiedDate DESC
							LIMIT 1
						) AS ltc
		WHERE ar.LeastCustID IS NULL
	)
	SELECT 1
	INTO op_IsHedging
	FROM CTE_Latest AS temp
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cla ON cla.CustID = temp.CustID
		INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
	WHERE temp.ParentID <> CONST_PARENTID_VVIP
		AND cc.ParentID = CONST_PARENTID_PA AND cc.IsHedgingReasonMM = 1
	LIMIT 1;

	IF op_IsHedging IS NOT NULL THEN 
		LEAVE sp;
	END IF;
    
    #=======CHECK AssociationByDevice================================       
    
    INSERT INTO Temp_AssociationByDevice(DeviceID, CTSCustID)
    SELECT	adv.DCSDeviceID
		,	adv.CTSCustID
	FROM Temp_Cust AS tmpCus
		INNER JOIN CTS_DataCenter.AssociationByDevice AS adv ON adv.CTSCustID = tmpCus.CTSCustID
	WHERE tmpCus.CTSCustID IS NOT NULL;
    
	INSERT INTO Temp_Device(DeviceID)
	SELECT	tmpAdv.DeviceID		
	FROM 	Temp_AssociationByDevice AS tmpAdv
	WHERE 	tmpAdv.CTSCustID IS NOT NULL
    GROUP BY tmpAdv.DeviceID	
    HAVING COUNT(1) > 0;
    
    DELETE tmpAdv
    FROM Temp_AssociationByDevice AS tmpAdv
		LEFT JOIN Temp_Device AS tmpDv ON tmpAdv.DeviceID = tmpDv.DeviceID
	WHERE tmpDv.DeviceID IS NULL;
    
    #===================================CHECK Is Hedging===================================================
    IF EXISTS(	SELECT 1 
				FROM Temp_AssociationByDevice AS tmpAdv
				WHERE	EXISTS(	SELECT 1 FROM CTS_DataCenter.AssociationRemove AS ar1 WHERE tmpAdv.CTSCustID = ar1.FromCTSCustID)
					OR	EXISTS(	SELECT 1 FROM CTS_DataCenter.AssociationRemove AS ar2 WHERE tmpAdv.CTSCustID = ar2.ToCTSCustID)	)THEN
	
		INSERT IGNORE INTO Temp_Association(FromCTSCustID, ToCTSCustID)
		SELECT LEAST(tmpAdv.CTSCustID,adv.CTSCustID), GREATEST(tmpAdv.CTSCustID,adv.CTSCustID)
		FROM Temp_AssociationByDevice AS tmpAdv
			INNER JOIN  CTS_DataCenter.AssociationByDevice AS adv ON tmpAdv.DeviceID = adv.DCSDeviceID AND tmpAdv.CTSCustID <> adv.CTSCustID;
		
		DELETE tmpAss
		FROM Temp_Association AS tmpAss
			INNER JOIN AssociationRemove AS tmpAr ON tmpAss.FromCTSCustID = tmpAr.FromCTSCustID AND tmpAss.ToCTSCustID = tmpAr.ToCTSCustID;
		
        #==============CHECK FOR MEMBER============================
		WITH CTE_Latest AS
		(
			SELECT DISTINCT tmpAss.FromCTSCustID AS CTSCustID, ltc.ParentID
			FROM Temp_Association AS tmpAss
				,	LATERAL (
								SELECT cc.CategoryID, cc.ParentID
								FROM CTS_DataCenter.CTSCustomerClassification AS cla 
									INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
								WHERE cla.CTSCustID = tmpAss.FromCTSCustID 
									AND cc.ParentID <> CONST_PARENTID_WRAPPER
								ORDER BY cc.CustomerClassPriority ASC, cla.LastModifiedDate DESC
								LIMIT 1
							) AS ltc
		)
		SELECT 1
		INTO op_IsHedging
		FROM CTE_Latest AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cla ON cla.CTSCustID = temp.CTSCustID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
		WHERE temp.ParentID <> CONST_PARENTID_VVIP
			AND cc.ParentID = CONST_PARENTID_PA AND cc.IsHedgingReasonMM = 1
		LIMIT 1;
		
		IF op_IsHedging IS NOT NULL THEN 
			LEAVE sp;
		END IF;
		
		WITH CTE_Latest AS
		(
			SELECT DISTINCT tmpAss.ToCTSCustID AS CTSCustID, ltc.ParentID
			FROM Temp_Association AS tmpAss
				,	LATERAL (
								SELECT cc.CategoryID, cc.ParentID
								FROM CTS_DataCenter.CTSCustomerClassification AS cla 
									INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
								WHERE cla.CTSCustID = tmpAss.ToCTSCustID 
									AND cc.ParentID <> CONST_PARENTID_WRAPPER
								ORDER BY cc.CustomerClassPriority ASC, cla.LastModifiedDate DESC
								LIMIT 1
							) AS ltc
		)
		SELECT 1
		INTO op_IsHedging
		FROM CTE_Latest AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cla ON cla.CTSCustID = temp.CTSCustID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
		WHERE temp.ParentID <> CONST_PARENTID_VVIP
			AND cc.ParentID = CONST_PARENTID_PA AND cc.IsHedgingReasonMM = 1
		LIMIT 1;
        
        IF op_IsHedging IS NOT NULL THEN 
			LEAVE sp;
		END IF;
        
        #==============CHECK FOR AGENCY============================
        WITH CTE_Latest AS
		(
			SELECT DISTINCT tmpAss.FromCTSCustID AS CTSCustID, ltc.ParentID
			FROM Temp_Association AS tmpAss
				,	LATERAL (
								SELECT cc.CategoryID, cc.ParentID
								FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cla 
									INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
								WHERE cla.CTSCustID = tmpAss.FromCTSCustID 
								ORDER BY cc.CustomerClassPriority ASC, cla.LastModifiedDate DESC
								LIMIT 1
							) AS ltc
		)
		SELECT 1
		INTO op_IsHedging
		FROM CTE_Latest AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS cla ON cla.CTSCustID = temp.CTSCustID
			INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
		WHERE temp.ParentID <> CONST_AGENCY_PARENTID_VVIP
			AND cc.ParentID = CONST_AGENCY_PARENTID_PA AND cc.IsHedgingReasonMM = 1
		LIMIT 1;
		
		IF op_IsHedging IS NOT NULL THEN 
			LEAVE sp;
		END IF;
		
		WITH CTE_Latest AS
		(
			SELECT DISTINCT tmpAss.ToCTSCustID AS CTSCustID, ltc.ParentID
			FROM Temp_Association AS tmpAss
				,	LATERAL (
								SELECT cc.CategoryID, cc.ParentID
								FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cla 
									INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
								WHERE cla.CTSCustID = tmpAss.ToCTSCustID 
								ORDER BY cc.CustomerClassPriority ASC, cla.LastModifiedDate DESC
								LIMIT 1
							) AS ltc
		)
		SELECT 1
		INTO op_IsHedging
		FROM CTE_Latest AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS cla ON cla.CTSCustID = temp.CTSCustID
			INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
		WHERE temp.ParentID <> CONST_AGENCY_PARENTID_VVIP
			AND cc.ParentID = CONST_AGENCY_PARENTID_PA AND cc.IsHedgingReasonMM = 1
		LIMIT 1;
        
    ELSE
		#======================CHECK FOR MEMBER=============================
		WITH CTE_Latest AS
		(
			SELECT DISTINCT adv.CTSCustID AS CTSCustID, ltc.ParentID
			FROM Temp_Device AS tmpAdv
				INNER JOIN CTS_DataCenter.AssociationByDevice AS adv ON adv.DCSDeviceID = tmpAdv.DeviceID
				,	LATERAL (
								SELECT cc.CategoryID, cc.ParentID
								FROM CTS_DataCenter.CTSCustomerClassification AS cla 
									INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
								WHERE cla.CTSCustID = adv.CTSCustID
									AND cc.ParentID <> CONST_PARENTID_WRAPPER
								ORDER BY cc.CustomerClassPriority ASC, cla.LastModifiedDate DESC
								LIMIT 1
							) AS ltc
		)
		SELECT 1
		INTO op_IsHedging
		FROM CTE_Latest AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cla ON cla.CTSCustID = temp.CTSCustID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
		WHERE temp.ParentID <> CONST_PARENTID_VVIP
			AND cc.ParentID = CONST_PARENTID_PA AND cc.IsHedgingReasonMM = 1
		LIMIT 1;
		
        IF op_IsHedging IS NOT NULL THEN 
		LEAVE sp;
		END IF;
        
        #======================CHECK FOR AGENCY=============================
        WITH CTE_Latest AS
		(
			SELECT DISTINCT adv.CTSCustID AS CTSCustID, ltc.ParentID
			FROM Temp_Device AS tmpAdv
				INNER JOIN CTS_DataCenter.AssociationByDevice AS adv ON adv.DCSDeviceID = tmpAdv.DeviceID
				,	LATERAL (
								SELECT cc.CategoryID, cc.ParentID
								FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cla 
									INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
								WHERE cla.CTSCustID = adv.CTSCustID
								ORDER BY cc.CustomerClassPriority ASC, cla.LastModifiedDate DESC
								LIMIT 1
							) AS ltc
		)
		SELECT 1
		INTO op_IsHedging
		FROM CTE_Latest AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS cla ON cla.CTSCustID = temp.CTSCustID
			INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON cc.CategoryID = cla.CategoryID AND cc.IsActive = 1
		WHERE temp.ParentID <> CONST_AGENCY_PARENTID_VVIP
			AND cc.ParentID = CONST_AGENCY_PARENTID_PA AND cc.IsHedgingReasonMM = 1
		LIMIT 1;
        
	END IF;
END$$
DELIMITER ;
