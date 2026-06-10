/*
Creator: 20191106@CaseyHuynh 
Task:	 	Correct data CTS_customer Missing vs CustDCSAccount
Server:  	Slave
DBName:		CTS_DataCenter

Revisions: 
		
Reviewer:
*/

#4. Correct Data for AlphaCN88 and CN88
#4.1 Update Subscriber Mapping Prefix for AlphaCN88
UPDATE	CTS_Admin.Subscriber
SET		SubscriberPrefix = 'CN88$'
WHERE	SubscriberName = 'AlphaCN88';

