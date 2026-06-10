# Daily Dangerous Classification - Diagrams

## Overview
This document contains diagrams for the **Daily Dangerous Classification** flow, which processes customers with dangerous scores detected by AI/ML system and classifies them as Problem Accounts.

## Flow Description
The Daily Dangerous Classification job:
1. Gets dangerous customers from DangerousDetection table (AI/ML detected)
2. Transforms dangerous customers to PA classification entities
3. Inserts as Problem Account classification
4. Pushes classification to MainDB (External)
5. Updates system parameters (pagination tracking)
6. Repeats in do-while loop until all processed

This job processes customers that were identified as **dangerous** by the **AI/ML Detection System** based on dangerous score thresholds.

## Diagrams

### 01_MainFlow.puml
**Main Business Flow Diagram**
- Shows the overall flow from job trigger to completion
- Illustrates do-while loop with pagination
- Details separate processing for Licensee vs Credit

### 02_Sequence.puml
**Sequence Diagram**
- Shows the interaction between components
- Details the sequence of method calls
- Shows pagination and external push

### 03_DatabaseFlow.puml
**Database Flow Diagram**
- Shows all database operations and stored procedures
- Illustrates the flow between DataCenter (MySQL) and VR2 (SQL Server)
- Details the batch processing and external push

### 04_SP_GetDangerousDetection_Detailed.puml
**Stored Procedure: GetDangerousDetection Detailed Flow**
- Details the logic of `CTS_DC_DangerousDetection_GetLatest`
- Shows how dangerous customers are retrieved with pagination
- Illustrates dangerous score based filtering

## Key Components

### JobService
- `DailyDangerousClassificationJobService`: Orchestrates the job execution
- Do-while loop with pagination
- Separate processing for Licensee vs Credit customers

### Service Layer
- `DailyDangerousClassificationService`: Business logic layer
- Extends `ProblemAccountServices` (inheritance)
- Methods:
  - `GetDangerousClassification(isLicensee)`: Get dangerous customers
  - `InsertDangerousClassification()`: Insert PA classification and push to MainDB

### Data Access Layer
- `DailyDangerousClassificationDataAccess`: Database access layer
- Calls stored procedures:
  - `CTS_DC_DangerousDetection_GetLatest`

### External Services
- `ProblemAccountServices`: PA classification insertion (inherited)
- `CustClassToMainDBService`: Push to MainDB (External)

### System Parameters (Pagination)
**For Licensee (Deposit) Customers**:
- `DangerousScoreClassification_Deposit_LastCustID`: Last processed CustID
- `DangerousScoreClassification_Deposit_LastScannedDate`: Last scanned date

**For Credit Customers**:
- `DangerousScoreClassification_Credit_LastCustID`: Last processed CustID
- `DangerousScoreClassification_Credit_LastScannedDate`: Last scanned date

## Stored Procedures

### CTS_DC_DangerousDetection_GetLatest
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Get customers with dangerous scores (AI/ML detected)
**Parameters**:
- `@ip_IsLicensee` (bool): Filter for Licensee vs Credit customers
**Returns**: Multiple result sets
1. **First Result Set**: DangerousToCCLastScannedEntity
   - LastScannedDate (DateTime?)
   - LastCustID (long)
2. **Second Result Set**: DangerousToCCEntity[]
   - CustID (long)
   - CTSCustID (int)
   - SubscriberID (int)
   - RoleID (int)
   - CategoryID (int)
   - CategoryGroup (int)
   - ClassifiedDate (DateTime)
   - ClassifiedScore (decimal)

**Logic**:
- Get from DangerousDetection table
- WHERE IsLicensee = @ip_IsLicensee
- AND CustID > LastCustID (from system parameters)
- AND ClassifiedDate > LastScannedDate
- Dangerous score above threshold
- ORDER BY CustID
- LIMIT (batch size, e.g., 10000)
- Return LastCustID and LastScannedDate for pagination

## Data Model

### DangerousToCCEntity
```csharp
public class DangerousToCCEntity
{
    public long CustID { get; set; }
    public int CTSCustID { get; set; }
    public int SubscriberID { get; set; }
    public int RoleID { get; set; }
    public int CategoryID { get; set; }         // PA category
    public int CategoryGroup { get; set; }      // PA group
    public DateTime ClassifiedDate { get; set; }
    public decimal ClassifiedScore { get; set; } // Dangerous score
}
```

### DangerousToCCLastScannedEntity
```csharp
public class DangerousToCCLastScannedEntity
{
    public DateTime? LastScannedDate { get; set; }
    public long LastCustID { get; set; }
}
```

### DangerousToCCModel
```csharp
public class DangerousToCCModel
{
    public DangerousToCCLastScannedEntity DangerousCCLastScanned { get; set; }
    public IEnumerable<DangerousToCCEntity> DangerousCCs { get; set; }
}
```

### InsertProblemAccountEntity (Transformation)
```csharp
public class InsertProblemAccountEntity
{
    public long CustID { get; set; }
    public int CTSCustID { get; set; }
    public int RoleID { get; set; }
    public int SubscriberID { get; set; }
    public int CategoryID { get; set; }
    public int CategoryGroupID { get; set; }
    public bool IsLicensee { get; set; }
    public int CreatedBy { get; set; }          // StarixITId
    public string Remark { get; set; }          // Empty
    public bool? IsMarkedDirectly { get; set; } // null
    public bool IsFromAI { get; set; }          // true ⭐
    public bool IsFromCTS { get; set; }         // false
    public bool IsFromTVS { get; set; }         // false
    public bool IsFromTW { get; set; }          // false
}
```

## API Endpoint
- **POST** `/api/classificationJobs/scanningDailyDangerousClassification`
- **Parameters**:
  - `batchSize` (int): Batch size for external push
  - `isLicensee` (bool): Process Licensee or Credit customers

## Key Features

### Dangerous Score Based Classification
- Customers detected by AI/ML system
- Based on dangerous score thresholds
- Automated classification (IsFromAI = true)
- High-risk customer identification

### Separate Processing: Licensee vs Credit
- **Licensee (Deposit)**: isLicensee = true
  - System parameters: Deposit_LastCustID, Deposit_LastScannedDate
  - Deposit-based customer processing
- **Credit**: isLicensee = false
  - System parameters: Credit_LastCustID, Credit_LastScannedDate
  - Credit-based customer processing
- Separate pagination tracking for each type

### Do-While Loop with Pagination
```csharp
do {
    dangerousCCs = GetDangerousClassification(isLicensee);
    isContinue = (LastCustID > 0);
    
    if (isContinue) {
        InsertDangerousClassification();
        UpdateSystemParameters(LastCustID, LastScannedDate);
    }
} while (isContinue);
```

### Data Transformation
- **Source**: DangerousToCCEntity (from AI detection)
- **Target**: InsertProblemAccountEntity (PA classification)
- Transformation mapping:
  - CustID → CustID
  - CTSCustID → CTSCustID
  - CategoryID → CategoryID (PA category)
  - **IsFromAI = true** (flagged as AI-detected)
  - CreatedBy = StarixITId
  - Other flags = false

### Multiple Result Sets
- **First Result Set**: Pagination info (LastCustID, LastScannedDate)
- **Second Result Set**: Dangerous customers to process
- Efficient single SP call for both

### Batch Processing
- Chunk by `externalBatchSize`
- Process each chunk:
  1. Insert PA classification
  2. Push to MainDB
- Batch push optimizes external API calls

### External Push to MainDB
- Push after each chunk insertion
- Makes dangerous classification visible to external systems
- Parameters:
  - RoleGroup: Member
  - ExternalBatchSize
  - IsUpdateDangerToMainDB: true

### AI/ML Integration
- **IsFromAI = true**: Marks as AI-detected
- Source: AI/ML Dangerous Detection System
- Automated classification based on ML models
- No manual intervention required

### Inheritance from ProblemAccountServices
- Extends `ProblemAccountServices`
- Reuses `InsertProblemAccountPackage()` method
- Consistent PA insertion logic
- Code reuse and maintainability

## Performance Considerations

### Batch Size
- Configurable batch size for external push
- Typical: 5000-10000 per batch
- Balance between throughput and memory

### Pagination
- Dual pagination: LastCustID + LastScannedDate
- Persistent system parameters
- Resumable processing
- No risk of re-processing

### Timeout Settings
- GetDangerousDetection: Default (300s)
- Insert PA: Default (300s)
- External push: Batched for efficiency

## Flow Summary

1. **Trigger**: HTTP POST to `/api/classificationJobs/scanningDailyDangerousClassification`
2. **Parameters**: batchSize, isLicensee (Deposit or Credit)
3. **Do-While Loop**:
   a. **Get Dangerous Classification**:
      - From DangerousDetection table
      - Filter by isLicensee
      - Use LastCustID and LastScannedDate for pagination
      - AI/ML detected customers with dangerous scores
   b. **Check Continue**: If LastCustID > 0
   c. **Transform Data**:
      - DangerousToCCEntity → InsertProblemAccountEntity
      - Set IsFromAI = true
      - Set CreatedBy = StarixITId
   d. **Batch Processing**:
      - Chunk by externalBatchSize
      - For each chunk:
        * **Insert PA Classification**: Via InsertProblemAccountPackage
        * **Push to MainDB**: External visibility
   e. **Update System Parameters**:
      - Set LastCustID (Deposit or Credit)
      - Set LastScannedDate (Deposit or Credit)
4. **Loop**: Continue if more dangerous customers exist
5. **Complete**: All dangerous customers processed

## Dangerous Classification Flow

```
┌─────────────────────────────────────────────────────────────┐
│          Daily Dangerous Classification                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   AI/ML Detection System    │
        │   Calculates Dangerous Score│
        └──────────────┬──────────────┘
                       │
        ┌──────────────┴──────────────────────────┐
        │   Store in DangerousDetection Table     │
        │   (ClassifiedScore, ClassifiedDate)     │
        └──────────────┬──────────────────────────┘
                       │
        ┌──────────────┴──────────────────┐
        │   Get Dangerous Customers       │
        │   (Licensee or Credit)          │
        │   Filter: CustID > LastCustID   │
        └──────────────┬──────────────────┘
                       │
        ┌──────────────┴──────────────────────────┐
        │   Transform to PA Entity                │
        │   IsFromAI = true ⭐                    │
        └──────────────┬──────────────────────────┘
                       │
        ┌──────────────┴──────────────────────────┐
        │   Batch Processing (Chunk)              │
        ├─────────────────────────────────────────┤
        │   For Each Chunk:                       │
        │   1. Insert PA Classification           │
        │   2. Push to MainDB (External)          │
        └──────────────┬──────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   Update System Parameters  │
        │   - LastCustID              │
        │   - LastScannedDate         │
        └──────────────┬──────────────┘
                       │
                 More dangerous?
                       │
                 Yes → Loop
                 No  → Done
```

## Integration Points

### Upstream (Data Source)
- **AI/ML Dangerous Detection System**: Calculates dangerous scores
- **DangerousDetection Table**: Stores dangerous classifications

### Downstream (Classification Storage)
- **CTSCustomerClassification**: Stores PA classification
- **MainDB**: Receives dangerous classification updates (external visibility)

### Related Jobs
- **DailyProblemClassification**: Processes PA from other sources
- **ProbationClassification**: Re-classifies PA during probation
- **DailyRobotClassification**: Processes robot customers

## Notes
- This job is **consumer** of AI/ML Detection System output
- Dangerous score based classification
- Automated AI/ML detection (IsFromAI = true)
- Separate processing for Licensee vs Credit
- Dual pagination: LastCustID + LastScannedDate
- Do-while loop (similar to ProbationClassification)
- Batch processing with external push
- Inheritance from ProblemAccountServices

## Comparison with Other Classification Jobs

| Aspect | Daily Problem | Probation | Daily Dangerous |
|--------|---------------|-----------|-----------------|
| **Source** | DailyPAQueue | CTSCustomerClassification | DangerousDetection (AI) ⭐ |
| **Detection** | Manual rules | Re-classification | AI/ML automated ⭐ |
| **IsFromAI** | false | false | true ⭐ |
| **Customer Type** | Licensee+Credit | Mixed | Separate runs ⭐ |
| **Loop Type** | Recursive | Do-While | Do-While |
| **Pagination** | Queue-based | System Params | System Params (dual) ⭐ |
| **External Push** | Yes | No | Yes |
| **Complexity** | High | Medium | Medium |

## Dangerous Score System

### What is Dangerous Score?
- **AI/ML Calculated**: Machine learning model output
- **Range**: Typically 0-100 (higher = more dangerous)
- **Thresholds**: Configurable (e.g., > 70 = dangerous)
- **Factors**:
  - Betting patterns
  - Win/loss trends
  - Transaction patterns
  - Account behavior
  - Historical data
  - Risk indicators

### Classification Logic
```
Dangerous Score Calculation (AI/ML):
├─ Betting Pattern Analysis (30%)
│  ├─ Frequency anomalies
│  ├─ Amount anomalies
│  └─ Timing patterns
├─ Win/Loss Analysis (25%)
│  ├─ Unusual win rates
│  ├─ Suspicious patterns
│  └─ Profit trends
├─ Transaction Analysis (25%)
│  ├─ Deposit/withdrawal patterns
│  ├─ Payment method usage
│  └─ Transaction velocity
└─ Behavioral Analysis (20%)
   ├─ Login patterns
   ├─ Device changes
   └─ Location changes

If DangerousScore > Threshold:
    → Insert into DangerousDetection
    → Processed by DailyDangerousClassification
    → Classified as PA
    → Push to MainDB
```

## System Parameters Structure

### Licensee (Deposit) Customers
- **Key**: `DangerousScoreClassification_Deposit_LastCustID`
- **Value**: Last processed CustID (long)
- **Key**: `DangerousScoreClassification_Deposit_LastScannedDate`
- **Value**: Last scanned date (DateTime)

### Credit Customers
- **Key**: `DangerousScoreClassification_Credit_LastCustID`
- **Value**: Last processed CustID (long)
- **Key**: `DangerousScoreClassification_Credit_LastScannedDate`
- **Value**: Last scanned date (DateTime)

### Usage
- Independent pagination for Licensee and Credit
- Separate job runs for each customer type
- Each run updates only its own parameters

## Online Viewer
http://www.plantuml.com/plantuml/uml/

