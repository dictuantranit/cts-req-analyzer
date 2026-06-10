/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Customer_DangerousScore_Insert`;
DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Customer_DangerousScore_Insert`(
		IN  ip_IsLicensee		TINYINT(1)
	,	IN 	ip_CustInfo 		JSON
  
)
SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20230515@Victoria.le
		Task:	 	Customer DangerousScore - Insert data after getting from AI
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20230515@Victoria.le:		Initial Writing [Redmine ID: #186191]
                - 20240315@Casey.Huynh: 	Classify Danger Score [Redmine ID: #201358]
                - 20240521@Victoria.Le: 	Classify Danger Score - Deposit [Redmine ID: #205166]

		Example:
			CALL CTS_DC_Customer_DangerousScore_Insert (@ip_IsLicensee:= 0,@ip_CustInfo:='[{"CustID":1275,"DangerousScore":0.2},{"CustID":1277,"DangerousScore":0.45},{"CustID":1280,"DangerousScore":0.95},{"CustID":1282,"DangerousScore":0.96}]');
			CALL CTS_DC_Customer_DangerousScore_Insert (ip_IsLicensee:= 0,@ip_CustInfo:='[{"CustID":1,"DangerousScore":0.55},{"CustID":2,"DangerousScore":0.45},{"CustID":3,"DangerousScore":0.98},{"CustID":4,"DangerousScore":0.94}]');
			CALL CTS_DC_Customer_DangerousScore_Insert (@ip_IsLicensee:= 1,@ip_CustInfo:='[{"CustID":11,"DangerousScore":0.45},{"CustID":12,"DangerousScore":0.44},"CustID":13,"DangerousScore":0.50},{"CustID":14,"DangerousScore":0.5}]');
	*/
	DECLARE lv_CreatedDate DATETIME(3);
	DECLARE lv_RuleCreditMinScore DECIMAL(8,4);
    DECLARE lv_RuleCreditMaxScore DECIMAL(8,4);
	
	DECLARE lv_RuleDepositMinScore DECIMAL(8,4);
    
    #====================================================
	SET lv_CreatedDate = CURRENT_TIMESTAMP();
    
    SELECT ItemValue
    INTO lv_RuleCreditMinScore
    FROM CTS_DataCenter.StaticList
    WHERE ListID = 22 AND ItemID = 1;
    
    SELECT ItemValue
    INTO lv_RuleCreditMaxScore
    FROM CTS_DataCenter.StaticList
    WHERE  ListID = 22 AND ItemID = 2;
	
	SELECT ItemValue
    INTO lv_RuleDepositMinScore
    FROM CTS_DataCenter.StaticList
    WHERE  ListID = 22 AND ItemID = 3;

    INSERT INTO CTS_DataCenter.Customer_DangerousScore 
    (
			CustID
		,	IsLicensee
		,	DangerousScore
		,	CreatedDate		
		,	LastModifiedDate
        ,	ClassifiedScore
        ,	ClassifiedDate
    )
    SELECT 	js.CustID		
		,	ip_IsLicensee	
		,	js.DangerousScore		
		,	lv_CreatedDate
		,	lv_CreatedDate
        ,	(CASE WHEN ip_IsLicensee = 0 AND js.DangerousScore BETWEEN lv_RuleCreditMinScore AND lv_RuleCreditMaxScore THEN js.DangerousScore 
				  WHEN ip_IsLicensee = 1 AND js.DangerousScore >= lv_RuleDepositMinScore THEN js.DangerousScore 
				  ELSE NULL 
			 END) AS ClassifiedScore
        ,	(CASE WHEN ip_IsLicensee = 0 AND js.DangerousScore BETWEEN lv_RuleCreditMinScore AND lv_RuleCreditMaxScore THEN lv_CreatedDate 
				  WHEN ip_IsLicensee = 1 AND js.DangerousScore >= lv_RuleDepositMinScore THEN lv_CreatedDate
				  ELSE NULL 
			 END) AS ClassifiedDate
	FROM JSON_TABLE(ip_CustInfo,
					"$[*]" COLUMNS( 	CustID				INT 			PATH "$.CustID"
									,	DangerousScore		DECIMAL(8,4)	PATH "$.DangerousScore"
					)) AS js
	ON DUPLICATE KEY UPDATE DangerousScore 		= js.DangerousScore
						,	LastModifiedDate 	= lv_CreatedDate
						,	ClassifiedScore = (CASE WHEN ClassifiedScore IS NULL AND ip_IsLicensee = 0 AND js.DangerousScore BETWEEN lv_RuleCreditMinScore AND lv_RuleCreditMaxScore THEN js.DangerousScore 
													WHEN ClassifiedScore IS NULL AND ip_IsLicensee = 1 AND js.DangerousScore >= lv_RuleDepositMinScore THEN js.DangerousScore 
													ELSE ClassifiedScore END)
                        ,	ClassifiedDate = (CASE WHEN ClassifiedDate IS NULL AND ip_IsLicensee = 0 AND js.DangerousScore BETWEEN lv_RuleCreditMinScore AND lv_RuleCreditMaxScore THEN lv_CreatedDate 
												   WHEN ClassifiedDate IS NULL AND ip_IsLicensee = 1 AND js.DangerousScore >= lv_RuleDepositMinScore THEN lv_CreatedDate
												   ELSE ClassifiedDate END)
	;
	
END$$
DELIMITER ;