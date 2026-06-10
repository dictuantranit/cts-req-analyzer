# Match Monitor Classification By Sport Diagrams

## Overview
This directory contains PlantUML diagrams documenting the Match Monitor Classification By Sport feature, which classifies customers detected in Match Monitor as Problem Accounts (PA) by sport.

## Diagrams

1. **MatchMonitorClassificationBySport_Diagrams_01_MainFlow.puml** - Main Business Flow Diagram
2. **MatchMonitorClassificationBySport_Diagrams_02_Sequence.puml** - Sequence Diagram (Detailed)
3. **MatchMonitorClassificationBySport_Diagrams_03_DatabaseFlow.puml** - Database Flow Diagram
4. **MatchMonitorClassificationBySport_Diagrams_04_SP_MatchMonitor_Classify_Detailed.puml** - SP Classify Detailed Flow
5. **MatchMonitorClassificationBySport_Diagrams_05_SP_Insert_Detailed.puml** - SP Insert Detailed Flow

### 1. **MatchMonitorClassificationBySport_MainFlow** (Activity Diagram)
- **Purpose**: High-level business flow of Match Monitor Classification By Sport
- **Content**: From job trigger to completion, including all major steps
- **Use**: Overview for stakeholders and business analysts

### 2. **MatchMonitorClassificationBySport_Sequence** (Sequence Diagram)
- **Purpose**: Detailed sequence of interactions between components
- **Content**: 
  - Controller → JobService → Service → DataAccess → Database
  - Problem Account insertion flow
  - Push to Main DB flow
  - Completion flow
- **Stored Procedures**:
  - `CTS_DC_CustClassification_BySport_MatchMonitor_Classify`
  - `CTS_ProblemAccountsClassification_BySport_Daily`
  - `CTS_DC_CustClassification_BySport_Insert`
  - `CTS_DC_CustClassification_BySport_MatchMonitor_Completed`
- **Use**: Technical documentation for developers

### 3. **MatchMonitorClassificationBySport_DatabaseFlow** (Activity Diagram)
- **Purpose**: Database operations and stored procedures flow
- **Content**: 
  - All stored procedure calls
  - Parameters and return values
  - Database update operations
- **Use**: Database documentation and troubleshooting

### 4. **MatchMonitorClassificationBySport_SP_Classify_Detailed** (Component Diagram)
- **Purpose**: Detailed flow of `CTS_DC_CustClassification_BySport_MatchMonitor_Classify` stored procedure
- **Content**:
  - Database: CTS_DataCenter (MySQL)
  - Tables: SystemParameter, MatchMonitor, MatchMonitorDetails, CTSCustomer, CustomerCategorySettings, CTSCustomerClassification_BySport
  - Temp tables: Temp_MatchMonitorDetailsCust, Temp_Cust, Temp_ExcludePACategoryID
  - Logic:
    - Get/Set MatchID from SystemParameter
    - Determine SportGroup (145 for Saba Soccer)
    - Get customers from MatchMonitorDetails
    - Filter out existing PA classifications
    - Return customer list for classification
- **Use**: Database team for SP optimization and maintenance

### 5. **MatchMonitorClassificationBySport_SP_Insert_Detailed** (Component Diagram)
- **Purpose**: Detailed flow of `CTS_DC_CustClassification_BySport_Insert` stored procedure
- **Content**:
  - Database: CTS_DataCenter (MySQL)
  - Tables: CTSCustomerClassification_BySport, CTSCustomerClassification_BySport_History, CustomerCategorySettings
  - Temp tables: Temp_NewClassification
  - Steps:
    1. Insert_GetInfo - Parse JSON and validate
    2. Insert_Process - Process classification logic (skip PreProcess for PA)
    3. Insert_Complete - Insert into main and history tables
  - Action Types:
    - 0: Insert (new classification)
    - 1: Update (existing classification)
    - 3: ExistedPA (skip if already PA)
- **Use**: Database team for SP optimization and maintenance

## Key Components

### Services
- **MatchMonitorClassificationBySportJobService**: Main job service orchestrator
- **MatchMonitorClassificationBySportService**: Business logic service
- **ProblemAccountBySportService**: Problem account insertion logic
- **CustClassToMainDBService**: Push classification to main database

### Data Access
- **MatchMonitorClassificationBySportDataAccess**: Database access for classification
- **ProblemAccountBySportDataAccess**: Database access for PA operations
- **BaseCustomerClassificationBySportDataAccess**: Base classification operations

### Stored Procedures
1. **CTS_DC_CustClassification_BySport_MatchMonitor_Classify**
   - Gets customers from MatchMonitor for classification
   - Returns: CustInfos, MMDetailIDList, MatchID

2. **CTS_ProblemAccountsClassification_BySport_Daily**
   - Gets losing performance data for customers
   - Returns: BetCount, ActiveDays, TurnoverRM, WinlossRM, etc.

3. **CTS_DC_CustClassification_BySport_Insert**
   - Inserts customer classification by sport
   - InputFlowID = 335 (BySportInsertPA)
   - Steps: GetInfo → Process → Complete

4. **CTS_DC_CustClassification_BySport_MatchMonitor_Completed**
   - Marks MatchMonitorDetails as completed
   - Updates SystemParameter

### Main Database Integration
- **UpdateCustomerClassificationBySport**: Updates customer classification in main database
- Retry mechanism: Up to 3 retries on failure

## Flow Summary

1. **Trigger**: HTTP POST to `/api/classificationBySportJobs/ClassifyMatchMonitorBySport`
2. **Classify**: Get customers from MatchMonitor that need classification
3. **Get Performance**: Get losing performance data for customers
4. **Insert PA**: Insert Problem Account classification by sport
5. **Push to Main DB**: Update main database with new classifications
6. **Complete**: Mark MatchMonitorDetails as completed

## Online Viewer
http://www.plantuml.com/plantuml/uml/

