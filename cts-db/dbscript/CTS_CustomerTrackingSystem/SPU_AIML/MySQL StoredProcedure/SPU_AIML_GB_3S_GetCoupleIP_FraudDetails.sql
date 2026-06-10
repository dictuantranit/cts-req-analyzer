DROP PROCEDURE IF EXISTS `SPU_AIML_GB_3S_GetCoupleIP_FraudDetails`;

DELIMITER $$
CREATE DEFINER=`AIMLOwner`@`%` PROCEDURE `SPU_AIML_GB_3S_GetCoupleIP_FraudDetails`(
		IN 	ip_CoupleInfoDetails	JSON
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20230112@Victoria.Le
		Task:		Get Couple Datails
		DB:			SPU_AIML
		Original:

		Revisions:
			- 20230112@Victoria.Le: Initial Writting [Redmine ID: #181994]
		
        Param's Explanation (filtered by):
			
		Example:
			CALL SPU_AIML.SPU_AIML_GB_3S_GetCoupleIP_FraudDetails (@ip_CoupleInfoDetails := '[{"CoupleID" : 17,"CreatedDate" : "2023-02-12", "TypeIPEntanglement:": 2},{"CoupleID" : 95,"CreatedDate" : "2023-02-11", "TypeIPEntanglement:": 2}]');
			
	*/
	
	DROP TEMPORARY TABLE IF EXISTS Temp_GB3S_CoupleInfo;
	CREATE TEMPORARY TABLE Temp_GB3S_CoupleInfo( 		
			CoupleID			BIGINT UNSIGNED NOT NULL
        , 	CreatedDate			DATE
		,	TypeIPEntanglement	SMALLINT
		
        ,	PRIMARY KEY (CoupleID,CreatedDate)
    );
	
	INSERT INTO Temp_GB3S_CoupleInfo
	(
			CoupleID
        ,	CreatedDate
		,	TypeIPEntanglement
	)
	SELECT 	tmp.CoupleID
        ,	tmp.CreatedDate
		,	tmp.TypeIPEntanglement
	FROM JSON_TABLE(ip_CoupleInfoDetails,'$[*]' COLUMNS(CoupleID			BIGINT		PATH '$.CoupleID'
                                                    ,	CreatedDate			DATE		PATH '$.CreatedDate'
													,	TypeIPEntanglement	SMALLINT	PATH '$.TypeIPEntanglement'
					)) AS tmp;

	SELECT 	tmp.TypeIPEntanglement
		,	cfi.MatchID
		,	cfi.EventDate
		,	cfi.FraudTransList
		,	tmp.CoupleID
		,	tmp.CreatedDate
	FROM SPU_AIML.GB_3S_CoupleIPFraudInfo AS cfi
		INNER JOIN Temp_GB3S_CoupleInfo AS tmp ON tmp.CoupleID = cfi.CoupleID
													AND tmp.CreatedDate = cfi.CreatedDate
	ORDER BY tmp.CreatedDate DESC;
        
END$$
DELIMITER ;