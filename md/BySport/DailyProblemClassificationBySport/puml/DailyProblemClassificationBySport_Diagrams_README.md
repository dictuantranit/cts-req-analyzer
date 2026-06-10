# Daily Problem Classification By Sport Diagrams

## Overview
This directory contains PlantUML diagrams documenting the Daily Problem Classification By Sport feature, which processes customers from a queue and updates their Problem Account (PA) classification based on losing performance by sport.

## Diagrams

1. **DailyProblemClassificationBySport_Diagrams_01_MainFlow.puml** - Main Business Flow Diagram
2. **DailyProblemClassificationBySport_Diagrams_02_Sequence.puml** - Sequence Diagram (Detailed)
3. **DailyProblemClassificationBySport_Diagrams_03_DatabaseFlow.puml** - Database Flow Diagram
4. **DailyProblemClassificationBySport_Diagrams_04_SP_GetFromQueue_Detailed.puml** - SP GetFromQueue Detailed Flow
5. **DailyProblemClassificationBySport_Diagrams_05_SP_Insert_Detailed.puml** - SP Insert Detailed Flow
6. **DailyProblemClassificationBySport_Diagrams_06_SP_GetLosingPerformance_Detailed.puml** - SP Get Losing Performance Detailed Flow

### 1. **DailyProblemClassificationBySport_MainFlow** (Activity Diagram)
- **Purpose**: High-level business flow of Daily Problem Classification By Sport
- **Content**: From job trigger to completion, including queue processing loop
- **Use**: Overview for stakeholders and business analysts

### 2. **DailyProblemClassificationBySport_Sequence** (Sequence Diagram)
- **Purpose**: Detailed sequence of interactions between components
- **Content**: 
  - Controller → JobService → Service → DataAccess → Database
  - Queue processing loop
  - Problem Account insertion flow
  - Push to Main DB flow
  - Queue completion flow
- **Stored Procedures**:
  - `CTS_DC_CustClassification_BySport_DailyScanPA_GetFromQueue`
  - `CTS_ProblemAccountsClassification_BySport_Daily`
  - `CTS_DC_CustClassification_BySport_DailyScanPA_Insert`
  - `CTS_DC_CustClassification_BySport_DailyScanPA_Complete`
- **Use**: Technical documentation for developers

### 3. **DailyProblemClassificationBySport_DatabaseFlow** (Activity Diagram)
- **Purpose**: Database operations and stored procedures flow
- **Content**: 
  - All stored procedure calls
  - Parameters and return values
  - Database update operations
- **Use**: Database documentation and troubleshooting

### 4. **DailyProblemClassificationBySport_SP_GetFromQueue_Detailed** (Component Diagram)
- **Purpose**: Detailed flow of `CTS_DC_CustClassification_BySport_DailyScanPA_GetFromQueue` stored procedure
- **Content**:
  - Database: CTS_DataCenter (MySQL)
  - Tables: SystemParameter, CTSCustomerClassification_BySport_DailyPAQueue, CTSCustomerClassification_BySport, CustomerCategorySettings
  - Temp tables: Temp_Customers
  - Logic:
    - Get LastScannedTime from SystemParameter (ID=200)
    - Add 24 hours to ensure customers have been in queue for at least 24 hours
    - Get customers from DailyPAQueue
    - Filter by FlowPADailyScan = 1
    - Order by ID ASC, Limit by batchSize
    - Return customer list for processing
- **Use**: Database team for SP optimization and maintenance

### 5. **DailyProblemClassificationBySport_SP_Insert_Detailed** (Component Diagram)
- **Purpose**: Detailed flow of `CTS_DC_CustClassification_BySport_DailyScanPA_Insert` stored procedure
- **Content**:
  - Database: CTS_DataCenter (MySQL)
  - Tables: CTSCustomerClassification_BySport, CustomerCategory, CustomerCategorySettings, SpecialCustomerClass, CTSCustomerClassification_BySport_History, CTSCustomerClassification_BySport_Log
  - Temp tables: Temp_PA
  - Logic:
    - Parse JSON with WinlossStatus, TurnoverRM, WinlossRM, BetCount, ActiveDays
    - Get current classification from CTSCustomerClassification_BySport
    - Determine IsDataChanged based on WinlossStatus and current category:
      * LOSING (0) + PA: Update (IsDataChanged = 1)
      * LOSING (0) + Probation: No Change (IsDataChanged = 0)
      * WINNING (2) + PA: No Change (IsDataChanged = 0)
      * WINNING (2) + Probation: Update (IsDataChanged = 1)
      * KEEPSTATE (1): No Change (IsDataChanged = 0)
    - Exclude VVIP customers
    - Update classification if IsDataChanged = 1
    - Determine TargetCC (considering SpecialCustomerClass, IsLicenseeVIP, IsLicenseeBA)
    - Insert into History and Log tables
    - Return only changed records
- **Use**: Database team for SP optimization and maintenance

### 6. **DailyProblemClassificationBySport_SP_GetLosingPerformance_Detailed** (Component Diagram)
- **Purpose**: Detailed flow of `CTS_ProblemAccountsClassification_BySport_Daily` stored procedure
- **Content**:
  - Database: bodb_VR2Model (SQL Server)
  - External: bodb_dwrs (Data Warehouse)
  - Temp tables: #tmpCustInfo, #tmpRawData, #tmpCustomerAccummulatedInfo
  - Logic:
    - Parse JSON customer list
    - Get accumulated data from bodb_dwrs (Acc_Rpt_CTS_GetCustAccumulatedInfo)
    - Filter by SportGroup = 145 (Saba VR Soccer only)
    - Sum data by CustID
    - Classify WinlossStatus:
      * LOSING (0): WinlossRM < -10000
      * KEEPSTATE (1): -10000 <= WinlossRM < -5000
      * WINNING (2): WinlossRM >= -5000
    - Return losing performance data
- **Use**: Database team for SP optimization and maintenance

## Key Components

### Services
- **DailyProblemClassificationBySportJobService**: Main job service orchestrator
- **DailyProblemClassificationBySportService**: Business logic service
- **ProblemWLClassificationBySportService**: Problem account Win/Loss classification service
- **ProblemAccountBySportService**: Problem account operations service
- **CustClassToMainDBService**: Push classification to main database

### Data Access
- **ProblemWLClassificationBySportDataAccess**: Database access for PA operations
- **ProblemAccountBySportDataAccess**: Database access for PA losing performance

### Stored Procedures
1. **CTS_DC_CustClassification_BySport_DailyScanPA_GetFromQueue**
   - Gets customers from DailyPAQueue for processing
   - Returns: CustID, SportGroup

2. **CTS_ProblemAccountsClassification_BySport_Daily**
   - Gets losing performance data from VR2 database
   - Returns: WinlossStatus, TurnoverRM, WinlossRM, BetCount, ActiveDays

3. **CTS_DC_CustClassification_BySport_DailyScanPA_Insert**
   - Updates customer classification based on losing performance
   - Logic: Determines if data changed and updates accordingly
   - Returns: CustID, SportGroup (only changed records)

4. **CTS_DC_CustClassification_BySport_DailyScanPA_Complete**
   - Marks processed customers as completed in queue
   - Updates SystemParameter if queue is empty

### Main Database Integration
- **UpdateCustomerClassificationBySport**: Updates customer classification in main database
- Retry mechanism: Up to 3 retries on failure

## Flow Summary

1. **Trigger**: HTTP POST to `/api/classificationBySportJobs/ScanDailyProblemClassiciationBySport`
2. **Loop**: Process customers from queue in batches
3. **Get Queue**: Get customers from DailyPAQueue (waiting at least 24 hours)
4. **Get Performance**: Get losing performance data from VR2 database
5. **Classify**: Determine if classification needs update based on WinlossStatus
6. **Insert PA**: Update classification if data changed
7. **Push to Main DB**: Update main database with new classifications
8. **Complete**: Remove processed customers from queue
9. **Continue**: Repeat until queue is empty

## Key Logic

### WinlossStatus Classification
- **LOSING (0)**: WinlossRM < -10000
- **KEEPSTATE (1)**: -10000 <= WinlossRM < -5000
- **WINNING (2)**: WinlossRM >= -5000

### IsDataChanged Logic
- **LOSING + PA**: Update classification (IsDataChanged = 1)
- **LOSING + Probation**: No change (IsDataChanged = 0)
- **WINNING + PA**: No change (IsDataChanged = 0)
- **WINNING + Probation**: Update classification (IsDataChanged = 1)
- **KEEPSTATE**: No change (IsDataChanged = 0)

### Queue Processing
- Customers must be in queue for at least 24 hours before processing
- Processed in batches (batchInternalSize for queue, batchExternalSize for external push)
- Queue is cleared after successful processing

## Online Viewer
http://www.plantuml.com/plantuml/uml/

