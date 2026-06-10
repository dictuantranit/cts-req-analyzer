/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transaction_GetHistoryByCustSubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transaction_GetHistoryByCustSubscriber`(
		IN	ip_SubscriberID	INT	
    ,	IN	ip_FromDate		DATETIME
    ,	IN	ip_ToDate 		DATETIME
    ,	IN	ip_CTSCustID	BIGINT UNSIGNED
    ,	IN	ip_Skip			INT
    ,	IN	ip_Take			INT
    ,	OUT	op_TotalItem	INT
    )
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230601@Casey.Huynh
		Task :		Get Association Account List
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230601@Casey.Huynh: Created [Redmine ID: 185787]
			
		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_DC_Transaction_GetHistoryByCustSubscriber(@ip_SubscriberID:=6,@ip_FromDate:='2023-01-01',@ip_ip_ToDate:='2023-01-15',@ip_CTSCustID:=1373636,@ip_Skip:=0, @ip_Take:=2000, @op_TotalItem); SELECT @op_TotalItem;    
    */
	DROP TEMPORARY TABLE IF EXISTS Temp_Account;
	CREATE TEMPORARY TABLE Temp_Account(
		AccountID INT PRIMARY KEY
	);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Flagged;
	CREATE TEMPORARY TABLE Temp_Flagged(
			Flagged 	SMALLINT PRIMARY KEY
        ,	DisplayName VARCHAR(200)
	);
    
    INSERT INTO Temp_Flagged(Flagged, DisplayName)
    SELECT	stl.ItemID
		,	stl.ItemName
    FROM DCS_DataCenter.StaticList AS stl
    WHERE stl.ListID = 1;
    
	INSERT INTO Temp_Account(AccountID)
	SELECT	cda.AccountID
	FROM CTS_DataCenter.CustDCSAccount AS cda
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cda.CTSCustID = cus.CTSCustID 
	WHERE	cda.CTSCustID = ip_CTSCustID
		AND cus.SubscriberID = ip_SubscriberID;

	SET @TotalRow = 0;
	SELECT 	tmp.TransID			AS TransID
		,	tmp.TransTime		AS TransTime
		,	tmp.FirstDeviceCode	AS FirstDeviceCode
		,	tmp.Action			AS Action
		,	tmp.ActionResult	AS ActionResult
		,	tmp.OS				AS OS
		,	tmp.Browser			AS Browser
		,	tmp.URLDetails		AS URLDetails
		,	tmp.IP				AS IP
        ,	tmp.DisplayName		AS RobotTracking
	FROM	(
			SELECT 	@TotalRow := @TotalRow + 1
				,	trs.TransTime
				,	trs.TransID
				,	trs.FirstDeviceCode
				,	ar.Action
				,	ar.ActionResult
				,	uag.OS
				,	uag.Browser
				,	ur.URLDetails
				,	trs.IP
                ,	tmpFg.DisplayName
			FROM	DCS_DataCenter.Transaction07 trs
				INNER JOIN Temp_Account AS tmpAcc ON trs.AccountID = tmpAcc.AccountID
				LEFT JOIN DCS_DataCenter.UserAgent AS uag ON trs.UserAgentKey = uag.UserAgentKey
				LEFT JOIN DCS_DataCenter.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
				LEFT JOIN DCS_DataCenter.URL AS ur ON trs.URLID = ur.URLID
                LEFT JOIN Temp_Flagged AS tmpFg ON trs.Flagged = tmpFg.Flagged
			WHERE trs.TransTime BETWEEN ip_FromDate AND ip_ToDate
			) AS tmp
		ORDER BY TransTime DESC            
		LIMIT ip_Skip, ip_Take;
		
		SET op_TotalItem = @TotalRow;
END$$

DELIMITER ;
