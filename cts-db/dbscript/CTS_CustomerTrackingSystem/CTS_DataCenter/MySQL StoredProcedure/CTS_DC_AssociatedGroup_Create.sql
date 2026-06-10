/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWebAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_Create`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_Create`(
		IN ip_GroupName 		VARCHAR(100)
    ,	IN ip_ABI 				INT
    ,	IN ip_Danger1 			INT
    ,	IN ip_AllCredit			SMALLINT
    ,	IN ip_AllLicensee		SMALLINT
    ,	IN ip_Sites				LONGTEXT
    ,	IN ip_HasDevice			TINYINT
    ,	IN ip_HasManual			TINYINT
    ,	IN ip_HasIP				TINYINT
    ,	IN ip_HasAI				TINYINT
    ,	IN ip_Remark 			VARCHAR(200)
    ,	IN ip_CreatedBy 		INT UNSIGNED
)
    SQL SECURITY INVOKER
BEGIN
	/* 
		Created:	20220705@Aries.Nguyen
		Task:		[CTS] Fraud Group Management [Redmine ID: #167748]
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20220705@Aries.Nguyen: Created [Redmine ID: #167748]
            - 20220831@Aries.Nguyen: Associated Group Enhancement [Redmine ID: #176991]
            - 20221025@Harvey.Nguyen: Associated Group Enhancement [Redmine ID: #179398]
		Param's Explanation (filtered by):
        
        Example: 
			CALL CTS_DC_AssociatedGroup_Create(@ip_GroupName:='DevGroup01', @ip_ABI:=18,@ip_Danger1:=1,@ip_AllCredit:=1,@ip_AllLicensee:=0,@ip_Sites:='16,30'
			,@ip_HasDevice:=1,@ip_HasManual:=1,@ip_HasIP:=0,@ip_HasAI:=1,@ip_Remark:='Dev Test',@ip_CreatedBy:=8);
	*/
    DECLARE lv_GroupID 			BIGINT UNSIGNED;
    
    DECLARE lv_LogInfo JSON;
    DECLARE CONST_USERLOG_LOGTYPE SMALLINT DEFAULT 34;
    DECLARE CONST_SPNAME VARCHAR(100) DEFAULT 'CTS_DC_AssociatedGroup_Create';
   
    #============USER LOG====================================
    SET lv_LogInfo = JSON_OBJECT(  'GroupName', ip_GroupName, 
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
			,	ip_CreatedBy AS CreatedBy;        
    

    INSERT INTO CTS_DataCenter.AssociatedGroup(GroupName, ABI, Danger1,AllCredit,AllLicensee,Sites,HasDevice,HasManual,HasIP,HasAI,Remark,CreatedBy,Modified)
    VALUES(ip_GroupName, ip_ABI, ip_Danger1 ,ip_AllCredit,ip_AllLicensee,ip_Sites,ip_HasDevice,ip_HasManual,ip_HasIP,ip_HasAI,ip_Remark,ip_CreatedBy,NULL);

END$$
DELIMITER ;