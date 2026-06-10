	/*
		Created:	20200515@CaseyHuynh	
		Task :		REMOVE Data
		DB:			CTS_DataCenter
		Original:

		Revisions:
		Param's Explanation (filtered by):
	*/
       SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;    
       
    /*Step 1: Backup up Delete CustDCSAccount 5798 + 578*******************/   
	
    INSERT INTO CTS_Adhoc.cs133426_BK_CustDCSAccount_Del
    SELECT 		cda.*, cdaBk.processType
	FROM		CTS_DataCenter.CustDCSAccount AS cda
    INNER JOIN  CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cdaBk
				ON cda.AccountID = cdaBk.cdaAccountID
	WHERE		cdaBk.processType != 1;    
    
    INSERT INTO CTS_Adhoc.cs133426_BK_CustDCSAccount_Del
    SELECT 		cda.*,  20
    FROM 		CTS_DataCenter.CustDCSAccount AS cda
    INNER JOIN 	CTS_Adhoc.cs133426_CustDCSAccountWrongSub AS cdaBk
				ON cda.CTSCustID = NewCTSCustID
	WHERE		cdaBk.processType = 2;

    /*Step 2: BACK UP delete AssociationByDevice*******************/    
    INSERT INTO CTS_Adhoc.cs133426_BK_AssociationByDevice_Del
    SELECT 		ass.*, assBk.processType
	FROM		CTS_DataCenter.AssociationByDevice AS ass
    INNER JOIN  CTS_Adhoc.cs133426_BK_CustDCSAccount_Del AS assBk
				ON ass.CTSCustID = assBk.CTSCustID
	WHERE		assBk.processType != 1 ;   
    
    /*Step 3: Delete CustDCSAccount******************************************/
    DELETE		cda
    FROM		CTS_DataCenter.CustDCSAccount AS cda
    INNER JOIN  CTS_Adhoc.cs133426_BK_CustDCSAccount_Del AS cdaBk
				ON cda.AccountID = cdaBk.cdaAccountID; 
    
    /*Step 4: DELETE AssociationByDevice *******************************************/
    DELETE		ass
    FROM		CTS_DataCenter.AssociationByDevice AS ass
    INNER JOIN  CTS_Adhoc.cs133426_BK_AssociationByDevice_Del AS assBk
				ON ass.CTSAssDevID = assBk.CTSAssDevID;
                
	/*Step 5: Turn ON Transform DCS_DataCenter.Account *****************************/
    UPDATE		DCS_DataCenter.Account	AS acc
    INNER JOIN	CTS_Adhoc.cs133426_BK_CustDCSAccount_Del AS bkAcc
				ON acc.AccountID = bkAcc.AccounID
	SET			acc.IsCTSProcessed = 0
    WHERE		bkAcc.ProcessType IN (2,20);
    
    UPDATE		DCS_DataCenter.Association	AS ass
    INNER JOIN  CTS_Adhoc.cs133426_BK_CustDCSAccount_Del AS bkAcc
				ON ass.AccountID = bkAcc.AccountID
	SET			ass.IsCTSProcessed = 0
    WHERE		bkAcc.ProcessType IN (2,20);