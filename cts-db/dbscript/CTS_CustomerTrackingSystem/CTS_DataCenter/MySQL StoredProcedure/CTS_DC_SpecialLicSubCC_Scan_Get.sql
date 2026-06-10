/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_SpecialLicSubCC_Scan_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_SpecialLicSubCC_Scan_Get`(
		IN ip_BatchSize INT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250514@Casey.Huynh
		Task:	 	SpecialLicSubCC Scan Get
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250514@Casey.Huynh: 	Created [Redmine ID: #226847]

		Param's Explanation (filtered by): 

		Example:
			CALL CTS_DC_SpecialLicSubCC_Scan_Get(@ip_BatchSize:=5);
	*/   
    IF EXISTS (SELECT 1 FROM CTS_DataCenter.Customer_SpecialLicSubCC AS cus WHERE cus.ProcessStatus = 1) THEN
        
        SELECT 0 AS 'CustID' 
        WHERE -1 = 1;
        
	ELSE
    
		SELECT 	cus.ID
			,	cus.CustID AS CustID
        FROM CTS_DataCenter.Customer_SpecialLicSubCC AS cus
        WHERE cus.ProcessStatus = 0 AND cus.CustID IS NOT NULL
        ORDER BY cus.ID ASC
        LIMIT ip_BatchSize;
        
    END IF;

END$$
DELIMITER ;
