/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_Association_GetPackage`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_Association_GetPackage`(
        IN ip_NoOfAssociation INT
    ,   IN ip_NoOfBatch INT
)
SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20190730@Casey.Huynh
	    Task : Get DeviceID NULL From Table Transaction
	    DB: DCS_DataCenter
	    Original:

	    Revisions:
		    - 20201112@CaseyHuynh: GET Lastest Code Move Server P3, update Permission and Add Meta data. Enhance  script1 [RedmineID: #145271]
            - 20201201@CaseyHuynh: Get Association if it completed Trasformed Account (Account.IsCTSTransformed !=0)
            - 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]
            - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]

	    Param's Explanation (filtered by):
	*/
	
	DECLARE	lv_TotalRecord		INT UNSIGNED DEFAULT 0;

	SET lv_TotalRecord = ip_NoOfAssociation*ip_NoOfBatch;
    
    SET @RowID = 1;
    SET @MaxAssociationID = 0;

	SELECT IFNULL(MAX(AssociationID),0) 
	INTO @MinAssociationID
	FROM DCS_DataCenter.Association AS ac 
	WHERE IsCTSTransformed = 0;
    
	SET lv_TotalRecord = ip_NoOfAssociation*ip_NoOfBatch;  
	SELECT	CEIL(@RowID/ip_NoOfAssociation) AS BatchID
		,	ass.AssociationID
		,	ass.AccountID
		,	ass.DeviceID
		,	ass.CreatedTime
		,	ass.SubscriberID
		,	@RowID := @RowID+1
		,	@MaxAssociationID := GREATEST(@MaxAssociationID,ass.AssociationID)
	FROM 	DCS_DataCenter.Association AS ass
		INNER JOIN	DCS_DataCenter.Account AS acc ON ass.AccountID = acc.AccountID
	WHERE	ass.IsCTSTransformed = 0
		AND acc.IsCTSTransformed != 0
	LIMIT	lv_TotalRecord;    
      
END$$
DELIMITER ;
