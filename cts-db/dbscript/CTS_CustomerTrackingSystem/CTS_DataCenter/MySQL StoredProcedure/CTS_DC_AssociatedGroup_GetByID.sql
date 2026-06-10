/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_GetByID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_GetByID`(
		IN 		ip_GroupID 		BIGINT UNSIGNED
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
            - 20221025@Harvey.Nguyen: Get Ori value [Redmine ID: #179398]
		
        Param's Explanation: 

		Example:
			- CALL CTS_DC_AssociatedGroup_GetByID(1);

*/
    
    SELECT 	grp.GroupID
		,	grp.GroupName
        ,	grp.ABI
        ,	grp.Danger1 AS 'Ori'
        ,	grp.AllCredit
        ,	grp.AllLicensee
		,	grp.Sites
        ,	grp.HasDevice
        ,	grp.HasManual
        ,	grp.HasIP
        ,	grp.HasAI
        ,	grp.Remark
        ,	grp.Created
		,	us.UserName AS CreatedBy
        ,	grp.Modified
		,	us1.UserName AS ModifiedBy
    FROM CTS_DataCenter.AssociatedGroup AS grp
		LEFT JOIN CTS_Admin.CTSUser AS us ON grp.CreatedBy = us.UserID
        LEFT JOIN CTS_Admin.CTSUser AS us1 ON grp.ModifiedBy = us1.UserID
	WHERE grp.GroupID = ip_GroupID
		AND  grp.IsDisable = 0;
END$$
DELIMITER ;