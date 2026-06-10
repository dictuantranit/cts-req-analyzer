DELIMITER $$
DROP PROCEDURE IF EXISTS CTS_Adhoc.CTMAX_GetWrongMappingSub$$
CREATE PROCEDURE CTS_Adhoc.CTMAX_GetWrongMappingSub()
BEGIN
	/*
		Created:	20200527@CaseyHuynh 
		Param's Explanation (filtered by):                
	*/
     DECLARE FromCTSCustID BIGINT;
    DECLARE toCTSCustID BIGINT;
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    
    
    WHILE EXISTS (SELECT 1 FROM CTS_Adhoc.csCTMax_CustDCSAccount_bk AS map WHERE map.IssueType IS NULL LIMIT 1)
    DO
		
	  ( SELECT  MIN(a.CTSCustID) ,MAX(a.CTSCustID) 
		INTO 	FromCTSCustID, toCTSCustID
		FROM 	(	SELECT 		CTSCustID 
					FROM 		CTS_Adhoc.csCTMax_CustDCSAccount_bk AS map 
					WHERE	 	map.IssueType IS NULL 
					ORDER BY 	CTSCustID
					LIMIT 1000 	) AS a);
        
        UPDATE 		CTS_Adhoc.csCTMax_CustDCSAccount_bk AS map
		LEFT JOIN	CTS_DataCenter.CTSCustomer AS cus
					ON map.CTSCustID = cus.CTSCustID
		SET 		map.cusSubscriberID = cus.SubscriberID
					, map.IssueType = (CASE WHEN map.SubscriberID != cus.SubscriberID THEN 1 											
										ELSE 0 END)
		WHERE 		map.CTSCustID BETWEEN FromCTSCustID AND ToCTSCustID;  
    END WHILE;
    
END$$
DELIMITER ;