
DROP PROCEDURE IF EXISTS `SPU_AIML_OTGB_GetCouple_FraudDetails`;

DELIMITER $$
CREATE DEFINER=`AIMLOwner`@`%` PROCEDURE `SPU_AIML_OTGB_GetCouple_FraudDetails`(
		IN 	ip_FraudType	TINYINT
	,	IN 	ip_CustID1		BIGINT UNSIGNED
	,	IN 	ip_CustID2		BIGINT UNSIGNED
    
)
    SQL SECURITY INVOKER
sp:BEGIN  
	/*  
		Created:	20220313@Casey.Huynh
		Task:		GET OTGB Fraud Detail by Couple
		DB:			CTS_DataCenter
        
		Revisions:
			- 20230313@Casey.Huynh:	Applied Betting Parten OTGB [Redmine ID: #184791]

		Param's Explanation (filtered by): 
			- ip_FraudType: 0: Return Exists any Scrore Type , 1:ScoreRound1, 2:ScoreRound2, 3:ScoreRound3
        Example:
			CALL SPU_AIML_OTGB_GetCouple_FraudDetails;
	*/   
    DECLARE lv_LeastCust BIGINT;
	DECLARE lv_GreatestCust BIGINT;    

    
    SET lv_LeastCust = LEAST(ip_CustID1,ip_CustID2);
    SET lv_GreatestCust = GREATEST(ip_CustID1,ip_CustID2);
    
    # REUTURN  ScoreRound IS EXISTING
	IF (ip_FraudType = 0) THEN
		
        SELECT 1 AS 'ScoreRound1'
        FROM SPU_AIML.GB_CoupleInfo AS ci
        WHERE ci.CustID1 = lv_LeastCust AND ci.CustID2 = lv_GreatestCust AND ci.ScoreRound1 > 0
        LIMIT 1;
        
        SELECT 1 AS 'ScoreRound2'
        FROM SPU_AIML.GB_CoupleInfo AS ci
        WHERE ci.CustID1 = lv_LeastCust AND ci.CustID2 = lv_GreatestCust AND ci.ScoreRound2 > 0
        LIMIT 1;
        
        SELECT 1 AS 'ScoreRound3'
        FROM SPU_AIML.GB_CoupleInfo AS ci
        WHERE ci.CustID1 = lv_LeastCust AND ci.CustID2 = lv_GreatestCust AND ci.ScoreRound3 > 0
        LIMIT 1;
        
    END IF;
    
    # REUTURN Fraud Round 1
	IF (ip_FraudType = 1) THEN
		SELECT DISTINCT js.TransID
				,	cf.MatchID
				,	1 AS Round
		FROM SPU_AIML.GB_CoupleInfo AS ci
			INNER JOIN SPU_AIML.GB_CoupleFraudInfo AS cf ON ci.CoupleID = cf.CoupleID AND ci.ScannedDate = cf.ScannedDate AND cf.IsSuspicious = 1
			JOIN JSON_TABLE(REPLACE(JSON_ARRAY(cf.TransList), ',', '","'), 
							'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
							) js
		WHERE ci.CustID1 = lv_LeastCust AND ci.CustID2 = lv_GreatestCust AND ci.ScoreRound1 > 0;
	END IF;
    
    # REUTURN Fraud Round 2
    IF (ip_FraudType = 2) THEN
		SELECT DISTINCT js.TransID
				,	cf.MatchID
				, 	2 AS Round
		FROM SPU_AIML.GB_CoupleInfo AS ci
			INNER JOIN SPU_AIML.GB_CoupleFraudInfo AS cf ON ci.CoupleID = cf.CoupleID AND ci.ScannedDate = cf.ScannedDate AND cf.IsSuspicious = 1
			JOIN JSON_TABLE(REPLACE(JSON_ARRAY(cf.TransList), ',', '","'), 
							'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
							) js
		WHERE ci.CustID1 = lv_LeastCust AND ci.CustID2 = lv_GreatestCust AND ci.ScoreRound2 > 0;
    END IF;
    
	# REUTURN Fraud Round 3
    IF (ip_FraudType = 3) THEN
		SELECT DISTINCT js.TransID
				,	cf.MatchID
				,	3 AS Round
		FROM SPU_AIML.GB_CoupleInfo AS ci
			INNER JOIN SPU_AIML.GB_CoupleFraudInfo AS cf ON ci.CoupleID = cf.CoupleID AND ci.ScannedDate = cf.ScannedDate AND cf.IsSuspicious = 1
			JOIN JSON_TABLE(REPLACE(JSON_ARRAY(cf.TransList), ',', '","'), 
							'$[*]' COLUMNS (TransID BIGINT UNSIGNED PATH '$')
							) js
		WHERE ci.CustID1 = lv_LeastCust AND ci.CustID2 = lv_GreatestCust AND ci.ScoreRound3 > 0;
	END IF;
END$$

DELIMITER ;
