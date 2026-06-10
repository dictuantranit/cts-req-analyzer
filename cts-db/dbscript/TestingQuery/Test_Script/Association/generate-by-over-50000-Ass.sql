USE CTS_DataCenter;
DROP TEMPORARY TABLE IF EXISTS Temp_Cust;
CREATE TEMPORARY TABLE 	Temp_Cust (CustID BIGINT UNSIGNED PRIMARY KEY, CTSCustID BIGINT UNSIGNED, SubscriberID INT UNSIGNED);  
DROP TEMPORARY TABLE IF EXISTS Temp_AssociationByDevice;
CREATE TEMPORARY TABLE 	Temp_AssociationByDevice (CTSCustID BIGINT UNSIGNED PRIMARY KEY, SubscriberID INT UNSIGNED);  

set @lv_CustIDs = '1,2,3';
set @lv_DeviceID = 211102;

-- Update Info 
SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_Cust (CustID) VALUES ('", REPLACE(@lv_CustIDs, ",", "'),('"),"');");
PREPARE stmt1 FROM @sql;
EXECUTE stmt1;      

-- Update Info 
UPDATE Temp_Cust AS temp
INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON temp.CustID = cust.CustID AND cust.CustSubID = 0
SET temp.CTSCustID = cust.CTSCustID, temp.SubscriberID = cust.SubscriberID;

-- Between 2 customers
INSERT IGNORE INTO Temp_AssociationByDevice (CTSCustID, SubscriberID)
SELECT temp.CTSCustID, temp.SubscriberID
FROM Temp_Cust AS temp;

-- All current ass by device
INSERT IGNORE INTO Temp_AssociationByDevice (CTSCustID, SubscriberID)
SELECT d.CTSCustID, d.SubscriberID
FROM CTS_DataCenter.CTSCustomer AS d
ORDER BY d.CTSCustID DESC
LIMIT 5000;

-- Clean data    
delete ass from CTS_DataCenter.AssociationByDevice AS ass where ass.DCSDeviceID = @lv_DeviceID;

-- Insert to Ass by device > 100k.
INSERT INTO CTS_DataCenter.AssociationByDevice(CTSCustID,DCSDeviceID,SubscriberID,CreatedTime,InsertTime)
SELECT DISTINCT temp.CTSCustID,@lv_DeviceID,temp.SubscriberID,current_timestamp(),current_timestamp()
from Temp_AssociationByDevice AS temp;

-- Check result
SELECT * FROM CTS_DataCenter.AssociationByDevice AS ass inner join Temp_AssociationByDevice AS temp on temp.CTSCustID = ass.CTSCustID and dcsdeviceid = @lv_DeviceID order by ass.CTSAssDevID desc;
-- CALL CTS_DataCenter.CTS_DC_Association_DeviceAssociationDay_Insert(500);