/*<info serverAlias="CTSMain-CTS_Archive" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_Archive`.`CTS_Archive_CustClassification_History_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_Archive_CustClassification_History_Insert`(
		IN ip_HistoryJson JSON
)
    SQL SECURITY INVOKER
BEGIN
/*
	Created: 20210826@Aries.Nguyen
	Task : Archive CTSCustomerClassification_History
	DB: CTS_Archive 
	Original:

	Revisions:
		- 20201006@Aries.Nguyen:	Created  [Redmine ID: #160758] 
		- 20230315@Victoria.Le:		Add Robot Imperva [Redmine ID: #184773]
		- 20230404@Victoria.Le		TVS Abnormal Bet and Abnormal Account - Add IsParlay,SportType,IssueTypeId [Redmine ID: #185319] 
		- 20230428@Jonas.Huynh: 	Realtime Renovation [Redmine ID: #186678]
		- 20231108@Victoria.Le: 	Add First5TWGBTicketCount [Redmine ID: #195060]
		- 20240812@Victoria.Le: 	Renovate CC - Phase 2 [Redmine ID: #205317]
		- 20240618@Victoria.Le:     RobotCounter - Change datatype [Redmine ID: #212240]
        
	Param's Explanation (filtered by):

*/

	INSERT INTO CTS_Archive.CTSCustomerClassification_History_Renovate_Archive(
			HistoryID
        ,	CustID
        ,	CTSCustID
        ,	ParentID
        ,	CategoryID
        ,	TurnoverRM
        ,	WinlossRM
        ,	BetCount
        ,	ActiveDays
        ,	RobotCounter
        ,	TargetCC
        ,	SourceTypeID
		,	OldCategoryID 			
        ,	DWCategoryID 						
        ,	IsDataChanged 			
        ,	ActionType 				
        ,	IsAuto 					
        ,	LastModifiedDate 		
        ,	LastModifiedBy 			
        ,	InsertDate 				
        ,	TaggingType 			
        ,	TargetDangerLevel1 		
        ,	TWGroupBettingRate 		
        ,	TWTicketRejectRate 		
        ,	TWBetCount 				
        ,	TWDesktopUsageRate   
     	,	Remark
        ,   IsMarkedDirectly
        ,   TVSRequestID
        ,	IsFromTVS 				 
		,	IsFromTW 				
		,	IsFromCTS 				
		,	IsFromAI
		,	IsFromImperva
		,	IsParlay
		,	SportType
		,	IssueTypeID
        ,	PerformanceTime
	)
	SELECT	HistoryID
        ,	CustID
        ,	CTSCustID
        ,	ParentID
        ,	CategoryID
        ,	TurnoverRM
        ,	WinlossRM
        ,	BetCount
        ,	ActiveDays
        ,	RobotCounter
        ,	TargetCC
        ,	SourceTypeID
		,	OldCategoryID 			
        ,	DWCategoryID 						
        ,	IsDataChanged 			
        ,	ActionType 				
        ,	IsAuto 					
        ,	LastModifiedDate 		
        ,	LastModifiedBy 			
        ,	InsertDate 				
        ,	TaggingType 			
        ,	TargetDangerLevel1 		
        ,	TWGroupBettingRate 		
        ,	TWTicketRejectRate 		
        ,	TWBetCount 				
        ,	TWDesktopUsageRate  
        ,	Remark
        ,   IsMarkedDirectly
        ,   TVSRequestID
        ,	IsFromTVS 				 
		,	IsFromTW 				
		,	IsFromCTS 				
		,	IsFromAI 	
		,	IsFromImperva
		,	IsParlay
		,	SportType
		,	IssueTypeID
        ,	PerformanceTime
	FROM JSON_TABLE(
			ip_HistoryJson,
			 "$[*]" COLUMNS(
								HistoryID				BIGINT UNSIGNED 	PATH "$.ID"       
							,	CustID					BIGINT UNSIGNED 	PATH "$.CustID"   
							,	CTSCustID				BIGINT UNSIGNED 	PATH "$.CTSCustID"
							,	ParentID    			INT UNSIGNED	    PATH "$.ParentID"
							,	CategoryID				INT     			PATH "$.CategoryID"
							,	TurnoverRM				DECIMAL(20 , 4 )	PATH "$.TurnoverRM"
							,	WinlossRM				DECIMAL(20 , 4 ) 	PATH "$.WinlossRM"
							,	BetCount				BIGINT 				PATH "$.BetCount"
                            ,	ActiveDays				INT					PATH "$.ActiveDays"
                            ,	RobotCounter			INT					PATH "$.RobotCounter"
							,	TargetCC				INT      			PATH "$.TargetCC"
                            ,	SourceTypeID			SMALLINT UNSIGNED	PATH "$.SourceTypeID"
							,	OldCategoryID 			INT UNSIGNED 	    PATH "$.OldCategoryID"
							,	DWCategoryID 			INT UNSIGNED 	    PATH "$.DWCategoryID"
							,	IsDataChanged 			TINYINT(1)			PATH "$.IsDataChanged"
							,	ActionType 				TINYINT 			PATH "$.ActionType"
							,	IsAuto 					TINYINT(1)			PATH "$.IsAuto"
							,	LastModifiedDate 		DATETIME 			PATH "$.LastModifiedDate"
							,	LastModifiedBy 			INT UNSIGNED 		PATH "$.LastModifiedBy"
							,	InsertDate 				DATETIME  			PATH "$.InsertDate"
							,	TaggingType 			SMALLINT  			PATH "$.TaggingType"
							,	TargetDangerLevel1 		SMALLINT  			PATH "$.TargetDangerLevel1"
							,	TWGroupBettingRate 		DECIMAL(10 , 4 )  	PATH "$.TWGroupBettingRate"
							,	TWTicketRejectRate 		DECIMAL(10 , 4 )  	PATH "$.TWTicketRejectRate"
							,	TWBetCount 				BIGINT  			PATH "$.TWBetCount"
							,	TWDesktopUsageRate		DECIMAL(10 , 4 ) 	PATH "$.TWDesktopUsageRate"
                            ,	Remark		            VARCHAR(500) 		PATH "$.Remark"
                            ,   IsMarkedDirectly        TINYINT(1)          PATH "$.IsMarkedDirectly"
                            ,   TVSRequestID            BIGINT UNSIGNED 	PATH "$.TVSRequestID"   
                            ,	IsFromTVS 				TINYINT(1) 	        PATH "$.IsFromTVS"
			                ,	IsFromTW 				TINYINT(1) 	        PATH "$.IsFromTW"  
			                ,	IsFromCTS 				TINYINT(1) 	        PATH "$.IsFromCTS"   
			                ,	IsFromAI 	            TINYINT(1) 	        PATH "$.IsFromAI"  
							,	IsFromImperva			TINYINT(1) 	        PATH "$.IsFromImperva"  
							,	IsParlay				TINYINT(1)			PATH "$.IsParlay"  
							,	SportType				SMALLINT			PATH "$.SportType"  
							,	IssueTypeID				TINYINT				PATH "$.IssueTypeID"  
                            ,	PerformanceTime			DATETIME			PATH "$.PerformanceTime"  
							)
		   ) AS  tbl; 

END$$
DELIMITER ;