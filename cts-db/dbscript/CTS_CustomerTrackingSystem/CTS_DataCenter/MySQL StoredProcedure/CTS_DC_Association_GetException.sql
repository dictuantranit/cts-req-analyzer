/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Association_GetException`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Association_GetException`(
		IN ip_CTSCustID BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20191225@Casey.Huynh	
		Task :		Get Exception by CTSCustID
		DB:			CTS_DataCenter
		Original: 
		Revisions:
			- 20191225@Casey.Huynh: Created
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
			
		Param's Explanation (filtered by):
	*/
	
    DROP TEMPORARY TABLE IF EXISTS Temp_CustException;
    CREATE TEMPORARY TABLE Temp_CustException(
			ExceptionCTSCustID 	BIGINT UNSIGNED
        , 	ExceptionDate		DATETIME
        , 	Comment				VARCHAR(200)
        , 	CreatedBy			INT
    );
    
    INSERT INTO Temp_CustException(ExceptionCTSCustID, ExceptionDate, Comment, CreatedBy)
	SELECT 	(CASE WHEN ce.FromCTSCustID != ip_CTSCustID 
				  THEN ce.FromCTSCustID 
				  ELSE ce.ToCTSCustID 
		    END) AS ExceptionCTSCustID
		,	CreatedDate
        ,	Comment
        ,	Createdby
    FROM	CTS_DataCenter.CustException AS ce
    WHERE	ce.FromCTSCustID = ip_CTSCustID
			OR ce.ToCTSCustID = ip_CTSCustID;
    
    SELECT	ex.ExceptionCTSCustID
		,	ct.Username	AS UserName
        ,	ct.UserName2	AS LoginID
		,	ex.ExceptionDate
        ,	ex.Comment
        ,	us.UserName AS CreatedBy
    FROM Temp_CustException AS ex
		INNER JOIN	CTS_DataCenter.CTSCustomer AS ct ON ex.ExceptionCTSCustID = ct.CTSCustID
		INNER JOIN	CTS_Admin.CTSUser AS us ON ex.CreatedBy = us.UserID;    

END$$

DELIMITER ;