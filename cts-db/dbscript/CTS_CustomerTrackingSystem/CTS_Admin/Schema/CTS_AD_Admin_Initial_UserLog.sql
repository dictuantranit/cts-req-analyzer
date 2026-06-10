/*
Creator: 20200204@CaseyHuynh
Task:	 Initail LogType
Server:  
DBName:	CTS_Admin

Revisions: 
Reviewer:
*/

INSERT IGNORE INTO CTS_Admin.LogType(LogTypeID, LogTypeName)
VALUES	(1,'Insert Exception')
		, (2,'Remove Exception')
		, (3,'Add Customer Evidence')
        , (4,'Remove Customer Evidence');