# Match Monitor Classification (General)

## 📄 Overview

**Match Monitor Classification** is a general background job that detects and classifies customers involved in group betting and suspicious match betting patterns. Unlike the sport-specific version, this job performs cross-sport detection and maintains match status updates.

## 🎯 Purpose

- **Detect Group Betting**: Identify suspicious betting patterns across matches
- **Classify Customers**: Mark customers as Problem Account (PA) with specific CC categories
- **Update Match Status**: Sync match status from MainDB to CTS database
- **Push to External Systems**: Update customer classification to MainDB

## 🔄 Background Jobs

This feature consists of **2 separate jobs**:

### 1. Update Status Match Monitor (Maintenance Job)

**Endpoint**: `POST /api/classificationJobs/UpdateStatusMatchMonitor`

**Run Frequency**: Periodic (recommended: every 30 minutes)

**Purpose**: Update match status from MainDB to CTS

**Flow**:
```
1. Get Match IDs from CTSMatchMonitor (unfinished matches)
2. Get Match Info from MainDB (current status)
3. Update Match Status in CTSMatchMonitor
```

**Use Case**: Keep match status synchronized (Pre-match, Live, Closed)

---

### 2. Classify Match Monitor (Main Detection Job) ⭐

**Endpoint**: `POST /api/classificationJobs/ClassifyMatchMonitor`

**Run Frequency**: Every 5 minutes (high frequency)

**Purpose**: Detect fraud and classify customers

**Flow**:
```
1. Get ONE match to classify (FIFO queue)
2. Run detection rules → Get fraud tickets
3. Extract CustIDs from fraud tickets
4. Insert as Problem Account (PA)
5. Push customer classification to MainDB
6. Mark match as completed
7. Loop back to step 1
```

**Key Characteristics**:
- **One match at a time**: Processes matches sequentially
- **FIFO Queue**: First In, First Out order
- **Automatic retry**: Failed matches stay in queue
- **Push to MainDB**: Customer classification synced externally

## 📊 Data Flow

### Write Operations (Job → Database)

**Tables Written:**
1. **CTSCustomerClassification** - Customer CC status (UPDATE)
2. **CTSMatchMonitor** - Match status (UPDATE)
3. **CTSMatchMonitorDetail** - Mark as completed (UPDATE)
4. **MainDB (External)** - Customer classification (PUSH)

### Read Operations (Database → Job)

**Tables Read:**
1. **CTSMatchMonitor** - Get matches to process (SELECT)
2. **MainDB Match Tables** - Get match info (SELECT)

## 🔗 Related Components

### Data Dependencies

**This job WRITES data that is READ by:**
- [Match Monitor Page](../../Website/MatchMonitor/) - Web page displays detection results
- Other monitoring systems

**Related Background Jobs:**
- [MatchMonitorClassificationBySport](../../BySport/MatchMonitorClassificationBySport/) - Sport-specific detection
- [DailyProblemClassification](../DailyProblemClassification/) - Daily PA classification
- [DailyDangerousClassification](../DailyDangerousClassification/) - Dangerous customer detection

## 🗄️ Stored Procedures

### Main Classification Flow

#### 1. CTS_DC_CustClassification_MatchMonitor_Get
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Get list of match IDs that need processing  
**Returns**: List of MatchIDs (unfinished matches)

#### 2. CTS_MatchInfo_Get
**Database**: bodb_VR2Model (SQL Server)  
**Purpose**: Get match information from MainDB  
**Input**: MatchIDs (comma-separated)  
**Returns**: Match info (HomeName, AwayName, EventStatus, etc.)

#### 3. CTS_DC_CustClassification_MatchMonitor_UpdateMatch
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Update match status in CTS database  
**Input**: Match status JSON  
**Processing**: Update EventStatus for each match

#### 4. CTS_DC_CustClassification_MatchMonitor_Classify ⭐
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: **Main detection and classification logic**  
**Output**: Multiple result sets
- Result Set 1: `ClassifyGBMMCustInfosEntity[]` - Customers to classify
- Result Set 2: `string` - MMDetailIDs (comma-separated)
- Result Set 3: `int?` - MatchID (current match being processed)

**Key Logic**:
- Select ONE match from queue (FIFO)
- Run group betting detection rules
- Identify fraud tickets
- Extract customer info for classification
- Return CustIDs to insert as PA

#### 5. CTS_DC_CustClassification_MatchMonitor_Completed
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Mark match as completed  
**Input**:
- `ip_MatchID` - Match that was processed
- `ip_MMDetailsIDList` - Fraud ticket IDs (comma-separated)

**Processing**: Update IsProcessed flag for completed tickets

## 💡 Key Concepts

### Customer Classification (CC)

When fraud is detected:
1. **Match** has multiple tickets (bets)
2. **Detection rules** identify suspicious patterns
3. **CustIDs** from fraud tickets are extracted
4. **Customers** are marked as **CC (Problem Account)**
5. **Specific CC category** is assigned (e.g., "Group Betting")

### Match Processing Queue

- Matches are processed **one at a time**
- **FIFO order**: First detected → First processed
- **Automatic retry**: Failed matches stay in queue
- **Completion tracking**: Processed matches marked as done

## 🔄 Complete Flow

### Job 1: Update Status Match Monitor

```
┌─────────────────────────────────────────┐
│ 1. Get Match IDs                        │
│    SP: CTS_DC_CustClassification_       │
│        MatchMonitor_Get                 │
│    Returns: [12345, 67890, ...]         │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│ 2. Get Match Info from MainDB           │
│    SP: CTS_MatchInfo_Get                │
│    Input: "12345,67890,..."             │
│    Returns: Match details with status   │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│ 3. Update Match Status in CTS           │
│    SP: CTS_DC_CustClassification_       │
│        MatchMonitor_UpdateMatch         │
│    Update EventStatus for each match    │
└─────────────────────────────────────────┘
```

### Job 2: Classify Match Monitor ⭐

```
┌─────────────────────────────────────────┐
│ 1. Classify ONE Match                   │
│    SP: CTS_DC_CustClassification_       │
│        MatchMonitor_Classify            │
│    Returns:                             │
│    - CustInfos[] (customers to classify)│
│    - MMDetailIDs (fraud tickets)        │
│    - MatchID (current match)            │
└────────────┬────────────────────────────┘
             │
             ▼
        ┌────┴────┐
        │ If has  │
        │ CustInfos?
        └────┬────┘
             │ YES
             ▼
┌─────────────────────────────────────────┐
│ 2. Insert Problem Account               │
│    - Convert to InsertProblemAccount    │
│    - FunctionId: ClassifyGBMatchMonitor │
│    - CCInputFlow: InsertPACategory      │
│    Returns: Inserted CustIDs            │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│ 3. Push to MainDB                       │
│    - Push customer classification       │
│    - ExternalBatchSize: 500             │
│    - IsUpdateDangerToMainDB: true       │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│ 4. Mark Match as Completed              │
│    SP: CTS_DC_CustClassification_       │
│        MatchMonitor_Completed           │
│    Input: MatchID, MMDetailIDs          │
│    Update IsProcessed = 1               │
└─────────────────────────────────────────┘
```

## 📝 Key Differences: BySport vs General

| Aspect | BySport | General |
|--------|---------|---------|
| **Scope** | Single sport per run | Cross-sport |
| **Batch Size** | Configurable | Fixed (500) |
| **Processing** | Multiple matches | One match at a time |
| **Update Match Status** | No | Yes (separate job) |
| **Detection Logic** | Sport-specific rules | General rules |

## 🚀 Technology Stack

- **Framework**: .NET Core 6.0+
- **Database**: MySQL (CTS_DataCenter) + SQL Server (bodb_VR2Model)
- **Pattern**: Fluent Interface (Chain of Responsibility)
- **External Push**: MainDB sync
- **Logging**: Sentry error logging

## 📊 Performance Considerations

- **One match at a time**: Prevents database overload
- **Batch size**: 500 for external push
- **High frequency**: Every 5 minutes for real-time detection
- **Error handling**: Automatic retry for failed matches
- **Logging**: Track all classification actions

## 🔍 Monitoring

**Key Metrics**:
- Matches processed per run
- Customers classified per match
- External push success rate
- Match completion rate

**Logs**:
- Service name: "Match Monitor Classication" [sic]
- Error logging: Sentry
- Function ID: ClassifyGBMatchMonitor

## 📖 Diagrams

1. [Main Flow](puml/MatchMonitorClassification_Diagrams_01_MainFlow.puml) - Overall job flow (2 jobs)
2. [Sequence Diagram](puml/MatchMonitorClassification_Diagrams_02_Sequence.puml) - Detailed interactions
3. [Database Flow](puml/MatchMonitorClassification_Diagrams_03_DatabaseFlow.puml) - Database operations
4. [SP Get Matches](puml/MatchMonitorClassification_Diagrams_04_SP_GetMatches_Detailed.puml) - Get match list
5. [SP Classify](puml/MatchMonitorClassification_Diagrams_05_SP_Classify_Detailed.puml) - Main classification logic
6. [SP Completed](puml/MatchMonitorClassification_Diagrams_06_SP_Completed_Detailed.puml) - Mark as done

## 🔗 Cross-References

### Related to:
- **Website**: [Match Monitor Page](../../Website/MatchMonitor/) - Displays detection results
- **BySport**: [MatchMonitorClassificationBySport](../../BySport/MatchMonitorClassificationBySport/) - Sport-specific version
- **General**: [DailyProblemClassification](../DailyProblemClassification/) - Related PA classification

### Tables Used:
- `CTSMatchMonitor` - Match detection data
- `CTSMatchMonitorDetail` - Fraud ticket details
- `CTSCustomerClassification` - Customer CC status
- `MainDB Match Tables` - Match master data

## 📌 Notes

- **General vs BySport**: This is the general version without sport-specific logic
- **Sequential Processing**: One match at a time ensures stability
- **External Sync**: All customer classifications pushed to MainDB
- **Queue Management**: Automatic FIFO queue with retry
- **Typo in code**: Service name has typo "Classication" (missing 'i')

