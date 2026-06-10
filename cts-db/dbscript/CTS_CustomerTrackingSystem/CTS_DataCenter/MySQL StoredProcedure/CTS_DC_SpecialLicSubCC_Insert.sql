/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_SpecialLicSubCC_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_SpecialLicSubCC_Insert`(
		IN ip_CustID		BIGINT UNSIGNED
    ,	IN ip_CustomerClass INT 
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Creator:	20250514@Casey.Huynh
		Task:	 	SpecialLicSubCC Source Inserted
		Server:  	CTSMain
		DBName:		CTS_DataCenter

		Revisions: 
				- 20250514@Casey.Huynh: 	Created [Redmine ID: #226847]

		Param's Explanation (filtered by): 

		Example:
			CALL CTS_DC_SpecialLicSubCC_Insert(@ip_Username:='HAIFAINH0112882',@ip_CustomerClass:=202);
	*/   
    
    DECLARE CONST_SUBSCRIBERID_HAIFA					INT DEFAULT 104;
    DECLARE CONST_ROLEID_MEMBER							TINYINT DEFAULT 1;   	
    DECLARE CONST_STATICLIST_LICSUBCUSTOMERCLASS		TINYINT DEFAULT 25;   
    DECLARE CONST_STATICLIST_LICSUBSTATUSCODE			TINYINT DEFAULT 26; 
	DECLARE CONST_STATICLIST_LICSUBSTATUSCODE_INVALID	SMALLINT DEFAULT 400;
    DECLARE CONST_STATICLIST_LICSUBSTATUSCODE_VALID		SMALLINT DEFAULT 300;
    DECLARE CONST_INSERTEDTIME							DATETIME(4) DEFAULT CURRENT_TIMESTAMP(4);
    DECLARE CONST_PROCESSSTATUS_COMPLETED				TINYINT DEFAULT 2;   
    
	DECLARE lv_CustID BIGINT UNSIGNED;
    DECLARE lv_StatusCode INT;
    DECLARE lv_ErrorMessage VARCHAR(200);
    DECLARE lv_MaxID INT DEFAULT 0;
	
    SELECT	cus.CustID 
    INTO 	lv_CustID 
    FROM CTS_DataCenter.CTSCustomer AS cus
    WHERE cus.CustID = ip_CustID
		AND cus.SubscriberID = CONST_SUBSCRIBERID_HAIFA
        AND cus.RoleID = CONST_ROLEID_MEMBER
        AND ip_CustomerClass IN (	SELECT stl.ItemValue 
									FROM CTS_DataCenter.StaticList AS stl 
                                    WHERE stl.ListID = CONST_STATICLIST_LICSUBCUSTOMERCLASS);    

    SET lv_MaxID = (SELECT MAX(ID) FROM CTS_DataCenter.Customer_SpecialLicSubCC);   

    IF (lv_CustID IS NOT NULL) THEN   
    
        SELECT	stl.ItemNameDisplay, 	stl.ItemValue
        INTO 	lv_ErrorMessage,		lv_StatusCode  
        FROM CTS_DataCenter.StaticList AS stl 
        WHERE stl.ListID = CONST_STATICLIST_LICSUBSTATUSCODE 
			AND stl.ItemValue = CONST_STATICLIST_LICSUBSTATUSCODE_VALID;
		
		INSERT INTO CTS_DataCenter.Customer_SpecialLicSubCC(CustID, APICustomerClass, InsertedTime)
		SELECT	ip_CustID
			,	ip_CustomerClass
			, 	CONST_INSERTEDTIME;
            
	ELSE     
    
		SELECT stl.ItemNameDisplay, stl.ItemValue
        INTO lv_ErrorMessage
			, lv_StatusCode  
        FROM CTS_DataCenter.StaticList AS stl 
        WHERE stl.ListID = CONST_STATICLIST_LICSUBSTATUSCODE 
			AND stl.ItemValue = CONST_STATICLIST_LICSUBSTATUSCODE_INVALID;   
            
		INSERT INTO CTS_DataCenter.Customer_SpecialLicSubCC(CustID, APICustomerClass, ProcessStatus, StatusCode, InsertedTime)
		SELECT	ip_CustID
			,	ip_CustomerClass
			,	CONST_PROCESSSTATUS_COMPLETED AS ProcessStatus
            ,	lv_StatusCode
			, 	CONST_INSERTEDTIME AS InsertedTime
		;            
	END IF;

    SELECT 	cus.ID
		,	cus.InsertedTime
	FROM CTS_DataCenter.Customer_SpecialLicSubCC AS cus
    WHERE cus.ID > lv_MaxID 
		AND InsertedTime = CONST_INSERTEDTIME;     

END$$
DELIMITER ;
