/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsService" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_CustInfo_GetByCustIDs`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_CustInfo_GetByCustIDs`(
		IN ip_CustIDList TEXT
    ,	IN ip_SourceType TINYINT
)
	SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20210115@Casey.Huynh
		Task:		CTSCustomer Flow [Redmine ID: 148849]
		DB:			CTS_DataCenter
		Original:
		Revisions:
			- 20210115@Casey.Huynh: Created [Redmine ID: 148849]
            - 20210208@Casey.Huynh: Implement Get info by Update from Customer_History [Redmine ID: 149941]
            - 20210423@CaseyHuynh: Update CTSCustomer (Credit Cust Status) by CustProductStatus_History [Redmine ID: #152259]
			- 20221205@Victoria.Le:	 Get more data: danger4, dange5, DangerSabaSc (Saba Soccer) and DangerSabaBkb (Saba Baseketball) [Redmine ID: #181208]
            
		Param's Explanation (filtered by):
			ip_CustIDList: String (custid01,custid02, custid03)
		Example: CALL CTS_DataCenter.CTS_DC_CTSCustomer_GetInfoByCustIDList ('123,124,125')
	*/  
		CALL CTS_DC_Sys_SplitStringToTempItemTable(ip_CustIDList,',','BIGINT');
        
        IF ip_SourceType = 3
        THEN
			SELECT 	CustID
				,	CustStatusID
			FROM		CTS_DataCenter.CTSCustomer AS cus
				INNER JOIN	TempItemTable AS tmpCus ON cus.CustID = tmpCus.Item
			WHERE		CustSubID = 0;
        END IF;
        
        IF ip_SourceType = 2
        THEN      
			SELECT 	CustID
				,	CustStatusID
				,	Danger1
				,	Danger2
				,	Danger3
				,	Danger4
				,	Danger5
				,	DangerSabaSc
				,	DangerSabaBkb
			FROM		CTS_DataCenter.CTSCustomer AS cus
				INNER JOIN	TempItemTable AS tmpCus ON cus.CustID = tmpCus.Item
			WHERE		CustSubID = 0;
		END IF;
		
		IF ip_SourceType = 1
        THEN      
			SELECT 	CustID
				,	Username
				,   UserName2
				,	SiteID
				,	Site
				,	RoleID
				,	CurrencyID
				,	Currency
				,	Srecommend
				,	Mrecommend
				,	Recommend
				,	CreatedDate
			FROM		CTS_DataCenter.CTSCustomer AS cus
				INNER JOIN	TempItemTable AS tmpCus ON cus.CustID = tmpCus.Item
			WHERE		CustSubID = 0;
		END IF;
END$$
DELIMITER ;