/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustClassification_Insert_PreProcess`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_Insert_PreProcess`(
    	IN ip_InputFlowID 	INT
)
    SQL SECURITY INVOKER
BEGIN
/*
		Created:	20240620@Thomas.Nguyen
		Task:		
		DB:			CTS_DataCenter

		Param's Explanation (filtered by):
        
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassification_Insert_PreProcess(9);
				
		Revisions: 
			- 20240620@Thomas.Nguyen: Created [Redmine ID: #205317]
			- 20250519@Thomas.Nguyen: Special Lic Sub CC - Add column ScanSpecialLicSubType to ignore keeping Probation rule [Redmine ID: #226847]
*/ 
	DECLARE CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL			INT;
	DECLARE CONST_CATEGROUPID_INACTIVE						INT;
	DECLARE CONST_CATEGROUPID_PROBATION     				INT;
	DECLARE CONST_CATEGROUPID_SMART							INT;
	DECLARE CONST_CATEGROUPID_RISKY							INT;
	DECLARE	CONST_ACTIONTYPE_UPDATE 						INT DEFAULT 1;
    DECLARE CONST_ACTIONTYPE_EXISTEDPA 						INT DEFAULT 3;
    DECLARE CONST_ACTIONTYPE_EXISTEDVVIP					INT DEFAULT 4;
    DECLARE CONST_ACTIONTYPE_IGNOREPROBATION 				INT DEFAULT 5;
    DECLARE CONST_SCANTAGGINGTYPE_NOTEXIST  				TINYINT DEFAULT 0;
	DECLARE	CONST_SCANTAGGINGTYPE_EXIST	   					TINYINT DEFAULT 1;
	DECLARE	CONST_SCANTAGGINGTYPE_EXISTONLY 				TINYINT DEFAULT 2;

	DECLARE lv_FromProbationLastDay 						DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY);
	DECLARE lv_ToProbationLastDay 							DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY);

	SET CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL				= CTS_DC_CategoryTypeParent_Get ('CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL');
	SET CONST_CATEGROUPID_INACTIVE							= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_INACTIVE');
	SET CONST_CATEGROUPID_PROBATION 						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_PROBATION');
	SET CONST_CATEGROUPID_SMART		 						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_SMART');
	SET CONST_CATEGROUPID_RISKY		 						= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_RISKY');

	/*EXCLUDE INTERNAL CUSTOMERS*/      
	CALL CTS_DataCenter.CTS_DC_ExcludeCustByCondition('Temp_NewClassification');
	
	/*SPECIALCC*/ 
	UPDATE Temp_NewClassification AS temp
		LEFT JOIN CTS_DataCenter.CustomerCategory AS cc ON temp.SpecialCC = cc.CustomerClass
															AND cc.IsActive = 1
	SET 	temp.SpecialCCName = cc.CustomerClassName
		,	temp.SpecialCCCatePriority = cc.CategoryPriority
		,	temp.SpecialCCDangerProbation = cc.IsDangerProbation
	WHERE temp.SpecialCC IS NOT NULL;

	IF ip_InputFlowID = CONST_INPUTFLOWID_GENERAL_INSERT_NORMAL THEN
		 
		DROP TEMPORARY TABLE IF EXISTS Temp_ProbationCustomer;    
		CREATE TEMPORARY TABLE Temp_ProbationCustomer(	  	
				CustID					BIGINT UNSIGNED	PRIMARY KEY
			,	DWCategoryGroupID		INT UNSIGNED
			, 	ProbationDate			DATE
			, 	LastProbationDay		DATE
			,	ScanTaggingType			TINYINT DEFAULT 0   
			,	IsPassProbationRule		TINYINT(1)
			,	ScanSpecialLicSubType	TINYINT DEFAULT 0
		);

		DROP TEMPORARY TABLE IF EXISTS Temp_CustIgnoranceAction;    
		CREATE TEMPORARY TABLE Temp_CustIgnoranceAction(	  	
				CustID					BIGINT UNSIGNED	PRIMARY KEY
			, 	ActionType				SMALLINT      
			,	IsReturnData			TINYINT(1)
		); 
		
		 /*GET PROBATION CUSTOMERS*/
		INSERT IGNORE INTO Temp_ProbationCustomer(CustID, DWCategoryGroupID, ProbationDate, LastProbationDay, ScanTaggingType, ScanSpecialLicSubType)
		SELECT 	cls.CustID
			,	temp.DWCategoryGroupID	
			, 	DATE(cls.CreatedDate)
			, 	lv_FromProbationLastDay
			, 	temp.ScanTaggingType
			, 	temp.ScanSpecialLicSubType
		FROM Temp_NewClassification AS temp
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS cls ON temp.CustID = cls.CustID
			INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cls.CategoryID = cate.CategoryID
		WHERE cate.CategoryGroupID = CONST_CATEGROUPID_PROBATION;
		
		UPDATE Temp_ProbationCustomer AS pro
			INNER JOIN Temp_NewClassification AS temp ON pro.CustID = temp.CustID
		SET pro.IsPassProbationRule = 0
		WHERE pro.ProbationDate >= lv_ToProbationLastDay
			OR (temp.DWCategoryGroupID IN (CONST_CATEGROUPID_PROBATION, CONST_CATEGROUPID_SMART, CONST_CATEGROUPID_RISKY) AND pro.ProbationDate > pro.LastProbationDay);
		
		INSERT IGNORE INTO Temp_CustIgnoranceAction(CustID, ActionType, IsReturnData)
		SELECT	temp.CustID, CONST_ACTIONTYPE_IGNOREPROBATION, 0 AS IsReturnData
		FROM 	Temp_ProbationCustomer AS temp 
		WHERE 	temp.IsPassProbationRule = 0
			AND temp.ScanTaggingType = CONST_SCANTAGGINGTYPE_NOTEXIST
			AND temp.ScanSpecialLicSubType = 0;
			
		INSERT IGNORE INTO Temp_CustIgnoranceAction(CustID, ActionType, IsReturnData)
		SELECT DISTINCT temp.CustID, CONST_ACTIONTYPE_EXISTEDVVIP, 0 AS IsReturnData
		FROM Temp_NewClassification AS temp
		WHERE temp.IsExistVVIP = 1;

        INSERT IGNORE INTO Temp_CustIgnoranceAction(CustID, ActionType, IsReturnData)
		SELECT DISTINCT temp.CustID, CONST_ACTIONTYPE_EXISTEDPA, 0 AS IsReturnData
		FROM Temp_NewClassification AS temp
		WHERE temp.IsExistPA = 1 OR temp.IsExistPotentialPA = 1;
		
		/*UPDATE BACK TO Temp_NewClassification*/
		/* HAS ACTION + NO VIEW LOG FAIL PROBATION FOR > 14 LAST DAYS*/ 
		UPDATE Temp_NewClassification AS temp
			INNER JOIN  Temp_ProbationCustomer AS pro ON pro.CustID = temp.CustID
		SET 	temp.IsDataChanged = 0
			,	temp.ActionType = CONST_ACTIONTYPE_UPDATE
		WHERE temp.DWCategoryGroupID = CONST_CATEGROUPID_PROBATION 
			AND pro.ProbationDate < pro.LastProbationDay;
		
		/* NO ACTION + VIEW LOG FOR IGNORE CASES*/ 
		UPDATE Temp_NewClassification AS temp 
			INNER JOIN Temp_CustIgnoranceAction AS ig ON temp.CustID = ig.CustID
		SET 	temp.ActionType = ig.ActionType
			, 	temp.IsDataChanged = 0
			, 	temp.IsReturnData = ig.IsReturnData;

        /*HAS ACTION + VIEW LOG FOR PROBATION NOT ENOUGH DAY WITH NEW TAGGING*/ 
        UPDATE Temp_NewClassification AS temp 
            INNER JOIN Temp_ProbationCustomer AS pro ON temp.CustID = pro.CustID AND pro.IsPassProbationRule = 0
        SET 	temp.ScanTaggingType = CONST_SCANTAGGINGTYPE_EXISTONLY
        WHERE 	pro.ScanTaggingType <> CONST_SCANTAGGINGTYPE_NOTEXIST;
		
		/*GENERATE CATEGORY - UPDATE DW CATEGORY*/
		UPDATE Temp_NewClassification AS temp 
			LEFT JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryGroupID = temp.DWCategoryGroupID 
																AND cate.TaggingType = temp.TaggingType 
																AND cate.TaggingID = temp.TaggingID
		SET temp.DWCategoryID = IFNULL(cate.CategoryID, temp.DWCategoryID)
		WHERE temp.DWCategoryGroupID <> CONST_CATEGROUPID_INACTIVE;
		
	ELSE
		CALL CTS_DataCenter.CTS_DC_CustClassification_PA_RemoveOldTVSRequest(); /*PAReason*/

    END IF;   
END$$
DELIMITER ;