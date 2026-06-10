/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/

DELIMITER $$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE CTS_DC_CustClassification_TWTagging_Exclude (
    IN ip_CustInfo JSON
)
    SQL SECURITY INVOKER
BEGIN
    /*
        Created:    20250328@Logan.Nguyen

        Task:       Customer Classification - TW - Adjust criteria for New_Good_Normal - GB_High Rejected [Redmine ID: #221508]
        DB:         CTS_DataCenter

        Revisions:
            - 20250328@Logan.Nguyen: Initial create [Redmine ID: #221508]

        Param's Explanation:
            ip_CustInfo : JSON array include CustID, CategoryID, TaggingID

        Sample Call:
            CALL CTS_DataCenter.CTS_DC_CustClassification_TWTagging_Exclude(
                '[{"CustID":1,"CategoryID":40100,"TaggingID":7}, {"CustID":2,"CategoryID":40200,"TaggingID":8}]'
            );
    */
	DECLARE CONST_CATEID_NEW 								INT;
	DECLARE CONST_CATEID_GOOD 								INT;
	DECLARE CONST_CATEID_NORMAL 							INT;
	
	SET CONST_CATEID_NEW 									= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_NEW');
	SET CONST_CATEID_GOOD 									= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_GOOD');
	SET CONST_CATEID_NORMAL 								= CTS_DC_CategoryTypeParent_Get ('CONST_CATEID_NORMAL');
	
    DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
    CREATE TEMPORARY TABLE Temp_Cust(
			CustID      INT
        ,	CategoryID  INT
        ,	TaggingID   INT
        ,	PRIMARY KEY (CustID, TaggingID)
    );

    INSERT INTO Temp_Cust(CustID, CategoryID, TaggingID)
    SELECT	js.CustID
        ,	js.CategoryID
		,	js.TaggingID 
	FROM JSON_TABLE(ip_CustInfo,
        "$[*]" COLUMNS (
              CustID      INT UNSIGNED	PATH "$.CustID"
            , CategoryID  INT			PATH "$.CategoryID"
            , TaggingID   SMALLINT		PATH "$.TaggingID"
        )) AS js;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_Cust_Exclude;
    CREATE TEMPORARY TABLE Temp_Cust_Exclude(
			CustID      INT
        ,	TaggingID   INT
        ,	PRIMARY KEY (CustID, TaggingID)
    );	
	
	INSERT INTO Temp_Cust_Exclude(CustID, TaggingID)
    SELECT	ti.CustID
		,	ti.TaggingID
    FROM Temp_Cust AS ti
    WHERE ti.CategoryID IN (CONST_CATEID_NEW, CONST_CATEID_GOOD, CONST_CATEID_NORMAL)
		AND NOT EXISTS (
			SELECT 1 
			FROM CTS_DataCenter.Customer_FirstTWTaggingCC AS c
			WHERE c.CustID = ti.CustID 
				AND c.TWTaggingID = ti.TaggingID
    );
	
    SELECT	tc.CustID
		,	tc.CategoryID
		,	tc.TaggingID
    FROM Temp_Cust AS tc
    WHERE NOT EXISTS (SELECT 1 FROM Temp_Cust_Exclude AS tcd WHERE tcd.CustID = tc.CustID AND tcd.TaggingID = tc.TaggingID);

END$$

DELIMITER ;



