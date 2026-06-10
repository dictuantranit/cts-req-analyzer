/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_SumTransaction_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_SumTransaction_Update`(
		IN ip_MaxTransID			BIGINT UNSIGNED
	,	IN ip_DateScan				DATE
    ,	IN ip_AccountID				BIGINT UNSIGNED
	,   IN ip_SumSubscriber			JSON  
    ,   IN ip_SumDeviceType			JSON 
    ,   IN ip_AccountIP				JSON  
    ,   IN ip_AccountDevice			JSON
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20210930@Casey.Huynh
	    Task : Update TransSum
	    DB: DCS_DataCenter (Master)
	    Original:

	    Revisions:		    
        	-	20210930@Casey.Huynh: Created [Redmine ID: 161528]
            -   20211214@Aries.Nguyen: Enrich the information on customer profile [Redmine ID: #165105]
			-   20220325@Aries.Nguyen: Refactor the Sum data job of transaction statistic [Redmine ID: #170525]

	    Param's Explanation (filtered by):
        
        Example: CALL DCS_DC_SumTransaction_Update(70001,'[{"TransDate":"2021-09-28", "SubscriberID":4, "ValidTotal":5000,"ValidNoDevice":500
        , "ValidDeviceStatusNew":500, "ValidDeviceStatusOld":3000, "ValidDeviceStatusRecover":1000, "ValidBrowserless":1500}]');
		SELECT * FROM SumTransaction;
    */
    
    /***************************************Sum Subscriber**********************************************/
    DROP TEMPORARY TABLE IF EXISTS Temp_SumTransaction;
    CREATE TEMPORARY TABLE Temp_SumTransaction(
			TransDate					DATETIME NOT NULL
		,	SubscriberID				INT NOT NULL
		,	ValidTotal					INT UNSIGNED
		,	ValidNoDevice				INT UNSIGNED
		,	ValidDeviceStatusNew		INT UNSIGNED
		,	ValidDeviceStatusOld		INT UNSIGNED
		,	ValidDeviceStatusRecover	INT UNSIGNED
		,	ValidBrowserless			INT UNSIGNED
		
		,	PRIMARY KEY PK_SumTransaction(TransDate, SubscriberId)
	) ENGINE=InnoDB;
    
    INSERT IGNORE INTO Temp_SumTransaction(TransDate, SubscriberID, ValidTotal, ValidNoDevice, ValidDeviceStatusNew, ValidDeviceStatusOld, ValidDeviceStatusRecover, ValidBrowserless)
	SELECT 	js.TransDate
		,	js.SubscriberID
        ,	js.ValidTotal
        ,	js.ValidNoDevice
        ,	js.ValidDeviceStatusNew
        ,	js.ValidDeviceStatusOld
        ,	js.ValidDeviceStatusRecover
        ,	js.ValidBrowserless
	FROM JSON_TABLE(ip_SumSubscriber,
		"$[*]" COLUMNS(
				TransDate					DATETIME PATH "$.TransDate"
			,   SubscriberID				INT UNSIGNED PATH "$.SubscriberID" 
			,	ValidTotal					INT UNSIGNED PATH "$.ValidTotal" 
            ,	ValidNoDevice				INT UNSIGNED PATH "$.ValidNoDevice" 
            ,	ValidDeviceStatusNew		INT UNSIGNED PATH "$.ValidDeviceStatusNew" 
            ,	ValidDeviceStatusOld		INT UNSIGNED PATH "$.ValidDeviceStatusOld" 
            ,	ValidDeviceStatusRecover	INT UNSIGNED PATH "$.ValidDeviceStatusRecover" 
            ,	ValidBrowserless			INT UNSIGNED PATH "$.ValidBrowserless"
			)
	) AS js ;
        
	INSERT IGNORE INTO DCS_DataCenter.SumTransaction(TransDate, SubscriberID, ValidTotal, ValidNoDevice, ValidDeviceStatusNew, ValidDeviceStatusOld, ValidDeviceStatusRecover, ValidBrowserless, LastTransID)
	SELECT	tmpSt.TransDate
		,	tmpSt.SubscriberID
		,	tmpSt.ValidTotal
		,	tmpSt.ValidNoDevice
		,	tmpSt.ValidDeviceStatusNew
		,	tmpSt.ValidDeviceStatusOld
		,	tmpSt.ValidDeviceStatusRecover
		,	tmpSt.ValidBrowserless
		,	ip_MaxTransID AS LastTransID
	FROM Temp_SumTransaction AS tmpSt;
        
	UPDATE DCS_DataCenter.SumTransaction AS st
	INNER JOIN Temp_SumTransaction AS tmpSt ON  st.TransDate = tmpSt.TransDate 
											AND st.SubscriberID = tmpSt.SubscriberID 
                                            AND st.LastTransID < ip_MaxTransID
	SET		st.ValidTotal = st.ValidTotal + tmpSt.ValidTotal
		,	st.ValidNoDevice = st.ValidNoDevice + tmpSt.ValidNoDevice
		,	st.ValidDeviceStatusNew = st.ValidDeviceStatusNew + tmpSt.ValidDeviceStatusNew
		,	st.ValidDeviceStatusOld = st.ValidDeviceStatusOld + tmpSt.ValidDeviceStatusOld
		,	st.ValidDeviceStatusRecover = st.ValidDeviceStatusRecover + tmpSt.ValidDeviceStatusRecover
		,	st.ValidBrowserless = st.ValidBrowserless + tmpSt.ValidBrowserless
		,	st.LastTransID = ip_MaxTransID;
	
	/***************************************Sum DeviceType**********************************************/
	DROP TEMPORARY TABLE IF EXISTS Temp_SumDeviceType;
    CREATE TEMPORARY TABLE Temp_SumDeviceType(
			AccountID		BIGINT UNSIGNED NOT NULL
		,	TransDate		DATE NOT NULL
		,	DeviceMobile	INT 
		,	DeviceDesktop	INT 
		,	DeviceOthers	INT 
		,	TotalLogin		INT 
        ,	MaxTransID		BIGINT UNSIGNED 
		,	PRIMARY KEY PK_Temp_SumDeviceType(AccountID, TransDate)
	) ENGINE=InnoDB;
    
    INSERT IGNORE INTO Temp_SumDeviceType(AccountID, TransDate, DeviceMobile, DeviceDesktop, DeviceOthers, TotalLogin,MaxTransID)
	SELECT 	js.AccountID
		,	DATE(js.TransDate)
        ,	js.DeviceMobile
        ,	js.DeviceDesktop
        ,	js.DeviceOthers
        ,	js.TotalLogin
        ,	js.MaxTransID
	FROM JSON_TABLE(ip_SumDeviceType,
		"$[*]" COLUMNS(
				AccountID		BIGINT UNSIGNED 	PATH "$.AccountID"
			,   TransDate		DATETIME 			PATH "$.TransDate" 
			,	DeviceMobile	INT 				PATH "$.DeviceMobile" 
            ,	DeviceDesktop	INT 				PATH "$.DeviceDesktop" 
            ,	DeviceOthers	INT 				PATH "$.DeviceOthers" 
            ,	TotalLogin		INT 				PATH "$.TotalLogin" 
            ,	MaxTransID		BIGINT UNSIGNED 	PATH "$.MaxTransID" 
			)
	) AS js ;
    
    INSERT IGNORE INTO DCS_DataCenter.SumAccountLogin(AccountID, TransDate, DeviceMobile, DeviceDesktop, DeviceOthers, TotalLogin, LastTransID)
	SELECT	tmp.AccountID
		,	tmp.TransDate
        ,	tmp.DeviceMobile
        ,	tmp.DeviceDesktop
        ,	tmp.DeviceOthers
        ,	tmp.TotalLogin
        ,	tmp.MaxTransID
	FROM Temp_SumDeviceType AS tmp
    WHERE NOT EXISTS (SELECT 1 
					  FROM DCS_DataCenter.SumAccountLogin AS lg 
                      WHERE lg.AccountID =  tmp.AccountID 
						AND lg.TransDate =  tmp.TransDate);
    
    UPDATE DCS_DataCenter.SumAccountLogin AS lg
	INNER JOIN Temp_SumDeviceType AS tmp ON  lg.AccountID =  tmp.AccountID 
										 AND lg.TransDate =  tmp.TransDate
										 AND lg.LastTransID  < tmp.MaxTransID
	SET		lg.DeviceMobile  = lg.DeviceMobile + tmp.DeviceMobile
		,	lg.DeviceDesktop = lg.DeviceDesktop + tmp.DeviceDesktop
		,	lg.DeviceOthers  = lg.DeviceOthers + tmp.DeviceOthers
		,	lg.TotalLogin    = lg.TotalLogin + tmp.TotalLogin
		,	lg.LastTransID   = tmp.MaxTransID;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_SumDeviceTypeByAccount;
    CREATE TEMPORARY TABLE Temp_SumDeviceTypeByAccount(
			AccountID		BIGINT UNSIGNED NOT NULL
		,	DeviceMobile	INT 
		,	DeviceDesktop	INT 
		,	DeviceOthers	INT 
		,	TotalLogin		INT 
		,	MaxTransID		BIGINT UNSIGNED 
		,	PRIMARY KEY PK_Temp_SumDeviceType(AccountID)
	) ENGINE=InnoDB;
    
    INSERT IGNORE INTO Temp_SumDeviceTypeByAccount(AccountID, DeviceMobile, DeviceDesktop, DeviceOthers, TotalLogin,MaxTransID)
	SELECT 	AccountID
        ,	SUM(DeviceMobile)
        ,	SUM(DeviceDesktop)
        ,	SUM(DeviceOthers)
        ,	SUM(TotalLogin)
        ,	MAX(MaxTransID)
	FROM  Temp_SumDeviceType
    GROUP BY AccountID;
    
    INSERT IGNORE INTO DCS_DataCenter.SumAccountLoginTotal(AccountID, DeviceMobile, DeviceDesktop, DeviceOthers, TotalLogin, LastTransID)
	SELECT	tmp.AccountID
        ,	tmp.DeviceMobile
        ,	tmp.DeviceDesktop
        ,	tmp.DeviceOthers
        ,	tmp.TotalLogin
        ,	tmp.MaxTransID
	FROM Temp_SumDeviceTypeByAccount AS tmp
    WHERE NOT EXISTS (SELECT 1 
					  FROM DCS_DataCenter.SumAccountLoginTotal AS lg 
                      WHERE lg.AccountID =  tmp.AccountID);
                      
	UPDATE DCS_DataCenter.SumAccountLoginTotal AS lg
	INNER JOIN Temp_SumDeviceTypeByAccount AS tmp  ON  lg.AccountID =  tmp.AccountID 
												   AND lg.LastTransID < tmp.MaxTransID 
	SET		lg.DeviceMobile  = lg.DeviceMobile + tmp.DeviceMobile
		,	lg.DeviceDesktop = lg.DeviceDesktop + tmp.DeviceDesktop
		,	lg.DeviceOthers  = lg.DeviceOthers + tmp.DeviceOthers
		,	lg.TotalLogin    = lg.TotalLogin + tmp.TotalLogin
		,	lg.LastTransID   = tmp.MaxTransID;
   
    /***************************************Update TransDate By AccountIP**********************************************/
    DROP TEMPORARY TABLE IF EXISTS Temp_AccountIP;
    CREATE TEMPORARY TABLE Temp_AccountIP(
			AccountID		BIGINT UNSIGNED NOT NULL
		,	TransDate		DATE NOT NULL
		,	IP 				VARCHAR(50) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL
		,	PRIMARY KEY PK_Temp_AccountIP(AccountID, IP)
	) ENGINE=InnoDB;
    
    INSERT IGNORE INTO Temp_AccountIP(AccountID, TransDate, IP)
	SELECT 	js.AccountID
		,	DATE(js.TransDate)
        ,	js.IP
	FROM JSON_TABLE(ip_AccountIP,
		"$[*]" COLUMNS(
				AccountID		BIGINT UNSIGNED 	PATH "$.AccountID"
			,   TransDate		DATETIME 			PATH "$.TransDate" 
			,	IP				VARCHAR(50) 		PATH "$.IP" 
			)
	) AS js ;
    
    INSERT IGNORE INTO DCS_DataCenter.AccountIP(AccountID, LastTransDate, IP)
	SELECT	tmp.AccountID
		,	tmp.TransDate
        ,	tmp.IP
	FROM Temp_AccountIP AS tmp
    WHERE NOT EXISTS (SELECT 1 
					  FROM DCS_DataCenter.AccountIP AS ip 
                      WHERE ip.AccountID =  tmp.AccountID 
						AND ip.IP =  tmp.IP);
   
    UPDATE DCS_DataCenter.AccountIP AS ip
	INNER JOIN Temp_AccountIP AS tmp ON  ip.AccountID =  tmp.AccountID 
									 AND ip.IP =  tmp.IP
                                     AND ip.LastTransDate <  tmp.TransDate
	SET	ip.LastTransDate = tmp.TransDate;
    
    /***************************************Update TransDate By AccountDevice**********************************************/
    DROP TEMPORARY TABLE IF EXISTS Temp_AccountDevice;
    CREATE TEMPORARY TABLE Temp_AccountDevice(
			AccountID		BIGINT UNSIGNED NOT NULL
		,	TransDate		DATE NOT NULL
		,	DeviceID 		BIGINT UNSIGNED
		,	PRIMARY KEY PK_Temp_AccountDevice(AccountID, DeviceID)
	) ENGINE=InnoDB;
    
    INSERT IGNORE INTO Temp_AccountDevice(AccountID, TransDate, DeviceID)
	SELECT 	js.AccountID
		,	DATE(js.TransDate)
        ,	js.DeviceID
	FROM JSON_TABLE(ip_AccountDevice,
		"$[*]" COLUMNS(
				AccountID		BIGINT UNSIGNED 	PATH "$.AccountID"
			,   TransDate		DATETIME 			PATH "$.TransDate" 
			,	DeviceID		BIGINT UNSIGNED 	PATH "$.DeviceID" 
			)
	) AS js ;
    
    INSERT IGNORE INTO DCS_DataCenter.AccountDevice(AccountID, LastTransDate, DeviceID)
	SELECT	tmp.AccountID
		,	tmp.TransDate
        ,	tmp.DeviceID
	FROM Temp_AccountDevice AS tmp
    WHERE NOT EXISTS (SELECT 1 
					  FROM DCS_DataCenter.AccountDevice AS dv 
                      WHERE dv.AccountID =  tmp.AccountID 
						AND dv.DeviceID =  tmp.DeviceID);
    
    UPDATE DCS_DataCenter.AccountDevice AS dv
	INNER JOIN Temp_AccountDevice AS tmp ON  dv.AccountID =  tmp.AccountID 
										 AND dv.DeviceID =  tmp.DeviceID
                                         AND dv.LastTransDate <  tmp.TransDate
	SET	dv.LastTransDate = tmp.TransDate;
    
	/*Update System Setting*/
	UPDATE SystemSetting AS s
	SET	s.VValue = ip_MaxTransID
	,	s.UpdatedTime = CURRENT_TIME()
	WHERE s.ID = 11;
    
    UPDATE SystemSetting AS s
	SET	s.VValue = ip_DateScan
	,	s.UpdatedTime = CURRENT_TIME()
	WHERE s.ID = 21;
    
    UPDATE SystemSetting AS s
	SET	s.VValue = ip_AccountID
	,	s.UpdatedTime = CURRENT_TIME()
	WHERE s.ID = 22;
    
END$$
DELIMITER ;
