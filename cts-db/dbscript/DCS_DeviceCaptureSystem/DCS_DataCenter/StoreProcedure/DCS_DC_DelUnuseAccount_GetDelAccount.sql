/*<info serverAlias="CTSMain-Adhoc" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_AD_DeleteDataByUnusedAccount_GetAccount`;

DELIMITER $$
CREATE DEFINER=`casey.vn`@`%` PROCEDURE `CTS_AD_DeleteDataByUnusedAccount_GetAccount`(
		IN ip_Size INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210330@Casey.Huynh
		Task:		GET Account Has IsCTSTransformed < 0 and LastLogtin < (90days)
		DB:			DCS_DataCenter
		Original:

		Revisions:
			- 20210330@Casey.Huynh [Redmine ID: #152454]
		Param's Explanation (filtered by):
	*/ 
	
    DECLARE	lv_FromAccountID	BIGINT UNSIGNED; # The Last AccountID
    DECLARE	lv_ToAccountID		BIGINT UNSIGNED;
    DECLARE	lv_MaxAccountID		BIGINT UNSIGNED;
    DECLARE	lv_StartTime		DATETIME(3);
   
	SET lv_FromAccountID= 1;
    SELECT 	IFNULL(AccountID,0)
    INTO	lv_FromAccountID
    FROM	CTS_Adhoc.CS152454_DelByUnusedAcc_01Account AS dc
    ORDER BY AccountID DESC 
    LIMIT 1;    
	
    
    SET @lv_152454ToAccountID = 0;

    SET lv_MaxAccountID = 27572620;# (SELECT AccountID FROM DCS_DataCenter.Account WHERE CreatedDate >= '2021-01-01' AND AccountID > 27500000  LIMIT 1);
	SELECT @lv_152454ToAccountID,lv_FromAccountID;
    WHILE (lv_FromAccountID != @lv_152454ToAccountID  )
    DO	
		SET lv_StartTime = NOW();
		SET lv_FromAccountID = @lv_152454ToAccountID;
        INSERT INTO CTS_Adhoc.CS152454_DelByUnusedAcc_01Account(AccountID, LoginName, SubscriberID, SubscriberType, CreatedTime, LastLoginTime, CreatedDate, InsertTime, IsCTSTransformed)
        SELECT	@lv_152454ToAccountID := AccountID
			,	LoginName
            ,	SubscriberID
            ,	SubscriberType
            ,	CreatedTime
            ,	LastLoginTime
            ,	CreatedDate
            ,	InsertTime
            ,	IsCTSTransformed
        FROM	DCS_DataCenter.Account AS acc
        WHERE	IsCTSTransformed < 0 
				AND AccountID > lv_FromAccountID
                AND AccountID < lv_MaxAccountID
                AND LastLoginTime < '2021-01-01'
        LIMIT	ip_Size;
        
        DO SLEEP(0.2);       
		INSERT INTO CS152454_DelByUnusedAcc_zzTrace(Steps,StartTime,EndTime,Notes)
        values(1,lv_StartTime,NOW(), FOUND_ROWS());
    END WHILE;
	SELECT @lv_152454ToAccountID;
END$$

DELIMITER ;


