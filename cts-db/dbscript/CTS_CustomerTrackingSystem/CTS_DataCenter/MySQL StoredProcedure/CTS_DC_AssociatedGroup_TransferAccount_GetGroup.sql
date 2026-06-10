/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_TransferAccount_GetGroup`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_TransferAccount_GetGroup`(
		IN ip_GroupID			BIGINT
)
    SQL SECURITY INVOKER
BEGIN
	/* 
		Created:	20221206@Victoria.Le
		Task:		Get List GroupID
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20221206@Victoria.Le: Initial Writing [Redmine ID: #179398]
        
		Param's Explanation (filtered by):
			ip_GroupID: it's current group which need to exclude
            
        Example:			
			- CALL CTS_DataCenter.CTS_DC_AssociatedGroup_TransferAccount_GetGroup (3);
	*/
    
    SELECT GroupID, GroupName
    FROM AssociatedGroup
    WHERE GroupID != ip_GroupID
		AND IsDisable = 0;

END$$
DELIMITER ;