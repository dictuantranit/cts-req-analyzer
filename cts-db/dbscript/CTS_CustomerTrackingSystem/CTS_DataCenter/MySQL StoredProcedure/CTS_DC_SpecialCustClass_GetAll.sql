/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_SpecialCustClass_GetAll`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_SpecialCustClass_GetAll`(
		IN ip_IsGetAllInfo 		BIT
	,	IN ip_Username 			VARCHAR(50)
	,	IN ip_SportList			VARCHAR(1000)
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200905@Long.Luu
		Task:		Insert special customer class
		DB:			CTS_DataCenter
		Original:

		Revisions:
		   - 20200905@Long.Luu [140996]: Created
           - 20200908@Irena.Vo [141020]: Exclude VVIP, Pin category in list
		   - 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
		   - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
		   - 20240319@Thomas.Nguyen: Add input param SportList and get data for BySport [Redmine ID: #201360]
           
		Param's Explanation (filtered by):
		Example:			
			- CALL CTS_DataCenter.CALL CTS_DC_SpecialCustClass_GetAll(TRUE,'','0,1');
	*/        
	DECLARE lv_IsGetSpecialCCGeneral BIT DEFAULT 0;

	DROP TEMPORARY TABLE IF EXISTS Temp_SportList;
	CREATE TEMPORARY TABLE Temp_SportList (SportID SMALLINT UNSIGNED PRIMARY KEY);

	INSERT INTO Temp_SportList(SportID)
	SELECT 	tmp.SportID
	FROM JSON_TABLE(REPLACE(JSON_ARRAY(ip_SportList), ',', '","'),
		 "$[*]" COLUMNS(
			SportID 		SMALLINT UNSIGNED	PATH "$"
		 )) AS tmp;

	IF EXISTS (SELECT 1 FROM Temp_SportList WHERE SportID = 0) THEN
		SET lv_IsGetSpecialCCGeneral = 1;
	END IF;

    IF (ip_IsGetAllInfo = 1) THEN
		WITH CTE_SpecialCC AS (
			SELECT 	s.CTSCustID
				,	s.CustID
				, 	c.UserName
				, 	sub.SubscriberName
				, 	s.CustomerClass
				,	u.UserName AS CreatedBy
				,	s.CreatedDate
				,	0 AS SportID
				,	(SELECT Remark FROM SpecialCustomerClass_History AS h WHERE h.CustID = s.CustID ORDER BY h.CreatedDate DESC LIMIT 1) AS Remark
			FROM CTS_DataCenter.SpecialCustomerClass AS s
				INNER JOIN CTS_DataCenter.CTSCustomer AS c ON s.CTSCustID = c.CTSCustID
				INNER JOIN CTS_Admin.Subscriber AS sub ON s.SubscriberID = sub.SubscriberID
				INNER JOIN CTS_Admin.CTSUser AS u ON s.CreatedBy = u.UserID
			WHERE s.CreatedFromFunction = 1
				AND (ip_Username = "" OR c.UserName = ip_Username)
				AND lv_IsGetSpecialCCGeneral = 1
			/*ORDER BY s.CreatedDate DESC; -- Enhance sort data*/
			UNION ALL
			SELECT 	s.CTSCustID
				,	s.CustID
				, 	c.UserName
				, 	sub.SubscriberName
				, 	s.CustomerClass
				,	u.UserName AS CreatedBy
				,	s.CreatedDate
				,	s.SportID AS SportID
				,	(SELECT Remark FROM SpecialCustomerClass_BySport_History AS h WHERE h.CustID = s.CustID AND h.SportID = s.SportID ORDER BY h.CreatedDate DESC LIMIT 1) AS Remark
			FROM CTS_DataCenter.SpecialCustomerClass_BySport AS s
				INNER JOIN CTS_DataCenter.CTSCustomer AS c ON s.CTSCustID = c.CTSCustID
				INNER JOIN CTS_Admin.Subscriber AS sub ON s.SubscriberID = sub.SubscriberID
				INNER JOIN CTS_Admin.CTSUser AS u ON s.CreatedBy = u.UserID
				INNER JOIN Temp_SportList AS tmp ON tmp.SportID = s.SportID
			WHERE (ip_Username = "" OR c.UserName = ip_Username) AND tmp.SportID <> 0
		)
		SELECT	cs.CTSCustID
			,	cs.CustID
			, 	cs.UserName
			, 	cs.SubscriberName
			, 	cs.CustomerClass
			,	cs.CreatedBy
			,	cs.CreatedDate
			,	cs.SportID
			,	cs.Remark
		FROM CTE_SpecialCC AS cs
		ORDER BY cs.CreatedDate DESC;
    ELSE
		SELECT CustID
		FROM CTS_DataCenter.SpecialCustomerClass
        WHERE CreatedFromFunction IN (1, 11, 21); -- Exclude Normal, VVIP, Pin Category customer class.
    END IF;
    	 
END$$

DELIMITER ;