/*<info serverAlias="CTSMain-CTS_DataCenter" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Common_GetStaticList`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Common_GetStaticList`(
		IN	ip_ListID INT
	,	IN	ip_Status BOOL
)
    SQL SECURITY INVOKER
BEGIN
/*
		Created:	20191219@CaseyHuynh	
		Task:		CTS_DC_GetStaticList
		DB:			CTS_DataCenter
		Original:

		Revisions:
			- 20191219@Casey.Huynh: Created
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
			- 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
            - 20231122@Casey.Huynh: Return more info(ItemValue,ItemDefaultValue) [Redmine ID: #196396]
			
		Param's Explanation (filtered by):
        
		Example:
			CALL CTS_DC_Common_GetStaticList(@ip_ListID:=18, @ip_Status:=1);
            
	*/
   
   SELECT	sl.ListID
		,	sl.ItemID
		,	sl.ListName 
        ,	sl.ListNameDisplay
        ,	sl.ItemName
        ,	sl.ItemNameDisplay
        ,	sl.ItemValue
		,	sl.ItemDefaultValue
        ,	sl.PriorityOrder
        ,	sl.Status
        ,	sl.Description
        ,	sl.CreatedDate
	FROM  CTS_DataCenter.StaticList	AS sl
    WHERE   sl.ListID = ip_ListID
		AND sl.Status = ip_Status;
    
END$$
DELIMITER ;
