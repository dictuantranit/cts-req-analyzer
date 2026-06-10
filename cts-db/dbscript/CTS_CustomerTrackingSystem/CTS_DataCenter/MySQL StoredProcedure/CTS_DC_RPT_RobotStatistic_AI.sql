/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService,ctsWeb" isFunction="0" isNested="1"></info>*/ 
DROP PROCEDURE IF EXISTS `CTS_DC_RPT_RobotStatistic_AI`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_RPT_RobotStatistic_AI`(
		IN	ip_IsMonthly		BOOLEAN
	,	IN	ip_IsDaily			BOOLEAN
    ,	IN	ip_IsLicensee		BOOLEAN
	,	IN	ip_FromDate			DATETIME
	,	IN	ip_ToDate			DATETIME
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

        Example:
			CALL CTS_DC_RPT_RobotStatistic_AI(@ip_IsMontly:=1, @ip_IsDaily:=1, @ip_IsLicensee:=NULL, @ip_FromDate:='2023-03-01', @ip_ToDate:='2023-05-31');
			CALL CTS_DC_RPT_RobotStatistic_AI(@ip_IsMontly:=1, @ip_IsDaily:=1, @ip_IsLicensee:=0, @ip_FromDate:='2023-03-01', @ip_ToDate:='2023-05-31');
            CALL CTS_DC_RPT_RobotStatistic_AI(@ip_IsMontly:=1, @ip_IsDaily:=1, @ip_IsLicensee:=1, @ip_FromDate:='2023-03-01', @ip_ToDate:='2023-05-31');
	*/
    DECLARE CONST_ROBOTAI_TI	SMALLINT DEFAULT 1;
    DECLARE CONST_ROBOTAI_SCE	SMALLINT DEFAULT 2;
	DECLARE CONST_ROBOTAI_TD	SMALLINT DEFAULT 3;
    DECLARE CONST_ROBOTAI_OCRD	SMALLINT DEFAULT 4;
    DECLARE CONST_ROBOTAI_LP	SMALLINT DEFAULT 5;
    DECLARE	CONST_ROLEID_MEMBER		INT DEFAULT 1;
    
	DROP TEMPORARY TABLE IF EXISTS Temp_CustAIRobot;
	CREATE TEMPORARY TABLE 		Temp_CustAIRobot (
			CustID		BIGINT UNSIGNED
		,	AIType		SMALLINT
		,	RobotDate	DATETIME
        ,	RobotMonth	DATETIME       
        
        ,	PRIMARY KEY PK_Temp_CustRobot_RobotDateRobotTypeCustID(RobotDate, AIType, CustID)
        ,	INDEX IX_Temp_CustRobot_RobotMonthRobotTypeCustID(RobotMonth, AIType, CustID)
	);   

	#======================INSERT ROBOT AI=========================================================
	INSERT IGNORE INTO Temp_CustAIRobot(CustID, AIType, RobotDate, RobotMonth)
	SELECT	rd.CustID
		,	(CASE WHEN rd.PeriodRangeType BETWEEN 1 AND 99 THEN CONST_ROBOTAI_TI
				WHEN rd.PeriodRangeType BETWEEN 100 AND 199 THEN CONST_ROBOTAI_SCE
                WHEN rd.PeriodRangeType BETWEEN 200 AND 299 THEN CONST_ROBOTAI_OCRD
                WHEN rd.PeriodRangeType BETWEEN 300 AND 399 THEN CONST_ROBOTAI_TD
                WHEN rd.PeriodRangeType BETWEEN 400 AND 499 THEN CONST_ROBOTAI_LP
			END) AS AIType
		,	DATE(rd.CreatedDate) AS RobotDate
        ,	DATE_SUB(DATE(rd.CreatedDate), INTERVAL DAYOFMONTH(DATE(rd.CreatedDate))-1 DAY) AS RobotMonth
	FROM CTS_DataCenter.RobotDetection AS rd
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON rd.CustID = cus.CustID AND cus.CustSubID = 0
	WHERE DATE(rd.CreatedDate) BETWEEN ip_FromDate AND ip_ToDate
		AND cus.IsLicensee = IFNULL(ip_IsLicensee,cus.IsLicensee)
        AND cus.RoleID = CONST_ROLEID_MEMBER;

    #======================RETURN DATA===============================================================
   
    IF ip_IsMonthly = 1 THEN
		SELECT 	tmpCr.RobotMonth AS 'DateRange'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_TI THEN CustID ELSE NULL END)) AS 'TI'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_SCE THEN CustID ELSE NULL END)) AS 'SCE'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_OCRD THEN CustID ELSE NULL END)) AS 'OCRD'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_TD THEN CustID ELSE NULL END)) AS 'TD'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_LP THEN CustID ELSE NULL END)) AS 'LP'
            ,	COUNT(DISTINCT tmpCr.CustID) AS TotalAccount
        FROM Temp_CustAIRobot AS tmpCr			
        GROUP BY tmpCr.RobotMonth;     

		SELECT 	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_TI THEN CustID ELSE NULL END)) AS 'TI'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_SCE THEN CustID ELSE NULL END)) AS 'SCE'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_OCRD THEN CustID ELSE NULL END)) AS 'OCRD'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_TD THEN CustID ELSE NULL END)) AS 'TD'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_LP THEN CustID ELSE NULL END)) AS 'LP'
        FROM Temp_CustAIRobot AS tmpCr	;

    END IF;
    
	IF ip_IsDaily = 1 THEN
		SELECT DATE(tmpCr.RobotDate) AS 'DateRange'
			,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_TI THEN CustID ELSE NULL END)) AS 'TI'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_SCE THEN CustID ELSE NULL END)) AS 'SCE'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_OCRD THEN CustID ELSE NULL END)) AS 'OCRD'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_TD THEN CustID ELSE NULL END)) AS 'TD'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_LP THEN CustID ELSE NULL END)) AS 'LP'
            ,	COUNT(DISTINCT tmpCr.CustID) AS TotalAccount
        FROM Temp_CustAIRobot AS tmpCr
        GROUP BY tmpCr.RobotDate;        

		SELECT  COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_TI THEN CustID ELSE NULL END)) AS 'TI'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_SCE THEN CustID ELSE NULL END)) AS 'SCE'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_OCRD THEN CustID ELSE NULL END)) AS 'OCRD'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_TD THEN CustID ELSE NULL END)) AS 'TD'
            ,	COUNT(DISTINCT(CASE WHEN tmpCr.AIType = CONST_ROBOTAI_LP THEN CustID ELSE NULL END)) AS 'LP'
        FROM Temp_CustAIRobot AS tmpCr;
        
    END IF;
    
END$$

DELIMITER ;
