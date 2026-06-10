# Hedging Detection 🛡️⚖️

## 📋 Overview

**Hedging Detection** is a Match Monitor rule designed to identify customers who place **opposite bets on the same match** to minimize risk or guarantee profit. Unlike Group Betting which focuses on multiple customers betting together, Hedging detects when **one customer (or associated customers) bets on both sides** of a match.

## 🎯 Purpose

Detect hedging behavior where:
- Same customer or associated group bets on opposite outcomes
- Bets are placed within a short time window
- Total stake meets minimum threshold
- Customers have specific classification flags indicating hedging behavior

## 🔑 Key Characteristics

### 📊 What is Hedging?

**Hedging (Phòng ngừa rủi ro)** is a betting strategy where a customer places bets on opposite outcomes to:
- **Minimize Risk**: Guarantee no loss (or minimal loss)
- **Lock in Profit**: Exploit odds differences to ensure profit
- **Arbitrage**: Take advantage of odds changes over time

**Example**:
```
Match: Barcelona vs Real Madrid
BetType: 1X2

Customer A bets:
- Bet 1: Barcelona Win @ 2.10 odds - $1000
- Bet 2: Real Madrid Win @ 2.00 odds - $1000

Outcomes:
- If Barcelona wins: Win $1100, Lose $1000 = +$100 profit
- If Real Madrid wins: Win $1000, Lose $1000 = $0
- If Draw: Lose both = -$2000 (risk)

→ Detected as Hedging (profit opportunity with minimal risk)
```

### 🎲 Detection Criteria

The Hedging detection uses **multiple criteria**:

1. **IsHedging Flag** (at Transaction Level)
   - Each transaction in staging has `IsHedging` flag
   - Set to TRUE if customer has opposite bets on same match
   - Calculated before staging insertion

2. **Association Detection** (3 Criteria)
   | Criterion | Description | Enabled |
   |-----------|-------------|---------|
   | **1. Device Association** | Same device fingerprint | ✅ Always On |
   | **2. AI Association** | AI-detected similarity | ✅ Always On |
   | **3. IP Association** | Same IP address | ✅ Always On |
   
   **Note**: Hedging uses **3 criteria** (no "3 Matches Last 7 Days", no "IP Last 3 Days")

3. **Agent Detection** (Special)
   - Specifically detect Alpha (SubscriberID=168) and Maxbet (SubscriberID=169) agents
   - If >1 agent from same subscriber places hedging bets → Flag as suspicious
   - AgentDetect_CTSCustIDList: List of agents to check

4. **Customer Classification Check**
   - Check if customer has `IsHedgingReasonMM = 1` in CustomerCategory
   - Only customers with PA (Problem Account) categories have this flag
   - Additional check: Call `CTS_DC_Association_IsAssociatedHedgingCustByCustIDList`

5. **Time Window & Stake**
   - **TimeStep**: 180 seconds (3 minutes)
   - **TotalStake**: Minimum total stake threshold (sport-specific)
   - Must have >1 customer in group
   - Must pass IsValidGroup check

### 🏅 Supported Sports

Hedging detection supports **multiple sports** with sport-specific TotalStake:

| Sport | SportType | RuleGroupID | Reason | MinStake | TotalStake | TimeStep |
|-------|-----------|-------------|--------|----------|------------|----------|
| ⚽ Soccer | 1 | 3 | 1 | Sport-specific | Sport-specific | 180s |
| 🏀 Basketball | 2 | 3 | 1 | Sport-specific | Sport-specific | 180s |
| 🎾 Tennis | 5 | 3 | 1 | Sport-specific | Sport-specific | 180s |
| ... | ... | 3 | 1 | ... | ... | 180s |

### 📂 Database Tables

#### Staging Tables (Input)
- **MatchMonitorStagingHedgingLive** - Live match tickets
- **MatchMonitorStagingHedgingNonLive** - Non-live match tickets
- **Key Field**: `IsHedging` (BOOLEAN) - Flag indicating hedging transaction

#### Result Tables (Output)
- **MatchMonitor** - Detected matches
- **MatchMonitorDetails** - Ticket and customer details

#### Reference Tables
- **CustomerCategory** - Contains `IsHedgingReasonMM` flag
- **CTSCustomerClassification** - Customer classification history

## 🔄 Processing Flow

### Phase 1: Insert Staging Data

When inserting into staging tables, calculate **IsHedging** flag:
```sql
-- Logic to set IsHedging flag
-- Check if customer has opposite bets on same match
-- within TimeStep window
```

**Staging Insert** (`CTS_DC_MatchMonitor_Staging_Insert`):
1. **Filter tickets** by MinStake and sport/bettype settings
2. **Set IsHedging flag** for tickets with opposite bets
3. **INSERT into staging** table (Live or NonLive)

### Phase 2: Get Matches to Process

**Stored Procedure**: `CTS_DC_MatchMonitor_RuleHedging_Get`

1. **Read last processed SequenceID**
   - Live: ParameterID = **120**
   - NonLive: ParameterID = **121**

2. **Read rule settings**
   ```sql
   SELECT TimeStep, TotalStake
   FROM MatchMonitorRuleSetting
   WHERE RuleGroupID = 3 AND Reason = 1 AND RuleStatus = 1
   ```

3. **Load Temp_OldGroup**
   - Existing groups still in staging (GroupID > 0)
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
          GROUP_CONCAT(DISTINCT CTSCustID) AS CTSCustIDList,
          CASE WHEN COUNT(DISTINCT CASE WHEN SubscriberID IN (168, 169) 
                                    THEN CTSCustID ELSE NULL END) > 1
               THEN GROUP_CONCAT(DISTINCT CASE WHEN SubscriberID IN (168, 169) 
                                          THEN CTSCustID ELSE NULL END)
               ELSE NULL END AS AgentDetect_CTSCustIDList,
          GROUP_CONCAT(SequenceID) AS SequenceIDList
   FROM Staging
   LEFT JOIN Temp_OldGroup
   WHERE SequenceID <= MaxSequenceID
   GROUP BY MatchID, ScoreDiff, BettypeID, BetID, Betteam, OldGroupID
   HAVING COUNT(DISTINCT CustID) > 1 
     AND SUM(Stake) >= Rule_TotalStake
   ```

6. **Return**:
   - MaxSequenceID
   - Match groups (with CTSCustIDList and AgentDetect_CTSCustIDList)

### Phase 3: Process Each Match (Parallel)

**Stored Procedure**: `CTS_DC_MatchMonitor_RuleHedging_Process`

#### Round 1: Association Detection

1. **For each match group**:
   - CTSCustIDList, AgentDetect_CTSCustIDList, SequenceIDList

2. **Call Association Detection Service**:
   ```csharp
   var param = new DetectAssociationParamModel
   {
       CTSCustIds = ctsCustIDList,
       AgentCTSCustIds = agentCTSCustIds,  // Special agent check
       IsDevice = true,
       IsAI = true,
       IsIP = true
   };
   var result = AssociationDetection.DetectAssociation(param);
   ```

3. **Group customers by association**:
   - Result: `[{CustID: 123, GroupID: 1}, {CustID: 456, GroupID: 1}, ...]`

4. **Call Process SP**:
   ```sql
   CALL CTS_DC_MatchMonitor_RuleHedging_Process(
       @ip_LiveIndicator,
       @ip_MatchID,
       @ip_ScoreDiff,
       @ip_BettypeID,
       @ip_BetID,
       @ip_Betteam,
       @ip_SportType,
       @ip_SequenceIDList,
       @ip_CustGroup  -- JSON: [{"CustID":123,"GroupID":1}, ...]
   )
   ```

5. **Inside Process SP**:
   - **Group tickets by TimeStep windows** (180 seconds)
   - **Calculate IsValidGroup**:
     ```sql
     CASE WHEN COUNT(DISTINCT CustID) > 1 
          AND SUM(Stake) >= Rule_TotalStake 
     THEN 1 ELSE 0 END
     ```
   - **Create Temp_Completed** table with groups that:
     - COUNT(DISTINCT TimeGroupID) = 1 (all in one time group)
     - MAX(IsValidGroup) = 1 (pass validation)

6. **Check IsHedging for each group**:
   ```sql
   WHILE GroupID IS NOT NULL DO
       -- Get customers in group
       -- Check latest customer classification
       -- If NOT already flagged:
       --   Call CTS_DC_Association_IsAssociatedHedgingCustByCustIDList
       -- Update IsHedging flag
   END WHILE
   ```

7. **Return complete groups and reprocess groups**

#### Round 2: Reprocess Unassigned Tickets

1. **For groups with unassigned customers** (GroupID = 0):
   - Extract CTSCustIDList of unassigned tickets
   - Run Association Detection again
   - Repeat Process SP

2. **Mark complete groups**:
   - Groups with all customers assigned to GroupID > 0
   - IsHedging flag set to TRUE

### Phase 4: Complete & Save

**Stored Procedure**: `CTS_DC_MatchMonitor_RuleHedging_Complete`

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
   WHERE SequenceID IN (...)
   ```

4. **Update MatchMonitor** (if new match)
5. **Update MatchMonitorDetails** (if new match or merge)

### Phase 5: Clean Staging Data

**Stored Procedure**: `CTS_DC_MatchMonitor_RuleHedging_StagingClean`

1. **Delete processed tickets**
   ```sql
   DELETE FROM MatchMonitorStagingHedging[Live/NonLive]
   WHERE SequenceID <= MaxSequenceID
   ```

2. **Update SystemParameter**
   ```sql
   UPDATE SystemParameter
   SET ParameterValue = MaxSequenceID
   WHERE ParameterID IN (120, 121)  -- Live/NonLive
   ```

## 🔁 Execution Schedule

### Background Jobs

| Job Name | API Endpoint | Schedule | Mode | Threads (External/Internal) |
|----------|-------------|----------|------|----------------------------|
| Hedging Detection (Live) | `/api/MatchMonitor/MatchMonitorProcessRuleHedgingLive` | Every 5 minutes | Live | Configurable (2 levels) |
| Hedging Detection (NonLive) | `/api/MatchMonitor/MatchMonitorProcessRuleHedgingNonLive` | Every 5 minutes | NonLive | Configurable (2 levels) |

**Note**: Hedging uses **2-level parallelism**:
- **External Thread**: Number of matches processed in parallel
- **Internal Thread**: Number of match groups processed in parallel per match

## 📊 Stored Procedures

### SP 1: Get Matches to Process
**Name**: `CTS_DC_MatchMonitor_RuleHedging_Get`

**Parameters**:
- `ip_LiveIndicator` (BOOLEAN)
- `op_MaxSequenceID` (BIGINT UNSIGNED) - OUTPUT

**Returns**: List of match groups with CTSCustIDList and AgentDetect_CTSCustIDList

### SP 2: Process Match
**Name**: `CTS_DC_MatchMonitor_RuleHedging_Process`

**Parameters**:
- `ip_LiveIndicator`, `ip_MatchID`, `ip_ScoreDiff`, `ip_BettypeID`, `ip_BetID`, `ip_Betteam`, `ip_SportType`
- `ip_SequenceIDList` (LONGTEXT)
- `ip_CustGroup` (JSON) - Association detection result

**Returns**: Complete groups and reprocess groups with IsHedging flag

### SP 3: Check Hedging Association
**Name**: `CTS_DC_Association_IsAssociatedHedgingCustByCustIDList`

**Parameters**:
- `ip_CustIDList` (LONGTEXT)
- `op_IsHedging` (BOOLEAN) - OUTPUT

**Purpose**: Additional check for hedging association beyond standard association detection

### SP 4: Complete and Save
**Name**: `CTS_DC_MatchMonitor_RuleHedging_Complete`

**Parameters**:
- `ip_LiveIndicator`, `ip_MaxSequenceID`, `ip_MatchID`, `ip_ScoreDiff`, `ip_BettypeID`, `ip_BetID`, `ip_Betteam`
- `ip_TransGroup` (JSON) - Complete groups with IsHedging flag

### SP 5: Clean Staging
**Name**: `CTS_DC_MatchMonitor_RuleHedging_StagingClean`

**Parameters**:
- `ip_LiveIndicator` (BOOLEAN)
- `ip_MaxSequenceID` (BIGINT UNSIGNED)

## 🎯 Key Differences

### Hedging vs Group Betting

| Feature | Hedging | Group Betting |
|---------|---------|---------------|
| **Detection Focus** | Opposite bets by same customer/group | Similar bets by multiple customers |
| **IsHedging Flag** | ✅ Yes (at transaction level) | ❌ No |
| **Association Criteria** | **3 criteria** (Device, AI, IP) | **5 criteria** (all) |
| **Agent Detection** | ✅ Yes (Alpha, Maxbet specific) | ❌ No |
| **Customer Classification Check** | ✅ Yes (IsHedgingReasonMM) | ❌ No |
| **Additional Association Check** | ✅ Yes (IsAssociatedHedgingCust SP) | ❌ No |
| **Time Window** | 180 seconds (3 minutes) | 180-300s (sport-specific) |
| **RuleGroupID** | **3** | 1 |
| **Reason** | **1** or **4** (Hedging) | 1 (GB) |
| **SystemParameter ID** | **120** (Live), **121** (NonLive) | 47, 48 |
| **Parallelism** | 2-level (External + Internal) | 1-level |

### Hedging vs Fixed Game

| Feature | Hedging | Fixed Game |
|---------|---------|------------|
| **Detection Focus** | Opposite bets to minimize risk | Suspicious betting patterns (volume, stake, odds) |
| **Association Detection** | ✅ Yes (3 criteria) | ❌ No |
| **Odds Analysis** | ❌ No | ✅ Yes (OddsSpread) |
| **High Stake Analysis** | ✅ Yes (TotalStake) | ✅ Yes (HighStakePercent) |
| **IsHedging Flag** | ✅ Yes | ❌ No |
| **Bet Type** | All types | All types |

## 📝 Example Detection Scenario

### Scenario: Hedging in Soccer HDP

**Input Tickets** (within 3 minutes):
| TransID | CustID | MatchID | BetType | Betteam | Odds | Stake | IsHedging | TransDate |
|---------|--------|---------|---------|---------|------|-------|-----------|-----------|
| 1001 | 5001 | 8001 | 1 (HDP) | h | 1.90 | 1000 | TRUE | 10:00:00 |
| 1002 | 5001 | 8001 | 1 (HDP) | a | 2.00 | 1000 | TRUE | 10:01:30 |
| 1003 | 5002 | 8001 | 1 (HDP) | h | 1.90 | 800 | TRUE | 10:02:00 |
| 1004 | 5002 | 8001 | 1 (HDP) | a | 2.00 | 800 | TRUE | 10:02:45 |

**Observations**:
- 2 customers (5001, 5002) bet on **opposite sides** (Home vs Away)
- All tickets have **IsHedging = TRUE**
- Total stake: 3600 (> threshold)
- Within 3-minute time window

**Association Detection Result**:
- Device: Same device fingerprint ✅
- AI: High similarity score ✅
- → **GroupID = 1** (both customers in same group)

**Customer Classification Check**:
- Customer 5001: Has CategoryID with `IsHedgingReasonMM = 1` ✅
- Call `CTS_DC_Association_IsAssociatedHedgingCustByCustIDList`: Returns TRUE ✅

**Detection Result**:
- Match 8001, HDP: **Hedging detected** (CustID 5001, 5002)
- IsHedging = TRUE

**Database Update**:
- **MatchMonitor**: New record with Reason = 1 (Hedging)
- **MatchMonitorDetails**: Record with TransIDList and CustIDList
- **Staging**: SET GroupID = 1 for detected tickets

## 🚀 Technical Implementation

### C# Service Layer

**File**: `fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS/Features/MatchMonitor/MatchMonitorHedging/MatchMonitorRuleHedgingProcessService.cs`

**Key Methods**:
```csharp
private IEnumerable<DetectAssociationMergeGroupEntity> DetectAssociation(
    string ctsCustIDList, string agentCTSCustIds)
{
    var param = new DetectAssociationParamModel
    {
        CTSCustIds = ctsCustIDList,
        AgentCTSCustIds = agentCTSCustIds,  // Special agent detection
        IsDevice = true,
        IsAI = true,
        IsIP = true
    };
    
    return _associationDetection.DetectAssociation(param);
}
```

### Job Service Layer

**File**: `fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS.JobService/Services/MatchMonitorJobService.cs`

**Processing Flow** (2-level parallelism):
```csharp
public Task<bool> ProcessRuleHedging(bool isLive, 
    int numberInternalOfThread,  // Internal parallelism
    int numberExternalOfThread)  // External parallelism
{
    var matchMonitorRule = _ruleHedgingService.GetMatchRuleHedging(isLive);
    
    matchMonitorRule.MatchStagingList?
        .AsParallel()
        .WithDegreeOfParallelism(numberExternalOfThread)  // Match-level
        .ForAll(matchInfo =>
        {
            _ruleHedgingService.GetInstanceProcessHedgingService()
                .PrepareProcessWithThread(matchInfo, isLive, numberInternalOfThread)  // Group-level
                .ProcessRound1()
                .ProcessRound2()
                .Complete(matchMonitorRule.MaxSequenceID.Value)
                .WriteLogSentryIfError(nameof(ProcessRuleHedging));
        });
    
    _ruleHedgingService.CleanTransRuleHedging(isLive, matchMonitorRule.MaxSequenceID.Value);
}
```

## 📚 Related Documentation

- [Match Monitor Group Betting](../GroupBetting/README.md) - Standard group betting detection
- [Match Monitor Saba Group Betting](../SabaGroupBetting/README.md) - Saba-specific group betting
- [Fixed Game Detection](../FixedGame/README.md) - Match fixing detection
- [Parlay Group Betting](../Parlay/README.md) - Parlay/combo betting detection
- [Match Monitor Classification (General)](../../General/MatchMonitorClassification/README.md) - Customer classification after detection

## 📊 Diagrams

See `puml/` folder for PlantUML diagrams:
- `Hedging_01_MainFlow.puml` - Main processing flow (5 phases)
- `Hedging_02_Sequence.puml` - Sequence diagram
- `Hedging_03_AssociationDetection.puml` - Association detection logic (3 criteria + Agent check)
- `Hedging_04_IsHedgingCheck.puml` - IsHedging flag calculation logic

## 🔧 Configuration

### System Parameters

| ParameterID | Parameter Name | Description | Default Value |
|-------------|----------------|-------------|---------------|
| 120 | MatchMonitor_HedgingLive_LastSequenceID | Last processed SequenceID (Live) | 0 |
| 121 | MatchMonitor_HedgingNonLive_LastSequenceID | Last processed SequenceID (NonLive) | 0 |
| 123 | MatchMonitor_Hedging_BatchSize | Batch size for processing | 5000 |

### Rule Settings (MatchMonitorRuleSetting)

| Field | Soccer | Basketball | Tennis |
|-------|--------|------------|--------|
| RuleGroupID | 3 | 3 | 3 |
| Reason | 1 | 1 | 1 |
| SportType | 1 | 2 | 5 |
| TimeStep | 180 sec | 180 sec | 180 sec |
| MinStake | Sport-specific | Sport-specific | Sport-specific |
| TotalStake | Sport-specific | Sport-specific | Sport-specific |
| RuleStatus | 1 (Active) | 1 | 1 |

### Customer Category Settings

**IsHedgingReasonMM** flag in CustomerCategory:
- Set to **1** for categories that should be flagged for hedging detection
- Only PA (Problem Account) categories have this flag
- Used in conjunction with association detection

---

**Last Updated**: November 2024  
**Maintained By**: CTS Development Team

