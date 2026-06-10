use CTS_DataCenter;
DROP TEMPORARY TABLE IF EXISTS Temp_Customers;
CREATE TEMPORARY TABLE 		Temp_Customers (
		CustID BIGINT UNSIGNED, CTSCustID BIGINT UNSIGNED, SubscriberID INT UNSIGNED
);  

set @lv_CustIDs = 
'37144067,37144068,37144070,37144071,37144072,37144073,37144074,37144076,37144077,37144079,37144081,37144083,37144084,37144085,37144086,37144088,37144089,37144091,37144092,37144093,37144094,37144095,37144096,37144097,37144098';
set @lv_DeviceID = 211110;

-- Update Info 
SET @sql = 	CONCAT("INSERT IGNORE INTO Temp_Customers (CustID) VALUES ('", REPLACE(@lv_CustIDs, ",", "'),('"),"');");
PREPARE stmt1 FROM @sql;
EXECUTE stmt1;      
	
UPDATE Temp_Customers AS temp
	INNER JOIN CTS_DataCenter.CTSCustomer AS cust ON cust.CustID = temp.CustID AND cust.CustSubID = 0
SET temp.CTSCustID = cust.CTSCustID, temp.SubscriberID = cust.SubscriberID;

-- Clean data    
delete ass from CTS_DataCenter.AssociationByDevice AS ass inner join Temp_Customers AS temp on temp.CTSCustID = ass.CTSCustID;
delete ass from CTS_DataCenter.AssociationByManual as ass inner join Temp_Customers AS temp on temp.CTSCustID = ass.FromCTSCustID OR temp.CTSCustID = ass.ToCTSCustID;
delete ce from CTS_DataCenter.CustEvidence as ce inner join Temp_Customers AS temp on temp.CTSCustID = ce.CTSCustID;
delete cate from CTS_DataCenter.CTSCustomerClassification as cate inner join Temp_Customers AS temp on temp.CTSCustID = cate.CTSCustID;
delete h from CTS_DataCenter.CTSCustomerClassification_History as h inner join Temp_Customers AS temp on temp.CTSCustID = h.CTSCustID;
delete p from CTS_DataCenter.ProbationAccountMonitor as p inner join Temp_Customers AS temp on temp.CTSCustID = p.CTSCustID;

insert into CTS_DataCenter.AssociationByDevice(CTSCustID,DCSDeviceID,SubscriberID,CreatedTime,InsertTime)
select temp.CTSCustID,@lv_DeviceID,temp.SubscriberID,current_timestamp(),current_timestamp()
from Temp_Customers AS temp;

-- Check result
select * from CTS_DataCenter.AssociationByDevice AS ass inner join Temp_Customers AS temp on temp.CTSCustID = ass.CTSCustID;
-- CALL CTS_DataCenter.CTS_DC_Association_DeviceAssociationDay_Insert(1000);
CALL CTS_DataCenter.CTS_DC_Association_GetGroup(@lv_CustIDs);
SELECT  * FROM CTS_DataCenter.Temp_Group;