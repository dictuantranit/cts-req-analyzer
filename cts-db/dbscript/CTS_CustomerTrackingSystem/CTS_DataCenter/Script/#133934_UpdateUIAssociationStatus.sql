/*
Created: 20200518@lex.khuat
		Task:		Update robot description from Green to Human [Redmine ID: #133934]
		DB:			CTS_DataCenter
		Original:
		Revisions:
/*

/****=====Step=====****/ 
UPDATE CTS_DataCenter.StaticList
SET		ItemName = 'Linked', ItemNameDisplay = 'Linked'
WHERE	ListID = 3
AND		ItemID = 1;

UPDATE CTS_DataCenter.StaticList
SET		ItemName = 'Unlinked', ItemNameDisplay = 'Unlinked'
WHERE	ListID = 3
AND		ItemID = 2
/*====================*/