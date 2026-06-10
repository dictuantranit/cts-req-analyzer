/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_InsertManualMultiple`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_InsertManualMultiple`(
		IN ip_ManualAssociationList 	JSON
)
SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200622@Harvey
		Task :		Add manual association muptiple
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20200416@Harvey.Nguyen: Initial	 		[Redmine ID: #136212]
            - 20210527@Aries.Nguyen: Cannot insert Exception Customers [Redmine ID: #155916]
            - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
            
		Param's Explanation:
        
        Example:
            -CALL CTS_DataCenter.CTS_DC_Association_InsertManualMultiple ('[{"FromSubscriberID":2,"FromCTSCustID":1,"ToSubscriberID":2,"ToCTSCustID":2,"Remark":"test","CreatedBy":"8"},{"FromSubscriberID":2,"FromCTSCustID":1,"ToSubscriberID":2,"ToCTSCustID":4,"Remark":"test","CreatedBy":"8"}]')
	*/ 

    DECLARE lv_CreatedBy 		BIGINT;
    DECLARE lv_FromCTSCustId 	VARCHAR(500);
    DECLARE lv_ToCTSCustId 		VARCHAR(500);

    DROP TEMPORARY TABLE IF EXISTS Temp_ManualAssociation;
	CREATE TEMPORARY TABLE Temp_ManualAssociation( 	 
		     FromSubscriberID 	INT
        , 	 FromCTSCustID 		BIGINT UNSIGNED
        ,	 ToSubscriberID 	INT
        , 	 ToCTSCustID 		BIGINT
        , 	 Remark 			VARCHAR(500)
        , 	 CreatedBy 			BIGINT
    );
 
	INSERT INTO Temp_ManualAssociation
	SELECT  FromSubscriberID 
        ,	FromCTSCustID 
        ,	ToSubscriberID 
        ,	ToCTSCustID
        ,	Remark
        ,	CreatedBy
	FROM JSON_TABLE(ip_ManualAssociationList,
		 "$[*]" COLUMNS(
		        FromSubscriberID 	INT 			PATH "$.FromSubscriberID"
		    ,   FromCTSCustID		BIGINT UNSIGNED	PATH "$.FromCTSCustID" 
		    ,   ToSubscriberID	    BIGINT			PATH "$.ToSubscriberID" 
            ,   ToCTSCustID		    INT 			PATH "$.ToCTSCustID" 
		    ,   Remark			    VARCHAR(500) 	PATH "$.Remark" 
		    ,   CreatedBy			BIGINT		 	PATH "$.CreatedBy" 
	)) AS tmpTable;

    
	INSERT INTO CTS_DataCenter.AssociationByManual(FromSubscriberID, FromCTSCustID, ToSubscriberID, ToCTSCustID, Remark, CreatedDate, CreatedBy)
	SELECT  CASE WHEN tma.FromCTSCustID > tma.ToCTSCustID THEN tma.ToSubscriberID ELSE tma.FromSubscriberID END
        ,	CASE WHEN tma.FromCTSCustID > tma.ToCTSCustID THEN tma.ToCTSCustID ELSE tma.FromCTSCustID END
        ,	CASE WHEN tma.FromCTSCustID > tma.ToCTSCustID THEN tma.FromSubscriberID ELSE tma.ToSubscriberID END
        ,	CASE WHEN tma.FromCTSCustID > tma.ToCTSCustID THEN tma.FromCTSCustID ELSE tma.ToCTSCustID END
        ,	tma.Remark
        , 	CURRENT_TIME()
        ,	tma.CreatedBy
    FROM Temp_ManualAssociation tma;
    
    SELECT DISTINCT CreatedBy
    INTO lv_CreatedBy
    FROM Temp_ManualAssociation
    LIMIT 1;
    
    SELECT GROUP_CONCAT(DISTINCT FromCTSCustID SEPARATOR ',') 
    INTO lv_FromCTSCustId
    FROM Temp_ManualAssociation;
    
    SELECT GROUP_CONCAT(ToCTSCustID SEPARATOR ',') 
    INTO lv_ToCTSCustId
    FROM Temp_ManualAssociation;    
   
	INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	VALUES(7, 'CTS_DC_Association_InsertManualMultiple', CONCAT('Insert Manual Multiple Association: ip_FromCTSCustID: ', lv_FromCTSCustId,'; ip_ToCTSCustIDList: ', lv_ToCTSCustId), CURRENT_TIME(), lv_CreatedBy);
	
END$$	
DELIMITER ;