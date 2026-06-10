# Realtime Check Change Classification - Diagrams

## Overview
This document contains diagrams for the **Realtime Check Change Classification** flow, which monitors and updates customer transaction changes in real-time for Customer Association tracking.

## Flow Description
The Realtime Check Change Classification job:
1. Checks for customers with transaction changes (Member and Agency)
2. Updates LastTicketDate for Member customers in batches
3. Updates LastTicketDate for Agency customers in batches
4. Updates the next scan time slots (4 time slots for optimization)

## Diagrams

### 01_MainFlow.puml
**Main Business Flow Diagram**
- Shows the overall flow from job trigger to completion
- Illustrates the sequential processing of Member and Agency updates
- Details the main steps: CheckChange, UpdateLastTransDate (x2), UpdateNextScanCheckChange

### 02_Sequence.puml
**Sequence Diagram**
- Shows the interaction between components:
  - Job Scheduler → Controller → JobService → Service → DataAccess → Database
- Details the sequence of method calls and data flow
- Shows batch processing with throttling

### 03_DatabaseFlow.puml
**Database Flow Diagram**
- Shows the database operations and stored procedures involved
- Illustrates the flow between bodb_VR2Model (SQL Server) and CTS_Archive (MySQL)
- Details the data transformations and batch processing

### 04_SP_CheckChange_Detailed.puml
**Stored Procedure: CheckChange Detailed Flow**
- Details the logic of `CTS_NormalClassification_RealTime_CheckChanges`
- Shows how customer changes are detected
- Illustrates the dual result sets (Member vs Agency)
- Shows the 4 output parameters for next scan time slots

### 05_SP_UpdateLastTrans_Detailed.puml
**Stored Procedure: UpdateLastTransDate Detailed Flow**
- Details the logic of `CTS_Arc_CustomerAssociation_LastTicketDate_Update`
- Shows how LastTicketDate is updated in Archive DB
- Illustrates JSON parsing and batch update logic

## Key Components

### JobService
- `RealtimeCheckChangeClassificationJobService`: Orchestrates the job execution
- Single execution flow (no loop)

### Service Layer
- `RealtimeCheckChangeClassificationService`: Business logic layer
- Methods:
  - `CheckChange()`: Get customers with transaction changes
  - `UpdateLastTransDate()`: Update LastTicketDate (batched with throttling)
  - `UpdateNextScanCheckChange()`: Update next scan time slots

### Data Access Layer
- `RealtimeCheckChangeClassificationDataAccess`: Database access layer
- Calls stored procedures:
  - `CTS_NormalClassification_RealTime_CheckChanges`
  - `CTS_Arc_CustomerAssociation_LastTicketDate_Update`
  - `CTS_NormalClassification_RealTime_UpdateNextScannedTime`

## Stored Procedures

### CTS_NormalClassification_RealTime_CheckChanges
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Detect customers with transaction changes
**Parameters**:
- `@NextScannedDateTime1` (OUTPUT): Next scan time slot 1
- `@NextScannedDateTime2` (OUTPUT): Next scan time slot 2
- `@NextScannedDateTime3` (OUTPUT): Next scan time slot 3
- `@NextScannedDateTime4` (OUTPUT): Next scan time slot 4
**Returns**: 
- ResultSet 1: CustInfos (Member customers with changes)
- ResultSet 2: CustInfosAgency (Agency customers with changes)
**Entity Structure**: CustId, LastTicketDate

### CTS_Arc_CustomerAssociation_LastTicketDate_Update
**Database**: CTS_Archive (MySQL)
**Purpose**: Update LastTicketDate in CustomerAssociation table
**Parameters**:
- `@ip_CustInfo` (JSON): Customer info in JSON format
**Logic**:
- Parse JSON array of {CustId, LastTicketDate}
- Update CustomerAssociation.LastTicketDate
- Used for tracking customer betting history

### CTS_NormalClassification_RealTime_UpdateNextScannedTime
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Update next scan time slots
**Parameters**:
- `@NextScannedDateTime1`: Next scan time slot 1
- `@NextScannedDateTime2`: Next scan time slot 2
- `@NextScannedDateTime3`: Next scan time slot 3
- `@NextScannedDateTime4`: Next scan time slot 4
**Logic**:
- Save 4 time slots for optimized scanning
- Enables sliding window or parallel time slot scanning

## Data Model

### RealtimeCheckChangeEntities
```csharp
public class RealtimeCheckChangeEntities
{
    public int CustId { get; set; }
    public DateTime? LastTicketDate { get; set; }
}
```

### RealtimeCheckChangeModel
```csharp
public class RealtimeCheckChangeModel
{
    public IEnumerable<RealtimeCheckChangeEntities> CustInfos { get; set; }
    public IEnumerable<RealtimeCheckChangeEntities> CustInfosAgency { get; set; }
    public DateTime? NextScannedDateTime1 { get; set; }
    public DateTime? NextScannedDateTime2 { get; set; }
    public DateTime? NextScannedDateTime3 { get; set; }
    public DateTime? NextScannedDateTime4 { get; set; }
}
```

## API Endpoint
- **POST** `/api/classificationJobs/realtimeCheckChanges`
- **Parameters**: 
  - `batchSize` (int): Batch size for updating LastTransDate

## Key Features

### Batch Processing with Throttling
- Customer updates are chunked by `batchSize`
- `Thread.Sleep(10)` between batches to prevent database overload
- Sequential processing for database stability

### Dual Customer Types
- **Member**: Regular customers (CustInfos)
- **Agency**: Agency customers (CustInfosAgency)
- Both types are processed separately but with same logic

### JSON Serialization
- Customer entities are serialized to JSON before SP call
- Enables efficient batch updates in a single SP call

### 4 Time Slots Optimization
- Uses 4 NextScannedDateTime slots
- Possible strategies:
  - Sliding window scanning
  - Parallel time slot processing
  - Multi-timezone support
  - Load balancing across time slots

### Database Architecture
- **VR2 Database**: Main classification database (SQL Server)
  - Detects changes
  - Manages scan timing
- **Archive Database**: Historical tracking database (MySQL)
  - Stores LastTicketDate
  - Used for Customer Association analysis

## Performance Considerations

### Throttling Strategy
- 10ms sleep between batches prevents database lock contention
- Allows other queries to execute between batches

### Batch Size
- Configurable batch size for flexibility
- Smaller batches: Lower memory, more DB calls
- Larger batches: Higher memory, fewer DB calls

### Timeout Settings
- DEV/LOCAL: 300 seconds
- SIT/PROD/KLDR: 600 seconds (10 minutes)
- Longer timeout for production stability

## Flow Summary

1. **Trigger**: HTTP POST to `/api/classificationJobs/realtimeCheckChanges`
2. **CheckChange**: Get customers with transaction changes (Member + Agency)
3. **Update Member**: Batch update LastTicketDate for Member customers
4. **Update Agency**: Batch update LastTicketDate for Agency customers
5. **Update Next Scan**: Save 4 next scan time slots for optimization

## Notes
- This job is realtime but uses batch processing for efficiency
- Customer Association tracking is critical for fraud detection
- The 4 time slots mechanism suggests advanced scheduling optimization
- Archive DB separation enables long-term historical analysis without impacting main DB performance

## Online Viewer
http://www.plantuml.com/plantuml/uml/

