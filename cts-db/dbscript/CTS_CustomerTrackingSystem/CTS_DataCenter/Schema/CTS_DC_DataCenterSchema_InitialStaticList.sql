/*
Creator: 20191106@CaseyHuynh
Task:	 	Create Initial Data StaticList
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		- [20200123@CaseyHuynh][#127571]: Created
        
Reviewer:
*/
#==========INITIAL DATA====================================================
INSERT INTO CTS_DataCenter.StaticList(
			ListID, ItemID	, ListName			, ListNameDisplay	, ItemName			, ItemNameDisplay	, PriorityOrder	, Status	, Description			, CreatedDate)
VALUES	  	(1		,1		, 'Account Status'	, 'Status'			, 'Open'			, 'Open'			, 1				, 1			, 'Profile Status Item'	, CURRENT_DATE() )
			, (1	,2		, 'Account Status'	, 'Status'			, 'Suspended'		, 'Suspended'		, 2				, 1			, 'Profile Status Item'	, CURRENT_DATE() )
			, (1	,3		, 'Account Status'	, 'Status'			, 'Closed'			, 'Closed'			, 3				, 1			, 'Profile Status Item'	, CURRENT_DATE() )
			, (1	,4		, 'Account Status'	, 'Status'			, 'Active'			, 'Active'			, 4				, 1			, 'Profile Status Item'	, CURRENT_DATE() )
			, (1	,5		, 'Account Status'	, 'Status'			, 'View Only'		, 'View Only'		, 5				, 1			, 'Profile Status Item'	, CURRENT_DATE() )
			, (1	,6		, 'Account Status'	, 'Status'			, 'Inactive'		, 'Inactive'		, 6				, 1			, 'Profile Status Item'	, CURRENT_DATE() )
			, (1	,7		, 'Account Status'	, 'Status'			, 'Locked'			, 'Locked'			, 7				, 1			, 'Profile Status Item'	, CURRENT_DATE() )
			, (1	,8		, 'Account Status'	, 'Status'			, 'Archived'		, 'Archived'		, 8				, 1			, 'Profile Status Item'	, CURRENT_DATE() )
			, (1	,9		, 'Account Status'	, 'Status'			, 'Disabled'		, 'Disabled'		, 9				, 1			, 'Profile Status Item'	, CURRENT_DATE() )
            , (1	,10		, 'Account Status'	, 'Status'			, 'Not Yet Deposit'	, 'Not Yet Deposit'	, 10			, 1			, 'Profile Status Item'	, CURRENT_DATE() )
            , (2	,1		, 'Association Type', 'Association Type', 'Device'			, 'Device'			, 1				, 1			, 'Profile Status Item'	, CURRENT_DATE() )
			, (2	,2		, 'Association Type', 'Association Type', 'IP'				, 'IP'				, 2				, 1			, 'Profile Status Item'	, CURRENT_DATE() )
        ;

#=========================
/*
Licensee: Active, Locked, Closed, Archived
MBC: Open, Closed, Suspended, Disabled
CN88: Active, View Only, Suspended, Inactive*/