/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_CustClassification_BySport_History_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustClassification_BySport_History_Get`(
		IN ip_CTSCustID 	BIGINT
	,	IN ip_SportID	INT
)
    SQL SECURITY INVOKER
BEGIN
/*
		Created:	20220908@Casey.Huynh
		Task:		Get Cust Classification Details by sport
		DB:			CTS_DataCenter
		Original:
		Revisions: 
				- 20220908@Casey.Huynh: Created [Redmine ID: #176992]
                - 20240320@Thomas.Nguyen: Return more Remark, SourceTypeName, SourceTypeID [Redmine ID: #201360]
				- 20240628@Thomas.Nguyen: Renovate CC phase 2 [Redmine ID: #205317]
				- 20251117@Thomas.Nguyen: Classify Saba Soccer in System Detect GB CC3101/CC3201 - Get Remark [Redmine ID: #239995]

		Param's Explanation:
        
        Example:
        SELECT * FROM CTSCustomerClassification_BySport_History;
				CALL CTS_DataCenter.CTS_DC_CustClassification_BySport_History_Get(@CTSCustID:=572272, @ip_SportID:=2);
*/ 
	DROP TEMPORARY TABLE IF EXISTS Temp_CustRemark;
	CREATE TEMPORARY TABLE 	Temp_CustRemark (
				HistoryID			BIGINT UNSIGNED NOT NULL PRIMARY KEY
			,	CustID				BIGINT UNSIGNED
			,	CategoryID			INT
			,	SourceTypeID		SMALLINT UNSIGNED
			,	Remark				TEXT
			,	KEY IX_Temp_CustRemark_CateID(CategoryID)	
	);

	INSERT IGNORE INTO Temp_CustRemark(HistoryID, CustID, CategoryID, SourceTypeID)
	SELECT  clh.ID
		,	clh.CustID
		,   clh.CategoryID
		,	clh.SourceTypeID
	FROM CTS_DataCenter.CTSCustomerClassification_BySport_History AS clh
	WHERE 	clh.CTSCustID = ip_CTSCustID AND clh.SportID = ip_SportID;

	UPDATE Temp_CustRemark AS tmp
		INNER JOIN CTS_DataCenter.CustomerCategorySettings AS cs ON cs.CategoryID = tmp.CategoryID AND cs.RemarkTemplateID IS NOT NULL
		INNER JOIN CTS_DataCenter.CustomerClassification_Remark AS cr ON cr.RemarkID = cs.RemarkTemplateID
	SET tmp.Remark = cr.RemarkTemplate;

	UPDATE Temp_CustRemark AS tmp
		INNER JOIN CTS_DataCenter.CustomerClassification_Remark AS cr ON cr.RemarkID = tmp.SourceTypeID
	SET tmp.Remark = cr.RemarkTemplate
	WHERE tmp.Remark IS NULL AND tmp.SourceTypeID IS NOT NULL;

    SELECT	clh.CustID
		,	clh.CTSCustID
		,	clh.SportID
		,	clh.CategoryID
        ,	(CASE WHEN clh.CategoryID IS NULL OR cat.CustomerClass IS NULL THEN '-' ELSE cat.CategoryName END) AS CategoryName
		,	clh.TargetCC
		,	clh.LastModifiedDate 
		,	IFNULL(us.UserName, clh.LastModifiedBy) AS CreatedBy
		,	TRIM(TRAILING '|' FROM TRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(tmpcr.Remark, 
							   '[Winloss]', IFNULL(FORMAT(clh.WinlossRM, 2),0))
							,   '[Margin]', CASE WHEN IFNULL(clh.TurnOverRM,0) = 0 THEN 0 ELSE ROUND((clh.WinlossRM/clh.TurnOverRM) * 100, 3) END)
							,   '[BetCount]', IFNULL(clh.BetCount,0))
							,   '[TurnOver]', IFNULL(FORMAT(clh.TurnOverRM, 2),0))
							,   '[ActiveDays]', IFNULL(clh.ActiveDays,0))
							,   '[Remark]', IFNULL(clh.Remark,''))
							,   '[MatchID]', CASE WHEN clh.Remark LIKE 'Auto MatchID: %' THEN REPLACE(clh.Remark,'Auto MatchID: ','') ELSE '' END)
							)) AS Remark
    FROM	CTS_DataCenter.CTSCustomerClassification_BySport_History AS clh
		LEFT JOIN Temp_CustRemark AS tmpcr ON tmpcr.HistoryID = clh.ID
		LEFT JOIN CTS_DataCenter.CustomerCategory AS cat ON clh.CategoryID = cat.CategoryID
        LEFT JOIN CTS_Admin.CTSUser AS us ON clh.LastModifiedBy = us.UserID
    WHERE	clh.CTSCustID = ip_CTSCustID AND clh.SportID = ip_SportID
    ORDER BY clh.LastModifiedDate DESC;
    
END$$
DELIMITER ;