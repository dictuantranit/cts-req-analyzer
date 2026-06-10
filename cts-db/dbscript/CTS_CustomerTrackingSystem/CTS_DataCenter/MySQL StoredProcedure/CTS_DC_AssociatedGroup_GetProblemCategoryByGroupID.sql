/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_GetProblemCategoryByGroupID`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_GetProblemCategoryByGroupID`(
		IN 		ip_GroupID 		BIGINT UNSIGNED
        
        
)
    SQL SECURITY INVOKER
BEGIN
/* 
		Created:	20221027@Harvey.Nguyen
		Task :		[CTS] Associated Group Enhancement
		DB:			CTS_DataCenter
		Original: 
		Revisions: 
			- 20221025@Harvey.Nguyen: Created [Redmine ID: #179398] 
		
        Param's Explanation: 

		Example:
			- CALL CTS_DC_AssociatedGroup_GetProblemCategoryByGroupID(1);

*/
    
    SELECT 	grp.GroupID
        ,	grp.PACategoryID
        ,	grp.PACreditSites
        ,	grp.PALicenseeSites
		,	us1.UserName AS ModifiedBy
    FROM CTS_DataCenter.AssociatedGroup AS grp
        LEFT JOIN CTS_Admin.CTSUser AS us1 ON grp.ModifiedBy = us1.UserID
	WHERE grp.GroupID = ip_GroupID
		AND  grp.IsDisable = 0;
END$$
DELIMITER ;