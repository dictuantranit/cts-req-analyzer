/*<info serverAlias="CTSMain-DCS_Extra" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_ET_Transform_UserAgent_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_ET_Transform_UserAgent_Insert`(
        IN ip_FromTransID   BIGINT UNSIGNED
    ,   IN ip_ToTransID     BIGINT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20190730@Casey.Huynh
	    Task :	Insert UserAgent
	    DB:		DCS_Extra
	    Original:
	
	    Revisions:
		    - 20201006@CaseyHuynh: Move New Server, Move table RawTransaction from DB "DCS_RawTransaction" to "DCS_Extra" AND Change UserAgent Data Type From TEXT to VARCHAR(1000)
			- 20201019@CaseyHuynh:	Move Server, Phase 2 [Redmine ID: #143011]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: @148723]
			- 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]
            - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
			- 2023292023@Casey.Huynh: CTMAX, Velki [RedmineID: #190118]
            
	    Param's Explanation (filtered by):
    */

    DROP TEMPORARY TABLE IF EXISTS Temp_UserAgent;
    CREATE TEMPORARY TABLE Temp_UserAgent(		
		    UserAgentKey		VARCHAR(32)
        ,   UserAgent			VARCHAR(1000)
        ,   CreatedDate		    DATETIME
    );    
	    
    INSERT INTO Temp_UserAgent (UserAgentKey, UserAgent, CreatedDate)
    SELECT	MD5(LOWER(rt.UserAgent)) AS UserAgentKey
		,	rt.UserAgent
		,	MIN(rt.CreatedDate)
	FROM DCS_Extra.RawTransaction	AS rt
		LEFT JOIN	DCS_Extra.UserAgent AS ua ON ua.UserAgentKey = MD5(LOWER(rt.UserAgent))
    WHERE	rt.TransID BETWEEN ip_FromTransID AND ip_ToTransID
		AND rt.IsProcessed = 0
		AND ua.UserAgentKey IS NULL
		AND rt.UserAgent IS NOT NULL
    GROUP BY rt.UserAgent;
    
	#========INSERT: Subscriber which are unhandled interagtion=====================================================
	INSERT IGNORE INTO DCS_Extra.UserAgent (UserAgentKey, UserAgent, CreatedDate )
	SELECT	tu.UserAgentKey
		,	tu.UserAgent
		,	tu.CreatedDate
    FROM Temp_UserAgent AS tu;
	 
END$$

DELIMITER ;
