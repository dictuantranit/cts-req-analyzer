/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_RPT_Transaction`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_RPT_Transaction`(
		IN ip_FromDate 			DATETIME
    ,	IN ip_ToDate 			DATETIME
    ,	IN ip_SubscriberList	TEXT
	,	IN ip_Skip 				INT
    ,	IN ip_Take 				INT
    
    ,	OUT op_TotalRow			INT
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
            -	20230606@Jonathan.Doan: Monitor Transaction Level Subscriber [Redmine ID: 189323]
            
	    Param's Explanation (filtered by):
        
        Example: CALL DCS_DC_RPT_Transaction('2021-09-28','2021-10-04','2,6',0,50,@op_TotalRow); SELECT @op_TotalRow;
    */    
    DROP TEMPORARY TABLE IF EXISTS Temp_Subscriber;
    CREATE TEMPORARY TABLE Temp_Subscriber(
			SubscriberID INT PRIMARY KEY
		,	SubscriberName VARCHAR(50)
    );  	
    
    SET @sql = CONCAT('	INSERT INTO Temp_Subscriber(SubscriberID, SubscriberName)
						SELECT SubscriberID, SubscriberName
						FROM CTS_Admin.Subscriber 
						WHERE SubscriberID IN (',ip_SubscriberList,')');
                     
    PREPARE	stmt1 FROM @sql;
	EXECUTE stmt1;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_TransReport;
    CREATE TEMPORARY TABLE Temp_TransReport(
			Subscriber 				VARCHAR(50)  PRIMARY KEY
        ,	TotalTrans				BIGINT
        ,	TotalValidTrans			BIGINT
        ,	ValidTransNewDevice		BIGINT
        ,	ValidTransOldDevice		BIGINT
        ,	ValidTransRecoverDevice	BIGINT
        ,	ValidTransNoDevice		BIGINT
        ,	InvalidTrans			BIGINT	
        ,	ValidBrowserless		BIGINT
    );
	
    INSERT INTO Temp_TransReport(Subscriber, TotalTrans, TotalValidTrans, ValidTransNewDevice, ValidTransOldDevice, ValidTransRecoverDevice
    , ValidTransNoDevice,  InvalidTrans, ValidBrowserless)
	SELECT	tmpSb.SubscriberName AS 'Subscriber'
		,	SUM(IFNULL(rt.TransTotal,0)) AS 'TotalTrans'
		,	SUM(IFNULL(ts.ValidTotal,0)) AS 'TotalValidTrans'
		,	SUM(IFNULL(ts.ValidDeviceStatusNew,0)) AS 'ValidTransNewDevice'
		,	SUM(IFNULL(ts.ValidDeviceStatusOld,0)) AS 'ValidTransOldDevice'
		,	SUM(IFNULL(ts.ValidDeviceStatusRecover,0)) AS 'ValidTransRecoverDevice'
		,	SUM(IFNULL(ts.ValidNoDevice,0)) AS 'ValidTransNoDevice'  
		,	SUM(IFNULL(rt.TransTotal,0)) - SUM(IFNULL(ts.ValidTotal,0)) AS 'InvalidTrans'
		,	SUM(IFNULL(ts.ValidBrowserless,0)) AS 'ValidBrowserless'
	FROM Temp_Subscriber AS tmpSb
		LEFT JOIN DCS_DataCenter.SumRawTransaction AS rt ON rt.SubscriberID = tmpSb.SubscriberID AND rt.TransDate BETWEEN ip_FromDate AND ip_ToDate
		LEFT JOIN DCS_DataCenter.SumTransaction AS ts ON rt.TransDate = ts.TransDate AND rt.SubscriberID = ts.SubscriberID
	GROUP BY tmpSb.SubscriberID, tmpSb.SubscriberName;
    
    SELECT	tmpTr.Subscriber
		,	tmpTr.TotalTrans
        ,	tmpTr.TotalValidTrans
        ,	tmpTr.ValidTransNewDevice
        ,	tmpTr.ValidTransOldDevice
        ,	tmpTr.ValidTransRecoverDevice
		,	tmpTr.ValidTransNoDevice
        ,	tmpTr.InvalidTrans
        ,	tmpTr.ValidBrowserless
	FROM	Temp_TransReport AS tmpTr
    ORDER BY tmpTr.Subscriber
	LIMIT ip_Take
	OFFSET ip_Skip;	
        
	SET op_TotalRow = (SELECT COUNT(1) FROM Temp_TransReport);
    
END$$
DELIMITER ;
