# Danger Monitor Diagrams
1. **DangerMonitor_Diagrams_01_MainFlow.puml** - Main Business Flow Diagram
2. **DangerMonitor_Diagrams_02_Sequence_NoAssociation.puml** - Sequence: No Association Mode
3. **DangerMonitor_Diagrams_03_Sequence_WithAssociation.puml** - Sequence: With Association Mode
4. **DangerMonitor_Diagrams_04_Sequence_DetailPage.puml** - Sequence: Detail Page
5. **DangerMonitor_Diagrams_05_Component.puml** - Component Architecture Diagram
6. **DangerMonitor_Diagrams_06_DatabaseFlow.puml** - Database Flow Diagram (High-level)
7. **DangerMonitor_Diagrams_07_DatabaseFlow_Detailed.puml** - Detailed Database Flow with Tables
8. **DangerMonitor_Diagrams_08_SP_Operations_Detail.puml** - Stored Procedure Operations Detail
9. **DangerMonitor_Diagrams_09_SP_GetFilter_Detailed.puml** - CTS_MatchMonitor_Details_GetFilter Detailed Flow
10. **DangerMonitor_Diagrams_10_SP_GetTicket_Detailed.puml** - CTS_MatchMonitor_Details_GetTicket Detailed Flow
11. **DangerMonitor_Diagrams_11_SP_Associations_Get_Detailed.puml** - CTS_MatchTicketInfo_Associations_Get Detailed Flow
12. **DangerMonitor_Diagrams_12_SP_Association_GetByUserNameList_Detailed.puml** - CTS_DC_Association_GetByUserNameList Detailed Flow

### 1. **DangerMonitor_MainFlow** (Activity Diagram)
- **Mục đích**: Business flow tổng thể của Danger Monitor
- **Nội dung**: Từ khi user mở page đến các actions chính
- **Sử dụng**: Overview cho stakeholders

### 2. **DangerMonitor_Sequence_NoAssociation** (Sequence Diagram)
- **Mục đích**: Chi tiết flow khi search không có association
- **Nội dung**: Controller → Service → Repository → Database
- **Stored Procedure**: `CTS_MatchTicketInfo_Get`
- **Sử dụng**: Technical documentation cho developers

### 3. **DangerMonitor_Sequence_WithAssociation** (Sequence Diagram)
- **Mục đích**: Chi tiết flow khi search có association
- **Nội dung**: Bao gồm Association Detection Service
- **Stored Procedure**: `CTS_MatchTicketInfo_Associations_Get`
- **Sử dụng**: Technical documentation cho developers

### 4. **DangerMonitor_Sequence_DetailPage** (Sequence Diagram)
- **Mục đích**: Flow của Detail Page
- **Nội dung**: Load filters và tickets
- **Stored Procedures**: 
  - `CTS_MatchMonitor_Details_GetFilter`
  - `CTS_MatchMonitor_Details_GetTicket`
- **Sử dụng**: Technical documentation cho developers

### 5. **DangerMonitor_Component_Diagram** (Component Diagram)
- **Mục đích**: Kiến trúc tổng thể của components
- **Nội dung**: Các layers và relationships
- **Sử dụng**: Architecture overview

### 6. **DangerMonitor_DatabaseFlow** (Activity Diagram)
- **Mục đích**: Database flow và stored procedures (High-level)
- **Nội dung**: Các stored procedures và parameters
- **Sử dụng**: Database documentation

### 7. **DangerMonitor_DatabaseFlow_Detailed** (Component + Entity Diagram)
- **Mục đích**: Chi tiết database tables và operations
- **Nội dung**: 
  - Database name (bodb02/WASAVerse)
  - Tables được sử dụng (bettrans, Match, Customer, Exchange)
  - Operations (SELECT, INSERT, JOIN)
  - Temp tables
- **Sử dụng**: Database documentation

### 8. **DangerMonitor_SP_Operations_Detail** (Activity Diagram)
- **Mục đích**: Chi tiết operations trong từng stored procedure
- **Nội dung**:
  - Temp table creation
  - SELECT operations với filters
  - JOIN operations
  - Aggregation logic
- **Sử dụng**: Database developers và performance tuning

### 9. **DangerMonitor_SP_GetFilter_Detailed** (Component Diagram)
- **Mục đích**: Chi tiết flow của CTS_MatchMonitor_Details_GetFilter
- **Nội dung**:
  - Database: bodb02/WASAVerse
  - Tables: bettrans, bettrans14, bettrans_bk, Match, Customer, custInfo, Exchange
  - Temp tables: #tmpTrans, #tmpSportBettype, #tmpSuspiciousTrans, etc.
  - ViewMode logic (0, 1, 2)
  - Data source logic (Origin, 14 days, Archive)
  - UPDATE operations để enrich data
  - Return filter options
- **Sử dụng**: Database team cho GetFilter SP

### 10. **DangerMonitor_SP_GetTicket_Detailed** (Component Diagram)
- **Mục đích**: Chi tiết flow của CTS_MatchMonitor_Details_GetTicket
- **Nội dung**:
  - Database: bodb02 / bodb_Archive
  - Tables: bettrans, bettrans14, bettrans_bk, Match, match14, match_bk, Customer, custInfo, Exchange, league
  - Temp tables: #tmpTickets, #tmpTransIds, #tmpSportBetType, #tmpUsername, #tmpCustomer, #tmpTransIdReason
  - QueryType logic (1: Service, 2: Last 3 Days, 3: Last 7 Days)
  - ViewMode logic (0: All-MatchMonitor, 1: Suspicious Only)
  - Data source logic (Origin, 14 days, Archive)
  - UPDATE operations để enrich data (IsLicensee, Danger1-5, CustomerClass)
  - MalayOdds conversion (Decimal, Hong Kong, Indonesia, Malaysian, US)
  - Complex filter operations (Score, IsLicensee, CustomerClass, Danger, Currency, Reason, AGroup, MGroup, HDPBetTeam, Status, CustAmountRM, IsCashout)
  - Return ticket details
- **Sử dụng**: Database team cho GetTicket SP

### 11. **DangerMonitor_SP_Associations_Get_Detailed** (Component Diagram)
- **Mục đích**: Chi tiết flow của CTS_MatchTicketInfo_Associations_Get
- **Nội dung**:
  - Database: bodb02/WASAVerse
  - Tables: bettrans, bettrans14, Match, match14, league, team
  - Temp tables: #tmpAssoc, #tmpBetType, #tmpCustomer, #tmpLeagueGroup, #tmpMatchInfo, #tmpMatchInfo14, #tmpCustTrans, #tmpMatchSum_Group
  - Parse Associations JSON (RootCustID, AssCustIDList)
  - Data source logic (Origin, 14 days, or both Union)
  - Match info selection (Match vs Match14)
  - Bet transactions aggregation by RootCustID
  - Separate Home/Away amounts and tickets
  - Filter by @UserAmount (per customer) and @TotalAmount (per group)
  - HAVING conditions: Must have Root Customer AND Association Customers
  - Return results grouped by RootCustID with ListCustID
- **Sử dụng**: Database team cho Associations Get SP

### 12. **DangerMonitor_SP_Association_GetByUserNameList_Detailed** (Component Diagram)
- **Mục đích**: Chi tiết flow của CTS_DC_Association_GetByUserNameList
- **Nội dung**:
  - Database: CTS_DataCenter (MySQL)
  - Tables: CTSCustomer, AssociationByDevice, AssociationByAI, AssociationGroupByAI, AssociationByIP, AssociationTypeSetting
  - Temp tables: Temp_Username, Temp_Cust, Temp_Association, Temp_CustDevice, Temp_AssociationByAI_AssType, Temp_CustGroupByAI, Temp_AssociationByIP_AssType
  - Parse username list (comma-separated)
  - Get CTSCustID and CustID from usernames
  - Association detection by 3 types:
    - Device (Type 1): Same device usage
    - Betting Pattern/AI (Type 2): AssociationByAI (bidirectional) and AssociationGroupByAI
    - IP (Type 4): AssociationByIP (bidirectional)
  - Filter by active AssociationTypeSetting
  - Filter: Only CustSubID = 0 (main accounts)
  - Return results grouped by RootCustID with AssCustIDList (comma-separated)
- **Sử dụng**: Database team  cho Association Detection SP


### Online Viewer
http://www.plantuml.com/plantuml/uml/



