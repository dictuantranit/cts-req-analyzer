# Match Monitor Group Betting Diagrams

## Overview
This directory contains PlantUML diagrams documenting the **Match Monitor Group Betting Rule Processing** feature, which detects suspicious group betting patterns in match betting transactions.

## Feature Summary
**Match Monitor Group Betting** is part of the SPU (Special Processing Unit) system that:
- Detects group betting patterns across matches
- Uses multi-criteria association detection (Device, IP, AI, etc.)
- Processes matches in parallel with 2-round detection
- Integrates with Association Detection service

## Diagrams

1. **MatchMonitorGroupBetting_01_MainFlow.puml** - Main Business Flow (2 Phases)
2. **MatchMonitorGroupBetting_02_Sequence.puml** - Sequence Diagram (Detailed)
3. **MatchMonitorGroupBetting_03_StagingFlow.puml** - Staging Phase Flow
4. **MatchMonitorGroupBetting_04_ProcessingFlow.puml** - Processing Phase Flow (Round 1 & 2)
5. **MatchMonitorGroupBetting_05_AssociationDetection.puml** - Association Detection Logic
6. **MatchMonitorGroupBetting_06_DatabaseFlow.puml** - Database Operations Flow
7. **MatchMonitorGroupBetting_07_CompleteFlow.puml** - Complete & Clean Flow

---

### 1. **MatchMonitorGroupBetting_MainFlow** (Activity Diagram)
- **Purpose**: High-level overview of the entire Group Betting detection flow
- **Content**: 
  - Phase 1: Staging (Insert Ticket Detail)
  - Phase 2: Processing (Detect Group Betting)
- **Use**: Overview for stakeholders and business analysts

### 2. **MatchMonitorGroupBetting_Sequence** (Sequence Diagram)
- **Purpose**: Detailed sequence of interactions between components
- **Content**:
  - Controller → JobService → Service → DataAccess → Database
  - Staging service flow
  - Rule processing service flow
  - Association detection integration
- **Components**:
  - `MatchMonitorController`
  - `MatchMonitorJobService`
  - `MatchMonitorStagingService`
  - `MatchMonitorRuleGroupBettingService`
  - `MatchMonitorRuleGroupBettingProcessService`
  - `AssociationDetectionService`
- **Use**: Technical documentation for developers

### 3. **MatchMonitorGroupBetting_StagingFlow** (Activity Diagram)
- **Purpose**: Detailed flow of Staging Phase (Insert Ticket Detail)
- **Content**:
  - Get LastScannedSequenceID from SystemParameter
  - Get ticket transactions from MainDB
  - Insert into staging tables (by Pool Type)
  - Update LastScannedSequenceID
- **Stored Procedures**:
  - `CTS_MatchMonitor_GetTicketTrans` (MainDB)
  - `CTS_MatchMonitor_InsertStaging` (CTS_DataCenter)
- **Use**: Understanding data ingestion flow

### 4. **MatchMonitorGroupBetting_ProcessingFlow** (Activity Diagram)
- **Purpose**: Detailed flow of Processing Phase
- **Content**:
  - Get match list from staging
  - Parallel processing (multiple threads)
  - Round 1: Initial detection
  - Round 2: Re-processing
  - Complete: Save results
  - Clean: Remove processed transactions
- **Key Concepts**:
  - 2-round detection strategy
  - Parallel processing with configurable threads
  - Association detection integration
- **Use**: Understanding fraud detection logic

### 5. **MatchMonitorGroupBetting_AssociationDetection** (Component Diagram)
- **Purpose**: Association detection criteria and logic
- **Content**:
  - Multi-criteria detection settings:
    - Device detection (same DeviceID)
    - AI detection (AI model)
    - IP detection (same IP address)
    - 3 Matches Last 7 Days
    - IP Last 3 Days
  - Sport-specific configuration
  - Group merging logic
- **Model**: `MatchDetectAssociationSettingModel`
- **Use**: Understanding how customers are grouped

### 6. **MatchMonitorGroupBetting_DatabaseFlow** (Activity Diagram)
- **Purpose**: Database operations and stored procedures flow
- **Content**:
  - All stored procedure calls
  - Parameters and return values
  - Database table operations
- **Stored Procedures**:
  - `CTS_MatchMonitor_RuleGroupBetting_Get`
  - `CTS_MatchMonitor_RuleGroupBetting_Process`
  - `CTS_MatchMonitor_RuleGroupBetting_Complete`
  - `CTS_MatchMonitor_RuleGroupBetting_Clean`
- **Tables**:
  - `CTSMatchMonitorStaging` (Input)
  - `CTSMatchMonitorRuleGroupBetting` (Output)
- **Use**: Database documentation and troubleshooting

### 7. **MatchMonitorGroupBetting_CompleteFlow** (Activity Diagram)
- **Purpose**: Complete and clean-up operations
- **Content**:
  - Merge results from Round 1 & 2
  - Assign GroupID
  - Insert into result table
  - Mark transactions as processed
  - Clean-up old transactions
- **Use**: Understanding result persistence

---

## Key Components

### Controllers
- **MatchMonitorController**: API endpoint controller
  - Route: `/api/matchmonitor`
  - Endpoints:
    - `POST /MatchMonitorInsertTicketDetailLive`
    - `POST /MatchMonitorInsertTicketDetailNonLive`
    - `POST /MatchMonitorProcessRuleGroupBettingLive`
    - `POST /MatchMonitorProcessRuleGroupBettingNonLive`

### Services

#### Job Services
- **MatchMonitorJobService**: Main job orchestrator
  - Methods:
    - `InsertTicketDetail(batchSize, isLive)`
    - `ProcessRuleGroupBetting(isLive, numberOfThread, assDetectSetting)`

#### Business Services
- **MatchMonitorStagingService**: Staging phase service
  - Fluent interface methods:
    - `Start(batchSize, isLive)`
    - `GetLastScannedSequenceID()`
    - `GetMatchTrans()`
    - `InsertMatchMonitorStagingWithParallel()`
    - `UpdateLastScannedSequenceID()`

- **MatchMonitorRuleGroupBettingService**: Rule service
  - Methods:
    - `GetMatchRuleGroupBetting(isLive)`
    - `GetInstanceProcessGroupBettingService()`
    - `CleanTransRuleGroupBetting(isLive, maxSequenceID)`

- **MatchMonitorRuleGroupBettingProcessService**: Processing service
  - Interface: `IMatchMonitorRuleProcessService<T>`
  - Methods:
    - `PrepareProcess(matchStaging, isLive, assDetectSetting)`
    - `ProcessRound1()`
    - `ProcessRound2()`
    - `Complete(maxSequenceID)`
    - `WriteLogSentryIfError(functionName)`

- **AssociationDetectionService**: External detection service
  - Methods:
    - `DetectAssociationLv1(params)`

### Data Access
- **MatchMonitorStagingDataAccess**: Staging database operations
- **MatchMonitorRuleGroupBettingDataAccess**: Rule database operations

### Models

#### Configuration Models
```csharp
public class MatchDetectAssociationSettingModel
{
    public HashSet<int> DeviceSports { get; set; }
    public HashSet<int> AISports { get; set; }
    public HashSet<int> IPSports { get; set; }
    public HashSet<int> _3MatchesLast7DaysSports { get; set; }
    public HashSet<int> IPLast3DaysSports { get; set; }
}
```

#### Staging Models
```csharp
public class TicketDetailEntity
{
    public long SequenceID { get; set; }
    public long MatchID { get; set; }
    public string BetID { get; set; }
    public int BettypeID { get; set; }
    public string CustID { get; set; }
    public int? CTSCustID { get; set; }
    public decimal Amount { get; set; }
    public decimal Odds { get; set; }
    public string Betteam { get; set; }
    public string ScoreDiff { get; set; }
    public int SportType { get; set; }
}
```

#### Processing Models
```csharp
public class MatchStagingRuleGroupBettingGroupModel
{
    public long MatchID { get; set; }
    public string ScoreDiff { get; set; }
    public int BettypeID { get; set; }
    public string BetID { get; set; }
    public string Betteam { get; set; }
    public List<MatchStagingRuleGroupBettingEntity> MatchGroupStagingList { get; set; }
}

public class MatchProcessRuleGroupBettingModel
{
    public MatchStagingRuleGroupBettingEntity MatchInfo { get; set; }
    public int RoundNumber { get; set; }
    public List<MatchProcessRuleGroupBettingInfoEntity> ReprocessMatches { get; set; }
    public List<MatchCompleteRuleGroupBettingEntity> CompleteMatches { get; set; }
}
```

---

## Stored Procedures

### Staging Phase

#### 1. CTS_MatchMonitor_GetTicketTrans
**Database**: MainDB (SQL Server)  
**Purpose**: Get betting transactions from MainDB  
**Input**:
- `@LastSequenceID` (bigint) - Last scanned sequence
- `@BatchSize` (int) - Number of records to fetch
- `@IsLive` (bit) - Live or Non-Live
- `@BetTypeInfos` (JSON) - Bet type filter

**Output**: List of `TicketDetailEntity`

**Logic**:
```sql
SELECT SequenceID, MatchID, BetID, BettypeID, CustID, CTSCustID,
       Amount, Odds, Betteam, ScoreDiff, SportType, ...
FROM TicketTrans
WHERE SequenceID > @LastSequenceID
  AND IsLive = @IsLive
  AND BettypeID IN (SELECT BettypeID FROM JSON_TABLE(@BetTypeInfos, ...))
ORDER BY SequenceID
LIMIT @BatchSize
```

#### 2. CTS_MatchMonitor_InsertStaging
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Insert tickets into staging table  
**Input**:
- `@MatchTransJson` (JSON) - Ticket data
- `@IsLive` (bit)
- `@PoolType` (int) - 1=GroupBetting, 2=Hedging, etc.

**Logic**:
```sql
INSERT INTO CTSMatchMonitorStaging (
    MatchID, BetID, BettypeID, CustID, CTSCustID,
    Amount, Odds, Betteam, ScoreDiff, PoolType,
    SequenceID, IsLive, CreatedDate
)
SELECT ... FROM JSON_TABLE(@MatchTransJson, ...)
```

### Processing Phase

#### 3. CTS_MatchMonitor_RuleGroupBetting_Get
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Get matches for group betting detection  
**Input**:
- `@IsLive` (bit)

**Output**:
- `MaxSequenceID` (bigint)
- List of `MatchStagingRuleGroupBettingEntity` (grouped)

**Logic**:
```sql
-- Get Max SequenceID
SELECT MAX(SequenceID) as MaxSequenceID
FROM CTSMatchMonitorStaging
WHERE IsLive = @IsLive AND PoolType = 1 AND IsProcessed = 0;

-- Get Match List (Grouped)
SELECT MatchID, ScoreDiff, BettypeID, BetID, Betteam,
       GROUP_CONCAT(SequenceID) as SequenceIDList,
       GROUP_CONCAT(CTSCustID) as CTSCustIDList,
       GROUP_CONCAT(CustID) as CustIDList,
       SportType
FROM CTSMatchMonitorStaging
WHERE IsLive = @IsLive AND PoolType = 1 AND IsProcessed = 0
GROUP BY MatchID, ScoreDiff, BettypeID, BetID, Betteam;
```

#### 4. CTS_MatchMonitor_RuleGroupBetting_Process
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Process group betting detection  
**Input**:
- `@IsLive` (bit)
- `@MatchInfo` (JSON)
- `@SequenceIDList` (string)
- `@GroupDetection` (JSON) - Association results

**Output**:
- `MatchProcessRuleGroupBettingModel` (multiple result sets)

#### 5. CTS_MatchMonitor_RuleGroupBetting_Complete
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Save detection results  
**Input**:
- `@IsLive` (bit)
- `@MatchInfo` (JSON)
- `@MaxSequenceID` (bigint)
- `@TransGroupJson` (JSON) - Completed groups

**Logic**:
```sql
-- Insert results
INSERT INTO CTSMatchMonitorRuleGroupBetting (
    MatchID, GroupID, TransIDList, CustIDList,
    TotalAmount, DetectionType, CreatedDate
)
SELECT ... FROM JSON_TABLE(@TransGroupJson, ...);

-- Mark as processed
UPDATE CTSMatchMonitorStaging
SET IsProcessed = 1, ProcessedDate = NOW()
WHERE SequenceID IN (...);
```

#### 6. CTS_MatchMonitor_RuleGroupBetting_Clean
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Clean up processed transactions  
**Input**:
- `@IsLive` (bit)
- `@MaxSequenceID` (bigint)

**Logic**:
```sql
DELETE FROM CTSMatchMonitorStaging
WHERE IsLive = @IsLive
  AND PoolType = 1
  AND IsProcessed = 1
  AND SequenceID <= @MaxSequenceID
  AND ProcessedDate < DATE_SUB(NOW(), INTERVAL 7 DAY);
```

---

## Flow Summary

### Phase 1: Staging (Insert Ticket Detail)
1. **Trigger**: HTTP POST to `/api/matchmonitor/MatchMonitorInsertTicketDetailLive`
2. **Get LastScannedSequenceID**: From SystemParameter
3. **Get Transactions**: From MainDB using SequenceID
4. **Insert Staging**: Parallel insert to multiple pools
5. **Update SequenceID**: Save max SequenceID for next run

### Phase 2: Processing (Detect Group Betting)
1. **Trigger**: HTTP POST to `/api/matchmonitor/MatchMonitorProcessRuleGroupBettingLive`
2. **Get Matches**: From staging, grouped by match + bet
3. **Parallel Process**: Multiple matches simultaneously
   - **Round 1**: Initial association detection
   - **Round 2**: Re-process with refined groups
4. **Complete**: Merge results, assign GroupID, save to DB
5. **Clean**: Remove processed transactions

---

## Association Detection Criteria

### Multi-Criteria Detection

| Criterion | Description | Configuration |
|-----------|-------------|---------------|
| **Device** | Same DeviceID | `DeviceSports` (sport IDs) |
| **AI** | AI model pattern | `AISports` (sport IDs) |
| **IP** | Same IP address | `IPSports` (sport IDs) |
| **3 Matches Last 7 Days** | Bet together 3+ times | `_3MatchesLast7DaysSports` |
| **IP Last 3 Days** | Same IP in 3 days | `IPLast3DaysSports` |

### Sport-Specific Configuration
Different sports can use different detection criteria based on `SportType`.

**Example**:
```json
{
  "DeviceSports": "1,2,3,4,5",      // Soccer, Basketball, etc.
  "AISports": "1,2,3,4,5",
  "IPSports": "1,2,3,4,5",
  "3MatchesLast7DaysSports": "1,2,3,4,5",
  "IPLast3DaysSports": "1,2,3,4,5"
}
```

---

## Design Patterns

### 1. Fluent Interface Pattern
Chaining methods for readable code flow:
```csharp
_serviceProvider.GetService<IMatchMonitorStagingService>()
    .Start(batchSize, isLive)
    .GetLastScannedSequenceID()
    .GetMatchTrans()
    .InsertMatchMonitorStagingWithParallel()
    .UpdateLastScannedSequenceID();
```

### 2. Strategy Pattern
Different rules implement common interface:
```csharp
public interface IMatchMonitorRuleProcessService<T>
{
    IMatchMonitorRuleProcessService PrepareProcess(T matchStaging, bool isLive, ...);
    IMatchMonitorRuleProcessService ProcessRound1();
    IMatchMonitorRuleProcessService ProcessRound2();
    IMatchMonitorRuleProcessService Complete(ulong maxSequenceID);
    void WriteLogSentryIfError(string functionName);
}
```

### 3. Parallel Processing
Using PLINQ for performance:
```csharp
matchMonitorRule.MatchStagingList
    .AsParallel()
    .WithDegreeOfParallelism(numberOfThread)
    .ForAll(matchInfo => { ... });
```

---

## Performance Considerations

- **Batch Processing**: Configurable batch size for staging
- **Parallel Processing**: Multi-threaded match processing
- **2-Round Detection**: Ensures high accuracy without missing fraud
- **Incremental Scanning**: Uses SequenceID to track progress
- **Clean-up**: Regular deletion of old processed data

---

## Error Handling

- **Sentry Logging**: All errors logged to Sentry
- **Aggregate Exception Handling**: For parallel processing errors
- **Service Name**: "MatchMonitor Service"
- **Function Names**: Specific per operation for tracking

---

## Related Documentation

- [Match Monitor Analysis](../../ANALYSIS_MatchMonitor.md) - Comprehensive analysis
- [Match Monitor Controller](../../../fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS.JobService/Controllers/MatchMonitorController.cs)
- [Association Detection](../../General/AssociationDetection/)

---

## Online Viewer
- PlantUML Online: http://www.plantuml.com/plantuml/uml/
- VS Code Extension: PlantUML

---

## Notes
- This is the **SPU.CTS** version (detection/staging)
- Different from **SPU.CTS.CC** version (classification)
- Focus on **Group Betting Rule** specifically
- Part of larger Match Monitor system with 7+ rules

---

**Version**: 1.0  
**Last Updated**: 2024-11-19  
**Author**: CTS Analysis Team

