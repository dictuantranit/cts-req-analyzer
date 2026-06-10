# Probation Classification - Diagrams

## Overview
This document contains diagrams for the **Probation Classification** flow, which processes customers in probation period to re-classify them based on their performance during probation.

## Flow Description
The Probation Classification job:
1. Gets customers in probation period from CTSCustomerClassification
2. Re-classifies these customers based on their updated performance
3. Updates system parameters to track progress (pagination)
4. Repeats in do-while loop until all probation customers processed

This job is a **follow-up** to **DailyProblemClassification**, processing PA/PotentialPA customers after their initial probation period to determine if their classification should change.

## Diagrams

### 01_MainFlow.puml
**Main Business Flow Diagram**
- Shows the overall flow from job trigger to completion
- Illustrates do-while loop with pagination
- Details the 3 main steps

### 02_Sequence.puml
**Sequence Diagram**
- Shows the interaction between components
- Details the sequence of method calls
- Shows pagination with system parameters

### 03_DatabaseFlow.puml
**Database Flow Diagram**
- Shows all database operations and stored procedures
- Illustrates the flow between DataCenter (MySQL) and VR2 (SQL Server)
- Details the pagination mechanism

### 04_SP_GetProbationScan_Detailed.puml
**Stored Procedure: GetProbationScan Detailed Flow**
- Details the logic of `CTS_DC_CustClassification_ProbationScan_Get`
- Shows how probation customers are retrieved with pagination
- Illustrates LastCustID and LastCategoryID tracking

### 05_SP_ProbationPreprocess_Detailed.puml
**Stored Procedure: ProbationPreprocess Detailed Flow**
- Details the logic of `CTS_GeneralNormalClassification_Probation_Preprocess`
- Shows how probation customers are re-classified
- Illustrates category changes and probation completion

## Key Components

### JobService
- `ProbationClassificationJobService`: Orchestrates the job execution
- Simple do-while loop with pagination

### Service Layer
- `ProbationClassificationServices`: Business logic layer
- Methods:
  - `Start()`: Initialize model
  - `GetProbationCustForScanning()`: Get probation customers with pagination
  - `ClassifyProbation()`: Re-classify probation customers
  - `UpdateLastScanDate()`: Update system parameters for pagination

### Data Access Layer
- `ProbationClassificationDataAccess`: Database access layer
- Calls stored procedures:
  - `CTS_DC_CustClassification_ProbationScan_Get`
  - `CTS_GeneralNormalClassification_Probation_Preprocess`

### System Parameters (Pagination)
- `DailyProbation_LastCustID`: Tracks last processed CustID
- `DailyProbation_LastCategoryID`: Tracks last processed CategoryID
- Used for pagination across job runs

## Stored Procedures

### CTS_DC_CustClassification_ProbationScan_Get
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Get customers in probation period
**Parameters**:
- `@ip_NoOfRecord` (int): Number of records to retrieve (batch size)
- `@op_LastCustID` (long): Output - Last processed CustID
- `@op_LastCategoryID` (int): Output - Last processed CategoryID
**Returns**: 
- CustId (long)
- SportGroupId (int)
**Logic**:
- Get customers from CTSCustomerClassification
- WHERE ProbationEndDate > NOW() (still in probation)
- AND CustID > LastCustID (pagination)
- ORDER BY CustID, CategoryID
- LIMIT @ip_NoOfRecord
- Return LastCustID and LastCategoryID for next batch
**Pagination**: Uses LastCustID and LastCategoryID from system parameters

### CTS_GeneralNormalClassification_Probation_Preprocess
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Re-classify probation customers
**Timeout**: 300 seconds (5 minutes)
**Parameters**:
- Customer list (comma-separated CustIDs)
**Logic**:
- Get customer performance since probation start
- Re-calculate classification based on:
  - Turnover during probation
  - Winloss during probation
  - BetCount during probation
  - ActiveDays during probation
  - Behavior changes
- Determine if classification should change:
  - PA → PotentialPA (improvement)
  - PA → Normal (significant improvement)
  - PotentialPA → PA (deterioration)
  - PotentialPA → Normal (improvement)
  - No change (maintain current category)
- Update CTSCustomerClassification with new category
- Complete probation if end date reached
- Set new probation period if still PA/PotentialPA

## Data Model

### ProbationEntity
```csharp
public class ProbationEntity
{
    public long CustId { get; set; }
    public int SportGroupId { get; set; }
}
```

### ProbationModel
```csharp
public class ProbationModel
{
    public IEnumerable<ProbationEntity> CustProbations { get; set; }
    public long LastCustID { get; set; }      // For pagination
    public int LastCategoryID { get; set; }   // For pagination
}
```

## API Endpoint
- **POST** `/api/classificationJobs/scanningProbationClassification`
- **Parameters**:
  - `batchSize` (int): Number of customers to process per batch

## Key Features

### Probation Period Review
- Customers placed in probation by **DailyProblemClassification**
- Review period: 15-30 days (depends on PA severity)
- Re-classification based on probation performance

### Pagination with System Parameters
- **LastCustID**: Tracks progress across batches
- **LastCategoryID**: Secondary pagination key
- Persisted in system parameters table
- Survives job restarts
- Enables resumable processing

### Do-While Loop
```csharp
do {
    GetProbationCustForScanning(batchSize);
    ClassifyProbation();
    isContinue = UpdateLastScanDate();
} while (isContinue);
```
- Continues until all probation customers processed
- No recursion (unlike DailyProblemClassification)
- Simple loop structure

### Re-Classification Logic
- **Improvement Path**:
  - PA → PotentialPA → Normal
  - Based on reduced losing behavior
  - Better betting patterns
- **Deterioration Path**:
  - Normal → PotentialPA → PA
  - Increased losing behavior
  - Worse betting patterns
- **Maintenance**:
  - Category unchanged if behavior stable
  - Extended probation if needed

### No External Push
- Unlike DailyProblemClassification, this job does NOT push to MainDB
- Classification changes are internal only
- External push happens in subsequent jobs

### Simple Processing
- No batch chunking (processes all in one go)
- No parallel processing
- Straightforward sequential flow

## Performance Considerations

### Batch Size
- Configurable batch size (typically 5000-10000)
- Pagination prevents memory overflow
- Balance between performance and resource usage

### System Parameters
- Persisted progress tracking
- Resume from last position if job interrupted
- No re-processing of completed customers

### Timeout Settings
- GetProbationScan: 300s (5 minutes)
- ProbationPreprocess: 300s (5 minutes)
- Shorter timeout than DailyProblemClassification

## Flow Summary

1. **Trigger**: HTTP POST to `/api/classificationJobs/scanningProbationClassification`
2. **Validate**: Check batchSize > 0
3. **Do-While Loop**:
   a. **Start**: Initialize ProbationModel
   b. **Get Probation Customers**: From CTSCustomerClassification
      - WHERE ProbationEndDate > NOW()
      - Use LastCustID/LastCategoryID for pagination
      - ORDER BY CustID, CategoryID
      - LIMIT batchSize
   c. **Classify Probation**: Re-classify customers
      - Convert CustIDs to comma-separated string
      - Call SP to re-calculate classification
      - Update CTSCustomerClassification with new category
   d. **Update Last Scan Date**: Update system parameters
      - Set DailyProbation_LastCustID
      - Set DailyProbation_LastCategoryID
      - Return isContinue flag
4. **Loop**: Continue if more probation customers exist
5. **Complete**: Exit when all processed

## Probation Re-Classification Rules

```
┌─────────────────────────────────────────────────────────────┐
│          Probation Re-Classification                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────────────────┐
        │   Get Probation Performance             │
        │   (Since ProbationStartDate)            │
        └──────────────┬──────────────────────────┘
                       │
        ┌──────────────┴──────────────────────────────┐
        │   Calculate Metrics During Probation        │
        │   - Turnover                                │
        │   - Winloss (loss amount)                   │
        │   - BetCount                                │
        │   - ActiveDays                              │
        │   - Behavior pattern changes                │
        └──────────────┬──────────────────────────────┘
                       │
              ┌────────┴────────┐
              │   PA Customer   │
              └────────┬────────┘
                       │
        ┌──────────────┴──────────────────────┐
        │   Check Performance Changes         │
        └──────────────┬──────────────────────┘
                       │
             ┌─────────┴─────────┐
             │                   │
         Improved          Maintained/Worse
             │                   │
             ↓                   ↓
     ┌───────────────┐   ┌───────────────┐
     │ Downgrade     │   │ Maintain PA   │
     │ PA → PotentialPA│ │ or Extend     │
     │ or PA → Normal│   │ Probation     │
     └───────────────┘   └───────────────┘
```

## Integration Points

### Upstream (Data Source)
- **DailyProblemClassification**: Creates PA customers with probation period
- **CTSCustomerClassification**: Stores probation dates

### Downstream (Classification Update)
- **CTSCustomerClassification**: Updates category after re-classification
- No external push (internal only)

### Related Jobs
- **DailyProblemClassification**: Initial PA classification (creates probation)
- **ProbationClassification**: This job (re-classifies during probation)
- **NormalAccountClassification**: Final classification (after probation)

## Notes
- This job is **consumer** of probation data created by DailyProblemClassification
- Processes customers during probation period
- Re-classifies based on probation performance
- Uses system parameters for pagination
- Simple do-while loop (no recursion)
- No external push (internal classification only)
- Shorter timeout than DailyProblemClassification

## Comparison with DailyProblemClassification

| Aspect | Daily Problem | Probation |
|--------|---------------|-----------|
| **Source** | DailyPAQueue | CTSCustomerClassification (Probation) |
| **Target** | Initial PA classification | Re-classification during probation |
| **Calculation** | Losing performance | Probation performance |
| **Logic Insert** | Yes (PA + Robot) | No |
| **External Push** | Yes (to MainDB) | No |
| **Loop Type** | Recursive | Do-While |
| **Pagination** | Queue-based | System Parameters |
| **Complexity** | High | Medium |
| **Timeout** | 1200s (20 min) | 300s (5 min) |
| **Purpose** | Identify new PA | Re-classify existing PA |

## Probation Lifecycle

```
1. Customer places bets → RealtimeClassification
                                  ↓
2. Identified as PA → DailyProblemClassification
                                  ↓
3. Insert PA Probation (ProbationStartDate, ProbationEndDate)
                                  ↓
4. During probation period → **ProbationClassification** (This Job)
                                  ↓
5. Re-classification based on probation performance
                                  ↓
6. Options:
   - Improved → PotentialPA or Normal
   - Maintained → Still PA (extend probation)
   - Deteriorated → Higher PA category
                                  ↓
7. End of probation → Final classification
```

## System Parameters Used

- **DailyProbation_LastCustID**: Last processed CustID (pagination)
- **DailyProbation_LastCategoryID**: Last processed CategoryID (pagination)
- Updated after each batch
- Reset to 0 when all probation customers processed

## Online Viewer
http://www.plantuml.com/plantuml/uml/

