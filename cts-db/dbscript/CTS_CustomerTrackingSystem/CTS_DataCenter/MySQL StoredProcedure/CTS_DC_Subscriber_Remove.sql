/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin,ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP procedure IF EXISTS `CTS_DC_Subscriber_Remove`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Subscriber_Remove`(
		IN ip_SubscriberID		INT UNSIGNED
	,	IN ip_UserID 			INT

    , 	OUT op_ErrorMessage 	VARCHAR(200)
)
	SQL SECURITY INVOKER
sp: BEGIN
/*
		Created:	20200914@Roger.Le
		Task :		Function add new subscriber
		DB:			CTS_DataCenter && CTS_Admin
		Original: 

		Revisions:
            - 20200914@Roger.Le: Created [Redmine ID: #138102]
            - 20200924@Lex.Khuat: Spec changes, terminating now deactivates whole sub including all sites [Redmine ID: #138102]
			- 20210702@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
            
            
		Param's Explanation:
	*/
    
    DECLARE lv_CurrentTime		DATETIME DEFAULT CURRENT_DATE();
    DECLARE lv_SPName 			VARCHAR(200)	DEFAULT 'CTS_DC_Subscriber_Remove';
    
	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
    
    IF (IFNULL(ip_SubscriberID, 0) = 0) THEN
		SET op_ErrorMessage = 'Invalid SubscriberID to terminate';
		LEAVE sp;
	END IF;
    
	#========= TERMINATE SUBSCRIBER =========
    UPDATE 	CTS_Admin.Subscriber AS sub
	SET		sub.TerminatedDate = lv_CurrentTime
		,	sub.SubscriberStatus = -1
    WHERE sub.SubscriberID = ip_SubscriberID;
    
    #========= TERMINATE ALL SITE MAPPINGS =========
    UPDATE 	CTS_DataCenter.MappingSubscriberSite AS map
	SET		map.SubscriberStatus = -1
    WHERE map.SubscriberID = ip_SubscriberID;

	INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	SELECT	26
		,	lv_SPName
		,	CONCAT('Terminate subscriber: SubID_', SubscriberID, '; SubName_', SubscriberName, '; SubPrefix_', SubscriberPrefix, '; SubType_', SubscriberType, '; IsTest_', IsTest)
		,	lv_CurrentTime
		,	ip_UserID
	FROM CTS_Admin.Subscriber
	WHERE SubscriberID = IFNULL(ip_SubscriberID, 0);

END$$

DELIMITER ;

