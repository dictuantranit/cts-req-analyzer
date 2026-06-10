# Daily Normal Classification - Diagrams

## Overview
This document contains diagrams for the **Daily Normal Classification** flow, which scans and preprocesses normal customers on a daily basis, inserting them into the Normal Pool for later classification.

## Flow Description
The Daily Normal Classification job:
1. Gets normal customers for daily scanning (based on category scan intervals)
2. Classifies/Preprocesses customers by inserting them into Normal Pool
3. Updates system parameters to track last scanned position (Category + Customer)
4. Repeats until no more customers found

This is a **feeder job** that populates the Normal Pool, which is then processed by **NormalAccountClassification** and **NormalAccountInsert**.

## Diagrams

### 01_MainFlow.puml
**Main Business Flow Diagram**
- Shows the overall flow from job trigger to completion
- Illustrates do-while loop based on customer availability
- Details the 3 main steps: Get, Classify, UpdateLastScan

### 02_Sequence.puml
**Sequence Diagram**
- Shows the interaction between components
- Details the sequence of method calls and data flow
- Shows loop structure with SystemParameter updates

### 03_DatabaseFlow.puml
**Database Flow Diagram**
- Shows the database operations and stored procedures involved
- Illustrates the flow between DataCenter (MySQL) and VR2 (SQL Server)
- Details the incremental scanning mechanism

### 04_SP_GetNormal_Detailed.puml
**Stored Procedure: GetNormal Detailed Flow**
- Details the logic of `CTS_DC_CustClassification_DailyScan_GetNormal`
- Shows incremental scanning with LastCategoryID and LastCustID
- Illustrates category-based scanning with scan intervals

### 05_SP_Preprocess_Detailed.puml
**Stored Procedure: Preprocess Detailed Flow**
- Details the logic of `CTS_GeneralNormalClassification_Daily_Preprocess`
- Shows how customers are inserted into Normal Pool
- Illustrates priority assignment for daily scanning

## Key Components

### JobService
- `DailyNormalClassificationJobService`: Orchestrates the job execution
- Do-while loop until no more customers

### Service Layer
- `DailyNormalClassificationServices`: Business logic layer
- Methods:
  - `Start()`: Initialize scanning entity
  - `GetCustomerForDailyNormalScanning()`: Get customers to scan
  - `ClassifyDailyNormal()`: Insert into Normal Pool
  - `UpdateLastScan()`: Update system parameters

### Data Access Layer
- `DailyNormalClassificationDataAccess`: Database access layer
- Calls stored procedures:
  - `CTS_DC_CustClassification_DailyScan_GetNormal`
  - `CTS_GeneralNormalClassification_Daily_Preprocess`

### System Parameter Service
- `SystemParameterServices`: Manages system parameters
- Updates:
  - `DailyNormalClassificationLastCategoryID` (ParameterID = 85)
  - `DailyNormalClassificationLastCustID` (ParameterID = 86)

## Stored Procedures

### CTS_DC_CustClassification_DailyScan_GetNormal
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Get normal customers for daily scanning
**Parameters**:
- `@op_LastCategoryID` (OUTPUT): Last scanned category ID
- `@op_LastCustID` (OUTPUT): Last scanned customer ID
**Returns**: List of CustID (long)
**Logic**:
- Get LastCategoryID and LastCustID from SystemParameter
- Find next category to scan (based on scan interval)
- Get customers from that category
- Filter by:
  - LastScannedDate >= interval threshold
  - Active customers (has transactions)
  - CustID > LastCustID (incremental)
- Return customer IDs + output parameters for next scan
**Incremental Scanning**:
- Scans one category at a time
- Within category, scans incrementally by CustID
- When category complete, moves to next category
- Wraps around when all categories scanned

### CTS_GeneralNormalClassification_Daily_Preprocess
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Insert customers into Normal Pool for classification
**Parameters**:
- `@ListCustId` (string): Comma-separated customer IDs
**Logic**:
- Parse customer ID list
- Get Priority from CustomerClassification_Priority table
  - GroupId = 1 (General)
  - FunctionId = 2 (Daily)
- Call NormalPool_Insert stored procedure
- Insert into CustomerClassification_NormalPool:
  - CustId
  - Priority (Daily priority, typically lower than Realtime)
  - FunctionId = 2 (Daily)
  - GroupId = 1 (General)
  - IsProcessed = 0
  - CreatedDate = NOW()
- Prevent duplicates (skip if already in pool)

## Data Model

### DailyNormalClassificationEntity
```csharp
public class DailyNormalClassificationEntity
{
    public int op_LastCategoryID { get; set; }      // OUTPUT from SP
    public UInt64 op_LastCustID { get; set; }       // OUTPUT from SP
    public IEnumerable<Int64> CustID { get; set; }  // Customer IDs to process
}
```

## API Endpoint
- **POST** `/api/classificationJobs/scanningDailyNormalClassification`
- **Parameters**: None

## Key Features

### Incremental Scanning
- Uses LastCategoryID and LastCustID to track progress
- Scans one category at a time
- Within category, scans incrementally by CustID
- Resumes from last position on next execution

### Category-Based Scanning
- Each category has ScanIntervalInSecond
- Only scans categories due for scanning
- Categories with shorter intervals scanned more frequently
- Balances load across categories

### Do-While Loop
- Continues until no more customers found
- Processes all due customers in one execution
- No fixed iteration limit

### System Parameter Tracking
- Persists scanning position between executions
- Two parameters:
  - **LastCategoryID** (85): Last processed category
  - **LastCustID** (86): Last processed customer in category
- Updated after each successful iteration

### Priority Assignment
- Daily customers assigned Daily priority
- Typically lower than Realtime priority
- Ensures Realtime customers processed first
- Default Daily priority: ~100 (vs Realtime: ~200)

### Normal Pool as Queue
- DailyNormalClassification is a **producer**
- Inserts into Normal Pool (queue)
- NormalAccountClassification is a **consumer**
- Processes from Normal Pool

### Database Architecture
- **DataCenter** (MySQL): Customer metadata and categories
  - Stores customer classifications
  - Category definitions with scan intervals
  - SystemParameter for tracking
- **VR2** (SQL Server): Classification engine
  - Normal Pool storage
  - Classification processing

## Performance Considerations

### Batch Processing
- Processes one category at a time
- Prevents overwhelming the system
- Manageable batch sizes per iteration

### Scan Intervals
- Categories scanned based on interval
- High-risk categories: Shorter intervals
- Low-risk categories: Longer intervals
- Optimizes scanning frequency

### Incremental Progress
- Resumes from last position
- No duplicate scanning
- Efficient even with interruptions

### Timeout Settings
- GetNormal: Standard timeout (300s)
- Preprocess: Longer timeout (1200s = 20 minutes)
- Allows processing large batches

## Flow Summary

1. **Trigger**: HTTP POST to `/api/classificationJobs/scanningDailyNormalClassification`
2. **Do-While Loop**:
   a. **Start**: Initialize entity
   b. **Get**: Get customers from next category due for scan
   c. **Classify**: Insert customers into Normal Pool
   d. **Update**: Update LastCategoryID and LastCustID
   e. **Check**: If customers found, continue; else stop

## Scanning Strategy

```
┌─────────────────────────────────────────────────────────────┐
│              Daily Normal Classification                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   Read SystemParameter      │
        │   LastCategoryID = X        │
        │   LastCustID = Y            │
        └──────────────┬──────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   Find Next Category        │
        │   (Based on scan interval)  │
        └──────────────┬──────────────┘
                       │
        ┌──────────────┴──────────────────────────┐
        │   Get Customers from Category           │
        │   - WHERE CustID > LastCustID           │
        │   - AND LastScannedDate due             │
        │   - AND Active (has transactions)       │
        └──────────────┬──────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   Insert to Normal Pool     │
        │   (Priority = Daily)        │
        └──────────────┬──────────────┘
                       │
        ┌──────────────┴──────────────────────────┐
        │   Update SystemParameter                │
        │   LastCategoryID = Current Category     │
        │   LastCustID = Last Customer in Batch   │
        └─────────────────────────────────────────┘
```

## Category Progression Example

```
Categories: [1, 2, 3, 4, 5]
Each category has scan interval

Execution 1:
  LastCategoryID = 1, LastCustID = 0
  → Scan Category 1, CustID 1-1000
  → Update: LastCategoryID = 1, LastCustID = 1000

Execution 2:
  LastCategoryID = 1, LastCustID = 1000
  → Scan Category 1, CustID 1001-2000
  → Update: LastCategoryID = 1, LastCustID = 2000

Execution 3:
  LastCategoryID = 1, LastCustID = 2000
  → Category 1 complete, move to Category 2
  → Scan Category 2, CustID 1-1000
  → Update: LastCategoryID = 2, LastCustID = 1000

... continues through all categories ...

When all categories complete:
  → Reset to Category 1 (wrap around)
  → Start next daily cycle
```

## Notes
- This is a **feeder/producer** job
- Populates Normal Pool for downstream processing
- Does NOT do actual classification (just preprocessing)
- Actual classification done by **NormalAccountClassification**
- Insertion to MainDB done by **NormalAccountInsert**
- Incremental scanning enables reliable processing
- Category-based approach balances load
- System parameters ensure no data loss on failure

## Integration Points

### Downstream (Consumers)
- **NormalAccountClassification**: Processes customers from Normal Pool
- **NormalAccountInsert**: Inserts classification and pushes to MainDB

### Data Flow
```
DailyNormalClassification
        ↓
   Normal Pool
        ↓
NormalAccountClassification
        ↓
  NormalAccount Table
        ↓
NormalAccountInsert
        ↓
     MainDB
```

## Comparison with Realtime

| Aspect | Daily | Realtime |
|--------|-------|----------|
| **Trigger** | Scheduled | New place bet |
| **Source** | Category scan | RealtimeChanges table |
| **Priority** | Lower (~100) | Higher (~200) |
| **Frequency** | Based on interval | Immediate |
| **Volume** | Large batches | Smaller batches |
| **Purpose** | Regular scanning | Quick response |

## Online Viewer
http://www.plantuml.com/plantuml/uml/

