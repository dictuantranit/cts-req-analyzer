/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_UpdateAssociationRemove`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_UpdateAssociationRemove`(
		OUT op_ErrorMessage 	VARCHAR(200)
    ,	IN ip_FromSubscriberID 	INT
    ,	IN ip_FromCTSCustID		BIGINT UNSIGNED
    ,	IN ip_ToSubscriberID	INT
    ,	IN ip_ToCTSCustID		BIGINT UNSIGNED
    ,	IN ip_Remark			VARCHAR(500)
    ,	IN ip_CreatedBy			INT
    ,	IN ip_IsActionRemove 	BIT)
    
    SQL SECURITY INVOKER
    
BEGIN
	/*
		Created:	20200416@Long.Luu	
		Task :		Update Association Remove table
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20200416@Long.Luu: Created [Redmine ID: #131506]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
            - 20220120@Casey.Huynh: Enhance Add Column CustID [Redmine ID: #157203]
            
		Param's Explanation:
	*/ 
 
    
	DECLARE lv_LeastCTSCustID 		BIGINT UNSIGNED;
    DECLARE lv_LeastSubscriberID 	INT;
    DECLARE lv_LeastCustID		 	INT;
    DECLARE lv_LeastCustSubID	 	INT;    
    DECLARE lv_GreatestCTSCustID 	BIGINT UNSIGNED;
    DECLARE lv_GreatestSubscriberID INT;
    DECLARE lv_GreatestCustID		INT;
    DECLARE lv_GreatestCustSubID	INT;
    DECLARE lv_FromCustID			INT;
    DECLARE lv_FromCustSubID		INT;
    DECLARE lv_ToCustID				INT;
    DECLARE lv_ToCustSubID			INT;
 
	DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN         
        GET DIAGNOSTICS CONDITION 1 op_ErrorMessage = MESSAGE_TEXT;
    END;
    
    SELECT cus.CustID, cus.CustSubID
	INTO lv_FromCustID, lv_FromCustSubID
    FROM CTS_DataCenter.CTSCustomer AS cus
    WHERE cus.CTSCustID = ip_FromCTSCustID;
    
    SELECT cus.CustID, cus.CustSubID
	INTO lv_ToCustID, lv_ToCustSubID
    FROM CTS_DataCenter.CTSCustomer AS cus
    WHERE cus.CTSCustID = ip_ToCTSCustID;    
    
	IF ip_FromCTSCustID = ip_ToCTSCustID
		THEN
			SET op_ErrorMessage = 'The Source & Target nodes are the same!';
		ELSE
			IF ip_FromCTSCustID < ip_ToCTSCustID
				THEN
					SET 	lv_LeastCTSCustID = ip_FromCTSCustID
                        ,	lv_LeastSubscriberID = ip_FromSubscriberID						
						,	lv_GreatestCTSCustID = ip_ToCTSCustID
                        ,	lv_GreatestSubscriberID = ip_ToSubscriberID;
				ELSE	                        
					SET 	lv_LeastCTSCustID = ip_ToCTSCustID
                        ,	lv_LeastSubscriberID = ip_ToSubscriberID
                        ,	lv_GreatestCTSCustID = ip_FromCTSCustID
						,	lv_GreatestSubscriberID = ip_FromSubscriberID;						
			END IF;
            
            IF lv_FromCustID < lv_ToCustID
				THEN
					SET 	lv_LeastCustSubID = lv_FromCustSubID
						,	lv_LeastCustID = lv_FromCustID
						,	lv_GreatestCustSubID = lv_ToCustSubID
						,	lv_GreatestCustID = lv_ToCustID;
				ELSE					
					SET 	lv_LeastCustID = lv_ToCustID
                        ,	lv_LeastCustSubID = lv_ToCustSubID
						,	lv_GreatestCustSubID = lv_FromCustSubID
						,	lv_GreatestCustID = lv_FromCustID;
			END IF;
            

			IF (ip_IsActionRemove = 1)
				THEN
					DELETE FROM CTS_DataCenter.AssociationRemove
					WHERE FromCTSCustID = lv_LeastCTSCustID AND ToCTSCustID = lv_GreatestCTSCustID;
                    
                    INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
					VALUES(9, 'CTS_DC_Association_UpdateAssociationRemove', CONCAT('Delete Association Remove: ip_FromCTSCustID_', lv_LeastCTSCustID, ';ip_ToCTSCustID_', lv_GreatestCTSCustID,')'), CURRENT_TIME(), ip_CreatedBy);    
                ELSE					
					INSERT INTO CTS_DataCenter.AssociationRemove(FromSubscriberID, FromCTSCustID, LeastCustID, LeastCustSubID, ToSubscriberID, ToCTSCustID, GreatestCustID, GreatestCustSubID, Remark, CreatedDate, CreatedBy)
					VALUES(lv_LeastSubscriberID,lv_LeastCTSCustID, lv_LeastCustID, lv_LeastCustSubID, lv_GreatestSubscriberID, lv_GreatestCTSCustID, lv_GreatestCustID, lv_GreatestCustSubID, ip_Remark, CURRENT_TIME(), ip_CreatedBy);
				   
					INSERT INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
					VALUES(8, 'CTS_DC_Association_UpdateAssociationRemove', CONCAT('Insert Association Remove: ip_FromCTSCustID_', lv_LeastCTSCustID, ';ip_ToCTSCustID_', lv_GreatestCTSCustID,')'), CURRENT_TIME(), ip_CreatedBy);
			END IF;
    END IF;
END$$

DELIMITER ;