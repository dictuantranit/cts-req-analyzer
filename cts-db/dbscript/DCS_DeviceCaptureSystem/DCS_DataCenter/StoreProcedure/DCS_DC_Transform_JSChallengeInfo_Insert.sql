/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
USE `DCS_DataCenter`;
DROP procedure IF EXISTS `DCS_DataCenter`.`DCS_DC_Transform_JSChallengeInfo_Insert`;
;

DELIMITER $$
USE `DCS_DataCenter`$$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_Transform_JSChallengeInfo_Insert`(
		IN ip_JSChallengeInfoJson	LONGTEXT
)
    SQL SECURITY INVOKER
BEGIN
	/*
		Created: 20240313@Teddy.le
		Task : Insert into DCS_DataCenter.JSChallengeInfo
		DB: DCS_DataCenter
		Original:

		Revisions:
			- 20240313@Teddy.le [Redmine ID: #196667]
			- 20240621@Jonathan.Doan: Change data flow v5.1 [Redmine ID: #206403]
			- 20240830@Jonathan.Doan: Update datatype [Redmine ID: #206403]

		Param's Explanation (filtered by):
			
		Example:
			CALL DCS_DC_Transform_JSChallengeInfo_Insert('[{"CreatedTime":"2024-01-01","ChallengeCode":"ChallengeCode1","ChallengeIds":"ChallengeIds1","Expect":"Expect1","Actual":"Actual1","Parameters":"Parameters1","ExeServerTimeInSecond":1,"ExeClientTimeInSecond":2,"Result":3,"ErrMsg":"ErrMsg1"}]');

	*/
    DECLARE lv_CurrentDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
	
	DROP TEMPORARY TABLE IF EXISTS Temp_JSChallengeInfo;
    
	CREATE TEMPORARY TABLE Temp_JSChallengeInfo(
			ID				 			INT UNSIGNED AUTO_INCREMENT		NOT NULL
		,	ChallengeCode				VARCHAR(50) 					NOT NULL
		,	ChallengeIds				VARCHAR(50) 					NULL DEFAULT ''
		,	Expect		 				VARCHAR(1000) 					NULL DEFAULT ''
		,	Actual		 				VARCHAR(1000) 					NULL DEFAULT ''
		,	Parameters	 				VARCHAR(300) 					NULL DEFAULT ''
		,	ExeServerTimeInSecond		INT UNSIGNED  					NOT NULL DEFAULT 0
		,	ExeClientTimeInSecond		INT UNSIGNED  					NOT NULL DEFAULT 0
		,	Result		 				TINYINT		 					NOT NULL DEFAULT 0
		,	ErrMsg	 					VARCHAR(300) 					NULL
        
        ,	PRIMARY KEY (ID)
    );
    
    
    INSERT INTO Temp_JSChallengeInfo(ChallengeCode, ChallengeIds, Expect, Actual, Parameters, ExeServerTimeInSecond, ExeClientTimeInSecond, Result, ErrMsg)
    SELECT	rt.ChallengeCode
		,	rt.ChallengeIds
		,	rt.Expect
		,	rt.Actual
		,	rt.Parameters
		,	rt.ExeServerTimeInSecond
		,	rt.ExeClientTimeInSecond
		,	rt.Result
		,	rt.ErrMsg
	FROM JSON_TABLE(
			ip_JSChallengeInfoJson,
			 "$[*]" COLUMNS(
						ChallengeCode			VARCHAR(50) 	PATH "$.ChallengeCode"
					,	ChallengeIds			VARCHAR(50) 	PATH "$.ChallengeIds"
					,	Expect					VARCHAR(1000) 	PATH "$.Expect"
					,	Actual					VARCHAR(1000) 	PATH "$.Actual"
					,	Parameters				VARCHAR(300) 	PATH "$.Parameters"
					,	ExeServerTimeInSecond	INT UNSIGNED 	PATH "$.ExeServerTimeInSecond"
					,	ExeClientTimeInSecond	INT UNSIGNED 	PATH "$.ExeClientTimeInSecond"
					,	Result					TINYINT 		PATH "$.Result"
					,	ErrMsg					VARCHAR(300) 	PATH "$.ErrMsg"
				)
		   ) AS  rt
	WHERE rt.ChallengeCode IS NOT NULL;
    
	INSERT IGNORE INTO DCS_DataCenter.JSChallengeInfo(CreatedTime, ChallengeCode, ChallengeIds, Expect, Actual, Parameters, ExeServerTimeInSecond, ExeClientTimeInSecond, Result, ErrMsg)
	SELECT	lv_CurrentDate AS CreatedTime
		,	tmp.ChallengeCode
		,	tmp.ChallengeIds
		,	tmp.Expect
		,	tmp.Actual
		,	tmp.Parameters
		,	tmp.ExeServerTimeInSecond
		,	tmp.ExeClientTimeInSecond
        ,   tmp.Result
		,	tmp.ErrMsg
	FROM Temp_JSChallengeInfo AS tmp;
    
END$$

DELIMITER ;
;
