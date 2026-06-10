# Realtime Classification By Sport Diagrams

## Overview
This directory contains PlantUML diagrams documenting the Realtime Classification By Sport feature, which processes customers with new place bets in real-time and routes them to either Normal classification pool or PA Daily Scan queue.

## Diagrams

1. **RealtimeClassificationBySport_Diagrams_01_MainFlow.puml** - Main Business Flow Diagram
2. **RealtimeClassificationBySport_Diagrams_02_Sequence.puml** - Sequence Diagram (Detailed)
3. **RealtimeClassificationBySport_Diagrams_03_DatabaseFlow.puml** - Database Flow Diagram
4. **RealtimeClassificationBySport_Diagrams_04_SP_GetChanges_Detailed.puml** - SP GetChanges Detailed Flow
5. **RealtimeClassificationBySport_Diagrams_05_SP_GetCategory_Detailed.puml** - SP GetCategory Detailed Flow
6. **RealtimeClassificationBySport_Diagrams_06_SP_Preprocess_Detailed.puml** - SP Preprocess Detailed Flow

### 1. **RealtimeClassificationBySport_MainFlow** (Activity Diagram)
- **Purpose**: High-level business flow of Realtime Classification By Sport
- **Content**: From job trigger to completion, including parallel processing
- **Use**: Overview for stakeholders and business analysts

### 2. **RealtimeClassificationBySport_Sequence** (Sequence Diagram)
- **Purpose**: Detailed sequence of interactions between components
- **Content**: 
  - Controller → JobService → Service → DataAccess → Database
  - Get new place bet customers
  - Categorize customers (Normal vs PA)
  - Parallel processing (Preprocess and Insert Queue)
  - Complete processing
- **Stored Procedures**:
  - `CTS_BySportNormalClassification_RealTime_GetChanges`
  - `CTS_DC_CustClassification_BySport_Realtime_GetCategory`
  - `CTS_BySportNormalClassification_RealTime_Preprocess`
  - `CTS_DC_CustClassification_BySport_DailyScanPA_InsertToQueue`
  - `CTS_BySportNormalClassification_RealTime_Complete`
- **Use**: Technical documentation for developers

### 3. **RealtimeClassificationBySport_DatabaseFlow** (Activity Diagram)
- **Purpose**: Database operations and stored procedures flow
- **Content**: 
  - All stored procedure calls
  - Parameters and return values
  - Database update operations
- **Use**: Database documentation and troubleshooting

### 4. **RealtimeClassificationBySport_SP_GetChanges_Detailed** (Component Diagram)
- **Purpose**: Detailed flow of `CTS_BySportNormalClassification_RealTime_GetChanges` stored procedure
- **Content**:
  - Database: bodb_VR2Model (SQL Server)
  - Tables: CustomerClassification_BySport_RealtimeChanges
  - Temp tables: #tmpResult
  - Logic:
    - Get TOP 20000 records from RealtimeChanges
    - Order by ID ASC
    - Return distinct CustID and SportGroup
    - Output ScannedMaxId (MAX ID) for completion tracking
- **Use**: Database team for SP optimization and maintenance

### 5. **RealtimeClassificationBySport_SP_GetCategory_Detailed** (Component Diagram)
- **Purpose**: Detailed flow of `CTS_DC_CustClassification_BySport_Realtime_GetCategory` stored procedure
- **Content**:
  - Database: CTS_DataCenter (MySQL)
  - Tables: CTSCustomerClassification_BySport, CustomerCategory
  - Temp tables: Temp_Customers, Temp_CustomerCategory
  - Logic:
    - Parse JSON customer list
    - Get current classification from CTSCustomerClassification_BySport
    - Join with CustomerCategory to get ParentID
    - Categorize customers:
      * NULL or Normal (ParentID = CONST_PARENTID_NORMAL): CustomerNormals
      * PA or PotentialPA (ParentID IN PA, PotentialPA): CustomerPADailyScans
    - Return two result sets:
      * ResultSet 1: CustomerNormals (for Normal Pool)
      * ResultSet 2: CustomerPADailyScans (for Daily PA Queue)
- **Use**: Database team for SP optimization and maintenance

### 6. **RealtimeClassificationBySport_SP_Preprocess_Detailed** (Component Diagram)
- **Purpose**: Detailed flow of `CTS_BySportNormalClassification_RealTime_Preprocess` stored procedure
- **Content**:
  - Database: bodb_VR2Model (SQL Server)
  - Tables: CustomerClassification_BySport_Priority
  - Temp tables: #tmpCustomers
  - Logic:
    - Parse XML customer list
    - Get Priority from CustomerClassification_BySport_Priority (GroupId=1, FunctionId=1)
    - Call CTS_BySportNormalClassification_NormalPool_Insert
    - Insert customers into Normal Pool for later classification
- **Use**: Database team for SP optimization and maintenance

## Key Components

### Services
- **RealtimeClassificationBySportJobService**: Main job service orchestrator
- **RealtimeClassificationBySportServices**: Business logic service with fluent interface

### Data Access
- **RealtimeClassificationBySportDataAccess**: Database access for realtime operations

### Stored Procedures
1. **CTS_BySportNormalClassification_RealTime_GetChanges** (VR2 DB)
   - Gets customers with new place bets from RealtimeChanges
   - Returns: CustID, SportGroup, ScannedMaxId (OUTPUT)

2. **CTS_DC_CustClassification_BySport_Realtime_GetCategory** (CTS_DataCenter)
   - Categorizes customers into Normal or PA Daily Scan
   - Returns: Two result sets (CustomerNormals, CustomerPADailyScans)

3. **CTS_BySportNormalClassification_RealTime_Preprocess** (VR2 DB)
   - Inserts customers into Normal Pool for classification
   - Uses Priority from Priority table

4. **CTS_DC_CustClassification_BySport_DailyScanPA_InsertToQueue** (CTS_DataCenter)
   - Inserts customers into DailyPAQueue for daily PA scan
   - Sets CreatedTime = NOW()

5. **CTS_BySportNormalClassification_RealTime_Complete** (VR2 DB)
   - Deletes processed records from RealtimeChanges
   - WHERE ID <= @ScannedMaxId

## Flow Summary

1. **Trigger**: HTTP POST to `/api/classificationBySportJobs/ScanRealtimeClassificationBySport`
2. **Get Changes**: Get customers with new place bets from RealtimeChanges (TOP 20000)
3. **Categorize**: Classify customers into Normal or PA Daily Scan based on current classification
4. **Parallel Processing**:
   - **Normal**: Insert into Normal Pool for classification
   - **PA**: Insert into DailyPAQueue for daily PA scan
5. **Complete**: Delete processed records from RealtimeChanges

## Key Logic

### Customer Categorization
- **CustomerNormals**: Customers with NULL classification or Normal category (ParentID = CONST_PARENTID_NORMAL)
- **CustomerPADailyScans**: Customers with PA or PotentialPA category (ParentID IN PA, PotentialPA) and RelevantCategoryID IS NOT NULL

### Parallel Processing
- Normal customers and PA customers are processed in parallel using `Parallel.Invoke()`
- This improves performance by processing both paths simultaneously

### Batch Processing
- Customers are processed in chunks (batchInternalSize, default: 5000)
- Each chunk is processed separately to avoid memory issues

### Completion Tracking
- ScannedMaxId tracks the maximum ID processed
- Records with ID <= ScannedMaxId are deleted from RealtimeChanges
- This ensures no duplicate processing

## Online Viewer
http://www.plantuml.com/plantuml/uml/

