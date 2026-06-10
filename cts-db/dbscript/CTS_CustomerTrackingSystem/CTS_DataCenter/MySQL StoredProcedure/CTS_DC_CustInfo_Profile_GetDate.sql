/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_Profile_GetDate`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_Profile_GetDate`(
		IN ip_CTSCustID BIGINT UNSIGNED 
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20211214@Aries.Nguyen	
		Task :		Enrich the information on customer profile
		DB:			CTS_DataCenter
		
		Revisions:
			- 20211214@Aries.Nguyen: Created [Redmine ID: #165105]
			- 20220407@Irena.Vo: Get additional date for New Member(no bet in 30 last days), PA, Robot [Redmine ID: #170468]
			- 20220603@Long.Luu: Merge Robot AI & Robot TW [Redmine ID: #172561]
			- 20240425@Thomas.Nguyen: Classify Initial Group Betting - Add SportGroupID = 150 [Redmine ID: #200854]
			- 20240628@Thomas.Nguyen: Renovate CC phase 2 - Remove hardcode SportGroupID, CategoryGroup and get next scan for robot user [Redmine ID: #205317]
			- 20250922@Thomas.Nguyen: Get more MB Account Last Login Time [Redmine ID: #239121]

		Param's Explanation (filtered by):
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustInfo_Profile_GetDate(200);
	*/
	DECLARE	CONST_PARENTID_PA 					INT;
	DECLARE	CONST_PARENTID_POTENTIALPA 			INT;
	DECLARE	CONST_PARENTID_NORMAL 				INT;

    DECLARE	CONST_CATEGROUPID_PROBATION 		INT;
    DECLARE	CONST_CATEGROUPID_NEW 				INT;
    
	DECLARE lv_NextCategoryScan					DATE;
    DECLARE lv_LastTicket 						DATETIME;
    DECLARE lv_LastLogin 						DATETIME;
    DECLARE lv_Created							DATETIME;
    DECLARE lv_LastLogin_MB						DATETIME;
    
    DECLARE lv_ScanScheduler					DATETIME DEFAULT CAST(CONCAT(DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) , ' ', '21:00:00') as DATETIME);
	
	SET CONST_PARENTID_PA 				    = CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_PA');
    SET CONST_PARENTID_POTENTIALPA 			= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_POTENTIALPA');
	SET CONST_PARENTID_NORMAL 				= CTS_DC_CategoryTypeParent_Get ('CONST_PARENTID_NORMAL');
	SET CONST_CATEGROUPID_NEW 				= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_NEW');
	SET CONST_CATEGROUPID_PROBATION 		= CTS_DC_CategoryTypeParent_Get ('CONST_CATEGROUPID_PROBATION');

	SELECT 	LastLoginTime
		, 	CreatedDate 
	INTO 	lv_LastLogin
		, 	lv_Created
	FROM CTS_DataCenter.CTSCustomer 
	WHERE CTSCustID = ip_CTSCustID;
    
	CALL CTS_DataCenter.CTSDCS_DC_CustInfo_AccountCustMapping(ip_CTSCustID);

	SELECT MAX(tmp.LastLoginTime)
	INTO lv_LastLogin_MB
	FROM Temp_CustDCSMBAccount AS tmp;

    SELECT LastTicketDate 
    INTO lv_LastTicket
	FROM CTS_Archive.CTSCustomerAssociationStatus 
	WHERE CTSCustID = ip_CTSCustID;

    /* PA Category */
    SELECT CASE WHEN CURRENT_TIMESTAMP() > lv_ScanScheduler THEN DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY) 
				ELSE CURRENT_DATE() 
			END
    INTO lv_NextCategoryScan
    FROM CTS_DataCenter.CTSCustomerClassification AS clss
		INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID =  clss.CategoryID
    WHERE clss.CTSCustID = ip_CTSCustID
			AND clss.ParentID IN (CONST_PARENTID_PA , CONST_PARENTID_POTENTIALPA)
    LIMIT 1;
    
    /* Normal Category */
    IF (lv_NextCategoryScan IS NULL) THEN
		 SELECT CASE WHEN cate.CategoryGroupID = CONST_CATEGROUPID_NEW AND lv_LastTicket <= DATE_SUB(CURRENT_DATE(), INTERVAL 29 DAY) AND CURRENT_TIMESTAMP() > lv_ScanScheduler THEN DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY)
					 WHEN cate.CategoryGroupID = CONST_CATEGROUPID_NEW AND lv_LastTicket <= DATE_SUB(CURRENT_DATE(), INTERVAL 29 DAY) AND CURRENT_TIMESTAMP() <= lv_ScanScheduler THEN CURRENT_DATE()
                     WHEN cate.CategoryGroupID = CONST_CATEGROUPID_PROBATION AND clss.CreatedDate < DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY) THEN DATE(CURRENT_DATE())
					 WHEN cate.CategoryGroupID = CONST_CATEGROUPID_PROBATION AND clss.CreatedDate >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY) THEN DATE(DATE_ADD(clss.CreatedDate, INTERVAL 3 DAY))
					 WHEN cate.ScanIntervalInSecond > 0 THEN DATE_ADD(clss.LastScannedDate, INTERVAL cate.ScanIntervalInSecond SECOND)
				 END 
		INTO lv_NextCategoryScan
		FROM CTS_DataCenter.CTSCustomerClassification AS clss
			INNER JOIN CTS_DataCenter.CustomerCategory AS cate ON cate.CategoryID =  clss.CategoryID
		WHERE clss.CTSCustID = ip_CTSCustID
			AND clss.ParentID = CONST_PARENTID_NORMAL;
    END IF;
    
    SELECT 	lv_NextCategoryScan AS NextCategoryScan
		,	lv_LastTicket		AS LastTicket
		,	GREATEST(IFNULL(lv_LastLogin, lv_LastLogin_MB), IFNULL(lv_LastLogin_MB, lv_LastLogin)) AS LastLogin
		,	lv_Created 			AS Created;
END$$
DELIMITER ;