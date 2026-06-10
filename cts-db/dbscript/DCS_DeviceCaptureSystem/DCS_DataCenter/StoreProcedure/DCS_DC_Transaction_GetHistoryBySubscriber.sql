/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transaction_GetHistoryBySubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transaction_GetHistoryBySubscriber`(
		IN	ip_SubscriberID	INT	
    ,	IN	ip_FromDate		DATETIME
    ,	IN	ip_ToDate 		DATETIME
    ,	IN  ip_UserName		VARCHAR(50)
    ,	IN	ip_IsPartial	BOOLEAN
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
			CALL DCS_DC_Transaction_GetHistoryBySubscriber(@ip_SubscriberID:=6,@ip_FromDate:='2023-01-01',@ip_ip_ToDate:='2023-06-15',@ip_UserName:='wintiger', @ip_IsPartial:= 0, @ip_Skip:=0, @ip_Take:=2000, @op_TotalItem); SELECT @op_TotalItem;    
			CALL DCS_DC_Transaction_GetHistoryBySubscriber(@ip_SubscriberID:=6,@ip_FromDate:='2023-01-01',@ip_ip_ToDate:='2023-06-15',@ip_UserName:='12BetAUD', @ip_IsPartial:= 1, @ip_Skip:=0, @ip_Take:=2000, @op_TotalItem); SELECT @op_TotalItem;    

   */

	DROP TEMPORARY TABLE IF EXISTS Temp_Account;
	CREATE TEMPORARY TABLE Temp_Account(
			AccountID BIGINT UNSIGNED PRIMARY KEY
        ,	CTSCustID BIGINT UNSIGNED
		,   UserName		VARCHAR(50)
		,	RegisterName	VARCHAR(50)
	);
    
	#=============GET CUSTOMER BY SEARCH====================================
	DROP TEMPORARY TABLE IF EXISTS Temp_Customer;
	CREATE TEMPORARY TABLE Temp_Customer(
			CTSCustID		BIGINT UNSIGNED PRIMARY KEY
		,   UserName		VARCHAR(50)
		,	RegisterName	VARCHAR(50)
	);
	#================================================================
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
    
	#================================================================================
	# GET SEARCH ACCOUNT
	IF(ip_IsPartial = 1) THEN #SEARCH PARTIAL
		#========SEARCH BY USERNAME=====================
		INSERT INTO Temp_Customer (CTSCustID, UserName, RegisterName)
		SELECT	cus.CTSCustID
			,	cus.UserName
            ,	cus.RegisterName
		FROM CTS_DataCenter.CTSCustomer AS cus
		WHERE cus.SubscriberID = ip_SubscriberID AND cus.UserName LIKE CONCAT(ip_UserName,'%') AND cus.IsInternal = 0;
			
		#========SEARCH BY USERNAME2=====================
		INSERT IGNORE INTO Temp_Customer (CTSCustID, UserName, RegisterName)
		SELECT	cus.CTSCustID
        	,	cus.UserName
            ,	cus.RegisterName
		FROM CTS_DataCenter.CTSCustomer AS cus
		WHERE cus.SubscriberID = ip_SubscriberID AND cus.RegisterName LIKE CONCAT(ip_UserName,'%') AND cus.IsInternal = 0;

	ELSE #SEARCH EXACTLY
		#========SEARCH BY USERNAME=====================
		INSERT INTO Temp_Customer (CTSCustID, UserName, RegisterName)
		SELECT	cus.CTSCustID
			,	cus.UserName
            ,	cus.RegisterName
		FROM CTS_DataCenter.CTSCustomer AS cus
		WHERE cus.SubscriberID = ip_SubscriberID AND cus.UserName = ip_UserName AND cus.IsInternal = 0;
			
		#========SEARCH BY USERNAME2=====================
		INSERT IGNORE INTO Temp_Customer (CTSCustID, UserName, RegisterName)
		SELECT	cus.CTSCustID
			,	cus.UserName
            ,	cus.RegisterName
		FROM CTS_DataCenter.CTSCustomer AS cus
		WHERE cus.SubscriberID = ip_SubscriberID AND cus.RegisterName =  ip_UserName AND cus.IsInternal = 0;
	END IF;
        
	INSERT INTO Temp_Account(AccountID, CTSCustID, UserName, RegisterName)
	SELECT	cda.AccountID
		,	cda.CTSCustID
        ,	tmp.UserName
		,	tmp.RegisterName
	FROM CTS_DataCenter.CustDCSAccount AS cda
		INNER JOIN Temp_Customer AS tmp ON cda.CTSCustID = tmp.CTSCustID;
        		
	IF ip_UserName IS NOT NULL THEN 
			SET @TotalRow = 0;
			SELECT 	tmp.TransID			AS TransID
				,	tmp.CTSCustID		AS CTSCustID
                ,	ip_SubscriberID		AS SubscriberID
				,	tmp.RegisterName	AS RegisterName
                ,	tmp.UserName		AS UserName
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
                        ,	tmpAcc.CTSCustID
                        ,	tmpAcc.RegisterName	AS RegisterName
						,	tmpAcc.UserName		AS UserName
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
                    	INNER JOIN  Temp_Account AS tmpAcc ON trs.AccountID = tmpAcc.AccountID
						LEFT JOIN DCS_DataCenter.UserAgent AS uag ON trs.UserAgentKey = uag.UserAgentKey
						LEFT JOIN DCS_DataCenter.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
						LEFT JOIN DCS_DataCenter.URL AS ur ON trs.URLID = ur.URLID
                        LEFT JOIN Temp_Flagged AS tmpFg ON trs.Flagged = tmpFg.Flagged
					WHERE trs.TransTime BETWEEN ip_FromDate AND ip_ToDate
					) AS tmp
				ORDER BY TransTime DESC            
				LIMIT ip_Skip, ip_Take;
			
			SET op_TotalItem = @TotalRow;
	ELSE # Transaction History Report    
		SET @TotalRow = 0;
		SELECT 	tmp.TransTime		AS TransTime
			,	tmp.CTSCustID		AS CTSCustID
             ,	ip_SubscriberID		AS SubscriberID
			,	tmp.TransID			AS TransID
			,	tmp.RegisterName	AS RegisterName
			,	tmp.UserName		AS UserName
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
                    ,	ca.CTSCustID
					,	trs.TransID
					,	cus.RegisterName
                    ,	cus.UserName
					,	trs.FirstDeviceCode
					,	ar.Action
					,	ar.ActionResult
					,	uag.OS
					,	uag.Browser
					,	ur.URLDetails
					,	trs.IP
                    ,	tmpFg.DisplayName
				FROM	DCS_DataCenter.Transaction07 trs 
					INNER JOIN CTS_DataCenter.CustDCSAccount AS ca ON trs.AccountID = ca.AccountID
					INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ca.CTSCustID = cus.CTSCustID AND cus.IsInternal = 0
					LEFT JOIN DCS_DataCenter.UserAgent AS uag ON trs.UserAgentKey = uag.UserAgentKey
					LEFT JOIN DCS_DataCenter.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
					LEFT JOIN DCS_DataCenter.URL AS ur ON trs.URLID = ur.URLID
                    LEFT JOIN Temp_Flagged AS tmpFg ON trs.Flagged = tmpFg.Flagged
				WHERE trs.TransTime BETWEEN ip_FromDate AND ip_ToDate
					AND trs.SubscriberID = ip_SubscriberID
				) AS tmp
			ORDER BY TransTime DESC            
			LIMIT ip_Skip, ip_Take;
			
			SET op_TotalItem = @TotalRow;
	END IF;
END$$

DELIMITER ;
