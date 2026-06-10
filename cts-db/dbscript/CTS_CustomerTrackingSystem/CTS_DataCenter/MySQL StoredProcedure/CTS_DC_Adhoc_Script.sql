DELIMITER $$
USE CTS_DataCenter $$
DROP PROCEDURE IF EXISTS `CTS_DataCenter`.`CTS_DC_Adhoc_MigrateNewMemberCategory`$$

CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Adhoc_MigrateNewMemberCategory`()
    SQL SECURITY INVOKER
BEGIN
	/*
	Created: 20201126@Long.Luu
	Task:    Migrate New Member category from 2 to 201 [Redmine ID: 0000]
	DB:      CTS_DataCenter


	Revisions:
			- 20201126@Long.Luu: Created [Redmine ID: 0000]

	Param's Explanation (filtered by):  
			- [Param1: brief about param1]

	Example:  
			- CALL Store_Name ();
	*/
    
    DROP TEMPORARY TABLE IF EXISTS Temp_Customers;
	CREATE TEMPORARY TABLE Temp_Customers (
		CustID		BIGINT UNSIGNED PRIMARY KEY
	);
    
    DROP TEMPORARY TABLE IF EXISTS Temp_CustomersByBatch;
	CREATE TEMPORARY TABLE Temp_CustomersByBatch (
		CustID		BIGINT UNSIGNED PRIMARY KEY
	);

	INSERT INTO Temp_Customers(CustID)
	SELECT DISTINCT CustID
	FROM CTS_DataCenter.CTSCustomer
    WHERE CustStatusID = 0;
    
	WHILE EXISTS (SELECT 1 FROM Temp_Customers)
	DO
		TRUNCATE TABLE Temp_CustomersByBatch;
		
		INSERT INTO Temp_CustomersByBatch(CustID)
		SELECT CustID
		FROM Temp_Customers
		LIMIT 5000; #batchsize
		
        UPDATE CTS_DataCenter.CTSCustomer AS c
		INNER JOIN Temp_CustomersByBatch AS m ON m.CustID = c.CustID
		SET c.CustStatusID = 1;
        
        DELETE c
        FROM Temp_CustomersByBatch AS t
			INNER JOIN Temp_Customers AS c ON t.CustID = c.CustID;      
		
		DO SLEEP(5);
	END WHILE;

	DROP TEMPORARY TABLE Temp_Customers;
    DROP TEMPORARY TABLE Temp_CustomersByBatch;
    
    /*
    DROP TEMPORARY TABLE IF EXISTS Temp_NewMembers;
	CREATE TEMPORARY TABLE Temp_NewMembers (
		CTSCustID1		BIGINT UNSIGNED
	,	CustID1			BIGINT UNSIGNED
	, 	DeviceID		BIGINT UNSIGNED
	, 	INDEX			IX_PAuseDevices_bk_CTSCustID1(CTSCustID1)
    , 	INDEX			IX_PAuseDevices_bk_CustID1(CustID1)
    , 	INDEX			IX_PAuseDevices_bk_DeviceID(DeviceID)
	);

	WHILE EXISTS (SELECT 1 FROM CTS_Adhoc.PAuseDevices)
	DO
		TRUNCATE TABLE Temp_NewMembers;
		
		INSERT INTO Temp_NewMembers(CTSCustID1,CustID1,DeviceID)
		SELECT CTSCustID1,CustID1,DeviceID
		FROM CTS_Adhoc.PAuseDevices
		LIMIT 5000; #batchsize
		
		INSERT INTO CTS_Adhoc.PADevicePA(CTSCustID1,CustID1,DeviceID,CTSCustID2)
		SELECT c.CTSCustID1, c.CustID1, c.DeviceID, d.CTSCustID
		FROM Temp_NewMembers AS c
			INNER JOIN CTS_DataCenter.AssociationByDevice AS d ON c.DeviceID = d.DCSDeviceID
		WHERE c.CTSCustID1 <> d.CTSCustID;
        
        SET SQL_SAFE_UPDATES = 0;
		UPDATE CTS_Adhoc.PADevicePA AS m
		INNER JOIN CTS_DataCenter.CTSCustomer AS c ON m.CustID2 IS NULL AND m.CTSCustID2 = c.CTSCustID
		SET m.CustID2 = c.CustID;
        
        UPDATE CTS_Adhoc.PADevicePA AS m
		INNER JOIN CTS_DataCenter.CTSCustomerClassification AS c ON m.CustID2 IS NOT NULL AND m.CustID2 = c.CustID
		SET m.IsCust2PA = 1
		WHERE c.SportGroupID = 200 AND c.CategoryID IN (206,203,204);
        
        DELETE c
        FROM Temp_NewMembers AS t
			INNER JOIN CTS_Adhoc.PAuseDevices AS c ON t.CTSCustID1 = c.CTSCustID1
				AND t.CustID1 = c.CustID1 AND t.DeviceID = c.DeviceID;           
		
		SELECT SLEEP(5);
	END WHILE;

	DROP TEMPORARY TABLE Temp_NewMembers;
    */
    /*
    DROP TEMPORARY TABLE IF EXISTS Temp_NewMembers;
	CREATE TEMPORARY TABLE Temp_NewMembers (
		CustId	BIGINT UNSIGNED PRIMARY KEY
	);

	WHILE EXISTS (SELECT 1 FROM CTS_Adhoc.AdhocData)
	DO
		TRUNCATE TABLE Temp_NewMembers;
		
		INSERT INTO Temp_NewMembers(CustId)
		SELECT CustId
		FROM CTS_Adhoc.AdhocData
		LIMIT 5000; #batchsize
		
		DELETE c
        FROM Temp_NewMembers AS t
			INNER JOIN CTS_DataCenter.ProbationAccountMonitor AS c ON t.CustId = c.CustId
		WHERE SportGroupID = 200;# AND c.CategoryID <> 201;
        
        DELETE c
        FROM Temp_NewMembers AS t
			INNER JOIN CTS_Adhoc.AdhocData AS c ON t.CustId = c.CustId;           
		
		SELECT SLEEP(5);
	END WHILE;

	DROP TEMPORARY TABLE Temp_NewMembers;
    */
	/* Migrate 2 to 201
    DROP TEMPORARY TABLE IF EXISTS Temp_NewMembers;
	CREATE TEMPORARY TABLE Temp_NewMembers (
		CustId	BIGINT UNSIGNED PRIMARY KEY
	);

	WHILE EXISTS (SELECT 1 FROM CTS_DataCenter.CTSCustomerClassification WHERE CategoryID = 2)
	DO
		TRUNCATE TABLE Temp_NewMembers;
		
		INSERT INTO Temp_NewMembers(CustId)
		SELECT CustId
		FROM CTS_DataCenter.CTSCustomerClassification
		WHERE CustId > 0 AND SportGroupID = 0 AND CategoryID = 2
		LIMIT 1000; #batchsize
		
		UPDATE Temp_NewMembers AS t
			INNER JOIN CTS_DataCenter.CTSCustomerClassification AS c ON t.CustId = c.CustId
		SET c.CategoryID = 201, c.SportGroupID = 200
		WHERE SportGroupID = 0 AND c.CategoryID = 2;
	END WHILE;

	DROP TEMPORARY TABLE Temp_NewMembers;
    */
END$$