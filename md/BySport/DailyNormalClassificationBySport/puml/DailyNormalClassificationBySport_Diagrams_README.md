# Daily Normal Classification By Sport - Diagrams

## Overview
This document contains diagrams for the **Daily Normal Classification By Sport** flow, which handles daily scanning and preprocessing of normal customer classifications by sport.

## Flow Description
The Daily Normal Classification By Sport job:
1. Retrieves normal accounts that need daily scanning based on category scan intervals
2. Preprocesses customers by filtering disabled, already scanned, and inactive accounts
3. Inserts valid customers into the Normal Pool for later classification processing
4. Updates system parameters to track the last scanned category and customer ID

## Diagrams

### 01_MainFlow.puml
**Main Business Flow Diagram**
- Shows the overall flow from job trigger to completion
- Illustrates the do-while loop that continues until no more customers are found
- Details the main steps: Start, GetCustClassificationForDailyScanning, PreprocessDailyNormalClassification, UpdateLastScan

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

### 04_SP_GetNormal_Detailed.puml
**Stored Procedure: GetNormal Detailed Flow**
- Details the logic of `CTS_DC_CustClassification_BySport_DailyScan_GetNormal`
- Shows how normal categories are retrieved
- Illustrates the customer selection logic based on:
  - LastCategoryID and LastCustID from SystemParameter
  - LastScannedDate validation
  - Active customer check (within 30 days)
- Shows the category progression when no customers are found

### 05_SP_Preprocess_Detailed.puml
**Stored Procedure: Preprocess Detailed Flow**
- Details the logic of `CTS_BySportNormalClassification_Daily_Preprocess`
- Shows the filtering steps:
  1. Parse XML customer list
  2. Remove disabled accounts
  3. Remove already scanned customers (today)
  4. Remove inactive customers (no transaction in 30 days)
- Shows the Priority retrieval and Normal Pool insertion

## Key Components

### JobService
- `DailyNormalClassificationBySportJobService`: Orchestrates the job execution
- Implements do-while loop to process all available customers

### Service Layer
- `DailyNormalClassificationBySportServices`: Business logic layer
- Methods:
  - `Start()`: Initialize model
  - `GetCustClassificationForDailyScanning()`: Get customers to scan
  - `PreprocessDailyNormalClassification()`: Preprocess and insert into Normal Pool
  - `UpdateLastScan()`: Update system parameters

### Data Access Layer
- `DailyNormalClassificationBySportDataAccess`: Database access layer
- Calls stored procedures:
  - `CTS_DC_CustClassification_BySport_DailyScan_GetNormal`
  - `CTS_BySportNormalClassification_Daily_Preprocess`

## Stored Procedures

### CTS_DC_CustClassification_BySport_DailyScan_GetNormal
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Get normal accounts for daily scanning
**Parameters**:
- `@op_LastCategoryID` (OUTPUT): Last processed category ID
- `@op_LastCustID` (OUTPUT): Last processed customer ID
**Returns**: List of customers (CustID, SportGroup) to scan

### CTS_BySportNormalClassification_Daily_Preprocess
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Preprocess customers and insert into Normal Pool
**Parameters**:
- `@CustomersXML` (XML): Customer list in XML format
**Logic**:
- Filters disabled accounts
- Filters already scanned customers
- Filters inactive customers (no transaction in 30 days)
- Inserts into Normal Pool via `NormalPool_Insert`

## System Parameters
- **ParameterID = 113**: BatchSize for processing
- **ParameterID = 114**: DailyNormalClassificationBySportLastCategoryID
- **ParameterID = 115**: DailyNormalClassificationBySportLastCustID

## API Endpoint
- **POST** `/api/classificationBySportJobs/ScanningDailyNormalClassificationBySport`
- No parameters required

## Notes
- The job uses a do-while loop to process all available customers
- Customers are filtered by:
  - Category scan interval (ScanIntervalInSecond)
  - LastScannedDate validation
  - Active status (transaction within 30 days)
- The job tracks progress using SystemParameter to resume from the last processed position

