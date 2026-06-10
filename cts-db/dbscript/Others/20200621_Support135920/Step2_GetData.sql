
	TRUNCATE TABLE CTS_Adhoc.Support135920_MemberClassification;
    INSERT INTO CTS_Adhoc.Support135920_MemberClassification( SuperUserName, CustID, SportGroupID,CategoryID,SportGroupName, CategoryName, InsertTime)
    SELECT 		mem.SuperUserName
                , mem.CustID
                , ccl.SportGroupID
                , ccl.CategoryID
                , (CASE WHEN ccl.SportGroupID > 0 THEN sg.SportGroupName ELSE '' END) AS SportGroupName
                , cat.CategoryName
                , current_timestamp()
    FROM		CTS_Adhoc.Support135920_Member AS mem
    LEFT JOIN   CTS_DataCenter.CTSCustomerClassification AS ccl
				ON mem.CustID = ccl.CustID
    LEFT JOIN	CTS_DataCenter.SportGroup AS sg
				ON ccl.SportGroupID = sg.SportGroupID
	LEFT JOIN  CTS_DataCenter.CustomerCategory AS cat
				ON ccl.CategoryID = cat.CategoryID; 
 
   
   TRUNCATE TABLE CTS_Adhoc.Support135920_CustomerCategory_Sport;
   INSERT INTO CTS_Adhoc.Support135920_CustomerCategory_Sport(SuperUserName, CustID,CategoryID, CategoryName,  CategorySports)
   SELECT 	ccl.SuperUserName
			, ccl.CustID
			, CategoryID
            , CategoryName
            , CONCAT(CategoryName, '(',GROUP_CONCAT(SportGroupName SEPARATOR ', '),')')  AS CategorySports 
   FROM CTS_Adhoc.Support135920_MemberClassification ccl
   GROUP BY ccl.SuperUserName, ccl.CustID, ccl.CategoryID, CategoryName;
   
  
   
   SELECT 		mem.SuperUserName, mem.CustID
				, GROUP_CONCAT(CategorySports SEPARATOR ', ')
   FROM		CTS_Adhoc.Support135920_CustomerCategory_Sport AS mem
   GROUP BY 	mem.SuperUserName, mem.CustID;
   
   SELECT * 
   FROM 		CTS_DataCenter.CTSCustomerClassification AS ccl
   WHERe 	CustID = 43119832;
   
   
	SELECT 	CustID
			, CategoryID
            , CategoryName
            , COUNT(1)
    FROM 	CTS_Adhoc.Support135920_MemberClassification ccl
    GROUP BY CustID, CategoryID, CategoryName
    ORDER BY CustID, CategoryID, CategoryName;
    
    CREATE TABLE 
    
    
    
    
    WHERE	ccl.CustID NOT IN (22932126, 22932845, 22932929, 22932965, 23273247, 23367350, 24626211, 26103912, 28093816, 32574035, 33206637, 36550998, 36599384, 37698462
					, 38042518, 38109846, 38157679, 39078964, 39393698, 39438402, 39471351, 39490575, 39556556, 39932345, 39965475, 40059418, 40183238, 40183287, 40201375, 40354292, 41022887, 41067048, 41067092, 41136512, 41323993, 41344263, 41477869, 41498011, 41514459, 41514545, 41518786, 41539070, 41563535, 41579181
                    , 41649847, 41807186, 41859688, 41859728, 42054743, 42064498, 42064548, 42280398, 42304580, 42305098, 42393105, 42402846, 42846578, 42855866, 42975008, 43119832, 43127984, 43156809, 43201821, 43357586);
                    