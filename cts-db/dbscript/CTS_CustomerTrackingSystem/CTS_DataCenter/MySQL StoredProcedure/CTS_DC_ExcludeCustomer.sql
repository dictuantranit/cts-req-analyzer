/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="1"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_ExcludeCustomer`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_ExcludeCustomer`(
		IN ip_QueryType TINYINT
	,	IN ip_TableName VARCHAR(200)  
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230928@Casey.Huynh
		Task:		Exclude CustID from ip_CustIDList when Cust's SiteID exists in ip_StaticListID.ItemIDs [Redmine ID: 193050]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20230928@Casey.Huynh: Created [Redmine ID: 20230928]
		Param's Explanation (filtered by):
			- ip_QueryType:
				  + 1: ip_TableName table(CustID) JOIN CTSCustomer to get IsInternal value
				  + 2: ip_TableName((CustID, IsInternal)) table have IsInternal value
        Sample Data:          
        CALL CTS_DataCenter.CTS_DC_ExcludeCustomer(2,'table_name');
	*/
   
    #--Exclude CustID by SiteID from table 'ip_TableName'
    DROP TEMPORARY TABLE IF EXISTS Temp_CustExclude;
    CREATE TEMPORARY TABLE Temp_CustExclude(
		CustID BIGINT UNSIGNED PRIMARY KEY
	);
    
    /***********GET EXCLUDE CustID BY OddsFeedSite, 8RM, BARM, CashOut **********/
	IF(ip_QueryType = 1) THEN 		
		SET @insertStr =CONCAT(	"	INSERT INTO Temp_CustExclude(CustID)
									SELECT tbl.CustID
									FROM ",ip_TableName," AS tbl 
										INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON cus.CustID = tbl.CustID
										LEFT JOIN CTS_DataCenter.StaticList AS stl ON stl.ItemID = cus.SiteID
												AND stl.ListID = 11
										WHERE cus.IsInternal = 1 OR stl.ItemID IS NOT NULL");   

		PREPARE insertStr FROM @insertStr;
		EXECUTE insertStr;
    END IF;
    
    IF(ip_QueryType = 2) THEN 		
		SET @insertStr =CONCAT(	"	INSERT INTO Temp_CustExclude(CustID)
									SELECT tbl.CustID
									FROM ",ip_TableName," AS tbl 
										LEFT JOIN CTS_DataCenter.StaticList AS stl ON stl.ItemID = tbl.SiteID
												AND stl.ListID = 11
										WHERE tbl.IsInternal = 1 OR stl.ItemID IS NOT NULL");   

		PREPARE insertStr FROM @insertStr;
		EXECUTE insertStr;
    END IF;
    /*********************DELETE************************/
    SET @insertStr =CONCAT("DELETE  del
							FROM	",ip_TableName," AS del
								INNER JOIN Temp_CustExclude AS tmp ON del.CustID = tmp.CustID");   

	PREPARE insertStr FROM @insertStr;
	EXECUTE insertStr;

	/******************************************************************************/
END$$
DELIMITER ;