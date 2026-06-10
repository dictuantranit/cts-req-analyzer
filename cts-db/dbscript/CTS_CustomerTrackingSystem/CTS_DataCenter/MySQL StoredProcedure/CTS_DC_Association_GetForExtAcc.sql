/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsAPI" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_Association_GetForExtAcc`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_GetForExtAcc`(
		IN ip_CustID 			BIGINT UNSIGNED
	,	IN ip_AssociationType	INT
	,	IN ip_AssociationStatus INT 
)
    SQL SECURITY INVOKER
sp : BEGIN
	/*
		Created:	20210330@Aries.Nguyen
		Task:		Get association account 
		DB:			CTS_DataCenter
        
		Revisions:
			- 20210330@Aries.Nguyen: 	Created [Redmine ID: #152507]
			- 20220408@Casey.Huynh: 	Add AssociationGroupByAI [Redmine ID: #171222]
			- 20230112@Victoria.Le: 	Modify SPs due to restructure AssociationByAI [Redmine ID: #181994]
            - 20230313@Casey.Huynh:		Applied Betting Parten OTGB [Redmine ID: #184791]
			- 20230421@Casey.Huynh: 	Add AssType to AssociationByIP [Redmine ID: #185783]
			
        Param's Explanation (filtered by):
			- ip_AssociationType: 0 - ALL, 1 - Device, 2 - AI, 3 - Manual, 4 - IP
            - ip_AssociationStatus: 0 - All, 1 - Linked, 2 - UnLinked
        Example:
			- CALL CTS_DataCenter.CTS_DC_Association_GetForExtAcc(169686, 2, 0);
	*/
	DECLARE CONST_ASSTYPE_BETTINGPATTERN 	INT DEFAULT 2;
	DECLARE CONST_ASSBYAI_ACTIVESTATUS 		INT DEFAULT 1;
	DECLARE CONST_ASSTYPE_IP 				INT DEFAULT 4;
	DECLARE CONST_ASSBYIP_ACTIVESTATUS 		INT DEFAULT 1;    
	#=============================================================================
	DECLARE lv_CTSCustID INT;
	
    DROP TEMPORARY TABLE IF EXISTS Temp_Accounts;
    CREATE TEMPORARY TABLE 		Temp_Accounts (
			CustID 				BIGINT UNSIGNED
		,	CTSCustID			BIGINT UNSIGNED
        ,	CustSubID			INT UNSIGNED
        ,	AssociationType 	INT
        , 	AssociationStatus	INT
        ,	AssociationDate 	DATETIME
        , 	PRIMARY KEY(CTSCustID)
	);   
	
    DROP TEMPORARY TABLE IF EXISTS Temp_CustAssociation;
    CREATE TEMPORARY TABLE 		Temp_CustAssociation (
			CTSCustID_Aff 		BIGINT UNSIGNED
        , 	AssociationType		INT
		, 	AssociationStatus	INT
        ,	AssociationDate		DATETIME
        , 	PRIMARY KEY (CTSCustID_Aff,AssociationType, AssociationStatus)
	);  
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustAssociationUnlinked;
    CREATE TEMPORARY TABLE 		Temp_CustAssociationUnlinked (
			CTSCustID_Aff 		BIGINT UNSIGNED
        , 	AssociationType		INT
        , 	AssociationStatus	INT
        ,	AssociationDate		DaTETIME
        , 	PRIMARY KEY (CTSCustID_Aff,AssociationType, AssociationStatus)
	);  
    
	DROP TEMPORARY TABLE IF EXISTS Temp_AssGroupByAI;
	CREATE TEMPORARY TABLE Temp_AssGroupByAI (
			GroupID 	BIGINT UNSIGNED
		,	CreatedDate	DATETIME
        
        , 	PRIMARY KEY (GroupID)
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
    
    /*<Customer Category Rule/>*/    
    SELECT CTSCustID 
    INTO lv_CTSCustID
    FROM CTS_DataCenter.CTSCustomer 
    WHERE CustID = ip_CustID AND CustSubID = 0;
    
    # ip_AssociationType: 0 - ALL, 1 - Device, 2 - AI, 3 - Manual, 4 - IP
    IF ip_AssociationType = 0 OR ip_AssociationType = 1 THEN
		INSERT INTO Temp_CustAssociation(CTSCustID_Aff, AssociationType, AssociationStatus,  AssociationDate)
		SELECT 
				asCus.CTSCustID  
			,	1 AS AssociationType
            , 	1 AS AssociationStatus
			,	GREATEST(asDv.CreatedTime, asCus.CreatedTime)
		FROM CTS_DataCenter.AssociationByDevice AS asDv 
			INNER JOIN CTS_DataCenter.AssociationByDevice AS asCus ON asCus.DCSDeviceID =  asDv.DCSDeviceID  AND asCus.CTSCustID  !=   lv_CTSCustID
		WHERE asDv.CTSCustID = lv_CTSCustID
        ON DUPLICATE KEY UPDATE AssociationDate = LEAST(Temp_CustAssociation.AssociationDate, GREATEST(asDv.CreatedTime, asCus.CreatedTime)); 
    END IF;
    
    # ip_AssociationType: 0 - ALL, 1 - Device, 2 - AI, 3 - Manual, 4 - IP
    IF ip_AssociationType = 0 OR ip_AssociationType = 3 THEN
		INSERT IGNORE INTO Temp_CustAssociation(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT 
				asMa.ToCTSCustID 
			,	3 AS AssociationType
            ,   1 AS AssociationStatus
			,	asMa.CreatedDate
		FROM CTS_DataCenter.AssociationByManual AS asMa 
		WHERE	asMa.FromCTSCustID =  lv_CTSCustID;
       
        
        INSERT IGNORE INTO Temp_CustAssociation(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT 
				asMa.FromCTSCustID
			,	3 AS AssociationType
            ,   1 AS AssociationStatus
			,	asMa.CreatedDate
		FROM CTS_DataCenter.AssociationByManual AS asMa 
		WHERE	asMa.ToCTSCustID =  lv_CTSCustID;
        
    END IF;

    # ip_AssociationType: 0 - ALL, 1 - Device, 2 - AI, 3 - Manual, 4 - IP
    IF ip_AssociationType = 0 OR ip_AssociationType = 2 THEN
		#==================GET association from AssociationByAI===============================================
		INSERT IGNORE INTO Temp_CustAssociation(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT 
				cust.CTSCustID 
			,	2 AS AssociationType
            ,	1 AS AssociationStatus
			,	asAI.CreatedDate
		FROM CTS_DataCenter.AssociationByAI AS asAI 
			INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID  = asAI.ToCustID AND cust.CustSubID = 0
		WHERE	asAI.FromCustID =  ip_CustID
			AND asAI.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt);
        
        INSERT IGNORE INTO Temp_CustAssociation(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT 
				cust.CTSCustID 
			,	2 AS AssociationType
            ,	1 AS AssociationStatus
			,	asAI.CreatedDate
		FROM CTS_DataCenter.AssociationByAI AS asAI 
			INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID  = asAI.FromCustID AND cust.CustSubID = 0
		WHERE	asAI.ToCustID =  ip_CustID
			AND asAI.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByAI_AssType AS tmpAt);
        
        #==================GET association from AssociationGroupByAI===============================================
        INSERT IGNORE INTO Temp_AssGroupByAI(GroupID, CreatedDate)
        SELECT	asg.GroupID 
			,	asg.CreatedDate
        FROM	CTS_DataCenter.AssociationGroupByAI AS asg
        WHERE	asg.CustID = ip_CustID;
        
        INSERT IGNORE INTO Temp_CustAssociation (CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
        SELECT	cus.CTSCustID
			,	2 AS AssociationType
            ,	1 AS AssociationStatus
            ,	asg.CreatedDate AS AssociationDate
        FROM	CTS_DataCenter.AssociationGroupByAI AS asg
			INNER JOIN Temp_AssGroupByAI AS tmpAg ON asg.GroupID = tmpAg.GroupID AND asg.CustID <> ip_CustID
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID  = asg.CustID AND cus.CustSubID = 0;            
    END IF;
    
	IF ip_AssociationType = 0 OR ip_AssociationType = 4 THEN
   
		INSERT IGNORE INTO Temp_CustAssociation(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT 
				cust.CTSCustID 
			,	4 AS AssociationType
            ,	1 AS AssociationStatus
			,	asIP.CreatedDate
		FROM CTS_DataCenter.AssociationByIP AS asIP 
			INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID  = asIP.ToCustID AND cust.CustSubID = 0
		WHERE	asIP.FromCustID =  ip_CustID
			AND asIP.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt);
        
        INSERT IGNORE INTO Temp_CustAssociation(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
		SELECT 
				cust.CTSCustID 
			,	4 AS AssociationType
            ,	1 AS AssociationStatus
			,	asIP.CreatedDate
		FROM CTS_DataCenter.AssociationByIP AS asIP 
			INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID  = asIP.FromCustID AND cust.CustSubID = 0
		WHERE	asIP.ToCustID =  ip_CustID
			AND asIP.AssType IN (SELECT tmpAt.AssTypeItemValue FROM Temp_AssociationByIP_AssType AS tmpAt);
    END IF;
    

    #ip_AssociationStatus: 0 - All, 1 - Linked, 2 - UnLinked

	INSERT IGNORE INTO Temp_CustAssociationUnlinked (CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
	WITH CTE_AssociationRemove AS (
		SELECT asRe.ToCTSCustID AS CTSCustID_Aff
			,  asRe.CreatedDate
		FROM CTS_DataCenter.AssociationRemove AS asRe 
		WHERE asRe.FromCTSCustID = lv_CTSCustID
	)
	SELECT 	cte.CTSCustID_Aff
		,	tmp.AssociationType
		,	2 AS AssociationStatus
		,	cte.CreatedDate
	FROM CTE_AssociationRemove AS cte
	INNER JOIN Temp_CustAssociation AS tmp ON cte.CTSCustID_Aff = tmp.CTSCustID_Aff;        
        
	INSERT IGNORE INTO Temp_CustAssociationUnlinked (CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
	WITH CTE_AssociationRemove AS (
		SELECT asRe.FromCTSCustID AS CTSCustID_Aff
			,  asRe.CreatedDate
		FROM CTS_DataCenter.AssociationRemove AS asRe 
		WHERE asRe.ToCTSCustID = lv_CTSCustID
	)
	SELECT 	cte.CTSCustID_Aff
		,	tmp.AssociationType
		,	2 AS AssociationStatus
		,	cte.CreatedDate
	FROM CTE_AssociationRemove AS cte
	INNER JOIN Temp_CustAssociation AS tmp ON cte.CTSCustID_Aff = tmp.CTSCustID_Aff;
        
	DELETE cuAs 
	FROM Temp_CustAssociation AS cuAs 
	WHERE cuAs.CTSCustID_Aff IN (SELECT CTSCustID_Aff FROM Temp_CustAssociationUnlinked);
       
	INSERT IGNORE INTO Temp_CustAssociation(CTSCustID_Aff, AssociationType, AssociationStatus, AssociationDate)
	SELECT CTSCustID_Aff
		,	AssociationType
		,	AssociationStatus
		,	AssociationDate
	FROM Temp_CustAssociationUnlinked;

     IF ip_AssociationStatus = 2 THEN
		DELETE 
        FROM Temp_CustAssociation 
        WHERE Temp_CustAssociation.AssociationStatus != 2;
     END IF;
     
     IF ip_AssociationStatus = 1 THEN
		DELETE cuAs
        FROM Temp_CustAssociation  AS cuAs
            INNER JOIN Temp_CustAssociationUnlinked AS un ON un.CTSCustID_Aff = cuAs.CTSCustID_Aff AND un.AssociationStatus = cuAs.AssociationStatus;
     END IF;     

     INSERT IGNORE INTO Temp_Accounts(CTSCustID, CustId, CustSubID, AssociationType, AssociationDate)
     SELECT cust.CTSCustID
		,	cust.CustId
        ,	cust.CustSubID
        ,	cuAs.AssociationType
        ,	cuAs.AssociationDate
     FROM Temp_CustAssociation AS cuAs
        INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cuAs.CTSCustID_Aff = cust.CTSCustID
     ON DUPLICATE KEY UPDATE AssociationDate = LEAST(Temp_Accounts.AssociationDate, cuAs.AssociationDate) ;

     SELECT CTSCustID
		,	CustId 				
        ,	CustSubID 			AS 'CustSubId'
        ,	AssociationDate
    FROM Temp_Accounts;
END$$

DELIMITER ;