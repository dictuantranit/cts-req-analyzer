/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_NotifyMessage_InsertMonitorTransaction`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_NotifyMessage_InsertMonitorTransaction`(
		IN ip_RptDate 			DATE
	,	IN ip_NotifyType		VARCHAR(100)
	,	IN ip_GroupId			VARCHAR(100)
	,	IN ip_LimitShowCust		INT
    
	,	OUT op_NotifyMessageID 	INT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20230615@Jonathan.Doan
	    Task : Store data Monitor Transaction
	    DB: DCS_DataCenter
	    Original:

	    Revisions:		    
			-	20230615@Jonathan.Doan: Created [Redmine ID: 189732]
            
	    Param's Explanation (filtered by):
        
        Example: CALL DCS_DC_NotifyMessage_InsertMonitorTransaction('2023-04-01', 'MonitorTransaction', 3);
    */    
    DECLARE lv_Title VARCHAR(1000);
    DECLARE lv_Message LONGTEXT;
    DECLARE lv_CountResult INT UNSIGNED;
    DECLARE lv_ListUserName VARCHAR(2000);
    DECLARE lv_CurDate DATETIME DEFAULT CURRENT_TIMESTAMP();
    
    DROP TEMPORARY TABLE IF EXISTS Temp_MonitorTransaction;
    CREATE TEMPORARY TABLE Temp_MonitorTransaction(
			CustID		 	INT UNSIGNED PRIMARY KEY 
        ,	UserName		VARCHAR(50) NULL
    );
    
    INSERT INTO Temp_MonitorTransaction(CustID, UserName)
    SELECT	CustID
		,	UserName
	FROM DCS_DataCenter.MonitorTransaction
	WHERE LastScanDate = ip_RptDate;
    
    SELECT COUNT(CustID)
    INTO lv_CountResult
    FROM Temp_MonitorTransaction;
    
    WITH cte_GroupUserName AS (
		SELECT UserName
		FROM Temp_MonitorTransaction
        ORDER BY CustID ASC
		LIMIT ip_LimitShowCust
    )
	SELECT GROUP_CONCAT(UserName SEPARATOR ', ')
    INTO lv_ListUserName
    FROM cte_GroupUserName;
    
    SET lv_Title = CONCAT('FPS-Cust-MissedTrans ', DATE_FORMAT(ip_RptDate, '%m/%d/%Y'));
    SET lv_Message = 'Please kindly check the following Usersname without Transaction';
    SET lv_Message = CONCAT(lv_Message,'\n - Total Usernames: ', lv_CountResult);
    SET lv_Message = CONCAT(lv_Message,'\n - Top ',ip_LimitShowCust,' Usernames: ',lv_ListUserName, (CASE WHEN lv_CountResult > ip_LimitShowCust THEN ', ...' ELSE '' END));
    
    INSERT INTO DCS_DataCenter.NotifyMessage(NotifyType, GroupId, Title, Message, CreatedDate, IsNotified)
    SELECT	ip_NotifyType AS NotifyType
		,	ip_GroupId AS GroupId
		,	lv_Title AS Title
		,	lv_Message AS Message
		,	lv_CurDate AS CreatedDate
		,	0 AS IsNotified;
        
    SET op_NotifyMessageID = LAST_INSERT_ID();
END$$
DELIMITER ;
