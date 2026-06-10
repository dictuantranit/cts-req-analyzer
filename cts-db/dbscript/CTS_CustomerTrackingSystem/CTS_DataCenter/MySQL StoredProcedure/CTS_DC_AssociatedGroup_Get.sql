/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_AssociatedGroup_Get`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_AssociatedGroup_Get`()
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
            - 20221025@Harvey.Nguyen: Get more info for PA setting [Redmine ID: #179398]
        
		Param's Explanation (filtered by):
        
        Example: 
			- CALL CTS_DC_AssociatedGroup_Get(); 
	*/
    
    SELECT 	grp.GroupID
		,	grp.GroupName
        ,	grp.ABI
        ,	grp.AllCredit
        ,	grp.AllLicensee
		,	grp.Sites
        ,	grp.Danger1 AS 'Ori'
        ,	cate.CategoryName
        ,	(CASE WHEN grp.PACreditSites IS NULL THEN 0 ELSE 1 END) AS IsPACreditSite
        ,	(CASE WHEN grp.PALicenseeSites IS NULL THEN 0 ELSE 1 END) AS IsPALicenseeSite
        ,	grp.HasDevice
        ,	grp.HasManual
        ,	grp.HasIP
        ,	grp.HasAI
        ,	(SELECT COUNT(1) 
             FROM AssociatedGroupAccount AS acc
             WHERE acc.GroupID =  grp.GroupID) AS TotalAccount
        ,	grp.Remark
        ,	grp.Created
		,	us.UserName AS CreatedBy
        ,	grp.Modified
		,	us1.UserName AS ModifiedBy
    FROM CTS_DataCenter.AssociatedGroup AS grp
		LEFT JOIN CTS_Admin.CTSUser AS us ON grp.CreatedBy = us.UserID
        LEFT JOIN CTS_Admin.CTSUser AS us1 ON grp.ModifiedBy = us1.UserID
        LEFT JOIN CTS_DataCenter.CustomerCategory AS cate ON grp.PACategoryID = cate.CategoryID
	WHERE grp.IsDisable = 0;
END$$
DELIMITER ;