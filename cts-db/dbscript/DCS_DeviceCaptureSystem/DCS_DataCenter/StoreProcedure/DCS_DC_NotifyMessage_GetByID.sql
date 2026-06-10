/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_NotifyMessage_GetByID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_NotifyMessage_GetByID`(
		IN ip_NotifyMessageID	INT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20230615@Jonathan.Doan
	    Task : Get NotifyMessage
	    DB: DCS_DataCenter
	    Original:

	    Revisions:		    
			-	20230615@Jonathan.Doan: Created [Redmine ID: 189732]
            
	    Param's Explanation (filtered by):
        
        Example: CALL DCS_DC_NotifyMessage_GetByID(1);
    */
    DECLARE lv_NotSent TINYINT(1) DEFAULT 0;
    
	SELECT	ID
		,	GroupID
		,	Title
		,	Message
		,	MoreInfo
    FROM DCS_DataCenter.NotifyMessage
    WHERE ID = ip_NotifyMessageID
		AND IsNotified = lv_NotSent;
    
END$$
DELIMITER ;
