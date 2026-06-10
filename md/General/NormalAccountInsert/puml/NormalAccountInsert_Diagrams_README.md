# Normal Account Insert - Diagrams

## Overview
This document contains diagrams for the **Normal Account Insert** flow, which takes classified customers from Normal Account Classification, applies tagging logic, inserts classification, and pushes data to MainDB.

## Flow Description
The Normal Account Insert job:
1. Gets classified customers (customers already processed by NormalAccountClassification)
2. Merges with tagging data through 3 processing steps:
   - **TW Tagged** (Taiwan Group Betting & Reject detection)
   - **Association with PA** (Associated with Problem Accounts)
   - **TW Tagged Special LicSub** (Special Licensee Sub-type tagging)
3. Inserts classification to database
4. Executes 4 parallel tasks:
   - Push classification to MainDB (External)
   - Complete Special LicSub classification
   - Preprocess Dangerous Association
   - Delete AFC (Anti-Fraud Center) accounts
5. Marks processed customers as completed

## Diagrams

### 01_MainFlow.puml
**Main Business Flow Diagram**
- Shows the overall flow from job trigger to completion
- Illustrates do-while loop for continuous processing
- Details the 3 tagging steps and 4 parallel tasks

### 02_Sequence.puml
**Sequence Diagram**
- Shows the interaction between components
- Details the sequence of tagging processing
- Shows parallel execution of 4 tasks with Parallel.Invoke()

### 03_DatabaseFlow.puml
**Database Flow Diagram**
- Shows all database operations and stored procedures
- Illustrates the flow between VR2 (SQL Server) and DataCenter (MySQL)
- Details tagging checks and external push

### 04_TaggingFlow_Detailed.puml
**Tagging Processing Flow**
- Details the 3-step tagging process
- Shows merge logic for each tagging type
- Illustrates priority and exclusion rules

### 05_SP_GetNormalAccount_Detailed.puml
**Stored Procedure: GetNormalAccount Detailed Flow**
- Details the logic of `CTS_GeneralNormalClassification_NormalAccount_Get`
- Shows how classified customers are retrieved
- Illustrates IsProcessed flag and ScannedMaxId tracking

### 06_ParallelTasks_Detailed.puml
**Parallel Tasks Execution**
- Details the 4 parallel tasks execution
- Shows Parallel.Invoke() strategy
- Illustrates each task's purpose and flow

## Key Components

### JobService
- `NormalAccountJobService`: Orchestrates the job execution
- Do-while loop for continuous processing until no more customers

### Service Layer
- `NormalAccountService`: Business logic layer
- Methods:
  - `GetNormalAccounts()`: Get classified customers
  - `MergeWithTaggedNormalTaggingFlow()`: Apply 3-step tagging
  - `InsertNormalAccount()`: Insert classification
  - `CompleteNormalAccountInsert()`: Mark as completed

### Data Access Layer
- `NormalAccountDataAccess`: Database access layer
- Calls stored procedures:
  - `CTS_GeneralNormalClassification_NormalAccount_Get`
  - `CTS_NormalClassification_NormalAccount_TWGroupBettingAndReject_Check`
  - `CTS_DC_CustClassification_GetTaggingByAssociationWithPA`
  - `CTS_DC_NormalClassification_NormalAccount_TWTaggedSpecialLicSub_Check`
  - `CTS_DC_NormalClassification_TW_CheckExclude`
  - `CTS_GeneralNormalClassification_NormalAccount_Complete`

### External Services
- `CustClassToMainDBService`: Push classification to MainDB
- `AntiFraudCenterServices`: Sync with AFC
- `NormalDangerousAssociationCheckService`: Dangerous association preprocessing
- `TWClassificationService`: Special LicSub completion

## Stored Procedures

### CTS_GeneralNormalClassification_NormalAccount_Get
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Get classified customers ready for insertion
**Parameters**:
- `@ScannedMaxId` (OUTPUT): Maximum ID processed
- `@IsLogData` (INPUT): Whether to log detailed data
**Returns**:
- CustId, CategoryId, CategoryGroupId
- CreatedTime, PerformanceTime
- TurnoverRM, WinlossRM, BetCount, ActiveDays
- ScanTaggingType, ScanTaggingTWType, ScanSpecialLicSubType
**Logic**:
- Get customers with IsProcessed = 0
- Already classified (has CategoryId)
- Order by ID ASC

### CTS_NormalClassification_NormalAccount_TWGroupBettingAndReject_Check
**Database**: bodb_VR2Model or DataCenter
**Purpose**: Check TW Group Betting and Reject patterns
**Parameters**:
- `@CustIdList` (string): Comma-separated customer IDs
**Returns**:
- CustID, TaggingID, TaggingType
- TWBetCount, TWGroupBettingRate
- TWTicketRejectRate, TWDesktopUsageRate
**Logic**:
- Detect Taiwan betting patterns
- Group betting detection
- Ticket reject rate analysis
- Desktop usage patterns

### CTS_DC_CustClassification_GetTaggingByAssociationWithPA
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Check customer association with Problem Accounts
**Parameters**:
- `@CustIdList` (string): Comma-separated customer IDs
**Returns**:
- CustID, TaggingID, TaggingType
**Logic**:
- Check if customer associated with PA
- Via device, IP, payment method, etc.
- Apply association tagging

### CTS_DC_NormalClassification_NormalAccount_TWTaggedSpecialLicSub_Check
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Check TW tagging for special licensee sub-types
**Parameters**:
- `@CustomerJson` (JSON): Customer info in JSON format
**Returns**:
- CustID, TaggingID, TaggingType
**Logic**:
- Check special licensee sub-type
- Apply special TW tagging rules
- Different rules for special licenses

### CTS_DC_NormalClassification_TW_CheckExclude
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Check if TW tagging should be excluded
**Parameters**:
- `@JsonData` (JSON): Customer, Category, Tagging info
**Returns**:
- CustID (customers that should keep TW tagging)
**Logic**:
- Exclusion rules based on Category + Tagging combination
- Some categories exempt from TW tagging
- Business rules for tagging applicability

### CTS_GeneralNormalClassification_NormalAccount_Complete
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Mark customers as processed
**Parameters**:
- `@ScannedMaxId` (long): Maximum ID processed
**Logic**:
- UPDATE IsProcessed = 1
- WHERE ID <= @ScannedMaxId
- Prevents reprocessing

## Data Model

### GetNormalAccountEntity
```csharp
public class GetNormalAccountEntity
{
    public long CustId { get; set; }
    public int? CategoryId { get; set; }
    public int? CategoryGroupId { get; set; }
    public DateTime CreatedTime { get; set; }
    public decimal TurnoverRM { get; set; }
    public decimal WinlossRM { get; set; }
    public Int64 BetCount { get; set; }
    public int ActiveDays { get; set; }
    public DateTime PerformanceTime { get; set; }
    public int ScanTaggingType { get; set; }
    public int ScanTaggingTWType { get; set; }
    public int ScanSpecialLicSubType { get; set; }
}
```

### InsertNormalAccountEntity (extends CustomerClassificationEntity)
```csharp
public class InsertNormalAccountEntity : CustomerClassificationEntity
{
    // From GetNormalAccountEntity
    public DateTime CreatedTime { get; set; }
    public int ScanTaggingType { get; set; }
    public int ScanSpecialLicSubType { get; set; }
    
    // From Tagging
    public int TaggingID { get; set; }
    public int TaggingType { get; set; }
    public int TWBetCount { get; set; }
    public decimal TWGroupBettingRate { get; set; }
    public decimal TWTicketRejectRate { get; set; }
    public decimal TWDesktopUsageRate { get; set; }
}
```

## API Endpoint
- **POST** `/api/classificationJobs/normalAccountInsert`
- **Parameters**:
  - `batchExternalSize` (int): External batch size for MainDB push
  - `batchInternalSize` (int): Internal batch size (default: 5000)
  - `isLogData` (bool): Whether to log detailed data

## Key Features

### Do-While Loop
- Continuous processing until no more customers
- `GetNormalAccounts()` returns `IsContinute` flag
- Processes all pending customers in one job execution

### Parallel Processing (5 Threads)
- Customers chunked by `batchInternalSize`
- `AsParallel().WithDegreeOfParallelism(5)`
- Each thread processes a batch independently

### 3-Step Tagging Processing
```
Step 1: TW Tagged (Group Betting & Reject)
  ↓
Step 2: Association with Problem Account
  ↓
Step 3: TW Tagged Special LicSub
```
Each step can add/update TaggingID and TaggingType

### Tagging Priority Rules
- **TW Tagged**: Applied first (if ScanTaggingTWType = 1)
- **Association with PA**: Applied second (if TaggingID still 0)
- **TW Tagged Special LicSub**: Applied last (if TaggingID still 0)
- Later tagging does NOT overwrite earlier tagging

### TW Tagging Exclusion
- Not all TW Tagged customers get tagged
- Exclusion rules based on Category + Tagging combination
- CheckTWTaggingExclude returns customers that SHOULD be tagged
- Filters out customers that should NOT be tagged

### 4 Parallel Tasks After Insert
```
Parallel.Invoke(
  1. PushCCToExternal        → Push to MainDB
  2. CompleteSpecialLicSub   → Special licensee handling
  3. PreprocessDangerousAssociation → Dangerous association check
  4. DeleteAFCAccounts       → Anti-Fraud Center sync
)
```

### Failed Thread Tracking
- `ConcurrentBag<bool>` tracks failed threads
- If any thread fails, mark batch as failed
- Failed batches NOT marked as completed
- Will be retried in next job execution

### Database Architecture
- **VR2 Database** (SQL Server): Classification data
  - NormalAccount table
  - TW tagging checks
  - Completion marking
- **DataCenter Database** (MySQL): Metadata and tagging
  - Association with PA
  - Special LicSub tagging
  - Exclusion rules

## Performance Considerations

### Batch Size
- Default internal: 5000 customers per batch
- 5 parallel threads processing simultaneously
- Effective throughput: ~25000 customers per iteration

### Do-While Loop
- Processes ALL pending customers
- No limit on iterations
- Continues until NormalAccount table is empty

### Parallel Task Execution
- 4 tasks after insert run concurrently
- Reduces total processing time
- Independent tasks (no dependencies)

### Timeout Settings
- All SPs: 300 seconds (5 minutes)
- Sufficient for batch processing

## Flow Summary

1. **Trigger**: HTTP POST to `/api/classificationJobs/normalAccountInsert`
2. **Do-While Loop**:
   a. **Get**: Classified customers from NormalAccount table
   b. **Tagging**: Apply 3-step tagging process
   c. **Parallel Processing (5 threads)**:
      - Chunk customers
      - Insert classification (JSON → BaseClassification SP)
      - Parallel.Invoke 4 tasks:
        * Push to MainDB
        * Complete Special LicSub
        * Preprocess Dangerous Association
        * Delete AFC accounts
   d. **Complete**: Mark as processed (if all threads successful)
   e. **Continue**: If more customers exist

## Tagging Decision Matrix

```
Customer → Check ScanTaggingTWType
            ↓
         = 1 ? 
         Yes ↓                           No ↓
    TW Group Betting Check          Skip TW Check
            ↓                              ↓
    Exclusion Check                        ↓
    (Keep tagged only)                     ↓
            ↓                              ↓
    TaggingID != 0 ?───────────────────────┤
            │ Yes                  No │    │
            ↓                         ↓    │
    Keep TaggingID        Association PA Check
                                      ↓    │
                          TaggingID != 0 ? │
                                  │ Yes    │ No
                                  ↓        ↓
                          Keep TaggingID  Special LicSub Check
                                            ↓
                                    TaggingID set (if match)
```

## Notes
- This job is **downstream** of **NormalAccountClassification**
- Customers must be classified before insertion
- Tagging adds additional risk indicators
- MainDB push makes classification visible to external systems
- Failed batches automatically retried in next execution
- AFC sync removes customers from fraud monitoring if now Normal
- Dangerous Association preprocessing triggers association analysis

## Integration Points

### Upstream
- **NormalAccountClassification**: Populates NormalAccount table with classified customers

### Downstream
- **MainDB**: Receives classification updates (external visibility)
- **Anti-Fraud Center**: Syncs customer status
- **Dangerous Association**: Triggers association scanning

### Parallel Services
- **Special LicSub Classification**: Completes special licensee handling
- **TW Classification**: Applies Taiwan-specific rules

## Online Viewer
http://www.plantuml.com/plantuml/uml/

