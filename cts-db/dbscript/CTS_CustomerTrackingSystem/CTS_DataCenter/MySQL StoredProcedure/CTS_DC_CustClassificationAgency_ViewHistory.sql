/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassificationAgency_ViewHistory`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassificationAgency_ViewHistory`(
	IN ip_CTSCustID 	BIGINT
)
    SQL SECURITY INVOKER
BEGIN
  /*
		Created:	20241008@Thomas.Nguyen
		Task:		View History for SMA customer category in CTS
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20241008@Thomas.Nguyen: Created [Redmine ID: #185799]
            - 20250725@Casey.Huynh: Agent CC, Insert Considerable Agency [Redmine ID: #219679]
			
		Param's Explanation (filtered by):		
        Example:
			- CALL CTS_DataCenter.CTS_DC_CustClassificationAgency_ViewHistory(11198);
	*/
    DECLARE CONST_AGENCY_CATEID_ROBOT								INT;
	DECLARE CONST_AGENCY_CATEID_ROBOTLOSING							INT;
    DECLARE CONST_AGENCY_REMARKID_ROBOTFROMTW				        INT DEFAULT 50;

    SET CONST_AGENCY_CATEID_ROBOT 									= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_ROBOT');
	SET CONST_AGENCY_CATEID_ROBOTLOSING 							= CTS_DC_CategoryTypeParent_Get ('CONST_AGENCY_CATEID_ROBOTLOSING');

    DROP TEMPORARY TABLE IF EXISTS Temp_CustRemark;
    CREATE TEMPORARY TABLE 	Temp_CustRemark (
                HistoryID			BIGINT UNSIGNED NOT NULL PRIMARY KEY
            ,	CustID				BIGINT UNSIGNED
            ,	CategoryID			INT
            ,	SourceTypeID		SMALLINT UNSIGNED
            ,	RemarkID			SMALLINT UNSIGNED
            ,	Remark				TEXT
            ,	KEY IX_Temp_CustRemark_CateID(CategoryID)	
    );

    INSERT IGNORE INTO Temp_CustRemark(HistoryID, CustID, CategoryID, SourceTypeID)
    SELECT  clss.ID
        ,	clss.CustID
        ,   clss.CategoryID
        ,	CASE WHEN clss.CategoryID IN (CONST_AGENCY_CATEID_ROBOT, CONST_AGENCY_CATEID_ROBOTLOSING) AND clss.IsFromTW = 1 
                    THEN CONST_AGENCY_REMARKID_ROBOTFROMTW ELSE clss.SourceTypeID END
    FROM CTS_DataCenter.CTSCustomerClassificationAgency_History AS clss
        INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON clss.CustID = cus.CustID
    WHERE 	clss.CTSCustID = ip_CTSCustID AND clss.IsDataChanged = 1;

    UPDATE Temp_CustRemark AS tmp
        INNER JOIN CTS_DataCenter.CustomerCategorySettingsAgency AS cs ON cs.CategoryID = tmp.CategoryID AND cs.RemarkTemplateID IS NOT NULL
        INNER JOIN CTS_DataCenter.CustomerClassificationAgency_Remark AS cr ON cr.RemarkID = cs.RemarkTemplateID
    SET tmp.Remark = cr.RemarkTemplate;

    UPDATE Temp_CustRemark AS tmp
        INNER JOIN CTS_DataCenter.CustomerClassificationAgency_Remark AS cr ON cr.RemarkID = tmp.SourceTypeID
    SET tmp.Remark = cr.RemarkTemplate
    WHERE tmp.Remark IS NULL AND tmp.SourceTypeID IS NOT NULL;

    SELECT 	temp.LastModifiedDate AS CreatedTime
        ,   (CASE WHEN temp.CategoryID IS NULL THEN '-' ELSE cate.CategoryName END) AS CategoryName
        ,   (CASE WHEN temp.TargetCC IN (-1, -99) THEN '-' /* -1: Remove, -99: No mapping CC */ ELSE temp.TargetCC END) AS CustomerClass
        ,   IFNULL(u.UserName, temp.LastModifiedBy) AS CreatedBy
        ,	TRIM(TRAILING '|' FROM TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(tmpcr.Remark, 
                            '[Winloss]', IFNULL(FORMAT(temp.WinlossRM, 2),0))
                        ,   '[2mWinloss]', IFNULL(FORMAT(temp.LastXDaysWinlossRM, 2),0))
                        ,   '[1yWinloss]', IFNULL(FORMAT(temp.LastYDaysWinlossRM, 2),0))                         
                        ,   '[Margin]', CASE WHEN IFNULL(temp.TurnOverRM,0) = 0 THEN 0 ELSE ROUND((temp.WinlossRM/temp.TurnOverRM) * 100, 3) END)
                        ,   '[2mMargin]', CASE WHEN IFNULL(temp.LastXDaysTurnoverRM,0) = 0 THEN 0 ELSE ROUND((temp.LastXDaysWinlossRM/temp.LastXDaysTurnoverRM) * 100, 3) END)
                        ,   '[1yMargin]', CASE WHEN IFNULL(temp.LastYDaysTurnoverRM,0) = 0 THEN 0 ELSE ROUND((temp.LastYDaysWinlossRM/temp.LastYDaysTurnoverRM) * 100, 3) END)                           
                        ,   '[BetCount]', IFNULL(temp.BetCount,0))
                        ,   '[2mBetCount]', IFNULL(temp.LastXDaysBetCount,0))
                        ,   '[1yBetCount]', IFNULL(temp.LastYDaysBetCount,0))
                        ,   '[TWRobotCounter]', IFNULL(temp.RobotCounter,0))
                        ,   '[PARatio]', CASE WHEN temp.Remark LIKE 'PARatio:%' THEN REPLACE(temp.Remark,'PARatio:','') ELSE '' END)
                        ,   '[Remark]', IFNULL(temp.Remark,''))
                        )) AS Remark
    FROM 	CTS_DataCenter.CTSCustomerClassificationAgency_History AS temp
        INNER JOIN Temp_CustRemark AS tmpcr ON tmpcr.HistoryID = temp.ID
        LEFT JOIN CTS_DataCenter.CustomerCategoryAgency AS cate ON temp.CategoryID = cate.CategoryID
        LEFT JOIN CTS_Admin.CTSUser AS u ON temp.LastModifiedBy = u.UserID
    WHERE 	temp.CTSCustID = ip_CTSCustID AND temp.IsDataChanged = 1
    ORDER BY temp.ID DESC; 
    
END$$
DELIMITER ;
