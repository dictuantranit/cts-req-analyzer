/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_Transform_UnhandleSubscriberAction`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_UnhandleSubscriberAction`(
        IN ip_FromTransID       BIGINT UNSIGNED
    ,   IN ip_ToTransID         BIGINT UNSIGNED
)
SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20190730@Casey.Huynh
	    Task :  Filter Unhandled Subscriber by IsProcessed = -1, Action Result
	    DB: DCS_RawTransaction(rtaging)
	    Original:

	    Revisions:
	        - 20201006@CaseyHuynh: Move New Server, Move table RawTransaction from DB "DCS_RawTransaction" to "DCS_DataCenter" [Redmine ID: #143011]
            - 20201019@CaseyHuynh:	Move Server, Phase 2 [Redmine ID: #143011]
            - 20201111@CaseyHuynh: Remove code  "Insert New Subscriber To Subscriber table when Subscriber Is Invalid" [Redmine ID: #144307]
            - 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]
            - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]

	    Param's Explanation (filtered by):
	*/
    
	DECLARE	lv_UnhandleStatus_Subscriber	BIT(16) DEFAULT 1;
    DECLARE	lv_UnhandleStatus_Action	    BIT(16) DEFAULT 2;
    DECLARE lv_UnhandleStatus	            TINYINT DEFAULT 0;
    DECLARE lv_NotTransformedStatus         BIT(16);
    
	DROP TEMPORARY TABLE IF EXISTS Temp_Transaction;
    CREATE TEMPORARY TABLE Temp_Transaction (	
		    TransID			    BIGINT
		,   SubscriberName		VARCHAR(50)
        ,   Action				VARCHAR(100)
        ,   ActionResult		VARCHAR(100)
        ,   URLDetails			VARCHAR(250)
        ,   TransStatus			INT
        ,   CreatedDate			DATETIME	#	Date Only        
        ,   SubscriberID		INT
		,   SubscriberStatus	TINYINT
        ,   ActionResultID		BIGINT
        ,   ActionResultStatus	TINYINT        
        ,   IsProcessed			BIT	DEFAULT 0
    );
        
    INSERT	INTO Temp_Transaction(TransID, SubscriberName, Action, ActionResult, URLDetails, TransStatus, CreatedDate, SubscriberID, SubscriberStatus, ActionResultID, ActionResultStatus)
    SELECT 	rt.TransID
	    ,   rt.SubscriberName
        ,   rt.Action
        ,   rt.ActionResult
        ,   rt.URL
        ,   rt.TransStatus
        ,   rt.CreatedDate
        ,   su.SubscriberID
        ,   su.SubscriberStatus
        ,   ActionResultID
        ,   ActionResultStatus
	FROM	DCS_DataCenter.RawTransaction AS rt
	    LEFT JOIN	CTS_Admin.Subscriber AS su ON rt.SubscriberName = su.SubscriberName AND su.DCSStatus = 1
	    LEFT JOIN	DCS_DataCenter.ActionResult AS ar ON rt.Action = ar.Action AND rt.ActionResult = ar.ActionResult
    WHERE	rt.TransID BETWEEN ip_FromTransID AND ip_ToTransID
	    AND rt.IsProcessed = 0;       
   
   
    #==UNHANDLE ACTION================================================================    
	INSERT IGNORE INTO DCS_DataCenter.ActionResult (Action, ActionResult, CreatedDate, ActionResultStatus)
	SELECT  Action 
	    ,   ts.ActionResult AS ActionResult
	    ,   MIN(ts.CreatedDate)	AS CreatedDate
	    ,   lv_UnhandleStatus AS ActionResultStatus # lv_UnhandleStatus_Subscriber
    FROM Temp_Transaction AS ts
    GROUP BY ts.Action
        ,    ts.ActionResult;
	
	
    SET lv_NotTransformedStatus = DCS_DC_GetTransStatus_NotTransformed();

    #===Update NOT Transform status for the Invalid Transaction (Invalid Subscriber)
    UPDATE Temp_Transaction AS ts
	SET TransStatus = TransStatus | lv_UnhandleStatus_Subscriber
    WHERE   ts.SubscriberID IS NULL
	    OR  ts.SubscriberStatus = lv_UnhandleStatus;
    
	#===Update NOT Transform status for the Invalid Action Result(Invalid Action Result)
    UPDATE Temp_Transaction AS ts
	SET TransStatus = TransStatus | lv_UnhandleStatus_Action
    WHERE   ts.ActionResultID IS NULL
	    OR  ts.ActionResultStatus = lv_UnhandleStatus; 
   
    UPDATE DCS_DataCenter.RawTransaction AS rt
        INNER JOIN	Temp_Transaction AS ts ON rt.TransID = ts.TransID
	SET     rt.IsProcessed = CASE WHEN (ts.TransStatus & lv_NotTransformedStatus) != 0 THEN -1 ELSE rt.IsProcessed END 
	    ,   rt.TransStatus = ts.TransStatus;
   
    
END$$
DELIMITER ;
