# Realtime Classification - Diagrams

## Overview
This document contains diagrams for the **Realtime Classification** flow, which processes customers with new place bets in real-time and routes them to either Normal classification pool or PA (Problem Account) Daily Scan queue.

## Flow Description
The Realtime Classification job:
1. Gets customers with new place bets from RealtimeChanges table
2. Categorizes customers based on current classification (Normal vs PA/PotentialPA)
3. Processes in parallel:
   - **Normal customers**: Insert into Normal Pool for classification
   - **PA customers**: Insert into PA Daily Scan Queue
4. Completes processing by removing processed records from RealtimeChanges

## Diagrams

### 01_MainFlow.puml
**Main Business Flow Diagram**
- Shows the overall flow from job trigger to completion
- Illustrates batch processing and parallel execution
- Details the main steps: Start, GetNewPlaceBetCustomers, GetCustomerCategory, Parallel Processing, Complete

### 02_Sequence.puml
**Sequence Diagram**
- Shows the interaction between components:
  - Job Scheduler → Controller → JobService → Service → DataAccess → Database
- Details the sequence of method calls and data flow
- Shows parallel processing with Parallel.Invoke()

### 03_DatabaseFlow.puml
**Database Flow Diagram**
- Shows the database operations and stored procedures involved
- Illustrates the flow between SQL Server (VR2) and MySQL (CTS_DataCenter)
- Details the data transformations and batch processing

### 04_SP_GetChanges_Detailed.puml
**Stored Procedure: GetChanges Detailed Flow**
- Details the logic of `CTS_GeneralNormalClassification_RealTime_GetChanges`
- Shows how new place bet customers are retrieved
- Illustrates the ScannedMaxId tracking mechanism

### 05_SP_GetCategory_Detailed.puml
**Stored Procedure: GetCategory Detailed Flow**
- Details the logic of `CTS_DC_CustClassification_Realtime_GetCategory`
- Shows how customers are categorized into Normal vs PA
- Illustrates the dual result sets (CustomerCategory vs CustomerPADailyScan)

### 06_SP_Preprocess_Detailed.puml
**Stored Procedure: Preprocess Detailed Flow**
- Details the logic of `CTS_GeneralNormalClassification_Realtime_Preprocess`
- Shows how customers are inserted into Normal Pool
- Illustrates priority assignment

## Key Components

### JobService
- `RealtimeClassificationJobService`: Orchestrates the job execution
- Single execution flow with parallel processing

### Service Layer
- `RealtimeClassificationService`: Business logic layer
- Methods:
  - `Start()`: Initialize models
  - `GetNewPlaceBetCustomers()`: Get customers with new bets
  - `GetCustomerCategory()`: Categorize customers (batched)
  - `PreprocessCustomerClassRealtime()`: Insert into Normal Pool (batched)
  - `InsertPADailyScanQueue()`: Insert into PA Queue (batched)
  - `CompleteCustomerRealtime()`: Mark as completed

### Data Access Layer
- `RealtimeClassificationDataAccess`: Database access layer
- Calls stored procedures:
  - `CTS_GeneralNormalClassification_RealTime_GetChanges`
  - `CTS_DC_CustClassification_Realtime_GetCategory`
  - `CTS_GeneralNormalClassification_Realtime_Preprocess`
  - `CTS_DC_CustClassification_DailyScanPA_InsertToQueue`
  - `CTS_GeneralNormalClassification_RealTime_Complete`

## Stored Procedures

### CTS_GeneralNormalClassification_RealTime_GetChanges
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Get customers with new place bets
**Parameters**:
- `@ScannedMaxId` (OUTPUT): Maximum ID processed
**Returns**: 
- CustId (long)
- SportId (int)
**Logic**:
- Get TOP 20000 records from CustomerClassification_RealtimeChanges
- Order by ID ASC
- Return distinct customers with their sport
- Output ScannedMaxId for completion tracking

### CTS_DC_CustClassification_Realtime_GetCategory
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Categorize customers into Normal or PA
**Parameters**:
- `@ip_CustIDs` (string): Comma-separated customer IDs
**Returns**: 
- ResultSet 1: CustomerCategory (CustId list for Normal customers)
- ResultSet 2: CustomerPADailyScan (CustId list for PA customers)
**Logic**:
- Parse customer ID list
- Get current classification from CTSCustomerClassification
- Join with CustomerCategory to get ParentID
- Categorize:
  - **Normal**: NULL classification OR ParentID = CONST_PARENTID_NORMAL
  - **PA**: ParentID IN (PA, PotentialPA) AND RelevantCategoryID IS NOT NULL

### CTS_GeneralNormalClassification_Realtime_Preprocess
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Insert customers into Normal Pool for classification
**Parameters**:
- `@ListCustId` (string): Comma-separated customer IDs
**Logic**:
- Parse customer ID list
- Get Priority from CustomerClassification_Priority table
- Call NormalPool_Insert stored procedure
- Insert into Normal Pool with Priority

### CTS_DC_CustClassification_DailyScanPA_InsertToQueue
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Insert PA customers into Daily Scan Queue
**Parameters**:
- `@ip_CustIDs` (string): Comma-separated customer IDs
**Logic**:
- Parse customer ID list
- INSERT INTO CTSCustomerClassification_DailyPAQueue
- Set CreatedTime = NOW()
- Queue for daily PA scanning

### CTS_GeneralNormalClassification_RealTime_Complete
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Mark processed records as completed
**Parameters**:
- `@ScannedMaxId` (long): Maximum ID processed
**Logic**:
- DELETE FROM CustomerClassification_RealtimeChanges
- WHERE ID <= @ScannedMaxId
- Prevents duplicate processing

## Data Model

### GetNewPlaceBetCustomerEntity
```csharp
public class GetNewPlaceBetCustomerEntity
{
    public long CustId { get; set; }
    public int SportId { get; set; }
}
```

### GetNewPlaceBetCustomerModel
```csharp
public class GetNewPlaceBetCustomerModel
{
    public IEnumerable<GetNewPlaceBetCustomerEntity> CustomerNewPlaceBets { get; set; }
    public long ScannedMaxId { get; set; }
}
```

### GetCustomerCategoryRealtimeModel
```csharp
public class GetCustomerCategoryRealtimeModel
{
    public List<long> CustomerCategory { get; set; }        // Normal customers
    public List<long> CustomerPADailyScan { get; set; }     // PA customers
}
```

## API Endpoint
- **POST** `/api/classificationJobs/scanningRealtimeClassification`
- **Parameters**: 
  - `batchExternalSize` (int): External batch size
  - `batchInternalSize` (int): Internal batch size (default: 5000)

## Key Features

### Batch Processing
- Customer categorization: Chunked by `batchInternalSize`
- Normal preprocessing: Chunked by `batchInternalSize`
- PA queue insertion: Chunked by `batchInternalSize`

### Parallel Processing
- Normal Pool insertion and PA Queue insertion run in parallel
- Uses `Parallel.Invoke()` for concurrent execution
- Improves performance by processing both paths simultaneously

### Dual Customer Routing
- **Normal Path**: Customers needing classification
  - NULL classification
  - Currently in Normal category
  - → Insert into Normal Pool
  - → Will be classified by NormalAccountClassification job

- **PA Path**: Customers with problem account indicators
  - Currently in PA or PotentialPA category
  - Have RelevantCategoryID
  - → Insert into PA Daily Scan Queue
  - → Will be processed by DailyProblemClassification job

### ScannedMaxId Tracking
- Tracks the maximum ID processed
- Used to delete processed records
- Ensures no duplicate processing
- Enables incremental processing

### Database Architecture
- **VR2 Database** (SQL Server): Main classification database
  - Stores RealtimeChanges
  - Manages Normal Pool
  - Handles completion
- **DataCenter Database** (MySQL): Metadata and queue management
  - Current customer classification
  - PA Daily Scan Queue
  - Category definitions

## Performance Considerations

### TOP 20000 Limit
- Processes maximum 20000 records per execution
- Prevents memory overflow
- Enables frequent job execution

### Batch Size Configuration
- `batchInternalSize`: Default 5000
- Smaller batches: Lower memory, more DB calls
- Larger batches: Higher memory, fewer DB calls
- Configurable per environment

### Parallel Execution
- Normal and PA paths execute concurrently
- Reduces total execution time
- Better CPU utilization

### Timeout Settings
- All SPs: 300 seconds (5 minutes)
- Sufficient for batch processing
- Consistent across environments

## Flow Summary

1. **Trigger**: HTTP POST to `/api/classificationJobs/scanningRealtimeClassification`
2. **Get Changes**: Get customers with new place bets (TOP 20000)
3. **Categorize**: 
   - Chunk customers by batchInternalSize
   - Get current classification
   - Separate Normal vs PA
4. **Parallel Processing**:
   - **Normal Path**: Insert into Normal Pool for classification
   - **PA Path**: Insert into PA Daily Scan Queue
5. **Complete**: Delete processed records from RealtimeChanges

## Customer Categorization Logic

```
┌─────────────────────────────────────────────────────────────┐
│                  Customer with New Place Bet                │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
                ┌──────────────────────┐
                │ Get Current Category │
                └──────────┬───────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
    ┌──────────────────┐      ┌──────────────────┐
    │ NULL or Normal   │      │  PA or PotentialPA│
    │ ParentID=Normal  │      │  Has RelevantCat  │
    └────────┬─────────┘      └────────┬─────────┘
             │                         │
             ▼                         ▼
    ┌──────────────────┐      ┌──────────────────┐
    │   Normal Pool    │      │  PA Daily Queue  │
    │  (for classify)  │      │  (for PA scan)   │
    └──────────────────┘      └──────────────────┘
```

## Notes
- This job is **trigger-based** (not scheduled loop)
- Processes up to 20000 customers per execution
- Parallel processing optimizes performance
- Customer routing is based on current classification
- PA customers are queued for specialized daily scanning
- Normal customers go through standard classification flow

## Integration Points

### Upstream
- **Betting System**: Inserts records into RealtimeChanges when customers place bets
- **Transaction Processor**: Triggers on new betting transactions

### Downstream
- **NormalAccountClassification**: Processes customers in Normal Pool
- **DailyProblemClassification**: Processes customers in PA Daily Scan Queue

## Online Viewer
http://www.plantuml.com/plantuml/uml/

