/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_Account_GetPackage`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_Account_GetPackage`(
		IN ip_NoOfAccount	INT
	,	IN ip_NoOfBatch		INT
)
SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20190730@Casey.Huynh
	    Task : Get DeviceID NULL From Table Transaction
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20191217@CaseyHuynh: Implement LastLoginTime [RedmineID: #125530]
		    - 20200512@CaseyHuynh: Add Nolock Statement
            - 20201112@CaseyHuynh: GET Lastest Code Move Server P3, update Permission and Add Meta data. Enhance  script [RedmineID: #145271]
            - 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]

	    Param's Explanation (filtered by):
	*/
	
    DECLARE lv_TotalRecord		INT UNSIGNED DEFAULT 0;
    
    SET @RowID = 1;
    SET @MaxAccountID = 0;
	 
	SELECT IFNULL(MIN(AccountID),0)
	INTO @MinAccountID 
	FROM DCS_DataCenter.Account AS ac 
	WHERE ac.IsCTSTransformed = 0;
    
	SET lv_TotalRecord = ip_NoOfAccount*ip_NoOfBatch;  
	SELECT	CEIL(@RowID/ip_NoOfAccount) AS BatchID
		,	ac.AccountID
		,	ac.LoginName
		,	ac.SubscriberID
		,	ac.LastLoginTime
		,	@RowID := @RowID + 1
		,	@MaxAccountID := GREATEST(@MinAccountID,AccountID)
	FROM 	DCS_DataCenter.Account AS ac
	WHERE	ac.IsCTSTransformed = 0
	LIMIT	lv_TotalRecord;
    
	
END$$
DELIMITER ;
