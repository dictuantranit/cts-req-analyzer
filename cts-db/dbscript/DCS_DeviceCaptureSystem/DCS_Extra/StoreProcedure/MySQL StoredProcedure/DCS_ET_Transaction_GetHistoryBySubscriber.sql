/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transaction_GetHistoryBySubscriber`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transaction_GetHistoryBySubscriber`(
		IN	ip_SubscriberID	INT	
    ,	IN	ip_FromDate		DATETIME
    ,	IN	ip_ToDate 		DATETIME
    ,	IN  ip_LoginName	VARCHAR(50)
    ,	IN	ip_IsPartial	BOOLEAN
    ,	IN	ip_DeviceCode	VARCHAR(32)
    ,	IN	ip_IP			VARCHAR(50)
    ,	IN	ip_Country		VARCHAR(64)
    ,	IN	ip_Region		VARCHAR(128)
    ,	IN	ip_City			VARCHAR(128)
    ,	IN	ip_Skip			INT
    ,	IN	ip_Take			INT
    ,	OUT	op_TotalItem	INT
)
    SQL SECURITY INVOKER
sp: BEGIN
	/*
		Created:	20230720@Casey.Huynh
		Task :		Get Association Account List
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 	20230720@Casey.Huynh: Created [Redmine ID: 189873]
            - 	20230809@Casey.Huynh: Show Device Info [Redmine ID: 192402]
			
		Param's Explanation (filtered by):

		Example:
			CALL DCS_ET_Transaction_GetHistoryBySubscriber(@ip_SubscriberID:=8000001,@ip_FromDate:='2023-07-03',@ip_ip_ToDate:='2023-12-24',@ip_LoginName:='tedddd', @ip_IsPartial:= 1
				, @ip_DeviceCode:='3a41d60a9b7b4a348594cd56dfd1ed81', @ip_IP:='1.1.1.1', @ip_Country:=NULL, @ip_Region:=NULL, @ip_City:=NULL
				, @ip_Skip:=0, @ip_Take:=2000, @op_TotalItem); SELECT @op_TotalItem; 

			CALL DCS_ET_Transaction_GetHistoryBySubscriber(@ip_SubscriberID:=8000001,@ip_FromDate:='2023-07-03',@ip_ip_ToDate:='2023-12-24',@ip_LoginName:=NULL, @ip_IsPartial:= 0
				, @ip_DeviceCode:='3a41d60a9b7b4a348594cd56dfd1ed81', @ip_IP:=NULL, @ip_Country:=NULL, @ip_Region:=NULL, @ip_City:=NULL
				, @ip_Skip:=0, @ip_Take:=2000, @op_TotalItem); SELECT @op_TotalItem;    
                
			CALL DCS_ET_Transaction_GetHistoryBySubscriber(@ip_SubscriberID:=8000001,@ip_FromDate:='2023-07-03',@ip_ip_ToDate:='2023-12-24',@ip_LoginName:=NULL, @ip_IsPartial:= 1
				, @ip_DeviceCode:='3a41d60a9b7b4a348594cd56dfd1ed81', @ip_IP:='1', @ip_Country:=NULL, @ip_Region:='Tokyo', @ip_City:=NULL
				, @ip_Skip:=0, @ip_Take:=2000, @op_TotalItem); SELECT @op_TotalItem;    
   */
   
	DECLARE lv_DeviceID BIGINT UNSIGNED;
    DECLARE lv_IsFilterAccount BOOLEAN DEFAULT 0;
    DECLARE lv_IsFilterIPInfo BOOLEAN DEFAULT 0;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Account;
	CREATE TEMPORARY TABLE Temp_Account(
			AccountID	BIGINT UNSIGNED PRIMARY KEY
		,   LoginName	VARCHAR(50)
	);
    
	#================================================================
	DROP TEMPORARY TABLE IF EXISTS Temp_Flagged;
	CREATE TEMPORARY TABLE Temp_Flagged(
			Flagged 	SMALLINT PRIMARY KEY
        ,	DisplayName VARCHAR(200)
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_IPInfo;
	CREATE TEMPORARY TABLE Temp_IPInfo(
			IPInfoID 	INT 
        ,	Country		VARCHAR(128)
        ,	City		VARCHAR(128)
        ,	Region		VARCHAR(128)
        ,	ISP			VARCHAR(128)
        
        ,	INDEX IX_Temp_IPInfo_IPInfoID(IPInfoID)
	);
	
    #========Device======================================
	IF (ip_DeviceCode IS NOT NULL) THEN
		   
		SELECT dc.DeviceID
        INTO lv_DeviceID 
        FROM DCS_Extra.DeviceCode AS dc
        WHERE dc.DeviceCode = ip_DeviceCode;
        
        IF lv_DeviceID IS NULL THEN
			LEAVE sp;
        END IF;
    END IF;  
    
    # GET SEARCH ACCOUNT
    IF ip_LoginName IS NOT NULL THEN
    
		SET lv_IsFilterAccount = 1;
        
		IF(ip_IsPartial = 1 ) THEN #SEARCH PARTIAL
			#========SEARCH BY USERNAME=====================
			INSERT INTO Temp_Account (AccountID, LoginName)
			SELECT	acc.AccountID
				,	acc.LoginName
			FROM DCS_Extra.Account AS acc
			WHERE acc.SubscriberID = ip_SubscriberID AND acc.LoginName LIKE CONCAT(ip_LoginName,'%');
            
		ELSE #SEARCH EXACTLY
			#========SEARCH BY USERNAME=====================
			INSERT INTO Temp_Account (AccountID, LoginName)
			SELECT	acc.AccountID
				,	acc.LoginName
			FROM DCS_Extra.Account AS acc
			WHERE acc.SubscriberID = ip_SubscriberID AND acc.LoginName = ip_LoginName;			
		END IF;
        
        IF NOT EXISTS (SELECT 1 FROM Temp_Account) THEN
			LEAVE sp;
        END IF;
	END IF;
    
     #========IPINFO======================================
	IF (ip_Country IS NOT NULL OR ip_City IS NOT NULL OR ip_Region IS NOT NULL) THEN
		SET lv_IsFilterIPInfo = 1;
		INSERT INTO Temp_IPInfo(IPInfoID, Country, City, Region, ISP)
		SELECT	ip.IPInfoID
			,	ip.Country
			,	ip.City
			,	ip.Region
			,	ip.ISP
		FROM DCS_Extra.IPInfo AS ip
        WHERE	ip.Country = IFNULL(ip_Country,ip.Country)
			AND ip.City = IFNULL(ip_City,ip.City)
            AND ip.Region = IFNULL(ip_Region,ip.Region);
		
		IF NOT EXISTS (SELECT 1 FROM Temp_IPInfo) THEN
			LEAVE sp;
        END IF;
    END IF; 

    #====================================================================
    INSERT INTO Temp_Flagged(Flagged, DisplayName)
    SELECT	stl.ItemID
		,	stl.ItemName
    FROM DCS_Extra.StaticList AS stl
    WHERE stl.ListID = 1;
    
    #========GET IP Region=============================================               		
	IF lv_IsFilterAccount = 1 AND lv_IsFilterIPInfo = 1 THEN 			
            
			SET @TotalRow = 0;
			SELECT 	tmp.TransID			AS TransID
				,	tmp.AccountID		AS AccountID
                ,	ip_SubscriberID		AS SubscriberID
				,	tmp.LoginName		AS LoginName
				,	tmp.TransTime		AS TransTime
				,	tmp.FirstDeviceCode	AS FirstDeviceCode
				,	tmp.Action			AS Action
				,	tmp.ActionResult	AS ActionResult
                ,	tmp.UserAgent		AS UserAgent
				,	tmp.OS				AS OS
				,	tmp.Browser			AS Browser
				,	tmp.URLDetails		AS URLDetails
				,	tmp.IP				AS IP
				,	tmp.Country			AS Country
				,	tmp.Region			AS Region
				,	tmp.City			AS City
				,	tmp.ISP				AS ISP
                ,	tmp.DisplayName		AS RobotTracking
			FROM	(
					SELECT 	@TotalRow := @TotalRow + 1
						,	trs.TransTime
                        ,	trs.AccountID
                        ,	trs.LoginName
						,	trs.TransID
						,	trs.FirstDeviceCode
						,	ar.Action
						,	ar.ActionResult
                        ,	uag.UserAgent
						,	uag.OS
						,	uag.Browser
						,	ur.URLDetails
						,	trs.IP
                        ,	tmpIp.Country
                        ,	tmpIp.Region
                        ,	tmpIp.City
                        ,	tmpIp.ISP
                        ,	tmpFg.DisplayName
					FROM DCS_Extra.Transaction07 AS trs
                    	INNER JOIN Temp_Account AS tmpAcc ON trs.AccountID = tmpAcc.AccountID
                        INNER JOIN Temp_IPInfo AS tmpIp ON trs.IPInfoID = tmpIp.IPInfoID
						LEFT JOIN DCS_Extra.UserAgent AS uag ON trs.UserAgentKey = uag.UserAgentKey
						LEFT JOIN DCS_Extra.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
						LEFT JOIN DCS_Extra.URL AS ur ON trs.URLID = ur.URLID
                        LEFT JOIN Temp_Flagged AS tmpFg ON trs.Flagged = tmpFg.Flagged
					WHERE trs.TransTime BETWEEN ip_FromDate AND ip_ToDate
						AND trs.DeviceID = IFNULL(lv_DeviceID,trs.DeviceID)
                        AND trs.IP LIKE CONCAT(IFNULL(ip_IP,trs.IP),'%')
					) AS tmp
				ORDER BY TransTime DESC            
				LIMIT ip_Skip, ip_Take;
			
			SET op_TotalItem = @TotalRow;
	END IF;
    
    IF lv_IsFilterAccount = 0 AND lv_IsFilterIPInfo = 0 THEN 			
            
			SET @TotalRow = 0;
			SELECT 	tmp.TransID			AS TransID
				,	tmp.AccountID		AS AccountID
                ,	ip_SubscriberID		AS SubscriberID
				,	tmp.LoginName		AS LoginName
				,	tmp.TransTime		AS TransTime
				,	tmp.FirstDeviceCode	AS FirstDeviceCode
				,	tmp.Action			AS Action
				,	tmp.ActionResult	AS ActionResult
                ,	tmp.UserAgent		AS UserAgent
				,	tmp.OS				AS OS
				,	tmp.Browser			AS Browser
				,	tmp.URLDetails		AS URLDetails
				,	tmp.IP				AS IP
				,	tmp.Country			AS Country
				,	tmp.Region			AS Region
				,	tmp.City			AS City
				,	tmp.ISP				AS ISP
                ,	tmp.DisplayName		AS RobotTracking
			FROM	(
					SELECT 	@TotalRow := @TotalRow + 1
						,	trs.TransTime
                        ,	trs.AccountID
                        ,	trs.LoginName
						,	trs.TransID
						,	trs.FirstDeviceCode
						,	ar.Action
						,	ar.ActionResult
                        ,	uag.UserAgent
						,	uag.OS
						,	uag.Browser
						,	ur.URLDetails
						,	trs.IP
                        ,	ip.Country
                        ,	ip.Region
                        ,	ip.City
                        ,	ip.ISP
                        ,	tmpFg.DisplayName
					FROM DCS_Extra.Transaction07 AS trs
                        LEFT JOIN DCS_Extra.IPInfo AS ip ON trs.IPInfoID = ip.IPInfoID
						LEFT JOIN DCS_Extra.UserAgent AS uag ON trs.UserAgentKey = uag.UserAgentKey
						LEFT JOIN DCS_Extra.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
						LEFT JOIN DCS_Extra.URL AS ur ON trs.URLID = ur.URLID
                        LEFT JOIN Temp_Flagged AS tmpFg ON trs.Flagged = tmpFg.Flagged
					WHERE trs.TransTime BETWEEN ip_FromDate AND ip_ToDate
						AND trs.DeviceID = IFNULL(lv_DeviceID,trs.DeviceID)
						AND trs.IP LIKE CONCAT(IFNULL(ip_IP,trs.IP),'%')
                        AND trs.SubscriberID = ip_SubscriberID
					) AS tmp
				ORDER BY TransTime DESC            
				LIMIT ip_Skip, ip_Take;
                
			SET op_TotalItem = @TotalRow;
	END IF;
    
    IF lv_IsFilterAccount = 1 AND lv_IsFilterIPInfo = 0 THEN 			
            
			SET @TotalRow = 0;
			SELECT 	tmp.TransID			AS TransID
				,	tmp.AccountID		AS AccountID
                ,	ip_SubscriberID		AS SubscriberID
				,	tmp.LoginName		AS LoginName
				,	tmp.TransTime		AS TransTime
				,	tmp.FirstDeviceCode	AS FirstDeviceCode
				,	tmp.Action			AS Action
				,	tmp.ActionResult	AS ActionResult
                ,	tmp.UserAgent		AS UserAgent
				,	tmp.OS				AS OS
				,	tmp.Browser			AS Browser
				,	tmp.URLDetails		AS URLDetails
				,	tmp.IP				AS IP
				,	tmp.Country			AS Country
				,	tmp.Region			AS Region
				,	tmp.City			AS City
				,	tmp.ISP				AS ISP
                ,	tmp.DisplayName		AS RobotTracking
			FROM	(
					SELECT 	@TotalRow := @TotalRow + 1
						,	trs.TransTime
                        ,	trs.AccountID
                        ,	trs.LoginName
						,	trs.TransID
						,	trs.FirstDeviceCode
						,	ar.Action
						,	ar.ActionResult
                        ,	uag.UserAgent
						,	uag.OS
						,	uag.Browser
						,	ur.URLDetails
						,	trs.IP
                        ,	ip.Country
                        ,	ip.Region
                        ,	ip.City
                        ,	ip.ISP
                        ,	tmpFg.DisplayName
					FROM DCS_Extra.Transaction07 AS trs
                    	INNER JOIN Temp_Account AS tmpAcc ON trs.AccountID = tmpAcc.AccountID
                        LEFT JOIN DCS_Extra.IPInfo AS ip ON trs.IPInfoID = ip.IPInfoID
						LEFT JOIN DCS_Extra.UserAgent AS uag ON trs.UserAgentKey = uag.UserAgentKey
						LEFT JOIN DCS_Extra.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
						LEFT JOIN DCS_Extra.URL AS ur ON trs.URLID = ur.URLID
                        LEFT JOIN Temp_Flagged AS tmpFg ON trs.Flagged = tmpFg.Flagged
					WHERE trs.TransTime BETWEEN ip_FromDate AND ip_ToDate
						AND trs.DeviceID = IFNULL(lv_DeviceID,trs.DeviceID)
						AND trs.IP LIKE CONCAT(IFNULL(ip_IP,trs.IP),'%')
					) AS tmp
				ORDER BY TransTime DESC            
				LIMIT ip_Skip, ip_Take;
			
			SET op_TotalItem = @TotalRow;
	END IF;
    
    IF lv_IsFilterAccount = 0 AND lv_IsFilterIPInfo = 1 THEN 			
            
			SET @TotalRow = 0;
			SELECT 	tmp.TransID			AS TransID
				,	tmp.AccountID		AS AccountID
                ,	ip_SubscriberID		AS SubscriberID
				,	tmp.LoginName		AS LoginName
				,	tmp.TransTime		AS TransTime
				,	tmp.FirstDeviceCode	AS FirstDeviceCode
				,	tmp.Action			AS Action
				,	tmp.ActionResult	AS ActionResult
                ,	tmp.UserAgent		AS UserAgent
				,	tmp.OS				AS OS
				,	tmp.Browser			AS Browser
				,	tmp.URLDetails		AS URLDetails
				,	tmp.IP				AS IP
				,	tmp.Country			AS Country
				,	tmp.Region			AS Region
				,	tmp.City			AS City
				,	tmp.ISP				AS ISP
                ,	tmp.DisplayName		AS RobotTracking
			FROM	(
					SELECT 	@TotalRow := @TotalRow + 1
						,	trs.TransTime
                        ,	trs.AccountID
                        ,	trs.LoginName
						,	trs.TransID
						,	trs.FirstDeviceCode
						,	ar.Action
						,	ar.ActionResult
                        ,	uag.UserAgent
						,	uag.OS
						,	uag.Browser
						,	ur.URLDetails
						,	trs.IP
                        ,	tmpIp.Country
                        ,	tmpIp.Region
                        ,	tmpIp.City
                        ,	tmpIp.ISP
                        ,	tmpFg.DisplayName
					FROM DCS_Extra.Transaction07 AS trs
                        INNER JOIN Temp_IPInfo AS tmpIp ON trs.IPInfoID = tmpIp.IPInfoID
						LEFT JOIN DCS_Extra.UserAgent AS uag ON trs.UserAgentKey = uag.UserAgentKey
						LEFT JOIN DCS_Extra.ActionResult AS ar ON trs.ActionResultID = ar.ActionResultID
						LEFT JOIN DCS_Extra.URL AS ur ON trs.URLID = ur.URLID
                        LEFT JOIN Temp_Flagged AS tmpFg ON trs.Flagged = tmpFg.Flagged
					WHERE trs.TransTime BETWEEN ip_FromDate AND ip_ToDate
						AND trs.DeviceID = IFNULL(lv_DeviceID,trs.DeviceID)
                        AND trs.IP LIKE CONCAT(IFNULL(ip_IP,trs.IP),'%')
                        AND trs.SubscriberID = ip_SubscriberID
					) AS tmp
				ORDER BY TransTime DESC            
				LIMIT ip_Skip, ip_Take;
		
			SET op_TotalItem = @TotalRow;
	END IF;
    
END$$

DELIMITER ;


