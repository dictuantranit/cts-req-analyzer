/*<info serverAlias="CTSMain-DCS_DataCenter" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `DCS_DC_TransformData_UserAgent_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `DCS_DC_TransformData_UserAgent_Insert`(
        IN ip_FromTransID   BIGINT
    ,   IN ip_ToTransID     BIGINT
)
    SQL SECURITY INVOKER
BEGIN
	/*
	    Created: 20190730@Casey.Huynh
	    Task :	Insert UserAgent
	    DB:		DCS_DataCenter
	    Original:
	
	    Revisions:
		    - 20201006@CaseyHuynh: Move New Server, Move table RawTransaction from DB "DCS_RawTransaction" to "DCS_DataCenter" AND Change UserAgent Data Type From TEXT to VARCHAR(1000)
			- 20201019@CaseyHuynh:	Move Server, Phase 2 [Redmine ID: #143011]
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: @148723]
			- 20210510@Aries.Nguyen: Remove insert log zzTracePerformance [Redmine ID: #154792]

	    Param's Explanation (filtered by):
    */
    
	### PERFORMANCE: START
    DECLARE		vrExecKey		BIGINT	UNSIGNED;
	DECLARE		vrSPName		VARCHAR(200) DEFAULT 'DCS_DC_TransformData_UserAgent_Insert' ;
    DECLARE		vrStepID		INT;
	DECLARE 	vrNotes	 		VARCHAR(500);
	DECLARE 	vrStartTime		TIMESTAMP(4);
	DECLARE		vrEndTime 		TIMESTAMP(4);
	DECLARE		vrDuration 		BIGINT;	
    DECLARE		vrTotalRecord	INT;
    DECLARE		vrFromID		BIGINT;
    DECLARE		vrToID			BIGINT;

    #SET		vrExecKey = CRC32((UUID_Short()));    
    #SET		vrNotes = 'Inser UserAgent';		
    #SET 	vrStepID = 1;    
	#SET 	vrStartTime = CURRENT_TIMESTAMP(4); 
    
    #INSERT INTO DCS_DataCenter.zzTracePerformance (ExecKey, StepID, SPName, Notes, StartTime, FromID, ToID)
    #VALUES(vrExecKey, vrStepID, vrSPName,  vrNotes, vrStartTime, ip_FromTransID, ip_ToTransID);
	 
	### PERFORMANCE: END
    
    DROP TEMPORARY TABLE IF EXISTS Temp_UserAgent;
    CREATE TEMPORARY TABLE Temp_UserAgent(		
		    UserAgentKey		VARCHAR(32)
        ,   UserAgent			VARCHAR(1000)
        ,   CreatedDate		    DATETIME
    );    
	    
    INSERT INTO Temp_UserAgent (UserAgentKey, UserAgent, CreatedDate)
    SELECT		MD5(LOWER(rt.UserAgent)) AS UserAgentKey
				, rt.UserAgent
                , MIN(rt.CreatedDate)
	FROM		DCS_DataCenter.RawTransaction	AS rt
    LEFT JOIN	DCS_DataCenter.UserAgent 			AS ua
				ON ua.UserAgentKey = MD5(LOWER(rt.UserAgent))
    WHERE		rt.TransID BETWEEN ip_FromTransID AND ip_ToTransID
				AND rt.IsProcessed = 0
                AND ua.UserAgentKey IS NULL
                AND rt.UserAgent IS NOT NULL
    GROUP BY	rt.UserAgent;
    
	#========INSERT: Subscriber which are unhandled interagtion=====================================================
	INSERT IGNORE INTO DCS_DataCenter.UserAgent (UserAgentKey, UserAgent, CreatedDate )
	SELECT 		tu.UserAgentKey
				, tu.UserAgent
                , tu.CreatedDate
    FROM		Temp_UserAgent AS tu;
	
	### PERFORMANCE
	#SET	vrEndTime = CURRENT_TIMESTAMP(4);
    
    #UPDATE	DCS_DataCenter.zzTracePerformance AS z
    #SET		z.EndTime = vrEndTime
	#		, z.Duration = TIMESTAMPDIFF(MICROSECOND, vrStartTime, vrEndTime)
    #        , z.TotalRecord = vrTotalRecord
    #        , z.FromID = vrFromID
    #        , z.ToID		= vrToID
    #WHERE	z.ExecKey = vrExecKey AND z.StepID = z.StepID;
    ### PERFORMANCE: END
    
END$$

DELIMITER ;
