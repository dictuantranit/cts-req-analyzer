/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transaction_GetHistoryByDeviceSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transaction_GetHistoryByDeviceSubscriber`(
		IN	ip_SubscriberID	INT	
    ,	IN	ip_FromDate		DATETIME
    ,	IN	ip_ToDate 		DATETIME
    ,	IN	ip_DeviceID		BIGINT UNSIGNED
    ,	IN	ip_Skip			INT
    ,	IN	ip_Take			INT
    ,	OUT	op_TotalItem	INT
    )
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230810@Casey.Huynh
		Task :		Get Transaction List By Device
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230810@Casey.Huynh: Created [Redmine ID: 190402]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_ET_Transaction_GetHistoryByDeviceSubscriber(@ip_SubscriberID:=8000001,@ip_FromDate:='2023-01-01',@ip_ip_ToDate:='2023-07-15',@ip_DeviceID:=1,@ip_Skip:=0, @ip_Take:=2000, @op_TotalItem); SELECT @op_TotalItem;    
    
    */
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Flagged;
	CREATE TEMPORARY TABLE Temp_Flagged(
			Flagged 	SMALLINT PRIMARY KEY
        ,	DisplayName VARCHAR(200)
	);
    
    INSERT INTO Temp_Flagged(Flagged, DisplayName)
    SELECT	stl.ItemID
		,	stl.ItemName
    FROM DCS_Extra.StaticList AS stl
    WHERE stl.ListID = 1;    

	SET @TotalRow = 0;
    
	SELECT 	tmp.TransID			AS TransID
		,	tmp.TransTime		AS TransTime
        ,	tmp.LoginName		AS LoginName
		,	tmp.AccountID		AS AccountID
		,	tmp.Action			AS Action
		,	tmp.ActionResult	AS ActionResult
		,	tmp.OS				AS OS
		,	tmp.Browser			AS Browser
		,	tmp.URLDetails		AS URLDetails
		,	tmp.IP				AS IP
        ,	tmp.DisplayName		AS RobotTracking
		,	tmp.Country			AS Country
		,	tmp.Region			AS Region
		,	tmp.City			AS City
		,	tmp.ISP				AS ISP
	FROM	(
			SELECT 	@TotalRow := @TotalRow + 1
				,	trs.TransTime
				,	trs.TransID
                ,	trs.LoginName
                ,	trs.AccountID
				,	ar.Action
				,	ar.ActionResult
				,	uag.OS
				,	uag.Browser
				,	ur.URLDetails
				,	trs.IP
                ,	tmpFg.DisplayName
                ,	ip.Country
                ,	ip.Region
                ,	ip.City
                ,	ip.ISP
			FROM DCS_Extra.Transaction07 AS trs 
				LEFT JOIN DCS_Extra.IPInfo AS ip ON trs.IPInfoID = ip.IPInfoID
				LEFT JOIN DCS_Extra.UserAgent AS uag ON trs.UserAgentKey = uag.UserAgentKey
				LEFT JOIN DCS_Extra.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
				LEFT JOIN DCS_Extra.URL AS ur ON trs.URLID = ur.URLID
                LEFT JOIN Temp_Flagged AS tmpFg ON trs.Flagged = tmpFg.Flagged
			WHERE trs.TransTime BETWEEN ip_FromDate AND ip_ToDate AND trs.DeviceID = ip_DeviceID AND trs.SubscriberID = ip_SubscriberID
			) AS tmp
		ORDER BY TransTime DESC            
		LIMIT ip_Skip, ip_Take;
		
		SET op_TotalItem = @TotalRow;
        
END$$

DELIMITER ;
