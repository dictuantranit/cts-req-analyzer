/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_CustEvidence_GetFlaggedEvidences`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustEvidence_GetFlaggedEvidences`(
		IN ip_CTSCustID BIGINT
	,   IN ip_EvidenceCodes TEXT	
)
    SQL SECURITY INVOKER
BEGIN

	/*
		Created:	20200123@Thai
		Task:		Get flagged evidences by CustID and evidence codes [Redmine ID: 127150]
		DB:			CTS_DataCenter
		Original:

		Revisions:
           - 20200123@Thai.Tran [Redmine ID: #127150]: Created
		   - 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
		   - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
		   
		Param's Explanation (filtered by):			
        
		Example:
			- CALL CTS_DC_GetFlaggedEvidence (11113, '1.2,6.1,6.2')
	*/
            
	DECLARE lv_a INT Default 0 ;
	DECLARE lv_str VARCHAR(255);
   	    
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
 
	SELECT  e.EvidenceID
		,	e.EvidenceCode           
		,	e.EvidenceName
		,	e.EvidenceDesc           		   
		,	ce.CreatedDate
		,	ce.Level		   
		,	ce.Remark
		,	user.UserName AS Creator
    FROM Evidence AS e 	
		INNER JOIN CustEvidence AS ce   ON e.EvidenceID = ce.EvidenceID	
		INNER JOIN CTS_Admin.CTSUser AS user ON user.UserID = ce.CreatedBy
		INNER JOIN Temp_EvidenceCode AS codes ON codes.EviCode = e.EvidenceCode      
	WHERE e.IsActive = True
		  AND ce.Level = 0
		  AND ce.CTSCustID = ip_CTSCustID;          
 
END$$

DELIMITER ;