/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_ExcludeCustByCondition`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_ExcludeCustByCondition`(
	IN ip_TableName VARCHAR(200)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210507@Casey.Huynh
		Task:		Exclude CustID from ip_CustIDList when Cust's SiteID exists in ip_StaticListID.ItemIDs [Redmine ID: 154694]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20210507@Casey.Huynh: Created [Redmine ID: 154694]
            - 20220519@Casey.Huynh: Update Get IsInternal FROM CTSCustomer
		Param's Explanation (filtered by):
            - ip_TableName: the table name include CustID column
        CALL CTS_DataCenter.CTS_DC_ExcludeCustByCondition('table_name');
	*/
    
    #--Exclude CustID by SiteID from table 'ip_TableName'
    DROP TEMPORARY TABLE IF EXISTS Temp_CustExclude;
    CREATE TEMPORARY TABLE Temp_CustExclude(
		CustID BIGINT UNSIGNED
	);
    
    /***********GET EXCLUDE CustID BY OddsFeedSite, 8RM, BARM, CashOut **********/
	SET @insertStr =CONCAT(	"	INSERT INTO Temp_CustExclude(CustID)
								SELECT tbl.CustID
								FROM ",ip_TableName," as tbl 
									INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tbl.CustID
									LEFT JOIN CTS_DataCenter.StaticList AS stl ON stl.ItemID = cus.SiteID
											AND stl.ListID = 11
									WHERE cus.IsInternal = 1 OR stl.ItemID IS NOT NULL");   

	PREPARE insertStr FROM @insertStr;
	EXECUTE insertStr;
    
    /*********************DELETE************************/
    SET @insertStr =CONCAT("DELETE  del
							FROM	",ip_TableName," AS del
								INNER JOIN Temp_CustExclude AS tmp ON del.CustID = tmp.CustID");   

	PREPARE insertStr FROM @insertStr;
	EXECUTE insertStr;

	/******************************************************************************/
END$$
DELIMITER ;