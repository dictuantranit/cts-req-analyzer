# Normal Account Classification By Sport - Diagrams

## Overview
This document contains diagrams for the **Normal Account Classification By Sport** flow, which handles classification of normal accounts from the Normal Pool based on their performance data.

## Flow Description
The Normal Account Classification By Sport job:
1. Retrieves customers from the Normal Pool that are ready for classification
2. Gets the current category for each customer
3. Classifies customers based on their accumulated performance data
4. Clears processed customers from the Normal Pool

## Diagrams

### 01_MainFlow.puml
**Main Business Flow Diagram**
- Shows the overall flow from job trigger to completion
- Illustrates the parallel processing with 5 threads
- Details the main steps: GetNormalPoolCustomers, GetCurrentCustomerCategory, ClassifyNormalPoolCustomers, ClearNormalPoolCustomers

### 02_Sequence.puml
**Sequence Diagram**
- Shows the interaction between components:
  - Job Scheduler → Controller → JobService → Service → DataAccess → Database
- Details the sequence of method calls and data flow
- Shows the parallel processing structure and chunk processing

### 03_DatabaseFlow.puml
**Database Flow Diagram**
- Shows the database operations and stored procedures involved
- Illustrates the flow between SQL Server (bodb_VR2Model) and MySQL (CTS_DataCenter)
- Details the data transformations and classification steps

### 04_SP_GetNormalPool_Detailed.puml
**Stored Procedure: GetNormalPool Detailed Flow**
- Details the logic of `CTS_BySportNormalClassification_NormalPool_Get`
- Shows how customers are retrieved from Normal Pool
- Illustrates the filtering logic based on:
  - ScannedMaxId (MAX ID from NormalPool)
  - LastScannedRow (from Parameter table)
  - RowVersion check (no changes in CustomerClassification_BySport)
- Shows the priority-based ordering

### 05_SP_GetCurrentCategory_Detailed.puml
**Stored Procedure: GetCurrentCategory Detailed Flow**
- Details the logic of `CTS_DC_CustClassification_BySport_GetCurrentCategory`
- Shows how current categories are retrieved for customers
- Illustrates:
  - Customer validation
  - Latest normal category retrieval
  - Probation LastDay calculation
- Returns category information for classification

### 06_SP_Classify_Detailed.puml
**Stored Procedure: Classify Detailed Flow**
- Details the logic of `CTS_BySportNormalClassification_NormalPool_Classify`
- Shows the classification process:
  1. Parse XML customer list
  2. Filter by IsCheckBetCount and CurrentCategoryId
  3. Get accumulated performance data
  4. Calculate classification rules
  5. Determine NewCategoryId based on:
     - TurnoverRM, WinlossRM, Margin
     - BetCount, ActiveDays, WinDaysRate
     - CurrentCategoryId, IsProbationLastDay
     - IsCheckBetCount, IsPlaceBetWithin30Days
  6. Update/Insert classification results
- Shows the filtering steps for bet count validation

### 07_SP_Clear_Detailed.puml
**Stored Procedure: Clear Detailed Flow**
- Details the logic of `CTS_BySportNormalClassification_NormalPool_Clear`
- Shows how processed customers are removed from Normal Pool
- Illustrates the deletion logic based on ScannedMaxId

## Key Components

### JobService
- `NormalAccountClassificationBySportJobService`: Orchestrates the job execution
- Implements parallel processing with 5 threads
- Chunks customers by batchInternalSize

### Service Layer
- `NormalAccountClassificationBySportService`: Business logic layer
- Methods:
  - `GetNormalPoolCustomers()`: Get customers from Normal Pool
  - `GetCurrentCustomerCategory()`: Get current category for customers
  - `ClassifyNormalPoolCustomers()`: Classify customers
  - `ClearNormalPoolCustomers()`: Clear processed customers

### Data Access Layer
- `NormalAccountClassificationBySportDataAccess`: Database access layer
- Calls stored procedures:
  - `CTS_BySportNormalClassification_NormalPool_Get`
  - `CTS_DC_CustClassification_BySport_GetCurrentCategory`
  - `CTS_BySportNormalClassification_NormalPool_Classify`
  - `CTS_BySportNormalClassification_NormalPool_Clear`

## Stored Procedures

### CTS_BySportNormalClassification_NormalPool_Get
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Get customers from Normal Pool for classification
**Parameters**:
- `@ScannedMaxId` (OUTPUT): Maximum ID scanned
**Returns**: List of customers (CustId, SportGroup, IsCheckBetCount)

### CTS_DC_CustClassification_BySport_GetCurrentCategory
**Database**: CTS_DataCenter (MySQL)
**Purpose**: Get current category for customers
**Parameters**:
- `@ip_CustSport` (JSON): Customer list in JSON format
**Returns**: Customer categories (CustID, SportGroup, CategoryID, IsProbationLastDay)

### CTS_BySportNormalClassification_NormalPool_Classify
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Classify customers based on performance
**Parameters**:
- `@CustomersXML` (XML): Customer list with category info in XML format
**Logic**:
- Gets accumulated performance data
- Calculates classification rules
- Determines NewCategoryId
- Updates/Inserts classification results

### CTS_BySportNormalClassification_NormalPool_Clear
**Database**: bodb_VR2Model (SQL Server)
**Purpose**: Clear processed customers from Normal Pool
**Parameters**:
- `@CustomersXML` (XML): Customer list in XML format
- `@ScannedMaxId` (BIGINT): Maximum ID to clear
**Logic**: Deletes customers from NormalPool where ID <= ScannedMaxId

## API Endpoint
- **POST** `/api/classificationBySportJobs/NormalAccountClassificationBySport`
- Parameter: `batchInternalSize` (default: 5000)

## Notes
- The job uses parallel processing with 5 threads for better performance
- Customers are processed in chunks based on batchInternalSize
- Classification is based on accumulated performance data from data warehouse
- The job tracks progress using ScannedMaxId to avoid reprocessing
- Customers are filtered by RowVersion to ensure no concurrent changes

