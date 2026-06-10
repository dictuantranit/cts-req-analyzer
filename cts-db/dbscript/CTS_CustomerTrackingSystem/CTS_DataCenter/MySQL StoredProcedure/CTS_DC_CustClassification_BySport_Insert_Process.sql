/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_BySport_Insert_Process`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_Insert_Process`(
	IN ip_InputFlowID			INT
)
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240618@Victoria.Le
		Task:		Insert main customer categories for Customer Classification
		DB:			CTS_DataCenter
			
		Param's Expanation:
			- 
		
		Example:
			- CALL CTS_DC_CustClassification_BySport_Insert_Process();
				
		Revisions: 
			- 20240618@Victoria.Le: Initial Writing [Redmine ID: #205317]
			- 20251113@Thomas.Nguyen: Classify Saba Soccer in System Detect GB CC3101/CC3201 - Add new InputFlowID for PA [Redmine ID: #239995]
*/
	DECLARE CONST_CATEID_NEW			 						INT;
	DECLARE CONST_CATEID_SPECIALCC 								INT;
	DECLARE CONST_PARENTID_NORMAL		 						INT;
	DECLARE CONST_PARENTID_PA		 							INT;
	DECLARE CONST_ACTIONTYPE_INSERT 							INT DEFAULT 0;
	DECLARE	CONST_ACTIONTYPE_UPDATE 							INT DEFAULT 1;
	DECLARE CONST_ACTIONTYPE_EXISTEDPA 							INT DEFAULT 3;
	DECLARE CONST_ACTIONTYPE_IGNOREPROBATION 					INT DEFAULT 5;
	DECLARE CONST_SOURCETYPE_SAMECATEGORY 						INT DEFAULT 0;
	DECLARE CONST_SOURCETYPE_LESSTHAN10TICKETS					INT DEFAULT 1;
	DECLARE CONST_ACTIONTYPE_RESCAN_CHANGECC 					INT DEFAULT 6;
	DECLARE CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL				INT;
	DECLARE CONST_INPUTFLOWID_BYSPORT_INSERT_PACATEGORY			INT;
	DECLARE CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY			INT;

	DECLARE lv_IsRescan											TINYINT(1) DEFAULT 0;
	DECLARE lv_CurrentDateTime									DATETIME DEFAULT CURRENT_TIMESTAMP();

	SET CONST_CATEID_NEW		 								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_NEW');
	SET CONST_CATEID_SPECIALCC	 								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_SPECIALCC');
	SET CONST_PARENTID_NORMAL	 								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
	SET CONST_PARENTID_PA	 									= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
	SET CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL');
	SET CONST_INPUTFLOWID_BYSPORT_INSERT_PACATEGORY				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_BYSPORT_INSERT_PACATEGORY');
	SET CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY');
	
	DROP TEMPORARY TABLE IF EXISTS Temp_UpdateCustomerClass;    
	CREATE TEMPORARY TABLE Temp_UpdateCustomerClass(	  
			CustID										BIGINT UNSIGNED	
		,	SportID										SMALLINT UNSIGNED
		,	CustomerClass 								INT
		,	PRIMARY KEY (CustID, SportID)
	); 

	DROP TEMPORARY TABLE IF EXISTS Temp_LastHistory;
	CREATE TEMPORARY TABLE Temp_LastHistory(
			CustID					BIGINT UNSIGNED 
		,	SportID					SMALLINT UNSIGNED
		,	CategoryID				INT
		,	ParentID				INT 
		,	TargetCC				INT
		,	PRIMARY KEY (CustID, SportID)
	);

	IF ip_InputFlowID = CONST_INPUTFLOWID_BYSPORT_INSERT_NORMAL THEN
		INSERT IGNORE INTO Temp_LastHistory(CustID, SportID, CategoryID, TargetCC)
		SELECT temp.CustID, tmpHis.SportID, tmpHis.CategoryID, tmpHis.TargetCC
		FROM Temp_NewClassification AS temp,
		LATERAL (	SELECT h.SportID, h.CategoryID, IFNULL(h.TargetCC,-1) AS TargetCC
					FROM CTS_DataCenter.CTSCustomerClassification_BySport_History AS h
					WHERE h.CustID = temp.CustID AND h.SportID = temp.SportID
					ORDER BY ID DESC
					LIMIT 1) AS tmpHis
		;
		
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN Temp_LastHistory AS h ON temp.CustID = h.CustID AND temp.SportID = h.SportID 
		SET temp.ActionType = CONST_ACTIONTYPE_RESCAN_CHANGECC /*Remove SpecialCC*/
		WHERE h.TargetCC = -1 OR h.CategoryID = CONST_CATEID_SPECIALCC;

		UPDATE Temp_NewClassification AS temp 
		SET 	temp.NewCategoryGroupID = temp.DWCategoryID 
			,	temp.NewCategoryID 		= temp.DWCategoryID
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA);
		
		INSERT IGNORE INTO Temp_CTSCustomerClassification_Old(CustID, SportID, OldCategoryGroupID, OldCategoryID)
		SELECT DISTINCT temp.CustID, temp.SportID, cc.CategoryGroupID, cate.CategoryID
		FROM Temp_NewClassification AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassification_BySport AS cate ON temp.CustID = cate.CustID AND cate.ParentID = CONST_PARENTID_NORMAL
																					AND temp.SportID = cate.SportID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cc ON cc.CategoryID = cate.CategoryID
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA);
		
		UPDATE Temp_NewClassification AS temp
			LEFT JOIN Temp_CTSCustomerClassification_Old AS o ON temp.CustID = o.CustID AND temp.SportID = o.SportID
		SET 	temp.OldCategoryGroupID 	= CASE WHEN o.CustID IS NULL THEN CONST_CATEID_NEW ELSE o.OldCategoryGroupID END
			,	temp.OldCategoryID 			= CASE WHEN o.CustID IS NULL THEN CONST_CATEID_NEW ELSE o.OldCategoryID END
			,	temp.IsFromOld				= CASE WHEN o.CustID IS NULL THEN 0 ELSE 1 END
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA);

		UPDATE Temp_NewClassification AS temp
		SET 	temp.IsReturnData = CASE WHEN temp.ActionType = CONST_ACTIONTYPE_RESCAN_CHANGECC AND temp.IsReturnData = 0 THEN 1 ELSE temp.IsReturnData END
			,	temp.ActionType = CASE WHEN	temp.IsDataChanged = 1 AND temp.ActionType IN (CONST_ACTIONTYPE_INSERT,CONST_ACTIONTYPE_RESCAN_CHANGECC) AND temp.NewCategoryID <> temp.OldCategoryID
											THEN CONST_ACTIONTYPE_INSERT
										WHEN temp.IsDataChanged = 1 AND temp.ActionType IN (CONST_ACTIONTYPE_INSERT,CONST_ACTIONTYPE_RESCAN_CHANGECC) AND temp.NewCategoryID = temp.OldCategoryID
											THEN (CASE WHEN temp.IsFromOld = 0 
															THEN (CASE WHEN temp.OldCategoryID = CONST_CATEID_NEW THEN CONST_ACTIONTYPE_INSERT ELSE CONST_ACTIONTYPE_UPDATE END)
													ELSE CONST_ACTIONTYPE_UPDATE END)
										ELSE temp.ActionType
									END
			,	temp.SourceTypeID = CASE WHEN temp.OldCategoryGroupID = CONST_CATEID_NEW AND temp.NewCategoryGroupID = CONST_CATEID_NEW
											THEN  CONST_SOURCETYPE_LESSTHAN10TICKETS
										WHEN temp.OldCategoryGroupID = temp.NewCategoryGroupID 
											THEN CONST_SOURCETYPE_SAMECATEGORY
									END
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA);
		
		UPDATE Temp_NewClassification AS temp
		SET 	temp.IsDataChanged = 0
		WHERE temp.ActionType IN (CONST_ACTIONTYPE_UPDATE,CONST_ACTIONTYPE_RESCAN_CHANGECC)
			AND temp.NewCategoryID = temp.OldCategoryID;
		
		UPDATE Temp_NewClassification AS temp 
			LEFT JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = temp.NewCategoryID
		SET 	temp.TargetCC = IFNULL(temp.SpecialCC, cate.CustomerClass)
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA);
		
		INSERT IGNORE INTO Temp_UpdateCustomerClass(CustID, SportID, CustomerClass)
		SELECT 	temp.CustID
			,	h.SportID
			,	h.TargetCC
		FROM Temp_NewClassification AS temp
			INNER JOIN Temp_LastHistory AS h ON temp.CustID = h.CustID AND temp.SportID = h.SportID
		WHERE temp.IsDataChanged  = 0;
		
		UPDATE Temp_UpdateCustomerClass AS c
			INNER JOIN Temp_NewClassification AS temp ON c.CustID = temp.CustID AND c.SportID = temp.SportID
		SET temp.OldTargetCC = c.CustomerClass;
		
		UPDATE Temp_NewClassification AS temp
			INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = temp.OldCategoryID
		SET 	temp.TargetCC 			= IFNULL(temp.SpecialCC, cate.CustomerClass)
			,	temp.NewCategoryID		= temp.OldCategoryID
			, 	temp.NewCategoryGroupID = temp.OldCategoryGroupID
		WHERE 	temp.ActionType IN (CONST_ACTIONTYPE_IGNOREPROBATION,CONST_ACTIONTYPE_RESCAN_CHANGECC);
		
		UPDATE Temp_NewClassification AS temp
		SET 	temp.IsDataChanged 	= 1
			,	temp.ActionType 	= CONST_ACTIONTYPE_UPDATE
		WHERE 	temp.IsDataChanged 	= 0 
			AND ((temp.TargetCC <> temp.OldTargetCC) OR (temp.OldCategoryID <> temp.NewCategoryID))
			AND (temp.ActionType IN (CONST_ACTIONTYPE_IGNOREPROBATION,CONST_ACTIONTYPE_RESCAN_CHANGECC)
					OR temp.SourceTypeID IN (CONST_SOURCETYPE_SAMECATEGORY, CONST_SOURCETYPE_LESSTHAN10TICKETS));
	ELSE
		DROP TEMPORARY TABLE IF EXISTS Temp_PAWinlossStatus;    
		CREATE TEMPORARY TABLE Temp_PAWinlossStatus(	
				CustID					BIGINT UNSIGNED
			,	SportID					SMALLINT
			, 	WinlossStatus			SMALLINT /*LOSING  = 0 (PROBATION), WINNING = 2 (NOT PROBATION);*/
			,	PRIMARY KEY (CustID, SportID)
		);
		
		DROP TEMPORARY TABLE IF EXISTS Temp_CustProbationStatus ;
		CREATE TEMPORARY TABLE Temp_CustProbationStatus(
				CustID 					BIGINT UNSIGNED
			,	CTSCustID 				BIGINT UNSIGNED
			,	SportID					SMALLINT
			,	IsPAProbation			TINYINT(1)
			,	TurnoverRM				DECIMAL(20,4)
			,	WinlossRM				DECIMAL(20,4)
			, 	BetCount				BIGINT 
			, 	ActiveDays				INT
			,	WinlossStatus			TINYINT
			,	PRIMARY KEY (CustID, SportID)
		); 
		
		IF ip_InputFlowID = CONST_INPUTFLOWID_BYSPORT_RESCAN_PACATEGORY THEN
			SET lv_IsRescan = 1;
		END IF;
        
		IF lv_IsRescan = 0 THEN 
			INSERT INTO Temp_PAWinlossStatus(CustID, SportID, WinlossStatus)
			SELECT DISTINCT 
					temp.CustID
				,	temp.SportID
				,	CASE WHEN cat.IsDangerProbation = 1 THEN 0 ELSE 2 END AS WinlossStatus
			FROM Temp_NewClassification AS temp
				INNER JOIN CTS_DataCenter.CTSCustomerClassification_BySport AS cls ON temp.CustID = cls.CustID AND temp.SportID = cls.SportID
				INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cls.CategoryID = cat.CategoryID
			WHERE cls.ParentID = CONST_PARENTID_PA;
		
		ELSE
			INSERT INTO Temp_PAWinlossStatus(CustID, SportID, WinlossStatus)
			SELECT DISTINCT 
					temp.CustID
				,	temp.SportID
				,	CASE WHEN cat.IsDangerProbation = 1 THEN 0 ELSE 2 END AS WinlossStatus
			FROM Temp_NewClassification AS temp
				INNER JOIN CTS_DataCenter.CTSCustomerClassification_BySport AS cls ON temp.CustID = cls.CustID AND temp.SportID = cls.SportID
				INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON temp.DWCategoryID = cat.CategoryID 
																		AND (temp.RelevantCategoryID = cls.CategoryID OR temp.DWCategoryID = cls.CategoryID)
			WHERE cls.ParentID = CONST_PARENTID_PA 
				AND temp.ParentID = CONST_PARENTID_PA
				AND temp.WinlossStatus 	= 1;
			
		END IF;
        		
		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_PAWinlossStatus AS r ON temp.CustID = r.CustID AND temp.SportID = r.SportID
		SET temp.WinlossStatus 		= r.WinlossStatus,
			temp.IsPAProbation 		= (CASE WHEN r.WinlossStatus = 0 THEN 1 ELSE 0 END)
		WHERE temp.WinlossStatus 	= 1;
		
		UPDATE Temp_NewClassification AS temp
            ,	LATERAL(SELECT 	cat.CategoryGroupID
							,	cat.CustomerClass
							,	cat.RelevantCategoryID
						FROM CTS_DataCenter.CustomerCategory AS cat 
						WHERE cat.CategoryID IN (temp.DWCategoryID, temp.RelevantCategoryID) 
							AND cat.IsPAProbation = temp.IsPAProbation 
						LIMIT 1) AS tmpCat
		SET 	temp.NewCategoryGroupID = tmpCat.CategoryGroupID	
			,	temp.NewCategoryID = tmpCat.CategoryGroupID
			,	temp.TargetCC = (CASE 	WHEN temp.SpecialCC IS NOT NULL THEN temp.SpecialCC 
										ELSE IFNULL(tmpCat.CustomerClass,-99) END)
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
		WHERE 	temp.ParentID = CONST_PARENTID_PA AND lv_IsRescan = 1;
		
		INSERT IGNORE INTO Temp_CTSCustomerClassification_Old(
				CustID, CTSCustID, SportID, ParentID, OldCategoryID, OldCategoryGroupID, ExistCategoryID, RelevantCategoryID
			, 	Remark, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy, LastScannedDate, InsertTime, SpecialCC, CustomerClass, CategoryPriority, CustomerClassPriority
			,	IsPAProbation, IsNew, IsMultiCateIDSameParentID, IsKeepOldCateID) 
		WITH CTE AS (
			SELECT DISTINCT CustID, SportID, SpecialCC
			FROM Temp_NewClassification
		)
		SELECT	cls.CustID
			,	cls.CTSCustID
			,	cls.SportID
			,	CASE WHEN cls.ParentID = CONST_PARENTID_NORMAL THEN NULL ELSE cat.ParentID END AS ParentID
			,	CASE WHEN cls.ParentID = CONST_PARENTID_NORMAL THEN cat.CategoryID ELSE cat.CategoryGroupID END AS OldCategoryID
			,	CASE WHEN cls.ParentID = CONST_PARENTID_NORMAL THEN NULL ELSE cat.CategoryGroupID END AS OldCategoryGroupID /*NORMAL NOT CONSIDER TO WIN/LOSE >> SET NULL*/
			,	cls.CategoryID AS ExistCategoryID
			,	cat.RelevantCategoryID
			,	cls.Remark
			,	cls.CreatedDate
			,	cls.CreatedBy
			,	cls.LastModifiedDate
			,	cls.LastModifiedBy
			,	cls.LastScannedDate
			,	lv_CurrentDateTime AS InsertTime
			,	temp.SpecialCC
			,	IFNULL(temp.SpecialCC,cat.CustomerClass)
			,	cat.CategoryPriority
			,	cat.CustomerClassPriority
			,	cat.IsPAProbation
			,	0 AS IsNew
			,	ccs.IsMultiCateIDSameParentID
			,	ccs.IsKeepOldCateID
		FROM CTS_DataCenter.CTSCustomerClassification_BySport AS cls
			INNER JOIN CTE AS temp ON temp.CustID = cls.CustID AND temp.SportID = cls.SportID
			INNER JOIN CTS_DataCenter.CustomerCategorySettings AS ccs ON ccs.CategoryID = cls.CategoryID 
			INNER JOIN CTS_DataCenter.CustomerCategory AS cat ON cat.CategoryID = ccs.CategoryID AND cat.IsActive = 1
		WHERE cls.ParentID IN (CONST_PARENTID_PA, CONST_PARENTID_NORMAL);
			
		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp.CustID = temp_old.CustID AND temp.SportID = temp_old.SportID
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
			INNER JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp.CustID = temp_old.CustID AND temp.SportID = temp_old.SportID
		WHERE temp_old.IsNew = 0 AND temp_old.IsRemove IS NULL;
		
		/*delete when priority existing < new and not the same parentID*/
		/*delete when normal has IsKeepOldCateID = 1*/
		DELETE temp_old
		FROM Temp_CTSCustomerClassification_Old AS temp_old 
		WHERE (temp_old.IsNew = 0 AND temp_old.IsRemove IS NULL)
			OR (temp_old.ParentID IS NULL AND temp_old.IsNew = 0 AND temp_old.IsRemove = 0);
		
		DROP TEMPORARY TABLE IF EXISTS Temp_CTSCustomerClassification_Old_Dup;
		CREATE TEMPORARY TABLE Temp_CTSCustomerClassification_Old_Dup (CustID BIGINT, SportID SMALLINT, ExistCategoryID INT,TargetCC INT,CustomerClassPriority SMALLINT);
        
        INSERT INTO Temp_CTSCustomerClassification_Old_Dup (CustID, SportID, ExistCategoryID, TargetCC, CustomerClassPriority)
		SELECT temp_old.CustID, temp_old.SportID, temp_old.ExistCategoryID, temp_old.CustomerClass, temp_old.CustomerClassPriority
		FROM Temp_CTSCustomerClassification_Old AS temp_old
		WHERE temp_old.IsRemove = 0
			AND temp_old.SpecialCC IS NULL;
		
		UPDATE Temp_CTSCustomerClassification_Old AS temp_old
			, LATERAL (	SELECT old_dup.ExistCategoryID , old_dup.TargetCC, old_dup.CustID, old_dup.SportID
						FROM Temp_CTSCustomerClassification_Old_Dup AS old_dup
						WHERE temp_old.CustID = old_dup.CustID AND temp_old.SportID = old_dup.SportID
						ORDER BY old_dup.CustomerClassPriority ASC
						LIMIT 1
						) AS OldTargetCC
		SET temp_old.CustomerClass = OldTargetCC.TargetCC
		WHERE temp_old.CustID = OldTargetCC.CustID
			AND temp_old.SportID = OldTargetCC.SportID;
		
        INSERT IGNORE INTO Temp_LastHistory(CustID, SportID, CategoryID, TargetCC, ParentID)
		SELECT temp.CustID, temp.SportID, tmpHis.CategoryID, tmpHis.TargetCC, tmpHis.ParentID
		FROM Temp_NewClassification AS temp,
		LATERAL (	SELECT h.CategoryID, IFNULL(h.TargetCC,-1) AS TargetCC, h.ParentID
					FROM CTS_DataCenter.CTSCustomerClassification_BySport_History AS h
						INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID = h.CategoryID
					WHERE h.CustID = temp.CustID AND h.SportID = temp.SportID
					ORDER BY h.LastModifiedDate DESC, h.ID DESC
					LIMIT 1) AS tmpHis;
		
		/*existing PotentialPA + PA - existing and new: not the same CateGroup*/
		UPDATE Temp_NewClassification AS temp 
			LEFT JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp.CustID = temp_old.CustID 
																			AND temp.SportID = temp_old.SportID
																			AND temp_old.ParentID IS NOT NULL
																			AND temp_old.IsNew = 0
																			AND temp.NewCategoryGroupID = temp_old.OldCategoryGroupID
		SET 	temp.IsDataChanged 		= 1
		WHERE 	temp.IsDataChanged 		= 0
			AND temp_old.CustID IS NULL;
			
		/*existing PA - existing and new: the same CateGroup*/
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN Temp_LastHistory AS h ON h.CustID = temp.CustID AND h.SportID = temp.SportID
			INNER JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp.CustID = temp_old.CustID 
																			AND temp.SportID = temp_old.SportID
																			AND temp_old.ParentID IS NOT NULL
																			AND temp_old.IsNew = 0
																			AND temp.NewCategoryGroupID = temp_old.OldCategoryGroupID
		SET 	temp.DataChangeType		= CASE WHEN temp.TargetCC <> h.TargetCC THEN 1 ELSE temp.DataChangeType END
			,	temp.IsDataChanged 		= CASE WHEN temp.TargetCC <> h.TargetCC AND lv_IsRescan = 1 THEN 1 ELSE temp.IsDataChanged END
			,	temp.OldCategoryID 		= temp_old.ExistCategoryID			
			,	temp.ActionType 		= CASE WHEN temp.TargetCC <> h.TargetCC THEN CONST_ACTIONTYPE_UPDATE ELSE temp.ActionType END
			,	temp.CreatedBy 			= CASE WHEN lv_IsRescan = 1 THEN temp.CreatedBy ELSE temp_old.CreatedBy END
		WHERE 	temp.IsDataChanged 		= 0;
		
		/*existing PotentialPA + PA - existing and new: the same CateGroup*/
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp.CustID = temp_old.CustID
																			AND temp.SportID = temp_old.SportID
																			AND temp_old.ParentID IS NOT NULL
																			AND temp_old.IsNew = 0
																			AND temp.RelevantCategoryGroupID = temp_old.OldCategoryGroupID
		SET 	temp.DataChangeType 	= 1 
			,	temp.IsDataChanged 		= 1 
			,	temp.OldCategoryID 		= temp_old.ExistCategoryID			
			,	temp.ActionType 		= CONST_ACTIONTYPE_UPDATE
			,	temp.CreatedBy 			= CASE WHEN lv_IsRescan = 1 THEN temp.CreatedBy ELSE temp_old.CreatedBy END;
			
		/*existing PA - existing and new: the same CateGroup - not change WinlossStatus (KEEP)*/
		DELETE temp_old
		FROM Temp_CTSCustomerClassification_Old AS temp_old
			INNER JOIN Temp_NewClassification AS temp ON temp.CustID = temp_old.CustID
															AND temp.SportID = temp_old.SportID
															AND temp_old.ParentID IS NOT NULL 
															AND temp.RelevantCategoryGroupID = temp_old.OldCategoryGroupID
															AND temp_old.IsNew = 0
															AND temp.WinlossStatus <> 1;
		
		INSERT IGNORE INTO Temp_CustProbationStatus(CustID, CTSCustID, SportID, TurnoverRM, WinlossRM, BetCount, ActiveDays, IsPAProbation, WinlossStatus)
		SELECT DISTINCT 
				temp.CustID
			,	temp.CTSCustID
			,	temp.SportID
			,	temp.TurnoverRM
			,	temp.WinlossRM
			,	temp.BetCount
			,	temp.ActiveDays
			,	(CASE WHEN temp.WinlossStatus = 0 THEN 1 ELSE 0 END) AS IsPAProbation
			,	temp.WinlossStatus
		FROM Temp_NewClassification AS temp;
		
		/*existing PA - existing and new: the same CateGroup - WinlossStatus <> KEEP*/
		INSERT INTO Temp_NewClassification(
				CustID, CTSCustID, SportID, ParentID, DWCategoryID, DWCategoryGroupID, OldCategoryID, NewCategoryID, NewCategoryGroupID
			, 	TargetCC, Remark, WinlossStatus, TurnoverRM, WinlossRM, BetCount, ActiveDays
			, 	IsDataChanged, DataChangeType, CustomerClassPriority, SpecialCC
			, 	LastModifiedDate, CreatedBy, IsPAProbation)
		SELECT 	temp_old.CustID
			,	temp_old.CTSCustID
			,	temp_old.SportID
			,	temp_old.ParentID
			,	temp_old.ExistCategoryID AS DWCategoryID
			,	temp_old.ExistCategoryID AS DWCategoryGroupID
			,	temp_old.ExistCategoryID AS OldCategoryID
			,	tmpLt.CategoryGroupID AS NewCategoryID
			,	tmpLt.CategoryGroupID AS NewCategoryGroupID
			,	(CASE 	WHEN temp_old.SpecialCC IS NOT NULL THEN temp_old.SpecialCC 
						ELSE IFNULL(tmpLt.CustomerClass,-99) END) AS TargetCC
			,	temp_old.Remark
			,	tmpCp.WinlossStatus
			,	tmpCp.TurnoverRM
			,	tmpCp.WinlossRM
			,	tmpCp.BetCount
			,	tmpCp.ActiveDays
			,	1 AS IsDataChanged
			,	(CASE WHEN tmpCp.WinlossStatus IS NULL THEN NULL ELSE 1 END) AS DataChangeType
			,	tmpLt.CustomerClassPriority
			,	temp_old.SpecialCC 
			,	temp_old.LastModifiedDate
			,	temp_old.CreatedBy
			,	temp_old.IsPAProbation
		FROM Temp_CTSCustomerClassification_Old AS temp_old
			INNER JOIN Temp_CustProbationStatus AS tmpCp ON temp_old.ParentID IS NOT NULL 
																AND temp_old.IsNew = 0 
																AND temp_old.IsRemove <> 1
																AND tmpCp.CustID = temp_old.CustID 
																AND tmpCp.IsPAProbation <> temp_old.IsPAProbation
																AND tmpCp.WinlossStatus <> 1 
																AND tmpCp.SportID = temp_old.SportID
		, 	LATERAL (SELECT cat.CategoryGroupID
						,	cat.CustomerClass
						,	cat.CustomerClassPriority
					FROM CTS_DataCenter.CustomerCategory AS cat 
					WHERE temp_old.RelevantCategoryID = cat.CategoryID 
					LIMIT 1) AS tmpLt; 

		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_LastHistory AS tmpHis ON temp.CustID = tmpHis.CustID AND temp.SportID = tmpHis.SportID
            LEFT JOIN Temp_CTSCustomerClassification_Old as temp_old ON temp_old.CustID = temp.CustID 
																		AND temp_old.SportID = temp.SportID
																		AND temp_old.OldCategoryGroupID = temp.NewCategoryGroupID
		SET temp.IsDataChanged = 1
		WHERE temp_old.CustID IS NULL 
			AND ((temp.NewCategoryGroupID <> tmpHis.CategoryID AND temp.ParentID <> tmpHis.ParentID) OR temp.TargetCC <> tmpHis.TargetCC);

		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_LastHistory AS tmpHis ON temp.CustID = tmpHis.CustID AND temp.SportID = tmpHis.SportID
            LEFT JOIN Temp_CTSCustomerClassification_Old as temp_old ON temp_old.CustID = temp.CustID
																		AND temp_old.SportID = temp.SportID
																		AND temp_old.OldCategoryGroupID = temp.NewCategoryGroupID
		SET temp_old.IsRemove = 0
		WHERE temp_old.CustID IS NOT NULL AND temp_old.IsRemove = 1
			AND ((temp.NewCategoryGroupID <> tmpHis.CategoryID AND temp.ParentID <> tmpHis.ParentID) OR temp.TargetCC <> tmpHis.TargetCC);

		UPDATE Temp_NewClassification AS temp
            INNER JOIN Temp_CTSCustomerClassification_Old AS temp_old ON temp_old.CustID = temp.CustID 
																		AND temp_old.SportID = temp.SportID
																		AND temp_old.ExistCategoryID = temp.OldCategoryID
		SET temp_old.IsRemove = 0
		WHERE temp_old.IsNew = 0 AND temp_old.IsRemove = 1 AND temp.IsDataChanged = 0;
	END IF;
END$$
DELIMITER ;