/*<info serverAlias="CTSMain-DCS_DataTrace" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DT_Summary_MemberMissingTransaction_DeleteByDate`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DT_Summary_MemberMissingTransaction_DeleteByDate`(
        IN ip_TransDate  	DATE
	,	IN ip_MissingType  	SMALLINT
)
SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20231017@Jonathan.Doan
	Task : Delete MemberMissingTransaction by Date
	DB: DCS_DataTrace
	Original:

	Revisions:
		- 20231017@Jonathan.Doan: Created [Redmine ID: 194933]
		
	Param's Explanation (filtered by):

	Example:
        CALL DCS_DataTrace.DCS_DT_Summary_MemberMissingTransaction_DeleteByDate('2023-10-17', 0);
	*/
    
    DELETE FROM DCS_DataTrace.MemberMissingTransaction
    WHERE TransDate = ip_TransDate
		AND MissingTransactionType = ip_MissingType;
    
END$$
DELIMITER ;
