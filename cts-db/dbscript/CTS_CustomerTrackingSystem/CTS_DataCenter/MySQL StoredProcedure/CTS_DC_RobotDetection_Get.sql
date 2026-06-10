/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_RobotDetection_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_RobotDetection_Get`(
		IN 	ip_CustID	 			BIGINT UNSIGNED
    
    ,	OUT op_FirstRobotDate		TIMESTAMP(3)
    ,	OUT op_LastRobotDate		TIMESTAMP(3)    
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20221027@Long.Luu
		Task:		Get SCE Robot Detection Detailed Info [Redmine ID: #179498]
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20221027@Long.Luu: 		Created [Redmine ID: #179498]
			- 20221027@Long.Luu: 		Support SCE Robots [Redmine ID: #179498]
			- 20230315@Victoria.Le:		Add Robot Imperva [Redmine ID: #184773]
            - 20230404@Casey.Huynh:		Return RobotDetection.PeriodRangeName for PeriodRangeType = 200 [Redmine ID: #185777]
            - 20230512@Casey.Huynh:		Return RobotDetection.PeriodRangeName for PeriodRangeType = 300 [Redmine ID: #186992]
			- 20241210@Casey.Huynh: 	New Robot AI, Bot Login Pattern [Redmine ID: #214655]
            
		Example:
			CALL CTS_DataCenter.CTS_DC_RobotDetection_Get(1317, @op_FirstRobotDate, @op_LastRobotDate); SELECT @op_FirstRobotDate,@op_LastRobotDate;
	*/    
	DECLARE	CONST_ROLEID_MEMBER		INT DEFAULT 1;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_PeriodRangeType;
    CREATE TEMPORARY TABLE Temp_PeriodRangeType(
			PeriodRangeType		SMALLINT PRIMARY KEY
		,	PeriodRangeName		VARCHAR(200)
        ,	AIGroup			INT	#1:Bot Login Pattern, ELSE 2
    );   
    
	SELECT 	MIN(rd.CreatedDate), MAX(rd.LastModifiedDate)
    INTO op_FirstRobotDate, op_LastRobotDate
    FROM CTS_DataCenter.RobotDetection AS rd
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON rd.CustID = cus.CustID AND cus.CustSubID = 0
    WHERE rd.CustID = ip_CustID
		AND cus.RoleID = CONST_ROLEID_MEMBER; 
    
    INSERT INTO Temp_PeriodRangeType(PeriodRangeType, PeriodRangeName, AIGroup)
    VALUES	(400,'Login Time Pattern', 1)
		,	(420,'Massive Login Attempt', 1)
        ,	(430,'Device Variety', 1)
        ,	(440,'IP Diversity', 1)
        ,	(1,'Tickets with 1s < Time Interval < 10s', 2)
        ,	(3,'Tickets with 10s <= Time Interval < 20s', 2)
        ,	(5,'Tickets with Time Interval >= 45s', 2)
        ,	(20,'Unconsecutive Tickets with Time Deviation < 2s', 2)
        ,	(40,'Consecutive Tickets with Time Deviation < 2s', 2)
        ,	(100,'More than 5/30 Days with Consecutive Tickets > 24 hours', 2)
        ,	(101,'Consecutive Tickets > 24 Hours and High Ugly Stake Tickets', 2)
        ,	(200,'Consecutive Tickets per Match <= 2 mins and Stake per Ticket < 30 RM', 2)
        ,	(300,'Time Discretization', 2);
        
    #==========Return Bot Login Pattern=======================
	SELECT 	rd.CustID
		,	rd.PeriodRangeType
		,	pt.PeriodRangeName
        ,	pt.AIGroup
    FROM CTS_DataCenter.RobotDetection AS rd
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON rd.CustID = cus.CustID AND cus.CustSubID = 0
        INNER JOIN Temp_PeriodRangeType AS pt ON pt.PeriodRangeType = rd.PeriodRangeType
    WHERE rd.CustID = ip_CustID
		AND cus.RoleID = CONST_ROLEID_MEMBER;        

	SELECT 	ri.CustID
		,	ri.CreateTime
		,	ri.Platform
	FROM CTS_DataCenter.RobotImperva AS ri
	WHERE ri.CustID = ip_CustID;
    
END$$	
DELIMITER ;