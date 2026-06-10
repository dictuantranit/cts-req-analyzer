/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociationGroupByAI_Insert`;

DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociationGroupByAI_Insert`(
		IN ip_GroupInfo	 			JSON
	,	IN ip_MaxGroupLength		SMALLINT UNSIGNED
    
    ,	OUT op_ErrorMessage 		VARCHAR(200)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20220404@Long.Luu
		Task:		Insert Association Group [Redmine ID: #0000]
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20220404@Long.Luu: Created [Redmine ID: #0000]
            
		Example:
			call CTS_DataCenter.CTS_DC_AssociationGroupByAI_Insert ('[{"G": 123, "C": "1,2,3,4,5,6,7,8"}]',10,@ErrorMessage);    
	*/        
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_GroupInfo;    
	CREATE TEMPORARY TABLE Temp_GroupInfo(	  	
			GroupID						BIGINT UNSIGNED
		,	OriginGroupID				BIGINT UNSIGNED
		, 	CustIDList					TEXT
        ,	PRIMARY KEY 				PK_Temp_Temp_GroupInfo(GroupID)
	); 
    
    INSERT INTO Temp_GroupInfo(GroupID, CustIDList)
	SELECT 	tmpTable.GroupID
		, 	tmpTable.CustIDList
	FROM JSON_TABLE(ip_GroupInfo,
		 "$[*]" COLUMNS(
				GroupID 				BIGINT UNSIGNED		PATH "$.G"
            , 	CustIDList 				TEXT				PATH "$.C"
		 )) AS tmpTable;  
    
    INSERT IGNORE INTO CTS_DataCenter.AssociationGroupByAI(GroupID,OriginGroupID,CustID,CreatedDate)
    WITH RECURSIVE v_pointer AS (
		SELECT 1 AS rowID
		UNION ALL
		SELECT rowID + 1
		FROM v_pointer
		WHERE rowID < ip_MaxGroupLength
	)
	SELECT 	t.GroupID
		,	t.GroupID
		,	SUBSTRING_INDEX(SUBSTRING_INDEX(t.CustIDList, ',', p.rowID), ',', -1)
        ,	NOW()
	FROM v_pointer AS p
		INNER JOIN Temp_GroupInfo AS t ON CHAR_LENGTH(t.CustIDList) - CHAR_LENGTH(REPLACE(t.CustIDList, ',', '')) >= p.rowID - 1;
     
END$$	
DELIMITER ;