/****STEP01: COPY DATE TO NEW TABLE****/
#1.1: GET ALL DATA @Casey.Huynh
CALL CTS_Adhoc.CS138925_GetCusEvidence_New();

#1.3: GET GAP AND DELETE Evidence*****/
CALL CTS_Adhoc.CS138925_GetCusEvidence_NewGAP(); 

DELETE		 	ed
FROM 			CTS_Adhoc.CS138925_CustEvidence_New	AS ed
LEFT JOIN  		CTS_DataCenter.CustEvidence AS cus
				ON ed.CustEvidID = cus.CustEvidID
WHERE			cus.CustEvidID IS NULL;

/****STEP02: START UM****/
#2.0: @Harvey
 MYSQL:	Stop Service, Transform "CTS_DC_TransformAssociation_AffectedEvidence"
 GRAPH DB: Stop Kafka
 
#2.1. Web Deploy @Long.Luu

#2.2: Remove Evidence  @Casey.Huynh
DELETE		 	ed
FROM 			CTS_Adhoc.CS138925_CustEvidence_New	AS ed
LEFT JOIN  		CTS_DataCenter.CustEvidence AS cus
				ON ed.CustEvidID = cus.CustEvidID
WHERE			cus.CustEvidID IS NULL;

CALL CTS_Adhoc.CS138925_GetCusEvidence_NewGAP();

#2.3: Rename Table AND Deploy SPs 
#2.3a @Harvey.Nguyen
	 Rename Table "CTS_DataCenter.CustEvidence" to "CTS_DataCenter.CustEvidence_BK"
	 Rename Table "CTS_DataCenter.CS138925_CustEvidence_New" to "CTS_DataCenter.CustEvidence"
     
#2.3b DEPLOY SPs: @Casey.Huynh
	#==DROP SP===
    ;DROP PROCEDURE IF EXISTS CTS_DataCenter.CTS_DC_GetDirectAssociatedAccount_TagAffected;
    
    #==DEPLOY SPs (Original and xtest):
    CTS_DC_AddEvidence
	CTS_DC_AddException
	CTS_DC_AddMultiCustomerEvidence
	CTS_DC_API_AddEvidencesForCustomers
    CTS_DC_GetCustomerFlagInfo
    CTS_DC_GetDirectAssociatedAccount_TagFlagged
    CTS_DC_TransformAssociation_AffectedEvidence 
    CTS_DC_RemoveException
    
#2.4: QC Verify PRO: @Lex.Khuuất

#2.5: 
 MYSQL:	Start Service, Transform "CTS_DC_TransformAssociation_AffectedEvidence"
 GRAPH DB: Start Kafka
/******END UM************/