/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_RobotClassification_GetHistory`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_RobotClassification_GetHistory`(
		IN ip_CustID 			BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
sp : BEGIN
	/*
		Created:	20210818@Harvey.Nguyen
		Task:		Get history's robot classification
		DB:			CTS_DataCenter
        
		Revisions:
			- 20210818@Harvey.Nguyen: Created [Redmine ID: #160382]
			- 20220211@Long.Luu: Get general classification history instead of detailed [Redmine ID: #167726]
            
        Example:
			- CALL CTS_DataCenter.CTS_DC_RobotClassification_GetHistory(32221326);
	*/
	
   DROP TEMPORARY TABLE IF EXISTS Temp_History1;  
	CREATE TEMPORARY TABLE Temp_History1
    (
		ID				INT UNSIGNED AUTO_INCREMENT,
		CustID			BIGINT,
        FromDate		DATETIME,
        ToDate			DATETIME,
        RobotType		TINYINT,
        Turnover		DECIMAL(20,4),
        Winloss			DECIMAL(20,4),
        BetCount		INT UNSIGNED,
        ActiveDays		TINYINT UNSIGNED,
        IsTypeChanged	BIT,
        PRIMARY KEY (`ID`)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_History2;  
	CREATE TEMPORARY TABLE Temp_History2
    (
		ID				INT UNSIGNED AUTO_INCREMENT,
        OriginID		INT UNSIGNED,
        RobotType		TINYINT,
        PRIMARY KEY (`ID`)
    );
    
    DROP TEMPORARY TABLE IF EXISTS Temp_OriginChangedID;  
	CREATE TEMPORARY TABLE Temp_OriginChangedID
    (
		OriginID		INT UNSIGNED PRIMARY KEY
    );
	
    INSERT INTO Temp_History1(CustID,FromDate,ToDate,RobotType,Turnover,Winloss,BetCount,ActiveDays)
    SELECT 	CustID
		, 	FromDate
        , 	ToDate
        ,	RobotType
        ,	Turnover
        ,	Winloss
        ,	BetCount
        ,	ActiveDays
	FROM CTS_DataCenter.RobotClassification
	WHERE CustID = ip_CustID
	ORDER BY FromDate ASC;

	INSERT INTO Temp_History2(RobotType, OriginID)
    SELECT 	RobotType, ID
	FROM Temp_History1
    WHERE ID > 1;
        
	INSERT INTO Temp_OriginChangedID (OriginID)
    VALUES (1);
    
    INSERT INTO Temp_OriginChangedID (OriginID)
    SELECT h2.OriginID
    FROM Temp_History1 AS h1
		LEFT JOIN Temp_History2 AS h2 ON h1.ID = h2.ID
    WHERE h1.RobotType <> h2.RobotType;
    
	SELECT 	h1.CustID
		, 	h1.FromDate
        , 	h1.ToDate
        ,	h1.RobotType
        ,	h1.Turnover
        ,	h1.Winloss
        ,	h1.BetCount
        ,	h1.ActiveDays
    FROM Temp_History1 AS h1
		INNER JOIN Temp_OriginChangedID AS o ON h1.ID = o.OriginID
	ORDER BY h1.FromDate DESC;        
	
	DROP TEMPORARY TABLE IF EXISTS Temp_History1;  
	DROP TEMPORARY TABLE IF EXISTS Temp_History2;  
	DROP TEMPORARY TABLE IF EXISTS Temp_OriginChangedID;  
END$$

DELIMITER ;