/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassificationAgency_Insert_Process`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_Insert_Process`(
		IN	ip_InputFlowID			INT
)
SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240927@Thomas.Nguyen
		Task:		
		DB:			CTS_DataCenter
			
		Param's Expanation:
			- ip_InputFlowID
		
		Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_Insert_Process(1009);
			
		Revisions: 
			-	20240927@Thomas.Nguyen:	Created [Redmine ID: #185799]
			-	20250303@Thomas.Nguyen:	Handle WinlossStatus [Redmine ID: #218588]
            -	20250725@Casey.Huynh: Agent CC, Considerable Danger [Redmine ID: #219679]
*/

	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL				INT;
	DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY			INT;
	DECLARE CONST_AGENCY_PARENTID_VVIP			 						INT;
	DECLARE CONST_AGENCY_CATEID_INACTIVENORMAL 							INT;
    DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_CONSIDERABLEDANGER	INT;
    DECLARE CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_CONSIDERABLEDANGER	INT;

	DECLARE CONST_AGENCY_CATEGROUPID_INACTIVE					INT;
	DECLARE CONST_AGENCY_CATEGROUPID_NEW						INT;
	DECLARE CONST_AGENCY_CATEGROUPID_SMART						INT;
	DECLARE CONST_AGENCY_CATEGROUPID_RISKY						INT;

	DECLARE CONST_AGENCY_PARENTID_PA 							INT;
    DECLARE CONST_AGENCY_PARENTID_CONSIDERABLEDANGER			INT;
    DECLARE CONST_AGENCY_PARENTID_NORMAL		    			INT;
		
    DECLARE CONST_ACTIONTYPE_INSERT 							INT DEFAULT 0;
	DECLARE	CONST_ACTIONTYPE_UPDATE 							INT DEFAULT 1;
    DECLARE CONST_ACTIONTYPE_EXISTEDPA 							INT DEFAULT 3;
    DECLARE CONST_ACTIONTYPE_EXISTEDVVIP						INT DEFAULT 4;    
    DECLARE CONST_ACTIONTYPE_RESCAN_CHANGECATEGORY				INT DEFAULT 7;
    DECLARE CONST_ACTIONTYPE_EXISTEDCD							INT DEFAULT 9;
	
    DECLARE CONST_SOURCETYPE_SAMECATEGORY 						INT DEFAULT 0;
    DECLARE CONST_SOURCETYPE_LESSTHAN40TICKETS 					INT DEFAULT 1;
	DECLARE	CONST_SOURCETYPE_AFTER40TICKETS 					INT DEFAULT 2;
	DECLARE CONST_SOURCETYPE_SCANONSCHEDULE						INT DEFAULT 3;
    DECLARE CONST_SOURCETYPE_INACTIVENORMAL 					INT DEFAULT 18;
	
	DECLARE	lv_CurrentDateTime									DATETIME DEFAULT CURRENT_TIMESTAMP();
	DECLARE lv_IsRescan											TINYINT(1) DEFAULT 0; 

	SET CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL');
	SET CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY');
    SET CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_CONSIDERABLEDANGER		= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_CONSIDERABLEDANGER');
    SET CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_CONSIDERABLEDANGER		= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_CONSIDERABLEDANGER');

	SET CONST_AGENCY_PARENTID_VVIP			 							= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_VVIP');
	SET CONST_AGENCY_CATEID_INACTIVENORMAL 								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_INACTIVENORMAL');
	
	SET CONST_AGENCY_CATEGROUPID_INACTIVE						= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEGROUPID_INACTIVE');
	SET CONST_AGENCY_CATEGROUPID_NEW							= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEGROUPID_NEW');
	SET CONST_AGENCY_CATEGROUPID_SMART							= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEGROUPID_SMART');
	SET CONST_AGENCY_CATEGROUPID_RISKY							= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEGROUPID_RISKY');

	SET CONST_AGENCY_PARENTID_PA 								= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_PA');
	SET CONST_AGENCY_PARENTID_NORMAL	 						= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_NORMAL');
    SET CONST_AGENCY_PARENTID_CONSIDERABLEDANGER 				= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_PARENTID_CONSIDERABLEDANGER');
	
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
	
	IF ip_InputFlowID = CONST_AGENCY_INPUTFLOWID_GENERAL_INSERT_NORMAL THEN
		
		INSERT IGNORE INTO Temp_LastHistory(CustID, CategoryID, ParentID, TargetCC)
		SELECT temp.CustID, tmpHis.CategoryID, tmpHis.ParentID, tmpHis.TargetCC
		FROM Temp_NewClassification AS temp,
		LATERAL (	SELECT h.CategoryID, h.ParentID, IFNULL(h.TargetCC,-1) AS TargetCC
					FROM CTS_DataCenter.CTSCustomerClassificationAgency_History AS h
					WHERE h.CustID = temp.CustID 
					ORDER BY h.LastModifiedDate DESC, h.ID DESC
					LIMIT 1) AS tmpHis
		;
		
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN Temp_LastHistory AS h ON temp.CustID = h.CustID
		SET temp.ActionType = CASE 	WHEN h.CategoryID IS NULL OR h.ParentID = CONST_AGENCY_PARENTID_VVIP THEN CONST_ACTIONTYPE_RESCAN_CHANGECATEGORY /*Unmark PA/VVIP*/
									ELSE temp.ActionType
							  END
		WHERE h.TargetCC = -1 OR h.CategoryID IS NULL;

		UPDATE Temp_NewClassification AS temp 
		SET	temp.NewCategoryGroupID = temp.DWCategoryGroupID
			, temp.NewCategoryID = CASE WHEN temp.DWCategoryGroupID <> CONST_AGENCY_CATEGROUPID_INACTIVE THEN temp.DWCategoryGroupID ELSE DWCategoryID END
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA,CONST_ACTIONTYPE_EXISTEDVVIP,CONST_ACTIONTYPE_EXISTEDCD);

		INSERT IGNORE INTO Temp_CTSCustomerClassificationAgency_Old (
				CustID, CTSCustID, SubscriberID, RoleID, CategoryID, CategoryGroupID)
		SELECT 	temp.CustID, temp.CTSCustID, temp.SubscriberID, temp.RoleID, ccs.CategoryID, ccs.CategoryGroupID
		FROM Temp_NewClassification AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassificationAgency AS cls ON temp.CustID = cls.CustID AND cls.ParentID = CONST_AGENCY_PARENTID_NORMAL
			INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS ccs ON ccs.CategoryID = cls.CategoryID
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA,CONST_ACTIONTYPE_EXISTEDVVIP,CONST_ACTIONTYPE_EXISTEDCD);

		UPDATE Temp_NewClassification AS temp
			LEFT JOIN Temp_CTSCustomerClassificationAgency_Old AS o ON temp.CustID = o.CustID
		SET 	temp.OldCategoryGroupID = CASE WHEN o.CustID IS NULL THEN CONST_AGENCY_CATEGROUPID_NEW ELSE o.CategoryGroupID END
			,	temp.OldCategoryID = CASE WHEN o.CustID IS NULL THEN CONST_AGENCY_CATEGROUPID_NEW ELSE o.CategoryID END
			,	temp.IsFromOld = CASE WHEN o.CustID IS NULL THEN 0 ELSE 1 END
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA,CONST_ACTIONTYPE_EXISTEDVVIP,CONST_ACTIONTYPE_EXISTEDCD);
								
		UPDATE Temp_NewClassification AS temp 
		SET temp.SourceTypeID = CASE WHEN temp.ActionType = CONST_ACTIONTYPE_RESCAN_CHANGECATEGORY THEN
										(CASE WHEN temp.NewCategoryGroupID = CONST_AGENCY_CATEGROUPID_NEW THEN CONST_SOURCETYPE_LESSTHAN40TICKETS
											  WHEN temp.NewCategoryGroupID = CONST_AGENCY_CATEGROUPID_INACTIVE AND temp.NewCategoryID = CONST_AGENCY_CATEID_INACTIVENORMAL 
												THEN CONST_SOURCETYPE_INACTIVENORMAL
											  WHEN ((temp.NewCategoryGroupID IN (CONST_AGENCY_CATEGROUPID_SMART, CONST_AGENCY_CATEGROUPID_RISKY) OR temp.NewCategoryGroupID NOT IN (CONST_AGENCY_CATEGROUPID_NEW,CONST_AGENCY_CATEGROUPID_INACTIVE)) AND temp.OldCategoryGroupID <> temp.NewCategoryGroupID)
												THEN CONST_SOURCETYPE_SCANONSCHEDULE
											  ELSE CONST_SOURCETYPE_SAMECATEGORY 
										 END)
									ELSE (CASE	WHEN temp.OldCategoryGroupID = CONST_AGENCY_CATEGROUPID_NEW AND temp.NewCategoryGroupID = CONST_AGENCY_CATEGROUPID_NEW 
													THEN CONST_SOURCETYPE_LESSTHAN40TICKETS
												WHEN (temp.OldCategoryGroupID IS NULL OR temp.OldCategoryGroupID <> CONST_AGENCY_CATEGROUPID_INACTIVE) AND temp.NewCategoryGroupID = CONST_AGENCY_CATEGROUPID_INACTIVE 
													THEN CONST_SOURCETYPE_INACTIVENORMAL 
												WHEN temp.OldCategoryGroupID IN (CONST_AGENCY_CATEGROUPID_NEW,CONST_AGENCY_CATEGROUPID_INACTIVE) AND temp.NewCategoryGroupID NOT IN (CONST_AGENCY_CATEGROUPID_NEW,CONST_AGENCY_CATEGROUPID_INACTIVE) 
													THEN CONST_SOURCETYPE_AFTER40TICKETS
												WHEN temp.OldCategoryGroupID = temp.NewCategoryGroupID 
													THEN CONST_SOURCETYPE_SAMECATEGORY
												ELSE CONST_SOURCETYPE_SCANONSCHEDULE
										  END)
								END
		,	temp.ActionType = CASE 	WHEN temp.IsDataChanged = 1 AND temp.ActionType = CONST_ACTIONTYPE_INSERT AND temp.NewCategoryGroupID <> temp.OldCategoryGroupID
										THEN CONST_ACTIONTYPE_INSERT
									WHEN temp.IsDataChanged = 1 AND temp.ActionType = CONST_ACTIONTYPE_INSERT AND temp.NewCategoryGroupID = temp.OldCategoryGroupID
										THEN ( CASE WHEN temp.IsFromOld = 0
														THEN (CASE WHEN temp.OldCategoryGroupID = CONST_AGENCY_CATEGROUPID_NEW THEN CONST_ACTIONTYPE_INSERT ELSE CONST_ACTIONTYPE_UPDATE END)
													ELSE CONST_ACTIONTYPE_UPDATE END)
									WHEN temp.ActionType = CONST_ACTIONTYPE_RESCAN_CHANGECATEGORY THEN
										CASE WHEN temp.OldCategoryGroupID = temp.NewCategoryGroupID AND temp.IsFromOld = 1 THEN CONST_ACTIONTYPE_UPDATE 
								   			 ELSE CONST_ACTIONTYPE_INSERT END
									ELSE temp.ActionType
							  END
		WHERE temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA,CONST_ACTIONTYPE_EXISTEDVVIP,CONST_ACTIONTYPE_EXISTEDCD);
		
		UPDATE Temp_NewClassification AS temp
		SET temp.IsDataChanged = 0
		WHERE temp.ActionType = CONST_ACTIONTYPE_UPDATE
			AND temp.NewCategoryID = temp.OldCategoryID;
		
		UPDATE Temp_NewClassification AS temp 
			LEFT JOIN CTS_DataCenter.CustomerCategoryAgency AS cate ON cate.CategoryID = temp.NewCategoryID
		SET temp.TargetCC = cate.CustomerClass
		WHERE 	temp.ActionType NOT IN (CONST_ACTIONTYPE_EXISTEDPA, CONST_ACTIONTYPE_EXISTEDVVIP,CONST_ACTIONTYPE_EXISTEDCD);
		
		INSERT IGNORE INTO Temp_UpdateCustomerClass(CustID, CustomerClass)
		SELECT temp.CustID, h.TargetCC
		FROM Temp_NewClassification AS temp
			INNER JOIN Temp_LastHistory AS h ON temp.CustID = h.CustID
		WHERE temp.IsDataChanged = 0;
		
		UPDATE Temp_UpdateCustomerClass AS c
			INNER JOIN Temp_NewClassification AS temp ON c.CustID = temp.CustID
		SET temp.OldTargetCC = c.CustomerClass;
		
		UPDATE Temp_NewClassification
		SET 	IsDataChanged = 1
			,	SourceTypeID = (CASE
									WHEN NewCategoryGroupID = CONST_AGENCY_CATEGROUPID_INACTIVE AND NewCategoryID = CONST_AGENCY_CATEID_INACTIVENORMAL 
										THEN CONST_SOURCETYPE_INACTIVENORMAL
									ELSE CONST_SOURCETYPE_SCANONSCHEDULE
								END)
			,	ActionType = CONST_ACTIONTYPE_UPDATE
		WHERE IsDataChanged = 0 
			AND ((TargetCC <> OldTargetCC) OR (OldCategoryID <> NewCategoryID))
			AND SourceTypeID IN (CONST_SOURCETYPE_SAMECATEGORY, CONST_SOURCETYPE_LESSTHAN40TICKETS);    
		
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS d ON d.CategoryID = temp.NewCategoryID 
		SET 	temp.TargetDangerLevel = CASE WHEN temp.IsLicensee = 0 THEN d.Ext_ABIDangerLevel_Credit ELSE NULL END
		WHERE 	temp.IsDataChanged  = 1;
	
	ELSE
		
		DROP TEMPORARY TABLE IF EXISTS Temp_CustProbationStatus ;
		CREATE TEMPORARY TABLE Temp_CustProbationStatus(
				CustID 					BIGINT UNSIGNED PRIMARY KEY
			,	CTSCustID 				BIGINT UNSIGNED
			,	IsPAProbation			TINYINT(1)
			,	TurnoverRM				DECIMAL(20,4)
			,	WinlossRM				DECIMAL(20,4)
			, 	BetCount				BIGINT 
			,	WinlossStatus			TINYINT
			,	IsLicensee				TINYINT(1)
		); 
		
		IF ip_InputFlowID IN (CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_PACATEGORY, CONST_AGENCY_INPUTFLOWID_GENERAL_RESCAN_CONSIDERABLEDANGER) THEN
			SET lv_IsRescan = 1;
		END IF;
			
		UPDATE Temp_NewClassification AS temp
            ,	LATERAL(SELECT 	cat.CategoryGroupID
							,	cat.CustomerClass
							,	cat.Ext_ABIDangerLevel_Credit
							,	cat.Ext_EvidenceID_Credit
							,	cat.RelevantCategoryID
						FROM CTS_DataCenter.CustomerCategoryAgency AS cat 
						WHERE cat.CategoryID IN (temp.DWCategoryID, temp.RelevantCategoryID) 
							AND cat.IsPAProbation = temp.IsPAProbation 
						LIMIT 1) AS tmpCat
		SET 	temp.NewCategoryGroupID = tmpCat.CategoryGroupID	
			,	temp.NewCategoryID = tmpCat.CategoryGroupID
			,	temp.TargetCC = IFNULL(tmpCat.CustomerClass,-99)
			,	temp.TargetDangerLevel = (CASE WHEN temp.IsLicensee = 0 THEN tmpCat.Ext_ABIDangerLevel_Credit ELSE NULL END) 
			,	temp.ToEvidenceID = (CASE WHEN temp.IsLicensee = 0 THEN tmpCat.Ext_EvidenceID_Credit ELSE NULL END)
			,	temp.RelevantCategoryID = tmpCat.RelevantCategoryID;
	
		UPDATE Temp_NewClassification AS temp
			,	LATERAL(SELECT 	cat.CategoryGroupID
							,	cat.IsPAProbation
						FROM CTS_DataCenter.CustomerCategoryAgency  AS cat 
						WHERE cat.CategoryID = temp.RelevantCategoryID 
						LIMIT 1) AS tmpCat
		SET 	temp.RelevantCategoryGroupID 	= tmpCat.CategoryGroupID	
			,	temp.RelevantCategoryID 		= tmpCat.CategoryGroupID
			,	temp.RelevantIsPAProbation 		= tmpCat.IsPAProbation;   
		
		/*Insert into CTSCustomerClassificationAgency*/
		UPDATE Temp_NewClassification AS temp
		SET 	temp.IsFromOldPA 	= 1
			,	temp.IsDataChanged 	= 0
			,	temp.IsReturnData	= 0
		WHERE 	temp.IsExistVVIP 	= 1
			AND temp.ParentID = CONST_AGENCY_PARENTID_PA;
		
        UPDATE Temp_NewClassification AS temp
		SET 	temp.IsDataChanged 	= 0
			,	temp.IsReturnData	= 0
		WHERE 	(temp.IsExistVVIP = 1 OR temp.IsExistPA = 1)
			AND temp.ParentID = CONST_AGENCY_PARENTID_CONSIDERABLEDANGER;
			
		UPDATE Temp_NewClassification AS temp
		SET 	temp.IsFromOldPA 	= 1 
		WHERE 	temp.IsExistVVIP 	= 0
			AND temp.ParentID = CONST_AGENCY_PARENTID_PA
			AND lv_IsRescan = 1;
		
		INSERT IGNORE INTO Temp_CTSCustomerClassificationAgency_Old(
				CustID, CTSCustID, SubscriberID, RoleID, ParentID, CategoryID, CategoryGroupID, ExistCategoryID, RelevantCategoryID
			, 	Remark, CreatedDate, CreatedBy, LastModifiedDate, LastModifiedBy, LastScannedDate
			, 	IsFromTW, IsFromCTS, IsFromAI, InsertTime, IsMarkedDirectly, CustomerClass, CategoryPriority, CustomerClassPriority
			,	IsPAProbation, IsNew, IsMultiCateIDSameParentID, IsKeepOldCateID) 
		SELECT	cls.CustID
			,	cls.CTSCustID
			,	cls.SubscriberID
			,	cls.RoleID
			,	CASE WHEN cls.ParentID = CONST_AGENCY_PARENTID_NORMAL THEN NULL ELSE cc.ParentID END AS ParentID
			,	CASE WHEN cls.ParentID = CONST_AGENCY_PARENTID_NORMAL THEN cc.CategoryID ELSE cc.CategoryGroupID END AS CategoryID
			,	CASE WHEN cls.ParentID = CONST_AGENCY_PARENTID_NORMAL THEN NULL ELSE cc.CategoryGroupID END AS CategoryGroupID /*NORMAL NOT CONSIDER TO WIN/LOSE >> SET NULL*/
			,	cls.CategoryID AS ExistCategoryID
			,	cc.RelevantCategoryID
			,	cls.Remark
			,	cls.CreatedDate
			,	cls.CreatedBy
			,	cls.LastModifiedDate
			,	cls.LastModifiedBy
			,	cls.LastScannedDate
			,	cls.IsFromTW
			,	cls.IsFromCTS
			,	cls.IsFromAI
			,	lv_CurrentDateTime AS InsertTime
			,	cls.IsMarkedDirectly
			,	cc.CustomerClass
			,	cc.CategoryPriority
			,	cc.CustomerClassPriority
			,	cc.IsPAProbation
			,	0 AS IsNew
			,	ccs.IsMultiCateIDSameParentID
			,	ccs.IsKeepOldCateID
		FROM CTS_DataCenter.CTSCustomerClassificationAgency AS cls
			INNER JOIN CTS_DataCenter.CustomerCategorySettingsAgency AS ccs ON ccs.CategoryID = cls.CategoryID 
			INNER JOIN CTS_DataCenter.CustomerCategoryAgency AS cc ON cc.CategoryID = ccs.CategoryID AND cc.IsActive = 1
		WHERE cls.ParentID IN (CONST_AGENCY_PARENTID_PA,CONST_AGENCY_PARENTID_NORMAL, CONST_AGENCY_PARENTID_CONSIDERABLEDANGER);
			
		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_CTSCustomerClassificationAgency_Old AS temp_old ON temp.CustID = temp_old.CustID 
		SET temp_old.IsRemove = CASE WHEN temp_old.CustomerClassPriority >= temp.CustomerClassPriority
											THEN (CASE 	WHEN temp_old.IsMultiCateIDSameParentID = 0 AND temp_old.IsKeepOldCateID = 1 THEN 0
														WHEN temp_old.IsMultiCateIDSameParentID = 0 AND temp_old.IsKeepOldCateID = 0 THEN 1
														WHEN temp_old.IsMultiCateIDSameParentID = 1 THEN 0 END)
									 ELSE (CASE WHEN temp_old.ParentID = temp.ParentID
													THEN (CASE  WHEN temp_old.IsMultiCateIDSameParentID = 1 THEN 0
																ELSE NULL END)
											ELSE NULL END)
									 END;

		/*delete when priority existing < new and not the same parentID*/
		DELETE temp
		FROM Temp_NewClassification AS temp 
			INNER JOIN Temp_CTSCustomerClassificationAgency_Old AS temp_old ON temp.CustID = temp_old.CustID		
		WHERE temp_old.IsNew = 0 AND temp_old.IsRemove IS NULL;
		
		/*delete when priority existing < new and not the same parentID*/
		/*delete when normal has IsKeepOldCateID = 1*/
		DELETE temp_old
		FROM Temp_CTSCustomerClassificationAgency_Old AS temp_old 
		WHERE (temp_old.IsNew = 0 AND temp_old.IsRemove IS NULL)
			OR (temp_old.ParentID IS NULL AND temp_old.IsNew = 0 AND temp_old.IsRemove = 0);
		
        INSERT IGNORE INTO Temp_LastHistory(CustID, CategoryID, TargetCC, ParentID)
		SELECT temp.CustID, tmpHis.CategoryID, tmpHis.TargetCC, tmpHis.ParentID
		FROM Temp_NewClassification AS temp,
		LATERAL (	SELECT h.CategoryID, IFNULL(h.TargetCC,-1) AS TargetCC, h.ParentID
					FROM CTS_DataCenter.CTSCustomerClassificationAgency_History AS h
					WHERE h.CustID = temp.CustID 
					ORDER BY h.LastModifiedDate DESC, h.ID DESC
					LIMIT 1) AS tmpHis
		WHERE temp.IsExistVVIP 	= 0;
        
		/*case: existing PA*/ 
		/*existing and new: not the same CateGroup*/
		UPDATE Temp_NewClassification AS temp 
			LEFT JOIN Temp_CTSCustomerClassificationAgency_Old AS temp_old ON temp.CustID = temp_old.CustID	
																			AND temp_old.ParentID IS NOT NULL
																			AND temp_old.IsNew = 0
																			AND temp.NewCategoryGroupID = temp_old.CategoryGroupID
		SET 	temp.IsDataChanged 		= 1
		WHERE 	temp.IsDataChanged 		= 0
			AND temp.IsExistVVIP 		= 0
			AND temp_old.CustID IS NULL;
			
		/*case: existing PA*/
		/*existing and new: the same CateGroup*/
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN Temp_LastHistory AS h ON h.CustID = temp.CustID
			INNER JOIN Temp_CTSCustomerClassificationAgency_Old AS temp_old ON temp.CustID = temp_old.CustID	
																			AND temp_old.ParentID IS NOT NULL
																			AND temp_old.IsNew = 0
																			AND temp.NewCategoryGroupID = temp_old.CategoryGroupID
		SET 	temp.DataChangeType		= CASE WHEN temp.TargetCC <> h.TargetCC THEN 1 ELSE temp.DataChangeType END
			,	temp.IsDataChanged 		= CASE WHEN temp.TargetCC <> h.TargetCC THEN 1 ELSE temp.IsDataChanged END
			,	temp.OldCategoryID 		= temp_old.ExistCategoryID			
			,	temp.ActionType 		= CASE WHEN temp.TargetCC <> h.TargetCC THEN CONST_ACTIONTYPE_UPDATE ELSE temp.ActionType END
			,	temp.CreatedBy 			= CASE WHEN lv_IsRescan = 1 THEN temp.CreatedBy ELSE temp_old.CreatedBy END
		WHERE 	temp.IsDataChanged 		= 0;
		
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN Temp_CTSCustomerClassificationAgency_Old AS temp_old ON temp.CustID = temp_old.CustID	
																			AND temp_old.ParentID IS NOT NULL
																			AND temp_old.IsNew = 0
																			AND temp.RelevantCategoryGroupID = temp_old.CategoryGroupID
		SET 	temp.DataChangeType 	= 1 
			,	temp.IsDataChanged 		= 1 
			,	temp.OldCategoryID 		= temp_old.ExistCategoryID			
			,	temp.ActionType 		= CONST_ACTIONTYPE_UPDATE
			,	temp.CreatedBy 			= CASE WHEN lv_IsRescan = 1 THEN temp.CreatedBy ELSE temp_old.CreatedBy END;
		
		/*case: existing PA */
		/*existing and new: the same CateGroup - not change WinlossStatus (KEEP)*/
		DELETE temp_old
		FROM Temp_CTSCustomerClassificationAgency_Old AS temp_old
			INNER JOIN Temp_NewClassification AS temp ON temp_old.ParentID IS NOT NULL 
															AND temp.RelevantCategoryGroupID = temp_old.CategoryGroupID
															AND temp_old.IsNew = 0
															AND temp.WinlossStatus <> 1;
		
		INSERT IGNORE INTO Temp_CustProbationStatus(CustID, CTSCustID, TurnoverRM, WinlossRM, BetCount, IsPAProbation, WinlossStatus, IsLicensee)
		SELECT DISTINCT 
				temp.CustID
			,	temp.CTSCustID
			,	temp.TurnoverRM
			,	temp.WinlossRM
			,	temp.BetCount
			,	(CASE WHEN temp.WinlossStatus = 0 THEN 1 ELSE 0 END) AS IsPAProbation
			,	temp.WinlossStatus
			,	temp.IsLicensee
		FROM Temp_NewClassification AS temp;
		
		/*case: existing PA*/
		/*existing and new: the same CateGroup and WinlossStatus <> KEEP*/
		INSERT INTO Temp_NewClassification(
				CustID, CTSCustID, SubscriberID, RoleID, ParentID, DWCategoryID, DWCategoryGroupID, OldCategoryID, NewCategoryID, NewCategoryGroupID
			, 	TargetCC,  TargetDangerLevel, ToEvidenceID, Remark, WinlossStatus, TurnoverRM, WinlossRM, BetCount, IsMarkedDirectly
			,	IsFromTW, IsFromCTS, IsFromAI, IsDataChanged, DataChangeType
			, 	LastModifiedDate, CreatedBy, IsPAProbation)
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
			,	IFNULL(tmpLt.CustomerClass,-99) AS TargetCC
			, 	CASE WHEN tmpCp.IsLicensee = 0 THEN tmpLt.Ext_ABIDangerLevel_Credit ELSE NULL END AS TargetDangerLevel
			,	CASE WHEN tmpCp.IsLicensee = 0 THEN tmpLt.Ext_EvidenceID_Credit ELSE NULL END AS ToEvidenceID
			,	temp_old.Remark
			,	tmpCp.WinlossStatus
			,	tmpCp.TurnoverRM
			,	tmpCp.WinlossRM
			,	tmpCp.BetCount
			,	temp_old.IsMarkedDirectly
			,	temp_old.IsFromTW
			,	temp_old.IsFromCTS
			,	temp_old.IsFromAI
			,	1 AS IsDataChanged
			,	(CASE WHEN tmpCp.WinlossStatus IS NULL THEN NULL ELSE 1 END) AS DataChangeType
			,	temp_old.LastModifiedDate
			,	temp_old.CreatedBy
			,	temp_old.IsPAProbation
		FROM Temp_CTSCustomerClassificationAgency_Old AS temp_old
			INNER JOIN Temp_CustProbationStatus AS tmpCp ON temp_old.ParentID IS NOT NULL AND temp_old.IsNew = 0 AND temp_old.IsRemove <> 1
																AND tmpCp.CustID = temp_old.CustID 
																AND tmpCp.IsPAProbation <> temp_old.IsPAProbation
																AND tmpCp.WinlossStatus <> 1 
		, 	LATERAL (SELECT cat.CategoryGroupID
						,	cat.CustomerClass
						,	cat.Ext_ABIDangerLevel_Credit
						,	cat.Ext_EvidenceID_Credit
					FROM CTS_DataCenter.CustomerCategoryAgency AS cat 
					WHERE temp_old.RelevantCategoryID = cat.CategoryID 
					LIMIT 1) AS tmpLt
		;        
		
		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_LastHistory AS tmpHis ON temp.CustID = tmpHis.CustID
            LEFT JOIN Temp_CTSCustomerClassificationAgency_Old as temp_old ON temp_old.CustID = temp.CustID AND temp_old.CategoryGroupID = temp.NewCategoryGroupID
		SET temp.IsDataChanged = 1
		WHERE temp_old.CustID IS NULL 
			AND ((temp.NewCategoryGroupID <> tmpHis.CategoryID AND temp.ParentID <> tmpHis.ParentID) OR temp.TargetCC <> tmpHis.TargetCC);

		UPDATE Temp_NewClassification AS temp
			INNER JOIN Temp_LastHistory AS tmpHis ON temp.CustID = tmpHis.CustID
            LEFT JOIN Temp_CTSCustomerClassificationAgency_Old as temp_old ON temp_old.CustID = temp.CustID AND temp_old.CategoryGroupID = temp.NewCategoryGroupID
		SET temp_old.IsRemove = 0
		WHERE temp_old.CustID IS NOT NULL AND temp_old.IsRemove = 1
			AND ((temp.NewCategoryGroupID <> tmpHis.CategoryID AND temp.ParentID <> tmpHis.ParentID) OR temp.TargetCC <> tmpHis.TargetCC);

		UPDATE Temp_NewClassification AS temp
            INNER JOIN Temp_CTSCustomerClassificationAgency_Old as temp_old ON temp_old.CustID = temp.CustID AND temp_old.ExistCategoryID = temp.OldCategoryID
		SET temp_old.IsRemove = 0
		WHERE temp_old.IsNew = 0 AND temp_old.IsRemove = 1 AND temp.IsDataChanged = 0;
			
	END IF;
	
END$$
DELIMITER ;