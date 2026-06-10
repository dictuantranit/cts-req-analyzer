# Probation Classification By Sport - Diagrams

## Overview
This document contains diagrams for the **Probation Classification By Sport** flow, which handles scanning and preprocessing of probation customers for classification.

## Flow Description
The Probation Classification By Sport job:
1. Retrieves probation customers that need to be scanned based on probation period rules
2. Preprocesses customers by filtering disabled and inactive accounts
3. Inserts valid customers into the Normal Pool for later classification processing
4. Updates system parameters to track the last scanned customer ID

## Diagrams

### 01_MainFlow.puml
**Main Business Flow Diagram**
- Shows the overall flow from job trigger to completion
- Illustrates the do-while loop that continues until no more customers are found
- Details the main steps: Start, GetProbationScanClassificationBySport, PreprocessProbationClassificationBySport, UpdateCompleteProbationScanBySport

### 02_Sequence.puml
**Sequence Diagram**
- Shows the interaction between components:
  - Job Scheduler → Controller → JobService → Service → DataAccess → Database
- Details the sequence of method calls and data flow
- Shows the loop structure and conditional logic

### 03_DatabaseFlow.puml
**Database Flow Diagram**
- Shows the database operations and stored procedures involved
- Illustrates the flow between MySQL (CTS_DataCenter) and SQL Server (bodb_VR2Model)
- Details the data transformations and filtering steps

### 04_SP_ProbationScan_Get_Detailed.puml
**Stored Procedure: ProbationScan Get Detailed Flow**
- Details the logic of `CTS_DC_CustClassification_BySport_ProbationScan_Get`
- Shows how probation customers are retrieved
- Illustrates the customer selection logic based on:
  - LastCustID from SystemParameter
  - CategoryID = CONST_CATEID_PROBATION
  - LastScannedDate validation (NULL or < CurrentDate)
  - CreatedDate validation (< CurrentDate - 2 days)
  - Active customer check (within 30 days)
- Shows the ordering and limiting logic

### 05_SP_Preprocess_Detailed.puml
**Stored Procedure: Preprocess Detailed Flow**
- Details the logic of `CTS_BySportNormalClassification_Probation_Preprocess`
- Shows the filtering steps:
  1. Parse XML customer list
  2. Remove disabled accounts
  3. Remove inactive customers (no transaction in 30 days)
- Shows the Priority retrieval and Normal Pool insertion

## Key Components

### JobService
- `ProbationClassificationBySportJobService`: Orchestrates the job execution
- Implements do-while loop to process all available customers

### Service Layer
- `ProbationClassificationBySportService`: Business logic layer
- Methods:
  - `Start()`: Initialize model
  - `GetProbationScanClassificationBySport()`: Get probation customers to scan
  - `PreprocessProbationClassificationBySport()`: Preprocess and insert into Normal Pool
  - `UpdateCompleteProbationScanBySport()`: Update system parameters

### Data Access Layer
- `ProbationClassificationBySportDataAccess`: Database access layer
- Calls stored procedures:
  - `CTS_DC_CustClassification_BySport_ProbationScan_Get`
  - `CTS_BySportNormalClassification_Probation_Preprocess`

## Stored Procedures

### CTS_DC_CustClassification_BySport_ProbationScan_Get
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Get probation customers for scanning
**Parameters**:
- `@op_LastCustID` (OUTPUT): Last processed customer ID
**Returns**: List of probation customers (CustID, SportGroup) to scan

**Logic**:
- Gets BatchSize from SystemParameter (ParameterID = 168)
- Gets LastCustID from SystemParameter (ParameterID = 169)
- Finds customers with:
  - CategoryID = CONST_CATEID_PROBATION
  - CustID > LastCustID
  - LastScannedDate IS NULL OR < CurrentDate
  - CreatedDate < CurrentDate - 2 days (probation period)
  - Active within 30 days
- Orders by CustID ASC
- Limits by BatchSize

### CTS_BySportNormalClassification_Probation_Preprocess
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Preprocess probation customers and insert into Normal Pool
**Parameters**:
- `@CustomersXML` (XML): Customer list in XML format
**Logic**:
- Filters disabled accounts
- Filters inactive customers (no transaction in 30 days)
- Inserts into Normal Pool via `NormalPool_Insert` with FunctionId = 2

## System Parameters
- **ParameterID = 168**: BatchSize for processing
- **ParameterID = 169**: DailyProbation_BySport_LastCustID

## API Endpoint
- **POST** `/api/classificationBySportJobs/ScanProbationClassificationBySport`
- No parameters required

## Notes
- The job uses a do-while loop to process all available customers
- Customers are filtered by:
  - Probation category (CONST_CATEID_PROBATION)
  - LastScannedDate validation (not scanned today)
  - CreatedDate validation (probation period: at least 2 days old)
  - Active status (transaction within 30 days)
- The job tracks progress using SystemParameter to resume from the last processed customer ID
- Probation customers are inserted into Normal Pool for later classification processing

