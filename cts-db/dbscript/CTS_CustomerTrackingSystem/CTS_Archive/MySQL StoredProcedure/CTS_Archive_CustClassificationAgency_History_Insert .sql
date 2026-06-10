/*<info serverAlias="CTSMain-CTS_Archive" databaseType="2" executers="ctsServiceAdmin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_Archive`.`CTS_Archive_CustClassificationAgency_History_Insert`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_Archive_CustClassificationAgency_History_Insert`(
		IN ip_HistoryJson JSON
)
    SQL SECURITY INVOKER
BEGIN
/*
	Created: 20250725@Winfred.Pham
	Task : Archive CTSCustomerClassificationAgency_History
	DB: CTS_Archive 
	Original:

	Revisions:
		- 20250725@Winfred.Pham: 	Created [Redmine ID: #219679]
        
	Param's Explanation (filtered by):

*/

	INSERT INTO CTS_Archive.CTSCustomerClassificationAgency_History_Archive(
			HistoryID
        ,	CustID
        ,	CTSCustID
        ,	RoleID
        ,	ParentID
        ,	CategoryID
        ,	OldCategoryID
        ,	DWCategoryID
        ,	TargetCC
        ,	SourceTypeID
        ,	IsDataChanged
        ,	ActionType
        ,	IsAuto
        ,	LastModifiedDate
        ,	LastModifiedBy
        ,	InsertDate
        ,	TargetDangerLevel1
        ,	Remark
        ,	IsMarkedDirectly
        ,	IsFromTW
        ,	IsFromCTS
        ,	IsFromAI
        ,	TurnoverRM
        ,	WinlossRM
        ,	BetCount
        ,	LastXDaysTurnoverRM
        ,	LastXDaysWinlossRM
        ,	LastXDaysBetCount
        ,	LastYDaysTurnoverRM
        ,	LastYDaysWinlossRM
        ,	LastYDaysBetCount
        ,	PerformanceTime
        ,	RobotCounter

	)
	SELECT	HistoryID
        ,	CustID
        ,	CTSCustID
        ,	RoleID
        ,	ParentID
        ,	CategoryID
        ,	OldCategoryID
        ,	DWCategoryID
        ,	TargetCC
        ,	SourceTypeID
        ,	IsDataChanged
        ,	ActionType
        ,	IsAuto
        ,	LastModifiedDate
        ,	LastModifiedBy
        ,	InsertDate
        ,	TargetDangerLevel1
        ,	Remark
        ,	IsMarkedDirectly
        ,	IsFromTW
        ,	IsFromCTS
        ,	IsFromAI
        ,	TurnoverRM
        ,	WinlossRM
        ,	BetCount
        ,	LastXDaysTurnoverRM
        ,	LastXDaysWinlossRM
        ,	LastXDaysBetCount
        ,	LastYDaysTurnoverRM
        ,	LastYDaysWinlossRM
        ,	LastYDaysBetCount
        ,	PerformanceTime
        ,	RobotCounter

	FROM JSON_TABLE(
			ip_HistoryJson,
			 "$[*]" COLUMNS(
								HistoryID				        BIGINT UNSIGNED 	PATH "$.ID"       
							,	CustID					        BIGINT UNSIGNED 	PATH "$.CustID"   
							,	CTSCustID				        BIGINT UNSIGNED 	PATH "$.CTSCustID"
							,	RoleID    			            TINYINT UNSIGNED	PATH "$.RoleID"
							,	ParentID    			        INT UNSIGNED	    PATH "$.ParentID"
							,	CategoryID				        INT     			PATH "$.CategoryID"
							,	OldCategoryID 			        INT UNSIGNED 	    PATH "$.OldCategoryID"
							,	DWCategoryID 			        INT UNSIGNED 	    PATH "$.DWCategoryID"
							,	TargetCC				        INT      			PATH "$.TargetCC"
                            ,	SourceTypeID			        SMALLINT UNSIGNED	PATH "$.SourceTypeID"
							,	IsDataChanged 			        TINYINT(1)			PATH "$.IsDataChanged"
							,	ActionType 				        TINYINT 			PATH "$.ActionType"
							,	IsAuto 					        TINYINT(1)			PATH "$.IsAuto"
							,	LastModifiedDate 		        DATETIME 			PATH "$.LastModifiedDate"
							,	LastModifiedBy 			        INT UNSIGNED 		PATH "$.LastModifiedBy"
							,	InsertDate 				        DATETIME  			PATH "$.InsertDate"
							,	TargetDangerLevel1 		        SMALLINT  			PATH "$.TargetDangerLevel1"
                            ,	Remark		                    VARCHAR(500) 		PATH "$.Remark"
                            ,   IsMarkedDirectly                TINYINT(1)          PATH "$.IsMarkedDirectly"
			                ,	IsFromTW 				        TINYINT(1) 	        PATH "$.IsFromTW"  
			                ,	IsFromCTS 				        TINYINT(1) 	        PATH "$.IsFromCTS"   
			                ,	IsFromAI 	                    TINYINT(1) 	        PATH "$.IsFromAI"  
							,	TurnoverRM				        DECIMAL(20 , 4 )	PATH "$.TurnoverRM"
							,	WinlossRM				        DECIMAL(20 , 4 ) 	PATH "$.WinlossRM"
							,	BetCount				        BIGINT 				PATH "$.BetCount"
							,	LastXDaysTurnoverRM 	        DECIMAL(20 , 4 )  	PATH "$.LastXDaysTurnoverRM"
							,	LastXDaysWinlossRM 		        DECIMAL(20 , 4 )  	PATH "$.LastXDaysWinlossRM"
							,	LastXDaysBetCount 		        BIGINT UNSIGNED  	PATH "$.LastXDaysBetCount"
							,	LastYDaysTurnoverRM 	        DECIMAL(20 , 4 )  	PATH "$.LastYDaysTurnoverRM"
							,	LastYDaysWinlossRM 		        DECIMAL(20 , 4 )  	PATH "$.LastYDaysWinlossRM"
							,	LastYDaysBetCount 		        BIGINT UNSIGNED  	PATH "$.LastYDaysBetCount"
                            ,	PerformanceTime			        DATETIME			PATH "$.PerformanceTime"  
                            ,	RobotCounter			        INT					PATH "$.RobotCounter"
							)
		   ) AS  tbl; 

END$$
DELIMITER ;