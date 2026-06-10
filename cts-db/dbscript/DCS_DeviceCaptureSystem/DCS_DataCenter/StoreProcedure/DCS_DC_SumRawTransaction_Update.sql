/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_SumRawTransaction_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_SumRawTransaction_Update`(
		IN ip_SumJson	JSON  
)
    SQL SECURITY INVOKER
BEGIN
    /*
	    Created: 20210930@Casey.Huynh
	    Task : Update TransSum
	    DB: DCS_DataCenter (Master)
	    Original:

	    Revisions:		    
			-	20210930@Casey.Huynh: Created [Redmine ID: 161528]
            
	    Param's Explanation (filtered by):
        
        Example: CALL DCS_DC_SumRawTransaction_Update('[{"TransDate":"2021-09-30", "SubscriberID":2, "TransTotal":2800}
														,{"TransDate":"2021-09-30", "SubscriberID":2, "TransTotal":2900}]');
    */
  
    INSERT INTO DCS_DataCenter.SumRawTransaction(TransDate, SubscriberID, TransTotal)
	SELECT 	js.TransDate
		,	js.SubscriberID
        ,	js.TransSum
		FROM JSON_TABLE(ip_SumJson,
			"$[*]" COLUMNS(
				TransDate		DATETIME PATH "$.TransDate"
            ,   SubscriberID	INT PATH "$.SubscriberID" 
			,	TransSum		INT PATH "$.TransTotal" 
			)
		) AS js
	ON DUPLICATE KEY UPDATE TransTotal = TransTotal + js.TransSum;    
    
END$$
DELIMITER ;
