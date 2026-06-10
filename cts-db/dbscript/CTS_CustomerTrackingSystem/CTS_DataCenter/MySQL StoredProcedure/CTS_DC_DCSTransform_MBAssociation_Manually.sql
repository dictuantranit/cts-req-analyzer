/*<info serverAlias="CTSMain-CTS_Adhoc" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_DCSTransform_MBAssociation_Manually`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_DCSTransform_MBAssociation_Manually`(
	IN ip_BatchSize INT
)
  SQL SECURITY INVOKER
BEGIN
/*
		Created:	20250409@Casey.Huynh
		Task:		Transform Association to CTS
		DB:			CTS_DataCenter
		Original:

		Revisions:
      - 20250409@CaseyHuynh: Created [Redmined: #221973]

		Param's Explanation (filtered by):
        
	*/  
	DECLARE CONST_SYSTEMPARAM_LASTASSID INT DEFAULT 191;
    
    DECLARE lv_LastAssID	BIGINT UNSIGNED;
	DECLARE lv_MaxAssID		BIGINT UNSIGNED;
  
	DROP TEMPORARY TABLE IF EXISTS Temp_MBAssociation;
	CREATE TEMPORARY TABLE Temp_MBAssociation (	
			MBAssID			BIGINT UNSIGNED PRIMARY KEY
		,	MBAccountID		BIGINT UNSIGNED
		,	MBDeviceID		BIGINT UNSIGNED
		,	SubscriberID	INT UNSIGNED
		,	CreatedTime		DATETIME(4)
		,	CTSCustID		BIGINT UNSIGNED
        
        ,	INDEX IX_Temp_MBAssociation_MBAccountID(CTSCustID, MBDeviceID)
	);  
    
    SET lv_LastAssID = 0;
    
    SELECT MAX(ass.ID)
    INTO lv_MaxAssID
    FROM DCS_DataCenter.MBAssociation AS ass;
    
    WHILE (lv_LastAssID < lv_MaxAssID) DO
		
        DELETE tmpAss 
        FROM Temp_MBAssociation AS tmpAss;
        
		INSERT  INTO Temp_MBAssociation(MBAssID, MBAccountID, MBDeviceID, SubscriberID, CTSCustID, CreatedTime)        
		SELECT	ass.ID
			,	ass.MBAccountID
            ,	ass.MBDeviceID
			,	ass.SubscriberID
            ,	cus.CTSCustID
            ,	ass.CreatedTime
		FROM 	DCS_DataCenter.MBAssociation AS ass
			LEFT JOIN CTS_DataCenter.CustDCSMBAccount AS cus ON ass.MBAccountID = cus.MBAccountID
		WHERE	ass.IsCTSTransformed = 0
			AND ass.ID > lv_LastAssID
			AND ass.ID <= lv_MaxAssID
		ORDER BY ass.ID ASC
		LIMIT	ip_BatchSize;
        
        INSERT IGNORE INTO CTS_DataCenter.AssociationByMBDevice(CTSCustID, MBDeviceID, SubscriberID, CreatedTime, InsertedTime)
        SELECT	tmpAss.CTSCustID
			,	tmpAss.MBDeviceID
            ,	tmpAss.SubscriberID
            ,	MIN(tmpAss.CreatedTime)
            ,	CURRENT_TIMESTAMP(4) AS InsertedTime
        FROM Temp_MBAssociation AS tmpAss
        WHERE tmpAss.CTSCustID IS NOT NULL
        GROUP BY tmpAss.CTSCustID
			,	tmpAss.MBDeviceID
            ,	tmpAss.SubscriberID;    
        		
        UPDATE DCS_DataCenter.MBAssociation AS ass
			INNER JOIN Temp_MBAssociation AS tmpAss ON tmpAss.MBAssID = ass.ID 
		SET ass.IsCTSTransformed = 1
        WHERE tmpAss.CTSCustID IS NOT NULL;
        
        SET lv_LastAssID = (SELECT MAX(MBAssID) FROM Temp_MBAssociation);        
		
		UPDATE CTS_DataCenter.SystemParameter AS sys
        SET sys.ParameterValue = IFNULL(lv_LastAssID,0)
		WHERE sys.ParameterID = CONST_SYSTEMPARAM_LASTASSID;        
        
	END WHILE;

    
END$$

DELIMITER ;
