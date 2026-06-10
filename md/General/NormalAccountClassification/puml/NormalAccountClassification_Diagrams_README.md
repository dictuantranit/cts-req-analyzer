# Normal Account Classification - Diagrams

## Overview
This document contains diagrams for the **Normal Account Classification** flow, which processes customers from the Normal Pool and applies classification based on their current category and various flags.

## Flow Description
The Normal Account Classification job:
1. Gets customers from Normal Pool (pending classification)
2. Retrieves current customer categories in batches
3. Joins Pool data with Category data
4. Classifies customers in parallel (4 threads)
5. Clears processed customers from Normal Pool

## Diagrams

### 01_MainFlow.puml
**Main Business Flow Diagram**
- Shows the overall flow from job trigger to completion
- Illustrates parallel processing with 4 threads
- Details the main steps: GetNormalPoolCustomers, GetCurrentCustomerCategory, Join, Parallel Classify, Clear

### 02_Sequence.puml
**Sequence Diagram**
- Shows the interaction between components:
  - Job Scheduler → Controller → JobService → Service → DataAccess → Database
- Details the sequence of method calls and data flow
- Shows parallel processing with AsParallel() and WithDegreeOfParallelism(4)

### 03_DatabaseFlow.puml
**Database Flow Diagram**
- Shows the database operations and stored procedures involved
- Illustrates the flow between SQL Server (VR2) and MySQL (DataCenter)
- Details the data transformations (JSON, XML) and parallel processing

### 04_SP_GetPool_Detailed.puml
**Stored Procedure: GetPool Detailed Flow**
- Details the logic of `CTS_GeneralNormalClassification_NormalPool_Get`
- Shows how customers are retrieved from Normal Pool
- Illustrates priority-based ordering and ScannedMaxId tracking

### 05_SP_GetCategory_Detailed.puml
**Stored Procedure: GetCategory Detailed Flow**
- Details the logic of `CTS_DC_CustClassification_Normal_GetCurrentCategory`
- Shows how current customer categories are retrieved
- Illustrates JSON parsing and various classification flags

### 06_SP_Classify_Detailed.puml
**Stored Procedure: Classify Detailed Flow**
- Details the logic of `CTS_GeneralNormalClassification_NormalPool_Classify`
- Shows how customers are classified
- Illustrates XML parsing and classification logic

### 07_SP_Clear_Detailed.puml
**Stored Procedure: Clear Detailed Flow**
- Details the logic of `CTS_GeneralNormalClassification_NormalPool_Clear`
- Shows how processed customers are removed from Pool
- Illustrates dual cleanup (by CustId list AND by ScannedMaxId)

## Key Components

### JobService
- `NormalAccountClassificationJobService`: Orchestrates the job execution
- Single execution flow with parallel processing

### Service Layer
- `NormalAccountClassificationService`: Business logic layer
- Methods:
  - `GetNormalPoolCustomers()`: Get customers from Normal Pool
  - `GetCurrentCustomerCategory()`: Get current categories (batched)
  - `ClassifyNormalPoolCustomers()`: Apply classification (XML)
  - `ClearNormalPoolCustomers()`: Remove from Pool

### Data Access Layer
- `NormalAccountClassificationDataAccess`: Database access layer
- Calls stored procedures:
  - `CTS_GeneralNormalClassification_NormalPool_Get`
  - `CTS_DC_CustClassification_Normal_GetCurrentCategory`
  - `CTS_GeneralNormalClassification_NormalPool_Classify`
  - `CTS_GeneralNormalClassification_NormalPool_Clear`

## Stored Procedures

### CTS_GeneralNormalClassification_NormalPool_Get
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Get customers from Normal Pool for classification
**Parameters**:
- `@ScannedMaxId` (OUTPUT): Maximum ID processed
**Returns**: 
- CustId (long)
- IsRealtimeOnly (bool)
- ScanTaggingType (int)
- ScanSpecialLicSubType (int)
**Logic**:
- Get unprocessed customers from Normal Pool
- Order by Priority DESC, ID ASC
- Return ScannedMaxId for cleanup

### CTS_DC_CustClassification_Normal_GetCurrentCategory
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Get current customer categories and flags
**Parameters**:
- `@ip_CustInfo` (JSON): Customer info in JSON format
**Returns**: 
- CustID (long)
- CategoryID (int)
- IsNewCreated (bool)
- IsProbationLastDay (bool)
- IsSpecialLicSubCC (bool)
**Logic**:
- Parse JSON customer list
- Get current classification from CTSCustomerClassification
- Retrieve various classification flags
- Used for determining classification logic

### CTS_GeneralNormalClassification_NormalPool_Classify
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Apply classification to customers
**Parameters**:
- `@CustomersXML` (XML): Customer data in XML format
**Logic**:
- Parse XML customer list
- Apply classification logic based on:
  - Current CategoryId
  - IsNewCreated flag
  - IsProbationLastDay flag
  - IsRealtimeOnly flag
  - ScanTaggingType
  - ScanSpecialLicSubType
- Insert/Update CustomerClassification table
- Handle various classification scenarios

### CTS_GeneralNormalClassification_NormalPool_Clear
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Remove processed customers from Normal Pool
**Parameters**:
- `@ListCustId` (string): Comma-separated customer IDs
- `@ScannedMaxId` (long): Maximum ID processed
**Logic**:
- Delete by specific CustId list (successful processing)
- Delete by ID <= ScannedMaxId (batch cleanup)
- Dual cleanup strategy for reliability

## Data Model

### GetNormalPoolCustomerEntity
```csharp
public class GetNormalPoolCustomerEntity
{
    public long CustId { get; set; }
    public bool IsRealtimeOnly { get; set; }
    public int ScanTaggingType { get; set; }
    public int ScanSpecialLicSubType { get; set; }  // 0: Not Exist LicSub, 1: Exist LicSub
}
```

### GetCurrentNormalCategoryEntity
```csharp
public class GetCurrentNormalCategoryEntity
{
    public long CustID { get; set; }
    public int CategoryID { get; set; }
    public bool IsNewCreated { get; set; }
    public bool IsProbationLastDay { get; set; }
    public bool IsSpecialLicSubCC { get; set; }
}
```

### GetCurrentCustomerCategoryModel (XML Serializable)
```csharp
[XName("r")]
public class GetCurrentCustomerCategoryModel
{
    [XName("CustId")] public long CustId { get; set; }
    [XName("CategoryId")] public int CategoryId { get; set; }
    [XName("IsNewCreated")] public bool IsNewCreated { get; set; }
    [XName("IsRealtimeOnly")] public bool IsRealtimeOnly { get; set; }
    [XName("IsProbationLastDay")] public bool IsProbationLastDay { get; set; }
    [XName("ScanTaggingType")] public int ScanTaggingType { get; set; }
    [XName("ScanSpecialLicSubType")] public int ScanSpecialLicSubType { get; set; }
    [XName("IsSpecialLicSubCC")] public bool IsSpecialLicSubCC { get; set; }
}
```

## API Endpoint
- **POST** `/api/classificationJobs/normalAccountClassification`
- **Parameters**: 
  - `batchInternalSize` (int): Internal batch size (default: 5000)

## Key Features

### Parallel Processing with 4 Threads
- Uses `AsParallel().WithDegreeOfParallelism(4)`
- Each thread processes a batch of customers
- Improves throughput significantly
- Balances CPU usage and database load

### Batch Processing
- Customers chunked by `batchInternalSize` (default: 5000)
- GetCurrentCustomerCategory: Batched calls
- Classification: Parallel batches
- Prevents memory overflow

### Data Joining
- Pool data (from VR2) + Category data (from DataCenter)
- LINQ Join in application layer
- Combines customer info with current classification
- Creates complete classification context

### Priority-Based Processing
- Customers ordered by Priority (DESC) then ID (ASC)
- Higher priority customers processed first
- Realtime customers typically have higher priority
- Ensures timely processing of critical customers

### Multiple Classification Flags
- **IsNewCreated**: First-time classification
- **IsProbationLastDay**: Last day of probation period
- **IsRealtimeOnly**: Only needs realtime classification
- **ScanTaggingType**: Special tagging logic
- **ScanSpecialLicSubType**: Special licensee sub-type handling
- **IsSpecialLicSubCC**: Special classification flag

### XML Serialization for Classification
- Customer data serialized to XML
- XML passed to stored procedure
- SP parses XML for batch processing
- Efficient for complex data structures

### Dual Cleanup Strategy
- Cleanup by specific CustId list (successful processing)
- Cleanup by ScannedMaxId (batch cleanup)
- Ensures no orphaned records
- Handles both success and partial failure scenarios

### Database Architecture
- **VR2 Database** (SQL Server): Classification engine
  - Normal Pool storage
  - Classification logic
  - Pool cleanup
- **DataCenter Database** (MySQL): Metadata
  - Current customer classification
  - Category definitions
  - Classification flags

## Performance Considerations

### Parallel Processing Degree
- `WithDegreeOfParallelism(4)`: 4 concurrent threads
- Balance between:
  - CPU utilization
  - Database connection pool
  - Memory usage
- Configurable for tuning

### Batch Size
- Default: 5000 customers per batch
- Smaller batches: More DB calls, lower memory
- Larger batches: Fewer DB calls, higher memory
- Affects JSON/XML payload size

### Priority Ordering
- Higher priority first
- Ensures critical customers processed promptly
- Realtime > Daily > Others

### ScannedMaxId Tracking
- Tracks maximum ID processed
- Used for cleanup
- Enables incremental processing
- Prevents reprocessing

### Timeout Settings
- All SPs: 300 seconds (5 minutes)
- Sufficient for batch processing
- Consistent across environments

## Flow Summary

1. **Trigger**: HTTP POST to `/api/classificationJobs/normalAccountClassification`
2. **Get Pool**: Get customers from Normal Pool (priority ordered)
3. **Get Categories**: 
   - Chunk customers into batches
   - Get current categories from DataCenter (JSON)
4. **Join Data**: Join Pool customers with their current categories
5. **Parallel Classification**:
   - Chunk into batches
   - Process 4 batches in parallel
   - Serialize to XML
   - Apply classification
6. **Clear Pool**: Remove processed customers from Normal Pool

## Classification Decision Logic

The classification is based on multiple factors:

```
┌─────────────────────────────────────────────────────────────┐
│                  Customer from Normal Pool                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   Get Current Category      │
        │   + Classification Flags    │
        └──────────────┬──────────────┘
                       │
        ┌──────────────┴──────────────────────────────────┐
        │   Classification Decision Matrix                │
        ├─────────────────────────────────────────────────┤
        │ • Current CategoryId                            │
        │ • IsNewCreated         → New customer logic     │
        │ • IsProbationLastDay   → Probation completion   │
        │ • IsRealtimeOnly       → Skip daily logic       │
        │ • ScanTaggingType      → Special tagging        │
        │ • ScanSpecialLicSubType → Licensee sub handling │
        │ • IsSpecialLicSubCC    → Special classification │
        └──────────────┬──────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   Apply Classification      │
        │   Update CustomerClass      │
        └──────────────┬──────────────┘
                       │
        ┌──────────────┴──────────────┐
        │   Clear from Normal Pool    │
        └─────────────────────────────┘
```

## Notes
- This job processes the **Normal Pool** created by:
  - **RealtimeClassification** (Realtime customers)
  - **DailyNormalClassification** (Daily customers)
  - Other normal classification sources
- Customers are classified based on current state and various flags
- Parallel processing (4 threads) optimizes throughput
- Priority ensures critical customers processed first
- After classification, results pushed to MainDB by **NormalAccountInsert** job

## Integration Points

### Upstream (Pool Feeders)
- **RealtimeClassification**: Inserts realtime customers into Normal Pool
- **DailyNormalClassification**: Inserts daily customers into Normal Pool
- **Other sources**: Various classification triggers

### Downstream
- **NormalAccountInsert**: Takes classified customers and pushes to MainDB
- **CustomerClassification table**: Updated with new classifications

## Online Viewer
http://www.plantuml.com/plantuml/uml/

