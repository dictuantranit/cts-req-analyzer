/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_CustEvidence_GetAffectedEvidences`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_GetAffectedEvidences`(
        IN ip_CTSCustID     BIGINT UNSIGNED
    ,   IN ip_EvidenceCodes TEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200123@Thai
		Task:		Get evidences which the member is affected and evidences which the member is retracted [Redmine ID: 127150]
		DB:			CTS_DataCenter
		Original:

		Revisions:
             - 20200123@Thai.Tran [Redmine ID: #127150]: Created
			 - 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
             - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
			 
		Param's Explanation (filtered by):			
        
        Example:
            - CALL CTS_DC_GetAffectedEvidence (10515, '6.9') 
	*/        
           
	DECLARE lv_a    INT Default 0 ;
	DECLARE lv_str  VARCHAR(255);
   	    
    /* Get evidence codes to table  */
    DROP TEMPORARY TABLE IF EXISTS Temp_EvidenceCode;
    CREATE TEMPORARY TABLE Temp_EvidenceCode(
		EviCode VARCHAR(10) PRIMARY KEY    
	);
    
    IF ip_EvidenceCodes IS NOT NULL THEN
		Evidence_loop: LOOP
			 SET lv_a = lv_a + 1;
			 SET lv_str = SPLIT_STR(ip_EvidenceCodes,",",lv_a);
			 IF lv_str = '' THEN
				LEAVE Evidence_loop;
			 END IF;         
			 INSERT INTO Temp_EvidenceCode VALUES (lv_str);
		END LOOP Evidence_loop;
    END IF;    
    
    DROP TEMPORARY TABLE IF EXISTS Temp_AffectedEvidence;
    CREATE TEMPORARY TABLE Temp_AffectedEvidence(
            CustEvidID      BIGINT
        ,   CTSCustID       BIGINT
        ,   FromCTSCustID   BIGINT
		,   EvidenceID      SMALLINT
        ,   EvidenceCode    VARCHAR(10)
        ,   EvidenceName    VARCHAR(50)       
        ,   CreatedDate     DATETIME
	);
    
    #=====GET AFFECTED EVIDENCES FOR MEMBER==========================
    
    INSERT INTO Temp_AffectedEvidence (EvidenceID, CTSCustID, FromCTSCustID, EvidenceCode, EvidenceName, CreatedDate)
	SELECT  e.EvidenceID
	    ,   ce.CTSCustID
        ,   ce.FromCustID
	    ,   e.EvidenceCode           
	    ,   e.EvidenceName					              
        ,   ce.CreatedDate		
    FROM CustEvidence AS ce 	
	    INNER JOIN Evidence AS e ON ce.EvidenceID = e.EvidenceID		
        INNER JOIN Temp_EvidenceCode AS codes ON codes.EviCode = e.EvidenceCode          
	WHERE e.IsActive = True
		  AND ce.Level = 2
		  AND ce.CTSCustID = ip_CTSCustID
          AND ce.EvidenceID NOT IN (SELECT cre.EvidenceID
									FROM CustRetractEvidence AS cre
									WHERE cre.CTSCustID = ce.CTSCustID);
                                                                 
	#=====DISPLAY EVIDENCES CREATED BY==========================
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Evidence;
    CREATE TEMPORARY TABLE Temp_Evidence( 
		    CTSCustID           BIGINT
		,   EvidenceID          SMALLINT
        ,   EvidenceCode        VARCHAR(10)        
        ,   EvidenceName        VARCHAR(50)
        ,   LoginID             VARCHAR(50)
        ,   UserName            VARCHAR(50)
        ,   AssociationType     VARCHAR(50)
        ,   LastLoginTime       DATETIME
        ,   CreatedDate         DATETIME
        ,   RowNumber           SMALLINT
	);
    
    INSERT Temp_Evidence(CTSCustID, EvidenceID, EvidenceCode, EvidenceName, LoginID, UserName, AssociationType, LastLoginTime, CreatedDate, RowNumber)
    SELECT  e.FromCTSCustID
	    ,   e.EvidenceID 
	    ,   e.EvidenceCode
        ,   e.EvidenceName
        ,   cust.UserName2
        ,   cust.UserName
        ,   'Device'
	    ,   cust.LastLoginTime
        ,   e.CreatedDate
        ,   ROW_NUMBER() OVER (PARTITION BY e.EvidenceID ORDER BY cust.LastLoginTime DESC) AS RowNumber
    FROM Temp_AffectedEvidence AS e	 
	    INNER JOIN CTSCustomer AS cust ON cust.CTSCustID = e.FromCTSCustID;	
    
    
	SELECT  CTSCustID
		,   EvidenceID    
		,   EvidenceCode
		,   EvidenceName
		,   LoginID
		,   UserName
		,   AssociationType
		,   LastLoginTime
		,   CreatedDate              
    FROM Temp_Evidence 
    WHERE RowNumber <= 50;	        
          
    #=====GET RETRACTED EVIDENCES FOR MEMBER==========================
    SELECT  e.EvidenceID
	    ,   e.EvidenceCode           
	    ,   e.EvidenceName
	    ,   e.EvidenceDesc
	    ,   cust.CTSCustID		   
        ,   cust.UserName2 As LoginID
	    ,   cust.UserName
	    ,   'Device' AS AssociationType
        ,   cre.Remark
        ,   cre.CreatedDate
        ,   user.UserName AS Creator
        ,   cust.LastLoginTime					
    FROM Evidence AS e 	
	    INNER JOIN CustRetractEvidence AS cre ON e.EvidenceID = cre.EvidenceID
	    INNER JOIN CTSCustomer AS cust ON cust.CTSCustID = cre.CTSCustID
        INNER JOIN Temp_EvidenceCode AS codes ON codes.EviCode = e.EvidenceCode          
	    INNER JOIN CTS_Admin.CTSUser AS user ON user.UserID = cre.CreatedBy
	WHERE   e.IsActive = True		  
	    AND cre.CTSCustID = ip_CTSCustID;
    	
END$$

DELIMITER ;