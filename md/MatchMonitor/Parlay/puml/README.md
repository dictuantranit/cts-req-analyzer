# Parlay Group Betting Detection 🎯🎲

## 📋 Overview

**Parlay Group Betting Detection** is a specialized Match Monitor rule designed to identify **group betting patterns in Parlay (Mix Parlay/Combo) bets**. Unlike standard group betting detection which focuses on single-match bets, this rule analyzes **multi-match combination bets** where customers place bets on multiple matches in a single ticket.

## 🎯 Purpose

Detect group betting in Parlay/Combo bets where:
- Multiple customers place similar combination bets
- Customers are associated through Device, AI, IP, or betting history
- Bets are placed within a short time window
- All bets are Parlay/Mix Parlay types (BetType = 29, MatchID = 29)

## 🔑 Key Characteristics

### 📊 What is Parlay Betting?

**Parlay (Cược xiên)** is a type of bet that combines multiple individual bets into one ticket:
- **Combo 2**: 2 matches in one ticket (BetCheck bit 2)
- **Combo 3+**: 3 or more matches in one ticket (BetCheck bit 3)
- **Betteam = 1**: Mix Parlay
- **BetType = 29, MatchID = 29**: Parlay identifier

### 🎲 Detection Criteria

Unlike Fixed Game which focuses on ticket patterns, **Parlay Group Betting** uses **Association Detection** similar to standard Group Betting:

| Criterion | Description | Enabled |
|-----------|-------------|---------|
| **1. Device Association** | Same device fingerprint | ✅ Always On |
| **2. AI Association** | AI-detected similarity | ✅ Always On |
| **3. IP Association** | Same IP address | ✅ Always On |
| **4. 3 Matches Last 7 Days** | Bet on same 3 matches in last 7 days | ✅ Always On |
| **5. IP Last 3 Days** | Same IP in last 3 days | ❌ Not Used |

**Note**: Parlay uses **4 criteria** (same as Saba Group Betting), not 5 like standard Group Betting.

### 🏅 Parlay-Specific Filters

When scanning for Parlay tickets in MainDB (bodb02):
```sql
WHERE bt.Betteam = 1                          -- 1: Mix Parlay
  AND bt.Bettype = 29
  AND bt.MatchID = 29
  AND (CAST(bt.BetCheck AS INT) & 2 = 2       -- Combo 2 (bit 2)
    OR CAST(bt.BetCheck AS INT) & 4 = 4)      -- Combo 3+ (bit 3)
  AND bt.Currency NOT IN (20,27,28)            -- Exclude specific currencies
  AND c.site NOT IN ('Nextbet','9wickets','9wsports')  -- Exclude specific sites
  AND c.Username NOT LIKE '%Cashout%'          -- Exclude cashout accounts
```

### 📂 Database Tables

#### Staging Tables (Input)
- **MatchMonitorParlayStagingGroupBettingLive** - Live parlay tickets
- **MatchMonitorParlayStagingGroupBettingNonLive** - Non-live parlay tickets

#### Result Tables (Output)
- **MatchMonitor** - Detected matches (shared with other rules)
- **MatchMonitorDetails** - Ticket and customer details (shared with other rules)

### 🔧 Rule Settings

| Field | Value | Description |
|-------|-------|-------------|
| RuleGroupID | **7** | Parlay Group Betting Detect |
| RuleGroupDesc | "Parlay Group Betting Detect" | Rule description |
| Reason | **5** | Parlay Group Betting |
| ReasonName | "Parlay Group Betting" | Reason display name |
| TimeStep | **180 seconds (3 minutes)** | Time window for grouping |
| RuleStatus | 1 | Active |

## 🔄 Processing Flow

### Phase 1: Get Parlay Tickets from MainDB (SQL Server)

**Stored Procedure**: `CTS_MatchMonitorParlay_GetNewTicket` (MainDB/bodb02)

1. **Read last scanned SequenceID**
2. **Query bettrans for Parlay tickets**
   ```sql
   SELECT TOP(@BatchSize) bt.refno, bt.sequenceid, bt.transid
   FROM bodb02.dbo.bettrans AS bt
   WHERE bt.sequenceid > @LastScannedSequenceID
     AND bt.Betteam = 1                    -- Mix Parlay
     AND bt.Bettype = 29
     AND bt.MatchID = 29
     AND (BetCheck & 2 = 2 OR BetCheck & 4 = 4)  -- Combo 2 or 3+
   ```

3. **Get ticket details from bettransm**
   - Each Refno contains multiple matches
   - Join with match and league tables
   - Filter by sport/bettype settings
   - Filter by LiveIndicator and EventStatus

4. **Return ticket list**
   - SequenceID, TransID, Refno
   - TransIDm (detail transaction ID)
   - MatchID, SportType, BetTypeID, BetID
   - CustID, TransDate, EventDate

### Phase 2: Insert into Staging Tables (MySQL)

**Service**: `MMParlayStagingService`

1. **Group tickets by Refno** (each Refno = 1 parlay ticket with multiple matches)
2. **For each match in the parlay**:
   - Calculate ScoreDiff = `(LiveHomeScore * 10000) + LiveAwayScore`
   - Convert TransDate to TO_SECONDS
3. **INSERT into staging table**:
   - `MatchMonitorParlayStagingGroupBettingLive` (if LiveIndicator = 1)
   - `MatchMonitorParlayStagingGroupBettingNonLive` (if LiveIndicator = 0)
4. **Update SystemParameter** with new LastSequenceID

### Phase 3: Get Matches to Process

**Stored Procedure**: `CTS_DC_MatchMonitorParlay_RuleGroupBetting_Get`

1. **Read last processed SequenceID**
   - Live: SystemParameter ID = **173**
   - NonLive: SystemParameter ID = **174**

2. **Read rule TimeStep** (180 seconds)
   ```sql
   SELECT TimeStep
   FROM MatchMonitorRuleSetting
   WHERE RuleGroupID = 7 AND Reason = 5 AND RuleStatus = 1
   ```

3. **Get existing groups (Temp_OldGroup)**
   - Load previous groups that still have tickets in staging
   - Used to merge new tickets with existing groups

4. **Calculate time window**
   ```sql
   SELECT TransDateToSecond + TimeStep AS MaxTime
   FROM Staging
   WHERE SequenceID >= LastSequenceID
   ORDER BY SequenceID ASC
   LIMIT 1
   ```

5. **Group tickets by match key**
   ```sql
   SELECT MatchID, ScoreDiff, BettypeID, BetID, Betteam,
          GROUP_CONCAT(DISTINCT CustID) AS CustIDList,
          GROUP_CONCAT(DISTINCT CTSCustID) AS CTSCustIDList,
          GROUP_CONCAT(TransIDm) AS TransIDmList
   FROM Staging
   LEFT JOIN Temp_OldGroup
   WHERE SequenceID <= MaxSequenceID
   GROUP BY MatchID, ScoreDiff, BettypeID, BetID, Betteam, OldGroupID
   HAVING COUNT(DISTINCT CustID) > 1  -- Must have multiple customers
   ```

6. **Return**:
   - MaxSequenceID
   - List of match groups to process

### Phase 4: Process Each Match Group (Parallel)

**Stored Procedure**: `CTS_DC_MatchMonitorParlay_RuleGroupBetting_Process`

#### Round 1: Association Detection

1. **For each match group**:
   - CustIDList, CTSCustIDList, TransIDmList

2. **Call Association Detection Service**:
   ```csharp
   var param = new DetectAssociationParamModel
   {
       CTSCustIds = ctsCustIDList,
       CustIds = custIDList,
       IsDevice = true,              // Check device association
       IsAI = true,                  // Check AI association
       IsIP = true,                  // Check IP association
       Is3MatchesLast7Days = true    // Check 3 matches history
   };
   var result = AssociationDetection.DetectAssociationLv1(param);
   ```

3. **Group customers by association**:
   - Customers with same Device/AI/IP/History → Same GroupID
   - Result: `[{CustID: 123, GroupID: 1}, {CustID: 456, GroupID: 1}, ...]`

4. **Call Process SP with group info**:
   ```sql
   CALL CTS_DC_MatchMonitorParlay_RuleGroupBetting_Process(
       @ip_LiveIndicator,
       @ip_MatchID,
       @ip_SportType,
       @ip_ScoreDiff,
       @ip_BettypeID,
       @ip_BetID,
       @ip_Betteam,
       @ip_TransIDmList,
       @ip_CustGroup  -- JSON: [{"CustID":123,"GroupID":1}, ...]
   )
   ```

5. **Inside Process SP**:
   - Group tickets by TimeStep windows (180 seconds)
   - Filter: Each time group must have >1 customer
   - Return complete groups and reprocess groups

#### Round 2: Reprocess Unassigned Tickets

1. **For groups with unassigned customers** (GroupID = 0):
   - Extract CustIDList of unassigned tickets
   - Run Association Detection again
   - Repeat Process SP

2. **Mark complete groups**:
   - Groups with all customers assigned to GroupID > 0

### Phase 5: Complete & Save

**Stored Procedure**: `CTS_DC_MatchMonitorParlay_RuleGroupBetting_Complete`

1. **Merge groups by TransIDList** (avoid duplicates)
2. **For each complete group**:
   - Check if match already exists in MatchMonitorDetails
   - If exists: **Merge** (UNION tickets)
   - If not: **Insert** new record

3. **Update staging tables**:
   - Set GroupID for detected tickets
   ```sql
   UPDATE Staging
   SET GroupID = ?
   WHERE TransIDm IN (...)
   ```

4. **Update MatchMonitor** (if new match)
5. **Update MatchMonitorDetails** (if new match or merge)

### Phase 6: Clean Staging Data

**Stored Procedure**: `CTS_DC_MatchMonitorParlay_RuleGroupBetting_StagingClean`

1. **Delete processed tickets**
   ```sql
   DELETE FROM MatchMonitorParlayStagingGroupBetting[Live/NonLive]
   WHERE SequenceID <= MaxSequenceID
   ```

2. **Update SystemParameter**
   ```sql
   UPDATE SystemParameter
   SET ParameterValue = MaxSequenceID
   WHERE ParameterID IN (173, 174)  -- Live/NonLive
   ```

## 🔁 Execution Schedule

### Background Jobs

| Job Name | API Endpoint | Schedule | Mode | Parallel Threads |
|----------|-------------|----------|------|------------------|
| **Step 1:** Insert Parlay Tickets | `/api/MatchMonitor/InsertParlayTicketDetailLive` | Every 5 minutes | Live | N/A |
| **Step 1:** Insert Parlay Tickets | `/api/MatchMonitor/InsertParlayTicketDetailNonLive` | Every 5 minutes | NonLive | N/A |
| **Step 2:** Process Parlay Group Betting | `/api/MatchMonitor/ProcessParlayRuleGroupBettingLive` | Every 5 minutes | Live | Configurable |
| **Step 2:** Process Parlay Group Betting | `/api/MatchMonitor/ProcessParlayRuleGroupBettingNonLive` | Every 5 minutes | NonLive | Configurable |

## 📊 Stored Procedures

### SP 1: Get Parlay Tickets from MainDB
**Name**: `CTS_MatchMonitorParlay_GetNewTicket` (SQL Server)

**Parameters**:
- `@LastScannedSequenceID` (BIGINT)
- `@IsLive` (BIT)
- `@BatchSize` (INT)
- `@ListSportBettype` (JSON) - Sport/BetType filter

**Returns**: List of parlay tickets with match details

### SP 2: Get Matches to Process
**Name**: `CTS_DC_MatchMonitorParlay_RuleGroupBetting_Get` (MySQL)

**Parameters**:
- `ip_LiveIndicator` (BOOLEAN)
- `op_MaxSequenceID` (BIGINT UNSIGNED) - OUTPUT

**Returns**: List of match groups to process

### SP 3: Process Match Group
**Name**: `CTS_DC_MatchMonitorParlay_RuleGroupBetting_Process` (MySQL)

**Parameters**:
- `ip_LiveIndicator` (BOOLEAN)
- `ip_MatchID`, `ip_ScoreDiff`, `ip_BettypeID`, `ip_BetID`, `ip_Betteam`
- `ip_TransIDmList` (LONGTEXT) - Comma-separated TransIDm list
- `ip_CustGroup` (JSON) - Association detection result

**Returns**: Complete groups and reprocess groups

### SP 4: Complete and Save
**Name**: `CTS_DC_MatchMonitorParlay_RuleGroupBetting_Complete` (MySQL)

**Parameters**:
- `ip_LiveIndicator` (BOOLEAN)
- `ip_MaxSequenceID` (BIGINT UNSIGNED)
- `ip_MatchID`, `ip_ScoreDiff`, `ip_BettypeID`, `ip_BetID`, `ip_Betteam`
- `ip_TransGroup` (JSON) - Complete groups

### SP 5: Clean Staging
**Name**: `CTS_DC_MatchMonitorParlay_RuleGroupBetting_StagingClean` (MySQL)

**Parameters**:
- `ip_LiveIndicator` (BOOLEAN)
- `ip_MaxSequenceID` (BIGINT UNSIGNED)

## 🎯 Key Differences

### Parlay vs Standard Group Betting

| Feature | Parlay Group Betting | Standard Group Betting |
|---------|---------------------|----------------------|
| **Bet Type** | Parlay/Combo only (BetType=29) | Single-match bets |
| **Ticket Structure** | Multiple matches per ticket (Refno) | One match per ticket |
| **Data Source** | MainDB (bodb02) → CTS | CTS Staging directly |
| **Association Criteria** | 4 criteria (no IP Last 3 Days) | 5 criteria (all) |
| **Time Window** | 180 seconds (3 minutes) | Sport-specific (180-300s) |
| **RuleGroupID** | 7 | 1 |
| **Reason** | 5 (Parlay GB) | 1 (GB) |
| **SystemParameter ID** | 173 (Live), 174 (NonLive) | 47 (Live), 48 (NonLive) |

### Parlay vs Fixed Game

| Feature | Parlay Group Betting | Fixed Game |
|---------|---------------------|-----------|
| **Detection Focus** | Customer associations in parlay | Ticket patterns (volume, stake, odds) |
| **Association Detection** | ✅ Yes (4 criteria) | ❌ No |
| **Odds Analysis** | ❌ No | ✅ Yes (OddsSpread) |
| **High Stake Analysis** | ❌ No | ✅ Yes (35% threshold) |
| **Bet Type** | Parlay only | All bet types |

## 📝 Example Detection Scenario

### Scenario: Group betting in Soccer Parlay

**Input Tickets** (within 3 minutes):
| Refno | TransIDm | CustID | MatchID | BetType | Betteam | TransDate |
|-------|----------|--------|---------|---------|---------|-----------|
| 100001 | 1001 | 5001 | 8001 | 1 (HDP) | h | 10:00:00 |
| 100001 | 1002 | 5001 | 8002 | 1 (HDP) | a | 10:00:00 |
| 100001 | 1003 | 5001 | 8003 | 3 (O/U) | o | 10:00:00 |
| 100002 | 1004 | 5002 | 8001 | 1 (HDP) | h | 10:01:30 |
| 100002 | 1005 | 5002 | 8002 | 1 (HDP) | a | 10:01:30 |
| 100002 | 1006 | 5002 | 8003 | 3 (O/U) | o | 10:01:30 |

**Observations**:
- 2 customers (5001, 5002)
- Similar combo structure (same 3 matches)
- Same bet choices on each match
- Within 3-minute time window

**Association Detection Result**:
- Device: Same device fingerprint ✅
- AI: High similarity score ✅
- → **GroupID = 1** (both customers in same group)

**Detection Result**:
- Match 8001, HDP, Home: Group Betting detected (CustID 5001, 5002)
- Match 8002, HDP, Away: Group Betting detected (CustID 5001, 5002)
- Match 8003, O/U, Over: Group Betting detected (CustID 5001, 5002)

**Database Update**:
- **MatchMonitor**: 3 new records (Reason = 5)
- **MatchMonitorDetails**: 3 records with TransIDmList and CustIDList

## 🚀 Technical Implementation

### C# Service Layer

**File**: `fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS/Features/MatchMonitor/Parlay/MMParlayRuleGroupBetting/MMParlayRuleGroupBettingProcessService.cs`

**Key Methods**:
```csharp
public interface IMMParlayRuleProcessService
{
    IMMParlayRuleProcessService PrepareProcess(
        MMParlayStagingRuleGroupBettingGroupModel matchStaging, 
        bool isLive,
        IReadOnlyDictionary<int, int> mappingCustDictionary = null);
    
    IMMParlayRuleProcessService ProcessRound1();
    IMMParlayRuleProcessService ProcessRound2();
    IMMParlayRuleProcessService Complete(ulong maxSequenceID);
    void WriteLogSentryIfError(string functionName);
}
```

**Processing Flow**:
```csharp
private IEnumerable<DetectAssociationMergeGroupLv1Entity> DetectAssociation(
    string ctsCustIDList, string custIDList)
{
    var param = new DetectAssociationParamModel
    {
        CTSCustIds = ctsCustIDList,
        CustIds = custIDList,
        IsDevice = true,
        IsAI = true,
        IsIP = true,
        Is3MatchesLast7Days = true
    };
    
    return _associationDetection.DetectAssociationLv1(param);
}
```

### Job Service Layer

**File**: `fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS.JobService/Services/Parlay/MatchMonitorParlayJobService.cs`

```csharp
public Task<bool> ProcessParlayRuleGroupBetting(bool isLive, int numberOfThread)
{
    var mmParlayRuleGB = _mmParlayRuleGBService.GetMMParlayRuleGroupBetting(isLive);
    
    if (mmParlayRuleGB != null && mmParlayRuleGB.MaxSequenceID.HasValue)
    {
        mmParlayRuleGB.MatchStagingList?
            .AsParallel()
            .WithDegreeOfParallelism(numberOfThread)
            .ForAll(matchInfo =>
            {
                _mmParlayRuleGBService.GetInstanceParlayProcessGBService()
                    .PrepareProcess(matchInfo, isLive)
                    .ProcessRound1()
                    .ProcessRound2()
                    .Complete(mmParlayRuleGB.MaxSequenceID.Value)
                    .WriteLogSentryIfError(nameof(ProcessParlayRuleGroupBetting));
            });
        
        _mmParlayRuleGBService.CleanTransRuleGroupBetting(
            isLive, mmParlayRuleGB.MaxSequenceID.Value);
    }
}
```

## 📚 Related Documentation

- [Match Monitor Group Betting](../GroupBetting/README.md) - Standard group betting detection
- [Match Monitor Saba Group Betting](../SabaGroupBetting/README.md) - Saba-specific group betting
- [Fixed Game Detection](../FixedGame/README.md) - Match fixing detection
- [Match Monitor Classification (General)](../../General/MatchMonitorClassification/README.md) - Customer classification after detection
- [Match Monitor Classification (By Sport)](../../BySport/MatchMonitorClassificationBySport/README.md) - Sport-specific customer classification

## 📊 Diagrams

See `puml/` folder for PlantUML diagrams:
- `Parlay_01_MainFlow.puml` - Main processing flow (6 phases)
- `Parlay_02_Sequence.puml` - Sequence diagram
- `Parlay_03_DataFlow.puml` - Data flow from MainDB to CTS
- `Parlay_04_AssociationDetection.puml` - Association detection logic (4 criteria)

## 🔧 Configuration

### System Parameters

| ParameterID | Parameter Name | Description | Default Value |
|-------------|----------------|-------------|---------------|
| 173 | MatchMonitorParlay_GroupBettingLive_LastSequenceID | Last processed SequenceID (Live) | 0 |
| 174 | MatchMonitorParlay_GroupBettingNonLive_LastSequenceID | Last processed SequenceID (NonLive) | 0 |

### Rule Settings (MatchMonitorRuleSetting)

| Field | Value |
|-------|-------|
| RuleGroupID | 7 |
| RuleGroupDesc | "Parlay Group Betting Detect" |
| Reason | 5 |
| ReasonName | "Parlay Group Betting" |
| TimeStep | 180 seconds (3 minutes) |
| RuleStatus | 1 (Active) |

---

**Last Updated**: November 2024  
**Maintained By**: CTS Development Team

