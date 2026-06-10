/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Notification_Transaction`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Notification_Transaction`(
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20210930@Casey.Huynh
	    Task : GET Sum Trans
	    DB: DCS_DataCenter (Slave)
	    Original:

	    Revisions:
			-	20210930@Casey.Huynh: Created [Redmine ID: 161528]
			
	    Param's Explanation (filtered by):
        
        Example: CALL DCS_DC_Notification_Transaction();

    */
	DECLARE lv_Yesterday DATETIME;
    DECLARE lv_PreYesterday DATETIME;
    
	SET lv_Yesterday = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY);
    SET lv_PreYesterday = DATE_SUB(lv_Yesterday, INTERVAL 1 DAY);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_PreYesterday;
    CREATE TEMPORARY TABLE Temp_PreYesterday(
			SubscriberID INT
        ,	TransTotal	INT UNSIGNED
        
        ,	PRIMARY KEY Temp_Yesterday(SubscriberID)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Yesterday;
    CREATE TEMPORARY TABLE Temp_Yesterday LIKE Temp_PreYesterday;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Subscriber;
    CREATE TEMPORARY TABLE Temp_Subscriber(
			SubscriberID INT PRIMARY KEY
		,	SubscriberName VARCHAR(50)
    );
    
    INSERT INTO Temp_Subscriber(SubscriberID, SubscriberName)
    SELECT	sb.SubscriberID
		,	sb.SubscriberName
    FROM CTS_Admin.Subscriber AS sb
    WHERE sb.DCSStatus = 1;
 
    INSERT INTO Temp_PreYesterday(SubscriberID, TransTotal)
    SELECT	srt.SubscriberID
		,	srt.TransTotal
	FROM	DCS_DataCenter.SumRawTransaction AS srt
    WHERE 	srt.TransDate = lv_PreYesterday;
    
	INSERT INTO Temp_Yesterday(SubscriberID, TransTotal)
    SELECT	srt.SubscriberID
		,	srt.TransTotal
	FROM	DCS_DataCenter.SumRawTransaction AS srt
    WHERE 	srt.TransDate = lv_Yesterday;

    /* Total Trans (Yesterday)/Total Trans (Yesterday - 1) < 50% */
    SELECT 	GROUP_CONCAT(tmpSb.SubscriberName) AS YesterdayLess50Percent
    FROM Temp_Subscriber AS tmpSb
		INNER JOIN Temp_PreYesterday AS tmpPy ON tmpSb.SubscriberID = tmpPy.SubscriberID
		LEFT JOIN Temp_Yesterday AS tmpYs ON tmpSb.SubscriberID = tmpYs.SubscriberID    
    WHERE (IFNULL(tmpYs.TransTotal,0)/tmpPy.TransTotal) < 0.5;
    
	/* Valid Trans(Yesterday)/Total Trans(Yesteday) < 50% */
    SELECT 	GROUP_CONCAT(tmpSb.SubscriberName) AS ValidLess50Percent  
    FROM Temp_Subscriber AS tmpSb
		INNER JOIN Temp_Yesterday AS tmpYs ON tmpSb.SubscriberID = tmpYs.SubscriberID
		LEFT JOIN DCS_DataCenter.SumTransaction AS st ON st.SubscriberID = tmpYs.SubscriberID AND st.TransDate = lv_Yesterday        
    WHERE IFNULL(st.ValidTotal,0)/tmpYs.TransTotal < 0.5 AND tmpYs.TransTotal > 0;

    
END$$
DELIMITER ;
