/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_TransferAccount_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_TransferAccount_Update`(
		IN ip_CTSCustIDs 		LONGTEXT
	,	IN ip_FromGroupID		BIGINT UNSIGNED
    ,	IN ip_ToGroupID			BIGINT UNSIGNED
    ,	IN ip_ModifiedBy 		INT UNSIGNED 
)
    SQL SECURITY INVOKER
BEGIN
	/* 
		Created:	20221206@Victoria.Le
		Task:		Update GroupID when Trasfer Account
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20221206@Victoria.Le: Initial Writing [Redmine ID: #179398]
        
		Param's Explanation (filtered by):
			ip_CTSCustIDs: string (CTSCustID1,CTSCustID2,CTSCustID3)
            ip_FromGroupID: GroupID of source group
            ip_ToGroupID: GroupID of target group
            ip_CreatedBy: UserID 
            
        Example:			
			- CALL CTS_DataCenter.CTS_DC_AssociatedGroup_TransferAccount_Update ('');
	*/
    DECLARE lv_AssociatedGroup_ABI TINYINT;
    DECLARE lv_AssociatedGroup_Ori TINYINT;
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
	CREATE TEMPORARY TABLE 	Temp_Cust (
			CTSCustID 		BIGINT UNSIGNED PRIMARY KEY
		,	CustID			INT	UNSIGNED
		,	Danger1			TINYINT DEFAULT NULL
        ,	Danger2			TINYINT DEFAULT NULL
	);
    
    SELECT ABI, Danger1
    INTO lv_AssociatedGroup_ABI, lv_AssociatedGroup_Ori
    FROM CTS_DataCenter.AssociatedGroup
    WHERE GroupID = ip_ToGroupID;
    
    SET lv_AssociatedGroup_ABI = IFNULL(lv_AssociatedGroup_ABI,0);
    SET lv_AssociatedGroup_Ori = IFNULL(lv_AssociatedGroup_Ori,0);
    
    INSERT INTO Temp_Cust (CTSCustID, CustID, Danger1, Danger2)
    SELECT cus.CTSCustID, cus.CustID, cus.Danger1, cus.Danger2
    FROM JSON_TABLE(CONCAT('[',ip_CTSCustIDs,']'),'$[*]' COLUMNS(NESTED PATH '$' COLUMNS (CTSCustID BIGINT UNSIGNED PATH '$'))) AS temp
		INNER JOIN CTS_DataCenter.CTSCustomer AS cus ON temp.CTSCustID = cus.CTSCustID;
        
    UPDATE CTS_DataCenter.AssociatedGroupAccount AS acc
		INNER JOIN Temp_Cust AS temp ON temp.CTSCustID = acc.CTSCustID
	SET 	acc.GroupID = ip_ToGroupID
		,	acc.LastModifiedDate = NOW()
        ,	acc.LastModifiedBy = ip_ModifiedBy
    WHERE acc.GroupID = ip_FromGroupID;
	
	SELECT GROUP_CONCAT(CustID) AS CustIDs, lv_AssociatedGroup_Ori AS Ori, lv_AssociatedGroup_ABI AS ABI
	FROM Temp_Cust;
END$$
DELIMITER ;