/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_RPT_AssociatedAccount_Detail`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_RPT_AssociatedAccount_Detail`(
		IN ip_CTSCustID			BIGINT
    ,	IN ip_AssociationType	INT
    ,	IN ip_FromAssDate		DATETIME
    ,	IN ip_ToAssDate			DATETIME
    ,	IN ip_Skip 				INT
    ,	IN ip_Take 				INT
    
    ,	OUT op_TotalItems		INT
)
    SQL SECURITY INVOKER
sp : BEGIN
	/*
		Created:	20210226@Harvey.Nguyen
		Task:		Get association report - detail
		DB:			CTS_DataCenter
        
		Revisions:
			- 20210226@Harvey.Nguyen: Created [Redmine ID: #150891]
            - 20210504@Aries.Nguyen: Enhance performance [Redmine ID: #152509] 

		Param's Explanation (filtered by):
            - ip_AssociationType: 0 - ALL, 1 - Device, 2 - AI, 3 - Manual
        Example:
			set @op_TotalItems = 0;
			call CTS_DataCenter.CTS_DC_RPT_AssociatedAccount_Detail(107,0,'2021-01-28','2021-01-30',0,10, @op_TotalItems);
			 select @op_TotalItems;
	*/    
    DROP TEMPORARY TABLE IF EXISTS Temp_Associations;
    CREATE TEMPORARY TABLE Temp_Associations (
			CTSCustID 			INT UNSIGNED
		,	AssociationDate		DATETIME
        ,	AssociationStatus	BIT
        , 	PRIMARY KEY  (CTSCustID)
	);
    
    IF ip_AssociationType = 0 OR ip_AssociationType = 1 THEN        
        INSERT INTO Temp_Associations (CTSCustID, AssociationDate, AssociationStatus)
        SELECT  asCus.CTSCustID  
			,	GREATEST(asDv.CreatedTime, asCus.CreatedTime)
            , 	1 AS AssociationStatus
		FROM CTS_DataCenter.AssociationByDevice AS asDv 
			INNER JOIN CTS_DataCenter.AssociationByDevice AS asCus ON asCus.DCSDeviceID = asDv.DCSDeviceID AND asCus.CTSCustID <> ip_CTSCustID
		WHERE asDv.CTSCustID = ip_CTSCustID
        ON DUPLICATE KEY UPDATE AssociationDate = LEAST(Temp_Associations.AssociationDate, GREATEST(asDv.CreatedTime, asCus.CreatedTime));
        
        DELETE FROM Temp_Associations WHERE  AssociationDate NOT  BETWEEN ip_FromAssDate AND ip_ToAssDate;
        
        UPDATE Temp_Associations AS tmp
		SET tmp.AssociationStatus = 0
        WHERE EXISTS (SELECT 1 FROM AssociationRemove AS rm WHERE rm.FromCTSCustID = ip_CTSCustID AND rm.ToCTSCustID = tmp.CTSCustID);
        
		UPDATE Temp_Associations AS tmp
		SET tmp.AssociationStatus = 0
        WHERE EXISTS (SELECT 1 FROM AssociationRemove AS rm WHERE rm.ToCTSCustID = ip_CTSCustID AND rm.FromCTSCustID = tmp.CTSCustID);

	END IF;
    
    IF ip_AssociationType = 0 OR ip_AssociationType = 3 THEN
		INSERT INTO Temp_Associations (CTSCustID, AssociationDate, AssociationStatus)
		SELECT CASE WHEN ass.FromCTSCustID = ip_CTSCustID THEN ass.ToCTSCustID ELSE ass.FromCTSCustID END
			, ass.CreatedDate
            , CASE WHEN assRemove.FromCTSCustID IS NULL THEN 1 ELSE 0 END
		FROM CTS_DataCenter.AssociationByManual ass
            LEFT JOIN CTS_DataCenter.AssociationRemove assRemove ON assRemove.FromCTSCustID = ass.FromCTSCustID AND assRemove.ToCTSCustID = ass.ToCTSCustID
		WHERE ass.CreatedDate BETWEEN ip_FromAssDate AND ip_ToAssDate
			AND (ass.FromCTSCustID = ip_CTSCustID OR ass.ToCTSCustID = ip_CTSCustID)
		ON DUPLICATE KEY UPDATE AssociationDate = LEAST(Temp_Associations.AssociationDate, ass.CreatedDate);
	END IF;
    
    SELECT cus.CTSCustID
		, cus.UserName
        , cus.SubscriberID
        , sub.SubscriberName
        , stl.ItemNameDisplay AS 'AccountStatus'
        , tass.AssociationDate
        , tass.AssociationStatus
        , ip_AssociationType AS 'AssociationType'
    FROM Temp_Associations tass
		INNER JOIN CTS_DataCenter.CTSCustomer cus ON cus.CTSCustID = tass.CTSCustID
        INNER JOIN CTS_Admin.Subscriber sub ON cus.SubscriberID = sub.SubscriberID
        INNER JOIN CTS_DataCenter.StaticList stl ON stl.ItemID = cus.CustStatusID AND stl.ListID = 1
	ORDER BY tass.AssociationDate DESC
	LIMIT ip_Take
    OFFSET ip_Skip;
	
    SELECT COUNT(1) 
    INTO op_TotalItems
	FROM Temp_Associations;		
	
END$$

DELIMITER ;