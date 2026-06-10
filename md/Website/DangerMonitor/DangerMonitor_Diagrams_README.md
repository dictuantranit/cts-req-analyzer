# Danger Monitor Diagrams - Hướng dẫn sử dụng

## 📁 Files

1. **DangerMonitor_Diagram_Architecture_Proposal.md** - Proposal về kiến trúc diagram
2. **DangerMonitor_Diagrams_PlantUML.puml** - File PlantUML tổng hợp (có thể quá lớn cho online server)
3. **DangerMonitor_Diagrams_01_MainFlow.puml** - Main Business Flow Diagram
4. **DangerMonitor_Diagrams_02_Sequence_NoAssociation.puml** - Sequence: No Association Mode
5. **DangerMonitor_Diagrams_03_Sequence_WithAssociation.puml** - Sequence: With Association Mode
6. **DangerMonitor_Diagrams_04_Sequence_DetailPage.puml** - Sequence: Detail Page
7. **DangerMonitor_Diagrams_05_Component.puml** - Component Architecture Diagram
8. **DangerMonitor_Diagrams_06_DatabaseFlow.puml** - Database Flow Diagram (High-level)
9. **DangerMonitor_Diagrams_07_DatabaseFlow_Detailed.puml** - Detailed Database Flow with Tables
10. **DangerMonitor_Diagrams_08_SP_Operations_Detail.puml** - Stored Procedure Operations Detail
11. **DangerMonitor_Diagrams_09_SP_GetFilter_Detailed.puml** - CTS_MatchMonitor_Details_GetFilter Detailed Flow
12. **DangerMonitor_Diagrams_10_SP_GetTicket_Detailed.puml** - CTS_MatchMonitor_Details_GetTicket Detailed Flow
13. **DangerMonitor_Diagrams_11_SP_Associations_Get_Detailed.puml** - CTS_MatchTicketInfo_Associations_Get Detailed Flow
14. **DangerMonitor_Diagrams_12_SP_Association_GetByUserNameList_Detailed.puml** - CTS_DC_Association_GetByUserNameList Detailed Flow

## ⚠️ Lưu ý về File Size

File `DangerMonitor_Diagrams_PlantUML.puml` có thể quá lớn để render qua online server (lỗi "Request header is too large"). 

**Giải pháp**: Sử dụng các file riêng lẻ:
- `DangerMonitor_Diagrams_01_MainFlow.puml`
- `DangerMonitor_Diagrams_02_Sequence_NoAssociation.puml`
- `DangerMonitor_Diagrams_03_Sequence_WithAssociation.puml`
- `DangerMonitor_Diagrams_04_Sequence_DetailPage.puml`
- `DangerMonitor_Diagrams_05_Component.puml`
- `DangerMonitor_Diagrams_06_DatabaseFlow.puml`

## 🎨 Các Diagram đã tạo

### 1. **DangerMonitor_MainFlow** (Activity Diagram)
- **Mục đích**: Business flow tổng thể của Danger Monitor
- **Nội dung**: Từ khi user mở page đến các actions chính
- **Sử dụng**: Overview cho business stakeholders

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
- **Sử dụng**: Database documentation overview

### 7. **DangerMonitor_DatabaseFlow_Detailed** (Component + Entity Diagram)
- **Mục đích**: Chi tiết database tables và operations
- **Nội dung**: 
  - Database name (bodb02/WASAVerse)
  - Tables được sử dụng (bettrans, Match, Customer, Exchange)
  - Operations (SELECT, INSERT, JOIN)
  - Temp tables
- **Sử dụng**: Database team documentation

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
- **Sử dụng**: Database team documentation cho GetFilter SP

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
- **Sử dụng**: Database team documentation cho GetTicket SP

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
- **Sử dụng**: Database team documentation cho Associations Get SP

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
- **Sử dụng**: Database team documentation cho Association Detection SP

## 🛠️ Cách sử dụng

### Option 1: Online Viewer
1. Truy cập: http://www.plantuml.com/plantuml/uml/
2. Copy nội dung từ file `.puml`
3. Paste vào editor
4. Xem diagram

### Option 2: VS Code Extension
1. Cài đặt extension: "PlantUML" (by jebbs)
2. Mở file `.puml`
3. Nhấn `Alt + D` để preview
4. Export sang PNG/SVG

### Option 3: Command Line
```bash
# Cài đặt PlantUML
# Windows: choco install plantuml
# Mac: brew install plantuml
# Linux: apt-get install plantuml

# Generate PNG
plantuml DangerMonitor_Diagrams_PlantUML.puml

# Generate SVG
plantuml -tsvg DangerMonitor_Diagrams_PlantUML.puml

# Generate PDF
plantuml -tpdf DangerMonitor_Diagrams_PlantUML.puml
```

### Option 4: IntelliJ IDEA / Rider
1. Cài đặt plugin "PlantUML integration"
2. Mở file `.puml`
3. Preview tự động
4. Export từ menu

## 📊 Cách render từng diagram riêng

**Cách 1: Sử dụng file riêng lẻ (RECOMMENDED)**
1. Mở file riêng lẻ (ví dụ: `DangerMonitor_Diagrams_01_MainFlow.puml`)
2. Copy toàn bộ nội dung
3. Paste vào PlantUML editor
4. Render

**Cách 2: Từ file tổng hợp**
1. Mở file `DangerMonitor_Diagrams_PlantUML.puml`
2. Copy một section từ `@startuml DiagramName` đến `@enduml`
3. Paste vào PlantUML editor
4. Render

**Lưu ý**: File tổng hợp có thể quá lớn cho online server, nên dùng file riêng lẻ.

## 🎯 Recommendations

### Cho Business Stakeholders
- **DangerMonitor_MainFlow** - Dễ hiểu business flow

### Cho Developers
- **Tất cả Sequence Diagrams** - Chi tiết technical flow
- **Component Diagram** - Architecture overview

### Cho Database Team
- **DangerMonitor_DatabaseFlow** - Database flow
- **Sequence Diagrams** - Stored procedure calls

## ✏️ Customization

### Thêm diagram mới
1. Mở file `.puml`
2. Thêm section mới:
```plantuml
@startuml YourDiagramName
!theme plain
title Your Title

' Your diagram content here

@enduml
```

### Thay đổi theme
Thay `!theme plain` bằng:
- `!theme reddress-darkblue`
- `!theme aws-orange`
- `!theme carbon-gray`
- Hoặc theme khác

### Thêm notes
```plantuml
note right of Component
  Your note here
end note
```

## 📝 Notes

- Tất cả diagram đều có thể edit và customize
- PlantUML syntax rất dễ học
- Có thể version control trong git
- Export sang nhiều formats (PNG, SVG, PDF, etc.)

## 🔗 Useful Links

- PlantUML Documentation: https://plantuml.com/
- PlantUML Syntax: https://plantuml.com/guide
- Online Editor: http://www.plantuml.com/plantuml/uml/
- VS Code Extension: https://marketplace.visualstudio.com/items?itemName=jebbs.plantuml

## 💡 Tips

1. **Keep it simple**: Không cần quá chi tiết, focus vào flow chính
2. **Use notes**: Thêm notes để giải thích complex logic
3. **Consistent naming**: Dùng naming convention nhất quán
4. **Update regularly**: Update diagram khi code thay đổi
5. **Version control**: Commit diagram vào git để track changes

