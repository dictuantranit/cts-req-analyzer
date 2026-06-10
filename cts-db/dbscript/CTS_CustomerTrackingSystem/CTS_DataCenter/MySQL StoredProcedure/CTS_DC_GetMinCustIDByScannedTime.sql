/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_GetMinCustIDByScannedTime`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_GetMinCustIDByScannedTime`(
		ip_FromCustID	INT
	,	ip_ToCustID		INT
	,	ip_TotalSecond	INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20250416@Casey.Huynh
		Task:		Insert Customer
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20250416@Casey.Huynh: [Redmine ID: #223443]            
            
		Param's Explanation (filtered by):
        
        CALL CTS_DataCenter.CTS_DC_GetMinCustIDByScannedTime(@ip_FromCustID:=179808692, @ip_ToCustID:=179808707, @ip_TotalSecond:=120);

	*/
	DECLARE lv_MinCreatedDate DATETIME;
	DECLARE lv_MaxCreatedDate DATETIME;

    SELECT cus.CreatedDate
    INTO lv_MaxCreatedDate
    FROM CTS_DataCenter.CTSCustomer AS cus
    WHERE cus.CustID = ip_ToCustID
		AND cus.CustSubID = 0;
    
    SET lv_MinCreatedDate = DATE_SUB(lv_MaxCreatedDate, INTERVAL ip_TotalSecond SECOND);

	SELECT cus.CustID
	FROM CTS_DataCenter.CTSCustomer AS cus
	WHERE cus.CustID > ip_FromCustID
		AND cus.CustID < ip_ToCustID
		AND cus.CreatedDate <= lv_MinCreatedDate
	ORDER BY cus.CreatedDate DESC, cus.CustID DESC
    LIMIT 1;

END$$
DELIMITER ;
