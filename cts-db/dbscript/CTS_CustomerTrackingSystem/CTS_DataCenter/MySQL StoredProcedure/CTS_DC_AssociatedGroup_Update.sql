/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_Update`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_Update`(
		IN ip_GroupID 			BIGINT UNSIGNED
	,	IN ip_GroupName 		VARCHAR(100)
    ,	IN ip_ABI 				INT
    ,	IN ip_Danger1 			INT
    ,	IN ip_AllCredit			TINYINT
    ,	IN ip_AllLicensee		TINYINT
    ,	IN ip_Sites				LONGTEXT
    ,	IN ip_HasDevice			TINYINT
    ,	IN ip_HasManual			TINYINT
    ,	IN ip_HasIP				TINYINT
    ,	IN ip_HasAI				TINYINT
    ,	IN ip_Remark 			VARCHAR(200)
    ,	IN ip_ModifiedBy 		INT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
/* 
		Created:	20220831@Aries.Nguyen
		Task :		[CTS] Associated Group Enhancement
		DB:			CTS_DataCenter
		Original: 
		Revisions: 
			- 20220831@Aries.Nguyen: Created [Redmine ID: #176991] 
            - 20221025@Harvey.Nguyen: Associated Group Enhancement [Redmine ID: #179398]
            
        Param's Explanation: 

		Example:
			CALL CTS_DC_AssociatedGroup_Update(@ip_GroupID:=14,@ip_GroupName:='DevGroup01', @ip_ABI:=18,@ip_Danger1:=1,@ip_AllCredit:=1,@ip_AllLicensee:=0,@ip_Sites:='16,30'
			,@ip_HasDevice:=1,@ip_HasManual:=1,@ip_HasIP:=0,@ip_HasAI:=1,@ip_Remark:='Dev Update Group',@ip_CreatedBy:=8);

*/
	DECLARE lv_LogInfo JSON;
    DECLARE CONST_USERLOG_LOGTYPE SMALLINT DEFAULT 34;
    DECLARE CONST_SPNAME VARCHAR(100) DEFAULT 'CTS_DC_AssociatedGroup_Update';
   
    #============USER LOG====================================
    SET lv_LogInfo = JSON_OBJECT(  'GroupID', ip_GroupID,
									'GroupName', ip_GroupName, 
								   'ABI', ip_ABI, 
                                   'Danger1', ip_Danger1, 
                                   'AllCredit', ip_AllCredit, 
                                   'AllLicensee', ip_AllLicensee, 
                                   'Sites', ip_Sites, 
                                   'HasDevice', ip_HasDevice, 
                                   'HasManual', ip_HasManual, 
                                   'HasIP', ip_HasIP, 
								   'HasAI', ip_HasAI,
                                   'Remark', ip_Remark);
                      
     INSERT IGNORE INTO CTS_Admin.UserLog(LogTypeID, SPName, LogInfo, CreatedDate, CreatedBy)
	 SELECT CONST_USERLOG_LOGTYPE AS LogTypeID
			,	CONST_SPNAME AS SPName
			,	lv_LogInfo AS LogInfo
			,	NOW() AS CreatedDate
			,	ip_ModifiedBy AS CreatedBy;        
	
    UPDATE CTS_DataCenter.AssociatedGroup
    SET  	GroupName =  ip_GroupName
		,	ABI = ip_ABI
        ,	Danger1 = ip_Danger1
		,	AllCredit = ip_AllCredit
		,	AllLicensee = ip_AllLicensee
		,	Sites = ip_Sites
		,	HasDevice = ip_HasDevice
		,	HasManual = ip_HasManual
		,	HasIP = ip_HasIP
		,	HasAI = ip_HasAI
		,	Remark =  ip_Remark
        ,	ModifiedBy = ip_ModifiedBy
    WHERE GroupID = ip_GroupID;    
    
END$$
DELIMITER ;