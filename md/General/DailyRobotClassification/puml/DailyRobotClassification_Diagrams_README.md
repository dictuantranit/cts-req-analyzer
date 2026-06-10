# Daily Robot Classification - Diagrams

## Overview
This document contains diagrams for the **Daily Robot Classification** flows, which processes Robot/AI-controlled customers detected by multiple detection systems and classifies them as Problem Accounts.

## Flow Description
The Daily Robot Classification job consists of **TWO SEPARATE FLOWS**:

### 1. AI Robot Detection Flow (robotAIDetection)
- Gets robot customers from AI/ML Robot Detection system
- Based on RobotDetection table (AI/ML output)
- Pagination using RobotDetectionID
- Automated detection (AI/ML models)

### 2. TW Robot Flow (robotTWClassification)
- Gets robot customers from TW (Taiwan) system
- Based on time-based scanning
- Uses timespan for filtering
- Manual/rule-based detection from TW system

Both flows:
1. Get robot customers from respective sources
2. Transform to PA classification entities
3. Insert as Problem Account (Robot category)
4. Push classification to MainDB (External)
5. Update system parameters/timespan

## Diagrams

### 01_AIRobot_MainFlow.puml
**AI Robot Detection Main Flow**
- Shows the AI Robot Detection flow from trigger to completion
- Illustrates pagination with RobotDetectionID
- Details the AI/ML integration

### 02_AIRobot_Sequence.puml
**AI Robot Detection Sequence Diagram**
- Shows the interaction between components for AI Robot
- Details the sequence of method calls
- Shows AI detection source

### 03_TWRobot_MainFlow.puml
**TW Robot Main Flow**
- Shows the TW Robot flow from trigger to completion
- Illustrates timespan-based processing
- Details the TW system integration

### 04_TWRobot_Sequence.puml
**TW Robot Sequence Diagram**
- Shows the interaction between components for TW Robot
- Details the sequence of method calls
- Shows TW system source

### 05_DatabaseFlow.puml
**Database Flow Diagram (Both Flows)**
- Shows all database operations and stored procedures
- Illustrates the flow for both AI and TW Robots
- Details the batch processing and external push

### 06_SP_AIRobotDetection_Detailed.puml
**Stored Procedure: AI Robot Detection Detailed Flow**
- Details the logic of `CTS_DC_RobotDetection_GetLatest`
- Shows how AI robots are retrieved with pagination
- Illustrates AI/ML detection source

### 07_SP_TWRobotList_Detailed.puml
**Stored Procedure: TW Robot List Detailed Flow**
- Details the logic of `CTS_Customer_RobotListSel`
- Shows how TW robots are retrieved by timespan
- Illustrates TW system integration

## Key Components

### JobService
- `RobotAccountInsertJobService`: Orchestrates BOTH robot flows
- Methods:
  - `ScanningAIRobotClassification()`: AI Robot Detection flow
  - `ScanningTWRobotAccount()`: TW Robot flow

### Service Layer (AI Robot)
- `RobotAIDetectionService`: Business logic for AI robot detection
- Extends `ProblemAccountServices` (inheritance)
- Methods:
  - `Start()`: Initialize
  - `GetRobotDetections()`: Get AI-detected robots
  - `InsertAIRobotPackage()`: Insert robot PA classification
  - `UpdateLastScannedId()`: Update pagination parameter

### Service Layer (TW Robot)
- `RobotTWInsertServices`: Business logic for TW robot detection
- Methods:
  - `Start()`: Initialize
  - `GetLastTimespan()`: Get last scan timespan
  - `GetTWRobotUser()`: Get TW robot customers
  - `GetCustomerRole()`: Get customer role info
  - `GetRobotUserCategoryId()`: Get robot category
  - `InsertTWRobotPackage()`: Insert robot PA classification
  - `UpdateLastTimespan()`: Update timespan parameter

### Data Access Layer
- `RobotAIDetectionDataAccess`: AI robot data access
  - `GetRobotDetections()`: Query AI robot detection table
- `RobotTWInsertDataAccess`: TW robot data access
  - `GetTWRobotUser()`: Query TW robot list

### External Services
- `ProblemAccountServices`: PA classification insertion (inherited)
- `CustClassToMainDBService`: Push to MainDB (External)

### System Parameters
**For AI Robot**:
- `RobotDetection_LastID`: Last processed RobotDetectionID

**For TW Robot**:
- Timespan-based (stored in service state)
- Not persisted in system parameters

## Stored Procedures

### CTS_DC_RobotDetection_GetLatest (AI Robot)
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Get AI-detected robot customers
**Parameters**:
- `@ip_RobotDetectionLastID` (long): Last processed RobotDetectionID
**Returns**: RobotAIEntity[]
- RobotDetectionID (long)
- CustID (long)
- CategoryID (int) - Robot category
- LastModifiedDate (DateTime)
**Logic**:
- Get from RobotDetection table
- WHERE RobotDetectionID > @ip_RobotDetectionLastID
- ORDER BY RobotDetectionID
- LIMIT (batch size)
**Pagination**: Uses RobotDetectionID (incremental ID)

### CTS_Customer_RobotListSel (TW Robot)
**Database**: ON_USER (SQL Server)
**Purpose**: Get TW system robot customers
**Timeout**: 900 seconds (15 minutes)
**Parameters**: Timespan (date range)
**Returns**: TWRobotUserEntity[]
- CustID (long)
- RoleID (int)
- Other customer info
**Logic**:
- Get from TW Robot detection system
- Filter by timespan (recent period)
- Robot detection rules from TW
**Pagination**: Time-based (not ID-based)

## Data Model

### RobotAIEntity (AI Robot)
```csharp
public class RobotAIEntity
{
    public long RobotDetectionID { get; set; }  // For pagination
    public long CustID { get; set; }
    public int CategoryID { get; set; }         // Robot category
    public DateTime LastModifiedDate { get; set; }
}
```

### TWRobotUserEntity (TW Robot)
```csharp
public class TWRobotUserEntity
{
    public long CustID { get; set; }
    public int RoleID { get; set; }
    // ... other customer info
}
```

### InsertProblemAccountEntity (Transformation for both)
```csharp
public class InsertProblemAccountEntity
{
    public long CustID { get; set; }
    public int CategoryID { get; set; }         // Robot category
    public int CategoryGroupID { get; set; }
    public int RoleID { get; set; }
    public bool IsLicensee { get; set; }
    public int CreatedBy { get; set; }          // StarixITId
    // Robot-specific flags (set during transformation)
}
```

## API Endpoints

### AI Robot Detection
- **POST** `/api/classificationJobs/robotAIDetection`
- **Parameters**:
  - `batchExternalSize` (int): Batch size for external push
  - `batchInternalSize` (int): Batch size for PA insertion

### TW Robot
- **POST** `/api/classificationJobs/robotTWClassification`
- **Parameters**:
  - `batchExternalSize` (int): Batch size for external push
  - `batchInternalSize` (int): Batch size for PA insertion

## Key Features

### Two Separate Robot Detection Systems ⭐⭐⭐

#### AI Robot Detection
- **Source**: AI/ML Robot Detection System
- **Detection**: Automated AI/ML models
- **Pagination**: RobotDetectionID (incremental)
- **Database**: CTS_DataCenter (MySQL)
- **Characteristics**:
  - Continuous AI monitoring
  - ML model predictions
  - Pattern-based detection
  - High accuracy

#### TW Robot
- **Source**: TW (Taiwan) System
- **Detection**: Manual/rule-based from TW
- **Pagination**: Timespan-based
- **Database**: ON_USER (SQL Server)
- **Timeout**: 900 seconds (15 minutes)
- **Characteristics**:
  - TW system integration
  - Time-window scanning
  - Rule-based detection
  - Regional focus (Taiwan)

### Fluent Interface (Chain of Responsibility) ⭐
**AI Robot**:
```csharp
robotDetectionService.Start()
    .GetRobotDetections(lastID)
    .InsertAIRobotPackage(batchSize, pushConfig);
```

**TW Robot**:
```csharp
robotAccountInsertServices.Start()
    .GetLastTimespan()
    .GetTWRobotUser()
    .GetCustomerRole()
    .GetRobotUserCategoryId()
    .InsertTWRobotPackage(batchSize, apiUrl, pushConfig);
```

### Batch Processing with Sleep ⭐
```csharp
foreach (var robotChunk in robotDetectionChunks)
{
    InsertProblemAccountPackage(robotChunk);
    PushExternalPackageByCustId(custIds);
    Thread.Sleep(RobotUsers_SleepTimes);  // Throttling ⭐
}
```
- Prevents overwhelming system
- Throttle between batches
- Smooth processing

### Inheritance from ProblemAccountServices ⭐
- Both services extend `ProblemAccountServices`
- Reuses `InsertProblemAccountPackage()` method
- Consistent robot PA insertion logic
- Code reuse and maintainability

### External Push to MainDB
- Push after each chunk insertion
- Makes robot classification visible to external systems
- Parameters:
  - RoleGroup: Member
  - IsUpdateDangerToMainDB: true
  - IsSyncAFCData: false (no AFC sync for robots)

### Different Pagination Strategies ⭐

**AI Robot** (ID-based):
- Uses RobotDetectionID
- Incremental pagination
- WHERE RobotDetectionID > @LastID
- Persistent system parameter

**TW Robot** (Time-based):
- Uses timespan
- Time-window scanning
- Recent period filtering
- Service state (not persisted)

### Robot Category Classification
- CategoryID: Robot-specific category
- CategoryGroupID: Robot group
- Special handling for robot customers
- Different from regular PA classification

## Performance Considerations

### Batch Sizes
**AI Robot**:
- Internal batch: Configurable (e.g., 5000)
- External batch: Configurable (e.g., 1000)
- Sleep between chunks: RobotUsers_SleepTimes

**TW Robot**:
- Internal batch: Configurable
- External batch: Configurable
- Sleep between chunks: RobotUsers_SleepTimes
- Long timeout: 900 seconds (15 min)

### Throttling
- `Thread.Sleep()` between chunks
- Prevents database/API overload
- Smooth processing

### Pagination Efficiency
- **AI**: Incremental ID (fast, reliable)
- **TW**: Timespan (flexible, time-based)

## Flow Summary

### AI Robot Detection Flow
1. **Trigger**: POST `/api/classificationJobs/robotAIDetection`
2. **Start**: Initialize service
3. **Get Robots**: From RobotDetection table
   - WHERE RobotDetectionID > LastID
   - AI/ML detected robots
4. **Batch Processing**:
   - Chunk by internalSize
   - For each chunk:
     a. Transform to InsertProblemAccountEntity
     b. Insert PA classification (Robot category)
     c. Push to MainDB
     d. Sleep (throttle)
5. **Update Parameter**: Set RobotDetection_LastID
6. **Complete**: All AI robots processed

### TW Robot Flow
1. **Trigger**: POST `/api/classificationJobs/robotTWClassification`
2. **Start**: Initialize service
3. **Get Timespan**: Get last scan timespan
4. **Get TW Robots**: From TW system
   - Filter by timespan
   - TW system detected robots
5. **Get Customer Role**: Fetch customer role info
6. **Get Robot Category**: Determine robot category
7. **Batch Processing**:
   - Chunk by internalSize
   - For each chunk:
     a. Transform to InsertProblemAccountEntity
     b. Insert PA classification (Robot category)
     c. Push to MainDB
     d. Sleep (throttle)
8. **Update Timespan**: Set last scan timespan
9. **Complete**: All TW robots processed

## Robot Detection Systems Comparison

```
┌─────────────────────────────────────────────────────────────┐
│              Robot Detection Systems                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
   AI Robot Detection           TW Robot System
        │                             │
        ↓                             ↓
┌───────────────────┐         ┌───────────────────┐
│ AI/ML Models      │         │ TW Rule-Based     │
│ - Pattern Analysis│         │ - Taiwan System   │
│ - Automated       │         │ - Manual Rules    │
│ - Continuous      │         │ - Regional Focus  │
└─────────┬─────────┘         └─────────┬─────────┘
          │                             │
          ↓                             ↓
   RobotDetection Table          TW Robot Database
          │                             │
          ↓                             ↓
   ID-based Pagination           Time-based Scanning
          │                             │
          ↓                             ↓
   Insert Robot PA               Insert Robot PA
          │                             │
          └──────────────┬──────────────┘
                         ↓
                  Push to MainDB
```

## Integration Points

### Upstream (Data Sources)
- **AI/ML Robot Detection System**: Automated robot detection (AI Robot)
- **TW System**: Taiwan-based robot detection (TW Robot)

### Data Storage
- **RobotDetection Table** (MySQL): Stores AI robot detections
- **TW Robot Database** (SQL Server): Stores TW robot detections

### Downstream (Classification Storage)
- **CTSCustomerClassification**: Stores robot PA classification
- **MainDB**: Receives robot classification updates (external visibility)

### Related Jobs
- **DailyDangerousClassification**: Processes dangerous customers (AI-detected)
- **DailyProblemClassification**: Processes PA customers
- **ProbationClassification**: Re-classifies PA during probation

## Notes
- This job has **TWO SEPARATE FLOWS** for different robot sources
- **AI Robot**: Automated AI/ML detection (continuous, pattern-based)
- **TW Robot**: TW system detection (regional, rule-based)
- Both flows insert robot customers as PA classification
- Both push to MainDB for external visibility
- Different pagination strategies (ID vs Timespan)
- Inheritance from ProblemAccountServices
- Throttling with Thread.Sleep between batches
- No AFC sync for robot customers (IsSyncAFCData = false)

## Comparison: AI Robot vs TW Robot

| Aspect | AI Robot Detection | TW Robot |
|--------|-------------------|----------|
| **Source** | AI/ML Detection System | TW (Taiwan) System |
| **Detection** | Automated AI/ML | Manual/Rule-based |
| **Database** | CTS_DataCenter (MySQL) | ON_USER (SQL Server) |
| **Pagination** | RobotDetectionID (ID-based) | Timespan (Time-based) |
| **Timeout** | 300s (default) | 900s (15 min) |
| **System Param** | RobotDetection_LastID | Timespan (service state) |
| **Processing** | Incremental (from last ID) | Time-window (recent period) |
| **Characteristics** | Continuous monitoring | Regional focus |
| **Complexity** | Medium | Medium-High |
| **Flow Type** | Simple (3 steps) | Complex (5 steps) |

## Comparison with Other Classification Jobs

| Aspect | Daily Problem | Daily Dangerous | **AI Robot** | **TW Robot** |
|--------|---------------|-----------------|--------------|--------------|
| **Source** | DailyPAQueue | DangerousDetection | **RobotDetection** | **TW System** |
| **Detection** | Manual rules | AI (dangerous score) | **AI (robot patterns)** | **TW rules** |
| **Pagination** | Queue-based | System Params (dual) | **RobotDetectionID** | **Timespan** |
| **Loop Type** | Recursive | Do-While | **Simple (once)** | **Simple (once)** |
| **External Push** | Yes | Yes | Yes | Yes |
| **Inheritance** | No | Yes | **Yes** | **Yes** |
| **Throttling** | No | No | **Yes (Sleep)** | **Yes (Sleep)** |
| **Complexity** | High | Medium | Medium | Medium-High |

## Robot Detection Criteria

### AI Robot Detection
- **Betting Patterns**: Automated, repetitive patterns
- **Frequency**: High-frequency betting (> threshold)
- **Timing**: Consistent time intervals
- **Behavior**: Machine-like behavior
- **API Usage**: API-based betting (not UI)
- **Response Time**: Instant reactions
- **ML Model**: Pattern recognition algorithms

### TW Robot Detection
- **TW System Rules**: Taiwan-specific detection rules
- **Regional Behavior**: Taiwan market patterns
- **Manual Review**: Human-reviewed detection
- **Historical Data**: Taiwan customer history
- **Rule-Based**: Predefined rule matching

## Online Viewer
http://www.plantuml.com/plantuml/uml/

