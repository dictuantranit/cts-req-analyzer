/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_RobotDetection_GetLatest`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_RobotDetection_GetLatest`(
		IN 	ip_RobotDetectionLastID		BIGINT UNSIGNED	
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20220523@Long.Luu
		Task:		Get Latest Robot Info to push to CTS [Redmine ID: #172561]
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20220523@Long.Luu: 		Created -  Robot Detection [Redmine ID: #172561]
			- 20230315@Victoria.Le:		Get Robot Imperva [Redmine ID: #184773]
            - 20230517@Casey.Huynh:		New Category for Robot OCRD [Redmine ID: #186991]
            - 20240717@Jonas.Huynh:		Renovate CC [Redmine ID: #205317]
            - 20241210@Casey.Huynh:		New Robot AI, Bot Login Pattern [Redmine ID: #214655]
            
		Example:
			CALL CTS_DataCenter.CTS_DC_RobotDetection_GetLatest(@ip_RobotDetectionLastID:= 0);
	*/    
       
    DECLARE	CONST_CATEID_ROBOTUSER					INT;
    DECLARE	CONST_CATEID_ROBOTOCRD					INT;
    DECLARE	CONST_CATEID_BOTLOGINPATTERN			INT;  
    
    DECLARE	CONST_PERIODRANGETYPE_OCRD						INT DEFAULT 200;
    DECLARE	CONST_PERIODRANGETYPE_LP_LOGINTIMEPATTERN		INT DEFAULT 400;
    DECLARE	CONST_PERIODRANGETYPE_LP_MASSIVELOGINATTEMPT	INT DEFAULT 420;
    DECLARE	CONST_PERIODRANGETYPE_LP_IPDEVERSITY			INT DEFAULT 430;    
    DECLARE	CONST_PERIODRANGETYPE_LP_DEVICEDEVERSITY		INT DEFAULT 440;
    
    DECLARE	CONST_ROLEID_MEMBER		INT DEFAULT 1;
    
    DECLARE lv_BatchSize INT;
     
    SET CONST_CATEID_ROBOTUSER	 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTUSER');
    SET CONST_CATEID_ROBOTOCRD	 					= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_ROBOTOCRD');
    SET CONST_CATEID_BOTLOGINPATTERN	 			= CTS_DataCenter.CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_BOTLOGINPATTERN');
        
	DROP TEMPORARY TABLE IF EXISTS Temp_RobotDetection;    
	CREATE TEMPORARY TABLE Temp_RobotDetection(
			ID					BIGINT UNSIGNED 
		,	CustID				BIGINT UNSIGNED  
        ,	CategoryID			INT UNSIGNED NOT NULL
        ,	LastModifiedDate	DATETIME(3)
        ,	PRIMARY KEY PK_Temp_RobotDetection_ID(ID)
        ,	INDEX IX_Temp_RobotDetection_CustIDCategoryID(CustID,CategoryID)
	);
    
    #======================================================================    
    SELECT s.ParameterValue
    INTO lv_BatchSize
    FROM CTS_DataCenter.SystemParameter AS s
    WHERE ParameterID = 140;
    
    INSERT INTO Temp_RobotDetection(ID, CustID, CategoryID, LastModifiedDate)
    SELECT	rd.ID
		,	rd.CustID
		, 	(CASE 	WHEN rd.PeriodRangeType = CONST_PERIODRANGETYPE_OCRD THEN CONST_CATEID_ROBOTOCRD 
					WHEN rd.PeriodRangeType IN (CONST_PERIODRANGETYPE_LP_LOGINTIMEPATTERN
												, CONST_PERIODRANGETYPE_LP_MASSIVELOGINATTEMPT
												, CONST_PERIODRANGETYPE_LP_IPDEVERSITY
                                                , CONST_PERIODRANGETYPE_LP_DEVICEDEVERSITY) THEN CONST_CATEID_BOTLOGINPATTERN 
				ELSE CONST_CATEID_ROBOTUSER END) AS CategoryID
		,	rd.LastModifiedDate
    FROM CTS_DataCenter.RobotDetection AS rd
			INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON rd.CustID = cus.CustID AND cus.CustSubID = 0
    WHERE rd.ID > ip_RobotDetectionLastID
		AND rd.IsDisabled = 0
        AND cus.RoleID = CONST_ROLEID_MEMBER
    ORDER BY rd.ID ASC
    LIMIT lv_BatchSize;    

	SELECT	tmpRd.CustID
		,	tmpRd.CategoryID
        ,	MAX(tmpRd.ID) AS RobotDetectionID
        , 	MAX(tmpRd.LastModifiedDate) AS LastModifiedDate
    FROM Temp_RobotDetection AS tmpRd
    GROUP BY tmpRd.CustID, tmpRd.CategoryID;

END$$	
DELIMITER ;
