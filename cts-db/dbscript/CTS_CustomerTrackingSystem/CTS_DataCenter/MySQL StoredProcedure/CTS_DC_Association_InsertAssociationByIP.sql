/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_InsertAssociationByIP`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_InsertAssociationByIP`(
		IN 	ip_CoupleIPStats 	JSON
	,	IN 	ip_ScanDate			DATETIME	
    ,	IN	ip_AssociationType	SMALLINT

	,	OUT op_ErrorMessage 	VARCHAR(200)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210315@Long.Luu
		Task:		Insert Association By IP [Redmine ID: #0000]
		DB:			CTS_DataCenter
		Original: 

		Revisions:
			- 20210315@Long.Luu: Created [Redmine ID: #0000]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]    
			- 20230227@Long.Luu: Support AssociationType [Redmine ID: #0000]        

		Example:
			- CALL CTS_DataCenter.CTS_DC_Association_InsertAssociationByIP ('[{"C1": 43600693, "C2": 45}]', '2021-01-11', @ErrorMessage);    
	*/ 
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN       
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;    

	#IF (ip_AssociationType = 1) THEN
		INSERT IGNORE INTO CTS_DataCenter.AssociationByIP(FromCustID, ToCustID, AssType, CreatedDate)
		SELECT 	tmpTable.CustID1
			, 	tmpTable.CustID2
            ,	ip_AssociationType
			,	ip_ScanDate
		FROM JSON_TABLE(ip_CoupleIPStats,
			 "$[*]" COLUMNS(
				  CustID1 		BIGINT UNSIGNED		PATH "$.C1"
				, CustID2		BIGINT UNSIGNED		PATH "$.C2"
			 )) AS tmpTable;       
	/*ELSE
		INSERT IGNORE INTO CTS_DataCenter.AssociationByIP_5G(FromCustID, ToCustID, CreatedDate, AssType)
		SELECT 	tmpTable.CustID1
			, 	tmpTable.CustID2
			,	ip_ScanDate
            ,	ip_AssociationType
		FROM JSON_TABLE(ip_CoupleIPStats,
			 "$[*]" COLUMNS(
				  CustID1 		BIGINT UNSIGNED		PATH "$.C1"
				, CustID2		BIGINT UNSIGNED		PATH "$.C2"
			 )) AS tmpTable;       
    END IF;*/
     
END$$	
DELIMITER ;