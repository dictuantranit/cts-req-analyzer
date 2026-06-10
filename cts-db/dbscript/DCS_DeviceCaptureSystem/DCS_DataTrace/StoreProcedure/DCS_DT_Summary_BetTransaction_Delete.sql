/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Summary_BetTransaction_Delete`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Summary_BetTransaction_Delete`(
    IN ip_TransDate DATE
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20231020@Jonathan.Doan
	Task : Delete data from BetTransactionSummary
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20231020@Jonathan.Doan: Created [Redmine ID: 195332]
		
	Param's Explanation (filtered by):

	Example:
		SET sql_safe_updates = 0;
        CALL DCS_DataTrace.DCS_DT_Summary_BetTransaction_Delete('2023-10-01');
	*/
    
    DELETE FROM DCS_DataTrace.BetTransactionSummary
    WHERE TransDate = ip_TransDate;
    
END$$
DELIMITER ;
