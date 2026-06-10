/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService,ctsWeb" isFunction="0" isNested="1"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_RPT_RobotStatistic`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_RPT_RobotStatistic`(
		IN	ip_IsMonthly		BOOLEAN
	,	IN	ip_IsDaily			BOOLEAN
    ,	IN	ip_IsLicensee		BOOLEAN
	,	IN	ip_FromDate			DATETIME
	,	IN	ip_ToDate			DATETIME
	,	IN	ip_CustCounterJs 	JSON 
)
    SQL SECURITY INVOKER
sp:BEGIN
	/* 
		Created:	20230915@Casey.Huynh
		Task:		Robot Statistic Report
		DB:			CTS_DataCenter
        
		Revisions:
			- 20230915@Casey.Huynh: Created [Redmine ID: #193036]
			- 20241211@Adam.Tran: 	New Robot AI, Bot Login Pattern [Redmine ID: #214655]

		Param's Explanation (filtered by):
			ip_IsLicensee: NULL:All, 0:Credit, 1:Licensee
        Example:
			CALL CTS_DC_RPT_RobotStatistic(@ip_IsMonthly:=1, @ip_IsDaily:=1, @ip_IsLicensee:= 0, @ip_FromDate:='2023-03-24', @ip_ToDate:='2023-05-18'
            , @ip_CustCounterJs:='[{"CustID":1, "RobotDate":"2023-03-24"},{"CustID":1, "RobotDate":"2023-04-25"},{"CustID":2, "RobotDate":"2023-04-25"}]' );
	*/
    DECLARE CONST_ROBOTTYPE_AI		SMALLINT DEFAULT 1;
    DECLARE CONST_ROBOTTYPE_IMPERVA	SMALLINT DEFAULT 2;
    DECLARE CONST_ROBOTTYPE_COUNTER	SMALLINT DEFAULT 3;
	DECLARE	CONST_ROLEID_MEMBER		INT DEFAULT 1;
    
    #============================================================================
    DROP TEMPORARY TABLE IF EXISTS Temp_CounterRobot;
	CREATE TEMPORARY TABLE 		Temp_CounterRobot (
			CustID		BIGINT UNSIGNED PRIMARY KEY
		,	RobotDate	DATETIME  
	);   
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustRobot;
	CREATE TEMPORARY TABLE 		Temp_CustRobot (
			CustID		BIGINT UNSIGNED
		,	RobotType	SMALLINT
		,	RobotDate	DATETIME
        ,	RobotMonth	DATETIME	       
        
        ,	PRIMARY KEY PK_Temp_CustRobot_RobotDateRobotTypeCustID(RobotDate, RobotType, CustID)
        ,	INDEX IX_Temp_CustRobot_RobotMonthRobotTypeCustID(RobotMonth, RobotType, CustID)
	);   
	
	#======================INSERT ROBOT AI=========================================================
	INSERT IGNORE INTO Temp_CustRobot(CustID, RobotType, RobotDate, RobotMonth)
	SELECT	rd.CustID
		,	CONST_ROBOTTYPE_AI AS RobotType
		,	DATE(rd.CreatedDate) AS RobotDate
		,	DATE_SUB(DATE(rd.CreatedDate), INTERVAL DAYOFMONTH(DATE(rd.CreatedDate))-1 DAY) AS RobotMonth
	FROM CTS_DataCenter.RobotDetection AS rd
    		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON rd.CustID = cus.CustID AND cus.CustSubID = 0
	WHERE DATE(rd.CreatedDate) BETWEEN ip_FromDate AND ip_ToDate
		AND cus.IsLicensee = IFNULL(ip_IsLicensee,cus.IsLicensee)
		AND cus.RoleID = CONST_ROLEID_MEMBER;
    
    #======================INSERT ROBOT IMPERVA=========================================================
	INSERT IGNORE INTO Temp_CustRobot(CustID, RobotType, RobotDate, RobotMonth)
	SELECT	ri.CustID
		,	CONST_ROBOTTYPE_IMPERVA AS RobotType
		,	DATE(ri.CreateTime) AS RobotDate
        ,	DATE_SUB(DATE(ri.CreateTime), INTERVAL DAYOFMONTH(DATE(ri.CreateTime))-1 DAY) AS RobotMonth
	FROM CTS_DataCenter.RobotImperva AS ri
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON ri.CustID = cus.CustID AND cus.CustSubID = 0
	WHERE DATE(ri.CreateTime) BETWEEN ip_FromDate AND ip_ToDate
		AND cus.IsLicensee = IFNULL(ip_IsLicensee,cus.IsLicensee);
    
    #======================INSERT ROBOT COUNTER=========================================================
    IF ip_CustCounterJs <> '' THEN
		INSERT IGNORE INTO Temp_CounterRobot(CustID, RobotDate)
		SELECT  js.CustID
			,	DATE(js.RobotDate)
		FROM JSON_TABLE(ip_CustCounterJs,
					 "$[*]" COLUMNS(
								CustID		BIGINT UNSIGNED PATH "$.CustID" 	
							,	RobotDate	DATETIME PATH "$.RobotDate" 
						)
					) AS js;
        
		INSERT IGNORE INTO Temp_CustRobot(CustID, RobotType, RobotDate, RobotMonth)
		SELECT  tmpCr.CustID
			,	CONST_ROBOTTYPE_COUNTER AS RobotType
			,	tmpCr.RobotDate
            ,	DATE_SUB(tmpCr.RobotDate, INTERVAL DAYOFMONTH(tmpCr.RobotDate)-1 DAY) AS RobotMonth
		FROM Temp_CounterRobot AS tmpCr; 
			
    END IF;
	
    #======================RETURN DATA===============================================================
   
    IF ip_IsMonthly = 1 THEN
		SELECT 	tmpCr.RobotMonth AS 'DateRange'
			,	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 1 THEN CustID ELSE NULL END)) AS 'AI'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 2 THEN CustID ELSE NULL END)) AS 'IMPERVA'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 3 THEN CustID ELSE NULL END)) AS 'COUNTER'
            ,	COUNT(DISTINCT tmpCr.CustID) AS TotalAccount
        FROM Temp_CustRobot AS tmpCr
        GROUP BY tmpCr.RobotMonth; 
        
		SELECT 	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 1 THEN CustID ELSE NULL END)) AS 'AI'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 2 THEN CustID ELSE NULL END)) AS 'IMPERVA'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 3 THEN CustID ELSE NULL END)) AS 'COUNTER'
		FROM Temp_CustRobot AS tmpCr;
    
    END IF;
    
	IF ip_IsDaily = 1 THEN
		SELECT DATE(tmpCr.RobotDate) AS 'DateRange'
			,	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 1 THEN CustID ELSE NULL END)) AS 'AI'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 2 THEN CustID ELSE NULL END)) AS 'IMPERVA'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 3 THEN CustID ELSE NULL END)) AS 'COUNTER'
            ,	COUNT(DISTINCT tmpCr.CustID) AS TotalAccount
        FROM Temp_CustRobot AS tmpCr
        GROUP BY tmpCr.RobotDate;     
        
		SELECT 	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 1 THEN CustID ELSE NULL END)) AS 'AI'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 2 THEN CustID ELSE NULL END)) AS 'IMPERVA'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.RobotType = 3 THEN CustID ELSE NULL END)) AS 'COUNTER'
		FROM Temp_CustRobot AS tmpCr;
    END IF;

END$$

DELIMITER ;
