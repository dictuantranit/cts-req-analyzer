/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_Insert_Process`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_Insert_Process`(
		IN	ip_InputFlowID			INT
)
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240618@Victoria.Le
		Task:		Insert main customer categories for Customer Classification
		DB:			CTS_DataCenter
			
		Param's Expanation:
			- ip_InputFlowID
		
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_Insert_Process(9);
			
		Revisions: 
			- 20240618@Victoria.Le: Initial Writing [Redmine ID: #205317]
           	- 20240923@Jonas.Huynh: Change CC Priority of Robot- Potential Risk  [RedmineID: #209792]
			- 20250519@Thomas.Nguyen: Add ActionType to ignore lower priority for Special Lic Sub CC [Redmine ID: #226847]	
			- 20250908@Thomas.Nguyen: CC 2900/2901 - Update logic to map DW Performance by DWSportType [Redmine ID: #237405]
*/

	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL		INT;
	DECLARE CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY	INT;
	DECLARE CONST_CATEID_VVIP			 				INT;
	DECLARE CONST_CATEID_LICVIPSUSPICIOUS 				INT;
	DECLARE CONST_CATEID_LICVIPDANGEROUS 				INT;
	DECLARE CONST_CATEID_LICBA 							INT;
	DECLARE CONST_CATEID_INACTIVENORMAL 				INT;
	DECLARE CONST_CATEID_INACTIVESMART	 				INT;
	DECLARE CONST_CATEID_SPECIALCC		 				INT;
	DECLARE CONST_CATEGORYID_NEW_LICSUB 				INT DEFAULT 40106;
	DECLARE CONST_CATEGORYID_PROB_LICSUB 				INT DEFAULT 40406;
	DECLARE CONST_CATEGORYID_SMART_LICSUB 				INT DEFAULT 40506;
	DECLARE CONST_CATEGORYID_RISKY_LICSUB 				INT DEFAULT 40606;

	DECLARE CONST_CATEGROUPID_INACTIVE					INT;
	DECLARE CONST_CATEGROUPID_NEW						INT;
	DECLARE CONST_CATEGROUPID_NORMAL					INT;
	DECLARE CONST_CATEGROUPID_GOOD						INT;
	DECLARE CONST_CATEGROUPID_PROBATION					INT;
	DECLARE CONST_CATEGROUPID_SMART						INT;
	DECLARE CONST_CATEGROUPID_RISKY						INT;

	DECLARE CONST_PARENTID_PA 							INT;
    DECLARE CONST_PARENTID_POTENTIALPA      			INT;
    DECLARE CONST_PARENTID_NORMAL		    			INT;
	
	DECLARE CONST_CC_VVIP			 					INT;
	DECLARE CONST_CC_LICVIPSUSPICIOUS 					INT;
	DECLARE CONST_CC_LICVIPDANGEROUS 					INT;
	DECLARE CONST_CC_LICBA			 					INT;
	
    DECLARE CONST_ACTIONTYPE_INSERT 					INT DEFAULT 0;
	DECLARE	CONST_ACTIONTYPE_UPDATE 					INT DEFAULT 1;
	DECLARE CONST_ACTIONTYPE_REMOVE 					INT DEFAULT 2;
    DECLARE CONST_ACTIONTYPE_EXISTEDPA 					INT DEFAULT 3;
    DECLARE CONST_ACTIONTYPE_EXISTEDVVIP				INT DEFAULT 4;
    DECLARE CONST_ACTIONTYPE_IGNOREPROBATION 			INT DEFAULT 5;
    DECLARE CONST_ACTIONTYPE_RESCAN_CHANGECC 			INT DEFAULT 6;
    DECLARE CONST_ACTIONTYPE_RESCAN_CHANGECATEGORY		INT DEFAULT 7;
	DECLARE CONST_ACTIONTYPE_IGNORELOWERPRIORITY		INT DEFAULT 8;
	
    DECLARE CONST_SOURCETYPE_SAMECATEGORY 				INT DEFAULT 0;
    DECLARE CONST_SOURCETYPE_LESSTHAN10TICKETS 			INT DEFAULT 1;
	DECLARE	CONST_SOURCETYPE_AFTER10TICKETS 			INT DEFAULT 2;
	DECLARE CONST_SOURCETYPE_SCANONSCHEDULE				INT DEFAULT 3;
    DECLARE CONST_SOURCETYPE_PASSPROBATION 				INT DEFAULT 4;
    DECLARE CONST_SOURCETYPE_INACTIVENORMAL 			INT DEFAULT 18;
    DECLARE CONST_SOURCETYPE_INACTIVEPROPUNTER			INT DEFAULT 19;
	
    DECLARE lv_LicBAPriority							SMALLINT UNSIGNED;
	DECLARE	lv_CurrentDateTime							DATETIME DEFAULT CURRENT_TIMESTAMP();
	DECLARE lv_IsRescan									TINYINT(1) DEFAULT 0; 

	SET CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL			= CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL');
	SET CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY		= CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY');
	SET CONST_CATEID_VVIP			 					= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_VVIP');
	SET CONST_CATEID_LICVIPSUSPICIOUS 					= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPSUSPICIOUS');
	SET CONST_CATEID_LICVIPDANGEROUS 					= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICVIPDANGEROUS');
	SET CONST_CATEID_LICBA 								= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_LICBA');
	SET CONST_CATEID_INACTIVENORMAL 					= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INACTIVENORMAL');
	SET CONST_CATEID_INACTIVESMART 						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_INACTIVESMART');
	SET CONST_CATEID_SPECIALCC	 						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_SPECIALCC');
	
	SET CONST_CATEGROUPID_INACTIVE						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_INACTIVE');
	SET CONST_CATEGROUPID_NEW							= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_NEW');
	SET CONST_CATEGROUPID_NORMAL						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_NORMAL');
	SET CONST_CATEGROUPID_GOOD							= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_GOOD');
	SET CONST_CATEGROUPID_PROBATION						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_PROBATION');
	SET CONST_CATEGROUPID_SMART							= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_SMART');
	SET CONST_CATEGROUPID_RISKY							= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_RISKY');
	
	SET CONST_PARENTID_PA 								= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_PARENTID_POTENTIALPA						= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_POTENTIALPA');
	SET CONST_PARENTID_NORMAL	 						= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
	
	SET CONST_CC_VVIP			 						= CTS_DC_CategoryTypeParent_Get ('CONST_CC_VVIP');
	SET CONST_CC_LICVIPSUSPICIOUS 						= CTS_DC_CategoryTypeParent_Get ('CONST_CC_LICVIPSUSPICIOUS');
	SET CONST_CC_LICVIPDANGEROUS	 					= CTS_DC_CategoryTypeParent_Get ('CONST_CC_LICVIPDANGEROUS');
	SET CONST_CC_LICBA				 					= CTS_DC_CategoryTypeParent_Get ('CONST_CC_LICBA');

	DROP TEMPORARY TABLE IF EXISTS Temp_UpdateCustomerClass;    
	CREATE TEMPORARY TABLE Temp_UpdateCustomerClass(	  
			CustID					BIGINT UNSIGNED	PRIMARY KEY
		,	CustomerClass 			INT
	);
	
	DROP TEMPORARY TABLE IF EXISTS Temp_LastHistory;
	CREATE TEMPORARY TABLE Temp_LastHistory(
			CustID					BIGINT UNSIGNED PRIMARY KEY
		,	CategoryID				INT
		,	ParentID				INT
		,	TargetCC				INT
	);

	IF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL THEN
		SELECT CustomerClassPriority
		INTO lv_LicBAPriority
		FROM CTS_DataCenter.CustomerCategory 
		WHERE CategoryID = CONST_CATEID_LICBA;
		
		INSERT IGNORE INTO Temp_LastHistory(CustID, CategoryID, TargetCC)
		SELECT temp.CustID, tmpHis.CategoryID, tmpHis.TargetCC
		FROM Temp_NewClassification AS temp,
		LATERAL (	SELECT h.CategoryID, IFNULL(h.TargetCC,-1) AS TargetCC
					FROM CTS_DataCenter.CTSCustomerClassification_History AS h
					WHERE h.CustID = temp.CustID 
					ORDER BY h.LastModifiedDate DESC, h.ID DESC
					LIMIT 1) AS tmpHis
		;
		
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN Temp_LastHistory AS h ON temp.CustID = h.CustID
		SET temp.ActionType = CASE 	WHEN h.CategoryID IS NULL OR h.CategoryID = CONST_CATEID_VVIP THEN CONST_ACTIONTYPE_RESCAN_CHANGECATEGORY /*Unmark PA/VVIP*/
									WHEN h.CategoryID = CONST_CATEID_SPECIALCC THEN CONST_ACTIONTYPE_RESCAN_CHANGECC /*Remove SpecialCC*/
									ELSE temp.ActionType
							  END
		WHERE h.TargetCC = -1 OR h.CategoryID IS NULL;

		UPDATE Temp_NewClassification AS temp 
		SET temp.NewCategoryGroupID = temp.DWCategoryGroupID 
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA,CONST_ACTIONTYPE_EXISTEDVVIP);
		
		UPDATE 	Temp_NewClassification AS temp 
			LEFT JOIN CTS_DataCenter.CustomerCategory AS tag ON tag.CategoryGroupID = temp.NewCategoryGroupID
																	AND tag.TaggingType = temp.TaggingType 
																	AND tag.TaggingID = temp.TaggingID
		SET temp.NewCategoryID = IFNULL(tag.CategoryID, temp.NewCategoryGroupID)
		WHERE temp.DWCategoryGroupID <> CONST_CATEGROUPID_INACTIVE /*Exclude Inactive category*/
			AND temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA,CONST_ACTIONTYPE_EXISTEDVVIP);
			
		UPDATE Temp_NewClassification AS temp 
		SET temp.NewCategoryID = DWCategoryID
		WHERE temp.DWCategoryGroupID = CONST_CATEGROUPID_INACTIVE
			AND temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA,CONST_ACTIONTYPE_EXISTEDVVIP); 

		INSERT IGNORE INTO Temp_CTSCustomerClassification_Old (
				CustID, CTSCustID, SubscriberID, RoleID, CategoryID, CategoryGroupID, CustomerClassPriority)
		SELECT 	temp.CustID, temp.CTSCustID, temp.SubscriberID, temp.RoleID, ccs.CategoryID, ccs.CategoryGroupID, ccs.CustomerClassPriority
		FROM Temp_NewClassification AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cls ON temp.CustID = cls.CustID AND cls.ParentID = CONST_PARENTID_NORMAL
			INNER JOIN CTS_DataCenter.CustomerCategory AS ccs ON ccs.CategoryID = cls.CategoryID
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA,CONST_ACTIONTYPE_EXISTEDVVIP);

		UPDATE Temp_NewClassification AS temp
			LEFT JOIN Temp_CTSCustomerClassification_Old AS o ON temp.CustID = o.CustID
		SET 	temp.OldCategoryGroupID = CASE WHEN o.CustID IS NULL THEN CONST_CATEGROUPID_NEW ELSE o.CategoryGroupID END
			,	temp.OldCategoryID = CASE WHEN o.CustID IS NULL THEN CONST_CATEGROUPID_NEW ELSE o.CategoryID END
			,	temp.IsFromOld = CASE WHEN o.CustID IS NULL THEN 0 ELSE 1 END
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA,CONST_ACTIONTYPE_EXISTEDVVIP);

		/*NO ACTION + VIEW LOG: If Priority of NewCategoryID > Priority of OldCategoryID (Special Lic Sub CC)*/
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON temp.NewCategoryID = cat.CategoryID
			INNER JOIN Temp_CTSCustomerClassification_Old AS old ON temp.CustID = old.CustID
		SET 	temp.ActionType = CONST_ACTIONTYPE_IGNORELOWERPRIORITY
			, 	temp.IsDataChanged = 0
			, 	temp.IsReturnData = 0
		WHERE cat.CustomerClassPriority > old.CustomerClassPriority AND old.CategoryID IN (CONST_CATEGORYID_NEW_LICSUB, CONST_CATEGORYID_PROB_LICSUB, CONST_CATEGORYID_SMART_LICSUB, CONST_CATEGORYID_RISKY_LICSUB);

		/* UPDATE NewIsDangerProbation */    
    	UPDATE 	Temp_NewClassification AS temp 
			INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON temp.NewCategoryID = cate.CategoryID
    	SET temp.NewIsDangerProbation = cate.IsDangerProbation;
								
		UPDATE Temp_NewClassification AS temp 
		SET temp.SourceTypeID = CASE WHEN temp.ActionType = CONST_ACTIONTYPE_RESCAN_CHANGECATEGORY THEN
										(CASE WHEN temp.NewCategoryGroupID = CONST_CATEGROUPID_NEW THEN CONST_SOURCETYPE_LESSTHAN10TICKETS
											  WHEN temp.NewCategoryGroupID = CONST_CATEGROUPID_INACTIVE AND temp.NewCategoryID = CONST_CATEID_INACTIVENORMAL 
												THEN CONST_SOURCETYPE_INACTIVENORMAL
											  WHEN temp.NewCategoryGroupID = CONST_CATEGROUPID_INACTIVE AND temp.NewCategoryID = CONST_CATEID_INACTIVESMART 
												THEN CONST_SOURCETYPE_INACTIVEPROPUNTER
											  WHEN ((temp.NewCategoryGroupID IN (CONST_CATEGROUPID_SMART, CONST_CATEGROUPID_RISKY) OR temp.NewCategoryGroupID NOT IN (CONST_CATEGROUPID_NEW,CONST_CATEGROUPID_INACTIVE)) AND temp.OldCategoryGroupID <> temp.NewCategoryGroupID)
												THEN CONST_SOURCETYPE_SCANONSCHEDULE
											  ELSE CONST_SOURCETYPE_SAMECATEGORY 
										 END)
									ELSE (CASE	WHEN temp.OldCategoryGroupID = CONST_CATEGROUPID_NEW AND temp.NewCategoryGroupID = CONST_CATEGROUPID_NEW 
													THEN CONST_SOURCETYPE_LESSTHAN10TICKETS
												WHEN temp.OldCategoryGroupID = CONST_CATEGROUPID_PROBATION AND temp.NewCategoryGroupID IN (CONST_CATEGROUPID_SMART, CONST_CATEGROUPID_RISKY) 
													THEN CONST_SOURCETYPE_PASSPROBATION
												WHEN (temp.OldCategoryGroupID IS NULL OR temp.OldCategoryGroupID IN (CONST_CATEGROUPID_NEW,CONST_CATEGROUPID_NORMAL,CONST_CATEGROUPID_GOOD)) AND temp.NewCategoryGroupID = CONST_CATEGROUPID_INACTIVE 
													THEN CONST_SOURCETYPE_INACTIVENORMAL 
												WHEN temp.OldCategoryGroupID IN (CONST_CATEGROUPID_SMART,CONST_CATEGROUPID_RISKY,CONST_CATEGROUPID_PROBATION) AND temp.NewCategoryGroupID = CONST_CATEGROUPID_INACTIVE 
													THEN CONST_SOURCETYPE_INACTIVEPROPUNTER
												WHEN temp.OldCategoryGroupID IN (CONST_CATEGROUPID_NEW,CONST_CATEGROUPID_INACTIVE) AND temp.NewCategoryGroupID NOT IN (CONST_CATEGROUPID_NEW,CONST_CATEGROUPID_INACTIVE) 
													THEN CONST_SOURCETYPE_AFTER10TICKETS
												WHEN temp.OldCategoryGroupID = temp.NewCategoryGroupID 
													THEN CONST_SOURCETYPE_SAMECATEGORY
												ELSE CONST_SOURCETYPE_SCANONSCHEDULE
										  END)
								END
		,	temp.IsReturnData = CASE WHEN temp.ActionType = CONST_ACTIONTYPE_RESCAN_CHANGECC AND temp.IsReturnData = 0 THEN 1 ELSE temp.IsReturnData END
		,	temp.ActionType = CASE 	WHEN temp.IsDataChanged = 1 AND temp.ActionType IN (CONST_ACTIONTYPE_INSERT,CONST_ACTIONTYPE_RESCAN_CHANGECC) AND temp.NewCategoryGroupID <> temp.OldCategoryGroupID
										THEN CONST_ACTIONTYPE_INSERT
									WHEN temp.IsDataChanged = 1 AND temp.ActionType IN (CONST_ACTIONTYPE_INSERT,CONST_ACTIONTYPE_RESCAN_CHANGECC) AND temp.NewCategoryGroupID = temp.OldCategoryGroupID
										THEN ( CASE WHEN temp.IsFromOld = 0
														THEN (CASE WHEN temp.OldCategoryGroupID = CONST_CATEGROUPID_NEW THEN CONST_ACTIONTYPE_INSERT ELSE CONST_ACTIONTYPE_UPDATE END)
													ELSE CONST_ACTIONTYPE_UPDATE END)
									WHEN temp.ActionType = CONST_ACTIONTYPE_RESCAN_CHANGECATEGORY THEN
										CASE WHEN temp.OldCategoryGroupID = temp.NewCategoryGroupID AND temp.IsFromOld = 1 THEN CONST_ACTIONTYPE_UPDATE 
								   			 ELSE CONST_ACTIONTYPE_INSERT END
									ELSE temp.ActionType
							  END
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA,CONST_ACTIONTYPE_EXISTEDVVIP);
		
		UPDATE Temp_NewClassification AS temp
		SET temp.IsDataChanged = 0
		WHERE temp.ActionType IN (CONST_ACTIONTYPE_UPDATE,CONST_ACTIONTYPE_RESCAN_CHANGECC)
			AND temp.NewCategoryID = temp.OldCategoryID;
		
		UPDATE Temp_NewClassification AS temp 
			LEFT JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = temp.NewCategoryID
		SET temp.TargetCC = CASE  
								WHEN (temp.SpecialCC IS NULL) OR (temp.SpecialCCCatePriority <> -1)
									THEN CASE
											WHEN cate.CustomerClass = CONST_CC_VVIP 
												THEN CONST_CC_VVIP                                                
											WHEN temp.IsLicenseeVIP = 1 AND cate.CustomerClassPriority > temp.SpecialCCCatePriority AND temp.SpecialCCDangerProbation = 1 
												THEN CONST_CC_LICVIPSUSPICIOUS
											WHEN temp.IsLicenseeVIP = 1 AND cate.CustomerClassPriority > temp.SpecialCCCatePriority AND temp.SpecialCCDangerProbation IS NOT NULL 
												THEN CONST_CC_LICVIPDANGEROUS
											WHEN temp.IsLicenseeVIP = 1 AND cate.IsDangerProbation = 1 
												THEN CONST_CC_LICVIPSUSPICIOUS
											WHEN temp.IsLicenseeVIP = 1 AND cate.IsDangerProbation = 0 
												THEN CONST_CC_LICVIPDANGEROUS                                                
											WHEN temp.IsLicenseeBA = 1 AND temp.SpecialCCCatePriority <> -1 AND temp.SpecialCCCatePriority < lv_LicBAPriority 
												THEN temp.SpecialCC  
											WHEN temp.IsLicenseeBA = 1 AND cate.CustomerClassPriority > lv_LicBAPriority 
												THEN CONST_CC_LICBA                                            
											WHEN temp.SpecialCCCatePriority <> -1 AND cate.CustomerClassPriority > temp.SpecialCCCatePriority 
												THEN temp.SpecialCC
											ELSE cate.CustomerClass
										END
								ELSE temp.SpecialCC
							END
		WHERE 	temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA, CONST_ACTIONTYPE_EXISTEDVVIP);
		
		INSERT IGNORE INTO Temp_UpdateCustomerClass(CustID, CustomerClass)
		SELECT temp.CustID, h.TargetCC
		FROM Temp_NewClassification AS temp
			INNER JOIN Temp_LastHistory AS h ON temp.CustID = h.CustID
		WHERE temp.IsDataChanged  = 0;
		
		UPDATE Temp_UpdateCustomerClass AS c
			INNER JOIN Temp_NewClassification AS temp ON c.CustID = temp.CustID
		SET temp.OldTargetCC = c.CustomerClass;
		
		UPDATE Temp_NewClassification AS tmp
			INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON tmp.OldCategoryID = cate.CategoryID
		SET tmp.TargetCC = 	CASE  
								WHEN (tmp.SpecialCC IS NULL) OR (tmp.SpecialCCCatePriority <> -1)
										THEN CASE
												WHEN cate.CustomerClass = CONST_CC_VVIP 
													THEN CONST_CC_VVIP
												WHEN tmp.IsLicenseeVIP = 1 AND cate.CustomerClassPriority > tmp.SpecialCCCatePriority AND tmp.SpecialCCDangerProbation = 1 
													THEN CONST_CC_LICVIPSUSPICIOUS
												WHEN tmp.IsLicenseeVIP = 1 AND cate.CustomerClassPriority > tmp.SpecialCCCatePriority AND tmp.SpecialCCDangerProbation IS NOT NULL 
													THEN CONST_CC_LICVIPDANGEROUS
												WHEN tmp.IsLicenseeVIP = 1 AND cate.IsDangerProbation = 1 
													THEN CONST_CC_LICVIPSUSPICIOUS
												WHEN tmp.IsLicenseeVIP = 1 AND cate.IsDangerProbation = 0 
													THEN CONST_CC_LICVIPDANGEROUS
												WHEN tmp.IsLicenseeBA = 1 AND tmp.SpecialCCCatePriority <> -1 AND tmp.SpecialCCCatePriority < lv_LicBAPriority 
													THEN tmp.SpecialCC    
												WHEN tmp.IsLicenseeBA = 1 AND cate.CustomerClassPriority > lv_LicBAPriority 
													THEN CONST_CC_LICBA                                            
												WHEN tmp.SpecialCCCatePriority <> -1 AND cate.CustomerClassPriority > tmp.SpecialCCCatePriority 
													THEN tmp.SpecialCC
												ELSE cate.CustomerClass
											END
								ELSE tmp.SpecialCC
							END
			,	tmp.NewCategoryID = tmp.OldCategoryID
			, 	tmp.NewCategoryGroupID = tmp.OldCategoryGroupID
			,	tmp.NewIsDangerProbation = cate.IsDangerProbation
		WHERE tmp.ActionType IN (CONST_ACTIONTYPE_IGNOREPROBATION,CONST_ACTIONTYPE_RESCAN_CHANGECC, CONST_ACTIONTYPE_IGNORELOWERPRIORITY);
		
		UPDATE Temp_NewClassification
		SET 	IsDataChanged = 1
			,	SourceTypeID = (CASE 
									WHEN  NewCategoryGroupID IN (CONST_CATEGROUPID_SMART, CONST_CATEGROUPID_RISKY) 
										THEN CONST_SOURCETYPE_PASSPROBATION
									WHEN NewCategoryGroupID = CONST_CATEGROUPID_INACTIVE AND NewCategoryID = CONST_CATEID_INACTIVENORMAL 
										THEN CONST_SOURCETYPE_INACTIVENORMAL 
									WHEN NewCategoryGroupID = CONST_CATEGROUPID_INACTIVE AND NewCategoryID = CONST_CATEID_INACTIVESMART 
										THEN CONST_SOURCETYPE_INACTIVEPROPUNTER
									ELSE CONST_SOURCETYPE_SCANONSCHEDULE
								END)
			,	IsReturnData = CASE WHEN ActionType = CONST_ACTIONTYPE_IGNOREPROBATION AND IsReturnData = 0 THEN 1 ELSE IsReturnData END
			,	ActionType = CONST_ACTIONTYPE_UPDATE
		WHERE IsDataChanged = 0 
			AND ((TargetCC <> OldTargetCC) OR (OldCategoryID <> NewCategoryID))
			AND (SourceTypeID IN (CONST_SOURCETYPE_SAMECATEGORY, CONST_SOURCETYPE_LESSTHAN10TICKETS ) OR ActionType IN (CONST_ACTIONTYPE_IGNOREPROBATION,CONST_ACTIONTYPE_RESCAN_CHANGECC));    
		
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN CTS_DataCenter.CustomerCategory AS d ON d.CategoryID = temp.NewCategoryID 
		SET 	temp.TargetDangerLevel = CASE WHEN temp.IsLicensee = 1 THEN d.Ext_ABIDangerLevel_Licensee ELSE d.Ext_ABIDangerLevel_Credit END
		WHERE 	temp.IsDataChanged  = 1;
	
	ELSE
	
		DROP TEMPORARY TABLE IF EXISTS Temp_PAWinlossStatus;    
		CREATE TEMPORARY TABLE Temp_PAWinlossStatus(	
				CustID					BIGINT UNSIGNED
			,	DWSportType				SMALLINT
			, 	WinlossStatus			SMALLINT /*LOSING  = 0 (PROBATION), WINNING = 2 (NOT PROBATION);*/
			,	PRIMARY KEY (CustID, DWSportType)
		);
		
		DROP TEMPORARY TABLE IF EXISTS Temp_CustProbationStatus ;
		CREATE TEMPORARY TABLE Temp_CustProbationStatus(
				CustID 					BIGINT UNSIGNED
			,	CTSCustID 				BIGINT UNSIGNED
			,	DWSportType				SMALLINT
			,	IsPAProbation			TINYINT(1)
			,	TurnoverRM				DECIMAL(20,4)
			,	WinlossRM				DECIMAL(20,4)
			, 	BetCount				BIGINT 
			, 	ActiveDays				INT
			,	WinlossStatus			TINYINT
			,	IsLicensee				TINYINT(1)
			,	IsLicenseeVIP			TINYINT(1)
			,	PRIMARY KEY (CustID, DWSportType)
		); 
		
		IF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY THEN
			SET lv_IsRescan = 1;
		END IF;
        
		IF lv_IsRescan = 0 THEN 
			INSERT INTO Temp_PAWinlossStatus(CustID, DWSportType, WinlossStatus)
			SELECT DISTINCT 
					temp.CustID
				,	temp.DWSportType
				,	CASE WHEN cc.IsDangerProbation = 1 THEN 0 ELSE 2 END AS WinlossStatus
			FROM Temp_NewClassification AS temp
				INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cls ON temp.CustID = cls.CustID
				INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cls.CategoryID = cc.CategoryID
				INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = cc.CategoryID AND ccs.SportType = temp.DWSportType
			WHERE cls.ParentID IN (CONST_PARENTID_PA, CONST_PARENTID_POTENTIALPA);
		
		ELSE
			INSERT INTO Temp_PAWinlossStatus(CustID, DWSportType, WinlossStatus)
			SELECT DISTINCT 
					temp.CustID
				,	temp.DWSportType
				,	CASE WHEN cc.IsDangerProbation = 1 THEN 0 ELSE 2 END AS WinlossStatus
			FROM Temp_NewClassification AS temp
				INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cls ON temp.CustID = cls.CustID
				INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON temp.DWCategoryID = cc.CategoryID 
																		AND (temp.RelevantCategoryID = cls.CategoryID OR temp.DWCategoryID = cls.CategoryID)
			WHERE cls.ParentID = CONST_PARENTID_PA 
				AND temp.ParentID = CONST_PARENTID_PA
				AND temp.WinlossStatus 	= 1;
			
		END IF;
        		
		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_PAWinlossStatus AS r ON temp.CustID = r.CustID
			INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON (ccs.CategoryID = temp.DWCategoryID OR ccs.CategoryID = temp.RelevantCategoryID) AND ccs.SportType = IFNULL(temp.DWSportType, 0)
		SET temp.WinlossStatus 		= r.WinlossStatus,
			temp.IsPAProbation 		= (CASE WHEN r.WinlossStatus = 0 THEN 1 ELSE 0 END)
		WHERE temp.WinlossStatus 	= 1;
		
		UPDATE Temp_NewClassification AS temp
            ,	LATERAL(SELECT 	cat.CategoryGroupID
							,	cat.CustomerClass
							,	cat.Ext_ABIDangerLevel_Licensee
							,	cat.Ext_ABIDangerLevel_Credit
							,	cat.Ext_EvidenceID_Licensee
							,	cat.Ext_EvidenceID_Credit
							,	cat.RelevantCategoryID
						FROM CTS_DataCenter.CustomerCategory AS cat 
						WHERE cat.CategoryID IN (temp.DWCategoryID, temp.RelevantCategoryID) 
							AND cat.IsPAProbation = temp.IsPAProbation 
						LIMIT 1) AS tmpCat
		SET 	temp.NewCategoryGroupID = tmpCat.CategoryGroupID	
			,	temp.NewCategoryID = tmpCat.CategoryGroupID
			,	temp.TargetCC = (CASE 	WHEN temp.SpecialCC IS NOT NULL THEN temp.SpecialCC 
										ELSE IFNULL(tmpCat.CustomerClass,-99) END)
			,	temp.TargetDangerLevel = (CASE  WHEN temp.IsLicensee = 1 THEN tmpCat.Ext_ABIDangerLevel_Licensee
												WHEN temp.IsLicensee = 0 THEN tmpCat.Ext_ABIDangerLevel_Credit END) 
			,	temp.ToEvidenceID = (CASE 	WHEN temp.IsLicensee = 1 THEN tmpCat.Ext_EvidenceID_Licensee
											WHEN temp.IsLicensee = 0 THEN tmpCat.Ext_EvidenceID_Credit
											ELSE NULL END)
			,	temp.RelevantCategoryID = tmpCat.RelevantCategoryID;
	
		UPDATE Temp_NewClassification AS temp
			,	LATERAL(SELECT 	cat.CategoryGroupID
							,	cat.IsPAProbation
						FROM CTS_DataCenter.CustomerCategory  AS cat 
						WHERE cat.CategoryID = temp.RelevantCategoryID 
						LIMIT 1) AS tmpCat
		SET 	temp.RelevantCategoryGroupID 	= tmpCat.CategoryGroupID	
			,	temp.RelevantCategoryID 		= tmpCat.CategoryGroupID
			,	temp.RelevantIsPAProbation 		= tmpCat.IsPAProbation;   
		
		/*Insert into CTSCustomerClassification*/
		UPDATE Temp_NewClassification AS temp
		SET 	temp.IsFromOldPA 	= 1
			,	temp.IsDataChanged 	= 0
			,	temp.IsReturnData	= 0
		WHERE 	temp.IsExistVVIP 	= 1
			AND temp.ParentID = CONST_PARENTID_PA;
			
		UPDATE Temp_NewClassification AS temp
		SET 	temp.IsFromOldPA 	= 1 
		WHERE 	temp.IsExistVVIP 	= 0
			AND temp.ParentID = CONST_PARENTID_PA
			AND lv_IsRescan = 1;
			
		INSERT IGNORE INTO Temp_LicVIPCust(CustID, CategoryID, CustomerClass)
		WITH CTE_LicVIPCust AS (
		SELECT	temp.CustID
			,	CASE WHEN cat.IsDangerProbation = 1 THEN CONST_CATEID_LICVIPSUSPICIOUS ELSE CONST_CATEID_LICVIPDANGEROUS END AS CategoryID
			,	CASE WHEN cat.IsDangerProbation = 1 THEN CONST_CC_LICVIPSUSPICIOUS ELSE CONST_CC_LICVIPDANGEROUS END AS CustomerClass
			,	cat.CustomerClassPriority
		FROM Temp_NewClassification AS temp
			INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = temp.NewCategoryID
		WHERE temp.IsExistVVIP 	= 0
			AND temp.IsLicenseeVIP = 1
		)
		SELECT CustID, CategoryID, CustomerClass
		FROM CTE_LicVIPCust
		ORDER BY CustomerClassPriority ASC
		LIMIT 1;

		/*delete: existing VVIP */
		DELETE temp
		FROM Temp_NewClassification AS temp
		WHERE temp.IsExistVVIP 	= 1 AND temp.ParentID = CONST_PARENTID_POTENTIALPA;
		
		INSERT IGNORE INTO Temp_CTSCustomerClassification_Old(
				CustID, CTSCustID, SubscriberID, RoleID, ParentID, CategoryID, CategoryGroupID, ExistCategoryID, RelevantCategoryID
			, 	Remark, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy, LastScannedDate, IsFromTVS
			, 	IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, InsertTime, TVSRequestID, IsTVSParlay
			, 	SportType, TVSIssueTypeID, IsMarkedDirectly, SpecialCC, CustomerClass, CategoryPriority, CustomerClassPriority
			,	IsPAProbation, IsNew, IsMultiCateIDSameParentID, IsKeepOldCateID) 
		WITH CTE AS (
			SELECT DISTINCT CustID,SpecialCC
			FROM Temp_NewClassification
		)
		SELECT	cls.CustID
			,	cls.CTSCustID
			,	cls.SubscriberID
			,	cls.RoleID
			,	CASE WHEN cls.ParentID = CONST_PARENTID_NORMAL THEN NULL ELSE cc.ParentID END AS ParentID
			,	CASE WHEN cls.ParentID = CONST_PARENTID_NORMAL THEN cc.CategoryID ELSE cc.CategoryGroupID END AS CategoryID
			,	CASE WHEN cls.ParentID = CONST_PARENTID_NORMAL THEN NULL ELSE cc.CategoryGroupID END AS CategoryGroupID /*NORMAL NOT CONSIDER TO WIN/LOSE >> SET NULL*/
			,	cls.CategoryID AS ExistCategoryID
			,	cc.RelevantCategoryID
			,	cls.Remark
			,	cls.CreatedDate
			,	cls.CreatedBy
			,	cls.LastModifiedDate
			,	cls.LastModifiedBy
			,	cls.LastScannedDate
			,	cls.IsFromTVS
			,	cls.IsFromTW
			,	cls.IsFromCTS
			,	cls.IsFromAI
			,	cls.IsFromImperva
			,	lv_CurrentDateTime AS InsertTime
			,	cls.TVSRequestID
			,	cls.IsParlay
			,	cls.SportType
			,	cls.IssueTypeID
			,	cls.IsMarkedDirectly
			,	temp.SpecialCC
			,	IFNULL(temp.SpecialCC,cc.CustomerClass)
			,	cc.CategoryPriority
			,	cc.CustomerClassPriority
			,	cc.IsPAProbation
			,	0 AS IsNew
			,	ccs.IsMultiCateIDSameParentID
			,	ccs.IsKeepOldCateID
		FROM CTS_DataCenter.CTSCustomerClassification AS cls
			INNER JOIN CTE AS temp ON temp.CustID = cls.CustID
			INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = cls.CategoryID 
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = ccs.CategoryID AND cc.IsActive = 1
		WHERE cls.ParentID IN (CONST_PARENTID_PA,CONST_PARENTID_POTENTIALPA,CONST_PARENTID_NORMAL);
			
		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp.CustID = temp_old.CustID 
		SET temp_old.IsRemove = CASE WHEN temp_old.CustomerClassPriority >= temp.CustomerClassPriority
											THEN (CASE 	WHEN temp_old.IsMultiCateIDSameParentID = 0 AND temp_old.IsKeepOldCateID = 1 THEN 0
														WHEN temp_old.IsMultiCateIDSameParentID = 0 AND temp_old.IsKeepOldCateID = 0 THEN 1
														WHEN temp_old.IsMultiCateIDSameParentID = 1 THEN 0 END)
									 ELSE (CASE WHEN temp_old.ParentID = temp.ParentID
													THEN (CASE  WHEN temp_old.IsMultiCateIDSameParentID = 1 THEN 0
																ELSE NULL END)
											ELSE NULL END)
									 END;

		/*delete: priority existing < new */
		DELETE temp
		FROM Temp_NewClassification AS temp 
			INNER JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp.CustID = temp_old.CustID		
		WHERE temp_old.IsNew = 0 AND temp_old.IsRemove IS NULL;
		
		/*delete: priority existing < new */
		/*delete: normal - smart/risky*/
		DELETE temp_old
		FROM Temp_CTSCustomerClassification_Old AS temp_old 
		WHERE (temp_old.IsNew = 0 AND temp_old.IsRemove IS NULL)
			OR (temp_old.ParentID IS NULL AND temp_old.IsNew = 0 AND temp_old.IsRemove = 0);
		
		DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassification_Old_Dup;
		CREATE TEMPORARY TABLE Temp_CTSCustomerClassification_Old_Dup (CustID BIGINT,ExistCategoryID INT,TargetCC INT,CustomerClassPriority SMALLINT);
        
        INSERT INTO Temp_CTSCustomerClassification_Old_Dup (CustID ,ExistCategoryID ,TargetCC ,CustomerClassPriority )
		SELECT temp_old.CustID, temp_old.ExistCategoryID, temp_old.CustomerClass, temp_old.CustomerClassPriority
		FROM Temp_CTSCustomerClassification_Old AS temp_old
		WHERE temp_old.IsRemove = 0
			AND temp_old.SpecialCC IS NULL;
		
		UPDATE Temp_CTSCustomerClassification_Old AS temp_old
			, LATERAL (	SELECT old_dup.ExistCategoryID , old_dup.TargetCC, old_dup.CustID
						FROM Temp_CTSCustomerClassification_Old_Dup AS old_dup
						WHERE temp_old.CustID = old_dup.CustID
						ORDER BY old_dup.CustomerClassPriority
						LIMIT 1
						) AS OldTargetCC
		SET temp_old.CustomerClass = OldTargetCC.TargetCC
		WHERE temp_old.CustID = OldTargetCC.CustID
			AND NOT EXISTS (SELECT 1 FROM Temp_LicVIPCust AS tmpVip WHERE temp_old.CustID = tmpVip.CustID);
		
		UPDATE Temp_CTSCustomerClassification_Old AS temp_old
			INNER JOIN Temp_LicVIPCust AS tmpVip ON temp_old.CustID = tmpVip.CustID
		SET temp_old.CustomerClass = IFNULL(temp_old.SpecialCC, tmpVip.CustomerClass)
		WHERE temp_old.SpecialCC IS NULL;            

		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_LicVIPCust AS tmpVip ON temp.CustID = tmpVip.CustID
		SET temp.TargetCC = IFNULL(temp.SpecialCC, tmpVip.CustomerClass)
		WHERE temp.SpecialCC IS NULL; 
		
        INSERT IGNORE INTO Temp_LastHistory(CustID, CategoryID, TargetCC, ParentID)
		SELECT temp.CustID, tmpHis.CategoryID, tmpHis.TargetCC, tmpHis.ParentID
		FROM Temp_NewClassification AS temp,
		LATERAL (	SELECT h.CategoryID, IFNULL(h.TargetCC,-1) AS TargetCC, h.ParentID
					FROM CTS_DataCenter.CTSCustomerClassification_History AS h
						INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = h.CategoryID
					WHERE h.CustID = temp.CustID 
					ORDER BY h.LastModifiedDate DESC, h.ID DESC
					LIMIT 1) AS tmpHis
		WHERE temp.IsExistVVIP 	= 0;
		
		/*existing PotentialPA + PA - existing and new: not the same CateGroup*/
		UPDATE Temp_NewClassification AS temp 
			LEFT JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp.CustID = temp_old.CustID	
																			AND temp_old.ParentID IS NOT NULL
																			AND temp_old.IsNew = 0
																			AND temp.NewCategoryGroupID = temp_old.CategoryGroupID
		SET 	temp.IsDataChanged 		= 1
		WHERE 	temp.IsDataChanged 		= 0
			AND temp.IsExistVVIP 		= 0
			AND temp_old.CustID IS NULL;
			
		/*existing PA - existing and new: the same CateGroup*/
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN Temp_LastHistory AS h ON h.CustID = temp.CustID
			INNER JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp.CustID = temp_old.CustID	
																			AND temp_old.ParentID IS NOT NULL
																			AND temp_old.IsNew = 0
																			AND temp.NewCategoryGroupID = temp_old.CategoryGroupID
		SET 	temp.DataChangeType		= CASE WHEN temp.TargetCC <> h.TargetCC THEN 1 ELSE temp.DataChangeType END
			,	temp.IsDataChanged 		= CASE WHEN temp.TargetCC <> h.TargetCC AND lv_IsRescan = 1 THEN 1 ELSE temp.IsDataChanged END
			,	temp.OldCategoryID 		= temp_old.ExistCategoryID			
			,	temp.ActionType 		= CASE WHEN temp.TargetCC <> h.TargetCC THEN CONST_ACTIONTYPE_UPDATE ELSE temp.ActionType END
			,	temp.CreatedBy 			= CASE WHEN lv_IsRescan = 1 THEN temp.CreatedBy ELSE temp_old.CreatedBy END
		WHERE 	temp.IsDataChanged 		= 0;
		
		/*existing PotentialPA + PA - existing and new: the same CateGroup*/
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp.CustID = temp_old.CustID	
																			AND temp_old.ParentID IS NOT NULL
																			AND temp_old.IsNew = 0
																			AND temp.RelevantCategoryGroupID = temp_old.CategoryGroupID
		SET 	temp.DataChangeType 	= 1 
			,	temp.IsDataChanged 		= 1 
			,	temp.OldCategoryID 		= temp_old.ExistCategoryID			
			,	temp.ActionType 		= CONST_ACTIONTYPE_UPDATE
			,	temp.CreatedBy 			= CASE WHEN lv_IsRescan = 1 THEN temp.CreatedBy ELSE temp_old.CreatedBy END;
			
		/*existing PotentialPA + PA - existing and new: the same CateGroup - not change WinlossStatus (KEEP)*/
		DELETE temp_old
		FROM Temp_CTSCustomerClassification_Old AS temp_old
			INNER JOIN Temp_NewClassification AS temp ON temp.CustID = temp_old.CustID
															AND temp_old.ParentID IS NOT NULL 
															AND temp.RelevantCategoryGroupID = temp_old.CategoryGroupID
															AND temp_old.IsNew = 0
															AND temp.WinlossStatus <> 1;
		
		INSERT IGNORE INTO Temp_CustProbationStatus(CustID, CTSCustID, DWSportType, TurnoverRM, WinlossRM, BetCount, ActiveDays, IsPAProbation, WinlossStatus, IsLicensee, IsLicenseeVIP)
		SELECT DISTINCT 
				temp.CustID
			,	temp.CTSCustID
			,	IFNULL(temp.DWSportType, 0)
			,	temp.TurnoverRM
			,	temp.WinlossRM
			,	temp.BetCount
			,	temp.ActiveDays
			,	(CASE WHEN temp.WinlossStatus = 0 THEN 1 ELSE 0 END) AS IsPAProbation
			,	temp.WinlossStatus
			,	temp.IsLicensee
			,	temp.IsLicenseeVIP
		FROM Temp_NewClassification AS temp;
		
		/*existing PotentialPA + PA - existing and new: the same CateGroup - WinlossStatus <> KEEP*/
		INSERT INTO Temp_NewClassification(
				CustID, CTSCustID, SubscriberID, RoleID, ParentID, DWCategoryID, DWCategoryGroupID, OldCategoryID, NewCategoryID, NewCategoryGroupID
			, 	TargetCC,  TargetDangerLevel, ToEvidenceID, Remark, WinlossStatus, TurnoverRM, WinlossRM, BetCount, ActiveDays, IsMarkedDirectly
			, 	IsFromTVS, IsFromTW, IsFromCTS, IsFromAI, IsFromImperva, IsDataChanged, DataChangeType, CustomerClassPriority, SpecialCC, IsLicenseeVIP
			, 	LastModifiedDate, CreatedBy, IsPAProbation, TVSRequestID, IsTVSParlay, SportType, TVSIssueTypeID)
		SELECT 	temp_old.CustID
			,	temp_old.CTSCustID
			,	temp_old.SubscriberID
			,	temp_old.RoleID
			,	temp_old.ParentID
			,	temp_old.ExistCategoryID AS DWCategoryID
			,	temp_old.ExistCategoryID AS DWCategoryGroupID
			,	temp_old.ExistCategoryID AS OldCategoryID
			,	tmpLt.CategoryGroupID AS NewCategoryID
			,	tmpLt.CategoryGroupID AS NewCategoryGroupID
			,	(CASE 	WHEN temp_old.SpecialCC IS NOT NULL THEN temp_old.SpecialCC 
						ELSE IFNULL(tmpLt.CustomerClass,-99) END) AS TargetCC
			, 	(CASE 	WHEN tmpCp.IsLicensee = 1 THEN tmpLt.Ext_ABIDangerLevel_Licensee
						WHEN tmpCp.IsLicensee = 0 THEN tmpLt.Ext_ABIDangerLevel_Credit END) AS TargetDangerLevel
			,	(CASE 	WHEN tmpCp.IsLicensee = 1 THEN tmpLt.Ext_EvidenceID_Licensee
						WHEN tmpCp.IsLicensee = 0 THEN tmpLt.Ext_EvidenceID_Credit ELSE NULL END) AS ToEvidenceID
			,	temp_old.Remark
			,	tmpCp.WinlossStatus
			,	tmpCp.TurnoverRM
			,	tmpCp.WinlossRM
			,	tmpCp.BetCount
			,	tmpCp.ActiveDays
			,	temp_old.IsMarkedDirectly
			,	temp_old.IsFromTVS
			,	temp_old.IsFromTW
			,	temp_old.IsFromCTS
			,	temp_old.IsFromAI
			,	temp_old.IsFromImperva
			,	1 AS IsDataChanged
			,	(CASE WHEN tmpCp.WinlossStatus IS NULL THEN NULL ELSE 1 END) AS DataChangeType
			,	tmpLt.CustomerClassPriority
			,	temp_old.SpecialCC 
			,	tmpCp.IsLicenseeVIP 
			,	temp_old.LastModifiedDate
			,	temp_old.CreatedBy
			,	temp_old.IsPAProbation
			,	temp_old.TVSRequestID
			,	temp_old.IsTVSParlay
			,	temp_old.SportType
			,	temp_old.TVSIssueTypeID
		FROM Temp_CTSCustomerClassification_Old AS temp_old
			INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = temp_old.RelevantCategoryID
			INNER JOIN Temp_CustProbationStatus AS tmpCp ON temp_old.ParentID IS NOT NULL AND temp_old.IsNew = 0 AND temp_old.IsRemove <> 1
																AND tmpCp.CustID = temp_old.CustID 
																AND tmpCp.IsPAProbation <> temp_old.IsPAProbation
																AND tmpCp.WinlossStatus <> 1 
																AND tmpCp.DWSportType = ccs.SportType
		, 	LATERAL (SELECT cat.CategoryGroupID
						,	cat.CustomerClass
						,	cat.Ext_ABIDangerLevel_Licensee
						,	cat.Ext_ABIDangerLevel_Credit
						,	cat.Ext_EvidenceID_Licensee
						,	cat.Ext_EvidenceID_Credit
						,	cat.CustomerClassPriority
					FROM CTS_DataCenter.CustomerCategory AS cat 
					WHERE temp_old.RelevantCategoryID = cat.CategoryID 
					LIMIT 1) AS tmpLt
		; 
		
		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_LicVIPCust AS tmpVip ON temp.CustID = tmpVip.CustID
		SET temp.TargetCC = IFNULL(temp.SpecialCC, tmpVip.CustomerClass)
		WHERE temp.SpecialCC IS NULL; 

		-- Potential Risk - config IsKeepOldCateID = 0 - Remove >> Rescan
		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_LastHistory AS tmpHis ON temp.CustID = tmpHis.CustID
            LEFT JOIN Temp_CTSCustomerClassification_Old as temp_old ON temp_old.CustID = temp.CustID AND temp_old.CategoryGroupID = temp.NewCategoryGroupID
		SET temp.IsDataChanged = 1
		WHERE temp_old.CustID IS NULL 
			AND ((temp.NewCategoryGroupID <> tmpHis.CategoryID AND temp.ParentID <> tmpHis.ParentID) OR temp.TargetCC <> tmpHis.TargetCC);

		-- Potential Risk - Rescan SpecialCC
		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_LastHistory AS tmpHis ON temp.CustID = tmpHis.CustID
            LEFT JOIN Temp_CTSCustomerClassification_Old as temp_old ON temp_old.CustID = temp.CustID AND temp_old.CategoryGroupID = temp.NewCategoryGroupID
		SET temp_old.IsRemove = 0
		WHERE temp_old.CustID IS NOT NULL AND temp_old.IsRemove = 1
			AND ((temp.NewCategoryGroupID <> tmpHis.CategoryID AND temp.ParentID <> tmpHis.ParentID) OR temp.TargetCC <> tmpHis.TargetCC);

		-- Potential Risk - Not remove IsDataChanged = 0
		UPDATE Temp_NewClassification AS temp
            INNER JOIN Temp_CTSCustomerClassification_Old as temp_old ON temp_old.CustID = temp.CustID AND temp_old.ExistCategoryID = temp.OldCategoryID
		SET temp_old.IsRemove = 0
		WHERE temp_old.IsNew = 0 AND temp_old.IsRemove = 1 AND temp.IsDataChanged = 0;
			
	END IF;
	
END$$
DELIMITER ;