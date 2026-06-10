
	/*
		Created:	20200519@Casey
		Task:		Remove Account NOT In CTS
		DB:			CTS_Adhoc
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
	
/********************************BACKUP DATE **********************************/	
/******************************************************************************/
	SHOW processlist; #STOP TRANSFORM SERVICE ALL
	
	SELECT current_timestamp() AS STARTTIME; #2020-05-21 03:03:21;
    
	#====STEP01: GET Account backup
    CALL CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetAccount();
    #368860 row(s) affected

    #====STEP02: GET Association backup
    CALL CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetAssociation();
    #100789 row(s) affected
    
    #====STEP03: GET Device backup
    CALL CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetDevice();
    
    #====STEP04: GET DeviceFingerprint backup
    CALL CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetDeviceFingerprint();
    
	#====STEP04.1: GET DeviceCode backup
    CALL CTS_Adhoc.cs0519_DCSAccountNotInCTS_GetDeviceCode();
    
    
/********************************REMOVE DATA **********************************/	
/******************************************************************************/
	#====STEP05: DELETE Account 
    CALL CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteAccount(); #368860 row(s) affected

    
    #====STEP06: DELETE Association
    CALL CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteAssociation();
    
    #====STEP07: DELETE Device
    CALL CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteDevice(); 79029 row(s) affected;

    
    #====STEP08: DELETE DeviceFingerprint 
    CALL CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteDeviceFingerprint; 98483 row(s) affected;
    
    #====STEP9: DELETE DeviceCode 
    CALL CTS_Adhoc.cs0519_DCSAccountNotInCTS_DeleteDeviceCode; 95779 row(s) affected

    
    SELECT current_timestamp() AS ENDTIME; 2020-05-21 05:39:50;