# Daily Problem Classification - Diagrams

## Overview
This document contains diagrams for the **Daily Problem Classification** flow, which processes Problem Account (PA) customers from the daily scan queue, calculates losing performance classification, and pushes results to MainDB.

## Flow Description
The Daily Problem Classification job:
1. Gets PA customers from Daily Scan Queue (populated by RealtimeClassification)
2. Gets Problem Account Losing Classification (calculates PA classification)
3. Processes in batches:
   - Insert PA Probation Classification
   - Insert PA Logic (separate for PA and Robot)
   - Push classification to MainDB (External)
4. Updates queue completion status
5. Repeats until queue is empty

This job processes customers that were identified as PA or PotentialPA in **RealtimeClassification** and queued for daily scanning.

## Diagrams

### 01_MainFlow.puml
**Main Business Flow Diagram**
- Shows the overall flow from job trigger to completion
- Illustrates batch processing loop
- Details the 5 main steps with external push

### 02_Sequence.puml
**Sequence Diagram**
- Shows the interaction between components
- Details the sequence of method calls
- Shows batch processing and recursive call

### 03_DatabaseFlow.puml
**Database Flow Diagram**
- Shows all database operations and stored procedures
- Illustrates the flow between DataCenter (MySQL) and VR2 (SQL Server)
- Details the batch processing and external push

### 04_SP_GetFromQueue_Detailed.puml
**Stored Procedure: GetFromQueue Detailed Flow**
- Details the logic of `CTS_DC_CustClassification_DailyScanPA_GetFromQueue`
- Shows how PA customers are retrieved from queue
- Illustrates FIFO processing

### 05_SP_InsertProbation_Detailed.puml
**Stored Procedure: InsertProbation Detailed Flow**
- Details the logic of `CTS_DC_CustClassification_ProblemAccountProbation_Insert`
- Shows how PA classification is inserted
- Illustrates JSON parsing and robot detection

## Key Components

### JobService
- `DailyProblemClassificationJobService`: Orchestrates the job execution
- Batch processing with recursive calls until queue empty

### Service Layer
- `DailyProblemClassificationServices`: Business logic layer
- Methods:
  - `Start()`: Initialize model
  - `Reset()`: Reset for new batch
  - `GetPADailyScanFromQueue()`: Get PA customers from queue
  - `GetProblemAccountLosingClassification()`: Calculate PA classification
  - `InsertProblemAccountProbationClassification()`: Insert classification
  - `InsertPALogic()`: Insert PA logic (separate PA and Robot)
  - `PushCCToExternal()`: Push to MainDB
  - `UpdateComplete()`: Mark queue as completed

### Data Access Layer
- `DailyProblemClassificationDataAccess`: Database access layer
- Calls stored procedures:
  - `CTS_DC_CustClassification_DailyScanPA_GetFromQueue`
  - `CTS_DC_CustClassification_ProblemAccountProbation_Insert`
  - `CTS_DC_CustClassification_DailyScanPA_Complete`

### External Services
- `ProblemAccountServices`: PA classification calculation
- `CustClassToMainDBService`: Push to MainDB (External)

## Stored Procedures

### CTS_DC_CustClassification_DailyScanPA_GetFromQueue
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Get PA customers from Daily Scan Queue
**Parameters**: None
**Returns**: 
- CustID (long)
- DWSportType (int) - Sport Group
**Logic**:
- Get customers from CTSCustomerClassification_DailyPAQueue
- FIFO order (oldest first)
- Batch size limit (e.g., TOP 10000)
**Queue Source**: Populated by **RealtimeClassification** job

### CTS_ProblemAccountsClassification_Daily
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Calculate Problem Account Losing Classification
**Timeout**: 1200 seconds (20 minutes)
**Parameters**: Customer list (from queue)
**Returns**: ProblemAccountLosingClassificationEntity[]
**Logic**:
- Calculate losing performance
- Determine PA category based on:
  - Turnover
  - Winloss (loss amount)
  - BetCount
  - ActiveDays
  - Performance period
- Apply PA classification rules
- Return classification results

### CTS_DC_CustClassification_ProblemAccountProbation_Insert
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Insert PA Probation Classification
**Parameters**:
- `@ip_ProblemAccount` (JSON): PA classification data
**Returns**: InsertPAProbationResult[]
- CTSCustID
- CustID
- IsRobot (flag)
**Logic**:
- Parse JSON PA data
- Insert into CTSCustomerClassification table
- Set category to PA/PotentialPA
- Set probation period
- Detect if customer is Robot
- Return inserted customers with Robot flag

### CTS_DC_CustClassification_DailyScanPA_Complete
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Mark PA queue as completed
**Parameters**:
- `@CustIDs` (string): Comma-separated customer IDs
**Logic**:
- DELETE FROM CTSCustomerClassification_DailyPAQueue
- WHERE CustID IN (parsed list)
- Remove processed customers from queue

## Data Model

### PADailyScanFromQueueEntity
```csharp
public class PADailyScanFromQueueEntity
{
    public long CustID { get; set; }
    public int DWSportType { get; set; }  // Sport Group
}
```

### ProblemAccountLosingClassificationEntity
```csharp
public class ProblemAccountLosingClassificationEntity
{
    public long CustID { get; set; }
    public int CategoryID { get; set; }
    public decimal TurnoverRM { get; set; }
    public decimal WinlossRM { get; set; }
    public long BetCount { get; set; }
    public int ActiveDays { get; set; }
    public DateTime PerformanceTime { get; set; }
    // ... other PA metrics
}
```

### InsertPAProbationResult
```csharp
public class InsertPAProbationResult
{
    public long CTSCustID { get; set; }
    public long CustID { get; set; }
    public bool IsRobot { get; set; }  // Robot detection flag
}
```

## API Endpoint
- **POST** `/api/classificationJobs/scanningDailyProblemClassification`
- **Parameters**:
  - `batchSize` (int): Batch size for processing

## Key Features

### Queue-Based Processing
- PA customers queued by **RealtimeClassification**
- FIFO processing (oldest first)
- Batch processing for efficiency

### Batch Processing with Recursion
- Process batches of PA customers
- Recursive call if more customers in queue
- Continues until queue empty

### Dual PA Logic Insertion
- **Regular PA**: InsertPALogics (normal PA rules)
- **Robot PA**: InsertRobotLogics (robot-specific rules)
- Separation based on IsRobot flag

### External Push
- Push classification to MainDB after insert
- Makes PA classification visible to external systems
- Batch push for efficiency

### Robot Detection
- PA classification includes robot detection
- IsRobot flag returned from insert
- Different logic applied for robots

### Performance Calculation
- Losing performance calculated from:
  - Turnover (betting volume)
  - Winloss (loss amount)
  - BetCount (number of bets)
  - ActiveDays (betting frequency)
  - Performance period (time window)
- PA category determined by thresholds

### Database Architecture
- **DataCenter** (MySQL): Queue management and classification storage
  - DailyPAQueue (FIFO queue)
  - CTSCustomerClassification (classification storage)
- **VR2** (SQL Server): PA calculation engine
  - Losing performance calculation
  - PA category determination

## Performance Considerations

### Batch Size
- Configurable batch size
- Default: 5000-10000 customers per batch
- Balances memory and throughput

### Timeout Settings
- GetFromQueue: Standard (300s)
- PA Classification: **1200s (20 minutes)**
- Insert Probation: Standard (300s)
- Long timeout for complex PA calculations

### Recursive Processing
- Continues until queue empty
- Each recursion processes one batch
- Prevents overwhelming system

### External Push
- Batched by externalBatchSize
- Reduces external API calls
- Improves performance

## Flow Summary

1. **Trigger**: HTTP POST to `/api/classificationJobs/scanningDailyProblemClassification`
2. **Start**: Initialize model
3. **Get Queue**: Get PA customers from DailyPAQueue
4. **Calculate**: Get Problem Account Losing Classification
5. **Batch Processing**:
   - Chunk by batchSize
   - For each batch:
     a. **Reset**: Initialize for batch
     b. **Insert**: Insert PA Probation Classification
     c. **Logic**: Insert PA Logic (PA + Robot separate)
     d. **Push**: Push to MainDB (External)
6. **Complete**: Mark queue as completed
7. **Recurse**: If more customers, call JobRun again

## PA Classification Flow

```
┌─────────────────────────────────────────────────────────────┐
│          Daily Problem Classification                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   Get from DailyPAQueue     │
        │   (FIFO, TOP 10000)         │
        └──────────────┬──────────────┘
                       │
        ┌──────────────┴──────────────────────────┐
        │   Calculate PA Classification           │
        │   - Turnover, Winloss, BetCount        │
        │   - Determine PA category              │
        └──────────────┬──────────────────────────┘
                       │
        ┌──────────────┴──────────────────┐
        │   Batch Processing              │
        │   (Chunk by batchSize)          │
        └──────────────┬──────────────────┘
                       │
        ┌──────────────┴──────────────────────────┐
        │   For Each Batch                        │
        ├─────────────────────────────────────────┤
        │ 1. Insert PA Probation (JSON)          │
        │ 2. Separate PA vs Robot (IsRobot flag)│
        │ 3. Insert PA Logic                     │
        │ 4. Insert Robot Logic                  │
        │ 5. Push to MainDB                      │
        └──────────────┬──────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   Complete Queue            │
        │   DELETE from DailyPAQueue  │
        └──────────────┬──────────────┘
                       │
                 More in Queue?
                       │
                 Yes → Recurse
                 No  → Done
```

## Integration Points

### Upstream (Queue Feeder)
- **RealtimeClassification**: Inserts PA customers into DailyPAQueue
  - Customers with PA or PotentialPA category
  - RelevantCategoryID IS NOT NULL

### Downstream (Classification Storage)
- **CTSCustomerClassification**: Stores PA classification
- **MainDB**: Receives PA classification updates (external visibility)

### Related Jobs
- **ProbationClassification**: Processes customers in probation period
- **DailyDangerousClassification**: Processes dangerous score classification

## Notes
- This job is **consumer** of DailyPAQueue
- Queue populated by **RealtimeClassification** (producer)
- PA classification based on losing performance
- Robot detection built into PA classification
- Different logic for PA vs Robot
- Recursive processing until queue empty
- External push makes PA visible to MainDB
- Batch processing optimizes performance
- Long timeout (20 min) for complex calculations

## Comparison with DailyNormalClassification

| Aspect | Daily Normal | Daily Problem |
|--------|--------------|---------------|
| **Source** | Category scan | DailyPAQueue |
| **Target** | Normal Pool | PA Classification |
| **Calculation** | None (just scan) | Losing performance |
| **Logic Insert** | No | Yes (PA + Robot) |
| **External Push** | No | Yes (to MainDB) |
| **Complexity** | Low | High |
| **Timeout** | 1200s | 1200s |
| **Purpose** | Queue for classification | Complete PA classification |

## Online Viewer
http://www.plantuml.com/plantuml/uml/

