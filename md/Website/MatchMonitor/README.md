# Match Monitor Page

> **📄 Interactive Documentation**: [Open MatchMonitor.html](MatchMonitor.html)  
> Complete page documentation with **2 tabs**:
> - **Data Lineage**: Field mapping (Database → API → UI)
> - **Flow Charts**: User flows, API flows, Component architecture

## 📄 Overview

**Match Monitor** is a web page for monitoring and analyzing suspicious betting matches detected by the CTS system. It displays matches flagged by background jobs and allows monitoring teams to investigate, verify, and take action on potentially fraudulent betting activity.

## 🎯 Purpose

- **Monitor**: Display dangerous matches detected by automated rules
- **Investigate**: View detailed ticket information for suspicious matches
- **Verify**: Allow PIC team to verify and confirm fraud transactions
- **Action**: Mark customers as Problem Account (PA) and assign classifications
- **Report**: Export match analysis for reporting and investigation

## 🔗 Data Dependencies

### Background Jobs (Data Writers)

This page displays data **written by** these background jobs:

| Background Job | Folder | Run Frequency | Data Written | Status |
|----------------|--------|---------------|--------------|--------|
| **MatchMonitorClassificationBySport** | [md/BySport/MatchMonitorClassificationBySport](../../BySport/MatchMonitorClassificationBySport/) | **5 minutes** | Match detections by sport | ✅ Analyzed |
| **MatchMonitorClassification (General)** | [md/General/MatchMonitorClassification](../../General/MatchMonitorClassification/) | **5 minutes** | General match detections | ✅ Analyzed |

### Data Tables (Read & Write)

**CTS_DataCenter (MySQL)**:
- `CTSMatchMonitor` - Match detection results (written by jobs, read by page)
- `CTSMatchMonitorDetail` - Fraud ticket details (written by jobs, read by page)
- `CTSCustomerClassification` - Customer CC/PA status (updated by jobs, read by page)

**bodb_VR2Model (SQL Server)**:
- Match info tables - Match master data (HomeName, AwayName, League, etc.)
- Transaction tables - Betting transaction data (all tickets, not just fraud)

## 📊 Key Concepts

### Customer Classification (CC)

**CC (Customer Class)** is the core concept of customer risk classification:

1. **Match Detection**:
   - A MatchID has multiple tickets (bets)
   - Background jobs run detection rules
   - Rules analyze betting patterns across tickets

2. **Classification Process**:
   - If rules are satisfied → CustID is flagged
   - Customer is marked as **CC (Problem Account)**
   - Assigned specific CC category (e.g., "Group Betting", "Sharp Player")

3. **CC Categories**:
   - **Normal**: Regular customer
   - **PotentialPA**: Potentially problematic
   - **PA (Problem Account)**: Confirmed problematic
   - **Probation**: Under observation
   - Sport-specific classifications

## 🎨 Page Features

### Main Page (Index)

**Search & Display Matches**:
- Filter by:
  - Date type (Scan Date vs Event Date)
  - Sport type
  - Bet type
  - Market
  - Reason (detection reason)
  - Verification status
- Display match list with:
  - Match info (HomeName vs AwayName)
  - League name
  - Sport & bettype
  - Detection reason
  - Fraud ticket count
  - Total turnover (Home/Away)
  - Verification status

**User Actions**:
- Click match → Navigate to Detail Page
- Filter and sort results
- Export to Excel

### Detail Page

**View Match Tickets**:
- Two modes:
  - **Fraud Tickets Only**: Show only detected fraud tickets
  - **All Tickets**: Show all tickets (fraud + normal)
- Ticket information:
  - Customer ID, Username
  - Customer Class (CC)
  - Bet amount, choice, odds
  - Transaction time
  - Robot status
  - Detection reason (for fraud tickets)

**Advanced Features**:
1. **Association Detection** (Manual):
   - Detect group betting manually
   - Input customer IDs/usernames
   - Options: IP, Device, Agent, BP
   - Display association groups

2. **Verify Transactions**:
   - PIC team verifies suspicious tickets
   - Mark as verified/not verified
   - Track verification status

3. **User Feedback**:
   - Add comments on detections
   - Mark as correct/incorrect detection
   - Provide reason for feedback

4. **Hold Key** (Host permission):
   - Lock match for review
   - Prevent others from editing
   - Track who is holding

5. **Mark PA** (Host permission):
   - Mark customers as Problem Account
   - Batch mark multiple customers
   - Redirect to PA management

6. **Ticket Voiding** (Host permission):
   - Redirect to ticket voiding system
   - Void fraudulent tickets

7. **Export to Excel**:
   - Export match details
   - Different templates for different sports
   - Single/Double grid formats

## 🔄 Data Flow

### Write Flow (Background Jobs → Database)

```
Background Jobs (Every 5 minutes)
    ├─→ Run detection rules
    ├─→ Analyze betting patterns
    ├─→ Detect group betting
    └─→ Write to Database:
        ├─→ CTSMatchMonitor (match detection results)
        ├─→ CTSMatchMonitorDetail (fraud ticket list)
        └─→ CTSCustomerClassification (customer CC status)
```

### Read Flow (Database → Web Page)

```
User Request
    ├─→ Controller: MatchMonitorController
    ├─→ Service: MatchMonitorService
    ├─→ Database Queries:
    │   ├─→ CTS_DC_MatchMonitor_Get (get matches)
    │   ├─→ CTS_DC_MatchMonitorDetail_Get (get fraud tickets)
    │   ├─→ CTS_Rpt_MatchMonitor_MatchInfo (get match info)
    │   └─→ CTS_Rpt_MatchMonitor_AllTickets_Get (get all tickets)
    └─→ Return to View (Display to user)
```

## 📝 Main Stored Procedures

### CTS_DC_MatchMonitor_Get
**Purpose**: Get match list with fraud detection data  
**Database**: CTS_DataCenter (MySQL)  
**Input**:
- Date range (FromDate, ToDate)
- Sport type list
- Bettype list
- Market
- Reason list
- IsVerified filter
- Match info JSON (for event date search)

**Output**: Match list with detection information

**Key Logic**:
- Join CTSMatchMonitor with CTSCustomerClassification
- Filter by search criteria
- Return match with fraud statistics

### CTS_Rpt_MatchMonitor_MatchInfo
**Purpose**: Get match master data from MainDB  
**Database**: bodb_VR2Model (SQL Server)  
**Input**:
- MatchIDs (comma-separated)
- OR Date range + Sport list

**Output**: Match info (HomeName, AwayName, League, KickOffTime, etc.)

### CTS_DC_MatchMonitorDetail_Get
**Purpose**: Get fraud ticket details for a match  
**Database**: CTS_DataCenter (MySQL)  
**Input**:
- MatchID
- BetTypeID
- BetID
- EventDate
- Ticket type (Single/Parlay)

**Output**: Fraud ticket list with customer info

## 🚀 Technology Stack

- **Backend**: ASP.NET MVC (C#)
- **Frontend**: JavaScript, jQuery
- **Database**: MySQL (CTS_DataCenter) + SQL Server (bodb_VR2Model)
- **Caching**: Memory Cache (for performance)
- **Export**: EPPlus (Excel generation)

## 📐 Controller Actions

### Main Page
- `Index()` - Display main page
- `GetMatchMonitor(para)` - Get match list (AJAX)
- `GetSportBettype()` - Get sport/bettype dropdown data

### Detail Page
- `Detail(para)` - Display detail page
- `GetMatchMonitorFilter(para)` - Get filter data for detail
- `GetMatchMonitorDetail(para, filter)` - Get ticket list (AJAX)
- `GetMatchMonitorTotalTicket(para, filter)` - Get total ticket count

### Association Detection
- `DetectGroupAssWithOptions(model)` - Manual association detection

### User Actions
- `VerifyTransMMDetail(para)` - Verify transactions
- `GetUserFeedback(para)` - Get user feedback
- `InsertUserFeedback(para)` - Add feedback
- `UpdateHoldKeyStatus(para)` - Update hold key
- `MarkPA(usernames)` - Mark as Problem Account
- `ExportToExcelMMDetail(form)` - Export to Excel

## 🔑 Permissions

- **Read**: All authenticated users
- **Verify**: Monitor team
- **Host**: Full control (Hold Key, Mark PA, Ticket Voiding)

## 📊 Performance Considerations

- **Memory Caching**: Fraud ticket data cached for performance
- **Batch Processing**: Large ticket lists processed in batches
- **Pagination**: Large result sets paginated
- **Async Loading**: Filter data loaded asynchronously
- **Background Tasks**: Some operations run in background

## 🆕 Data Freshness

- **Match Detection Data**: 5-minute latency (job run frequency)
- **Customer Classification**: Near real-time (updated by jobs)
- **Match Info**: Real-time (from MainDB)
- **Transaction Data**: Real-time (from MainDB)

## 🔍 Related Pages

- **Customer Search** - Search customer details
- **Association Detection** - Detect customer associations
- **Danger Monitor** - Monitor dangerous customers
- **Problem Account Management** - Manage PA customers

## 📖 Cross-References

### Related Background Jobs:
- [MatchMonitorClassificationBySport](../../BySport/MatchMonitorClassificationBySport/) - Sport-specific detection
- [MatchMonitorClassification (General)](../../General/MatchMonitorClassification/) - General detection (✅ Analyzed)

### Related Tables:
- CTSMatchMonitor - Match detection results
- CTSMatchMonitorDetail - Fraud ticket details
- CTSCustomerClassification - Customer CC status

## 📌 Notes

- **Data Source**: Match Monitor page is a **READ-ONLY** display of data written by background jobs
- **Detection Logic**: All detection rules and classification logic are in background jobs, not in web page
- **Real-time Updates**: Page shows near real-time data (5-minute latency)
- **Performance**: Caching used extensively for large ticket lists

## 🎯 Next Steps

To fully understand Match Monitor page, you should also analyze:
1. ✅ **md/General/MatchMonitorClassification** - General detection job (Analyzed)
2. Association Detection logic (manual group detection)
3. Frontend JavaScript code (user interactions)
4. Excel export templates (reporting)
5. Create Flow Charts for Tab 2 in MatchMonitor.html

