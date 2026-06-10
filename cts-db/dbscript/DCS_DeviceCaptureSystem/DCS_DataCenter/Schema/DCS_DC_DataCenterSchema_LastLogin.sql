/*
Creator: 20190521@Casey.Huynh
Task:    Create Schema FPS4.0 - Data Center
Server:  
DBName:	DCS_DataCenter

Revisions:
		[20200522@Casey.Huynh][133488]: Create tranform temp table         

Reviewer: 
*/

CREATE TABLE IF NOT EXISTS DCS_DataCenter.LastLoginTime_TransformTemp(
		ID					BIGINT		AUTO_INCREMENT
        , CTSCustID			BIGINT		UNSIGNED	NOT NULL   
        , LastLoginTime		TIMESTAMP(4)			NOT NULL 
        
        , PRIMARY KEY	PK_TrasformLastLoginTime_ID(ID)
        , INDEX 		IX_TrasformLastLoginTime_CTSCustID(CTSCustID)
        
) ENGINE=InnoDB, AUTO_INCREMENT = 1;
  