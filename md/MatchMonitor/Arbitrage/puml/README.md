# 💹 Match Monitor - Arbitrage Detection

## 📋 Overview

**Arbitrage Detection** identifies customers who exploit **odds differences between bookmakers** to guarantee profit regardless of match outcome. This is also known as "Sure Betting" or "Miracle Betting" where customers place bets on all possible outcomes across multiple platforms at favorable odds.

---

## 🎯 Purpose

| Purpose | Description |
|---------|-------------|
| **Cross-Platform Detection** | Detect betting across multiple bookmakers (platforms) |
| **Profit Guarantee** | Identify bets that guarantee profit regardless of outcome |
| **Association Analysis** | Link related customers using 3 criteria (Device, AI, IP) |
| **Agent Detection** | Special handling for Alpha (168) and Maxbet (169) agents |
| **Risk Mitigation** | Flag suspicious arbitrage patterns for review |

---

## 🔍 What is Arbitrage?

**Arbitrage Opportunity** occurs when:
```
(1/Odds_Platform_A) + (1/Odds_Platform_B) < 1
```

**Example:**
```
Match: Barcelona vs Real Madrid (1X2)

Platform A (Alpha):
- Barcelona Win @ 2.20 odds → 1/2.20 = 0.454

Platform B (Maxbet):  
- Real Madrid Win @ 2.10 odds → 1/2.10 = 0.476

Total: 0.454 + 0.476 = 0.93 < 1 ✅ ARBITRAGE!

Customer bets:
- $1000 on Barcelona @ Platform A
- $1000 on Real Madrid @ Platform B

Outcomes:
- If Barcelona wins: Win $1200, Lose $1000 = +$200 profit
- If Real Madrid wins: Win $1100, Lose $1000 = +$100 profit
- If Draw: Lose both = -$2000 (risk)

→ 7% guaranteed profit on 2 outcomes!
```

---

## 🔄 Workflow (5 Phases)

```
┌─────────────────────────────────────────────────────┐
│ Phase 1: GET STAGING MATCHES                       │
│  ├─ Read from MatchMonitorStagingArbitrageNonLive  │
│  ├─ Group by: Match, ScoreDiff, Bettype, BetID, HDP│
│  └─ WHERE SequenceID > LastScannedSequenceID       │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ Phase 2: PROCESS ROUND 1 (Parallel)                │
│  ├─ For each match group:                          │
│  │   ├─ Detect Association (Device, AI, IP)        │
│  │   ├─ Group customers by association             │
│  │   ├─ Check Agent customers (Alpha/Maxbet)       │
│  │   └─ Call SP: CTS_DC_MM_RuleArbitrage_Process   │
│  └─ Returns: Complete + Reprocess lists            │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ Phase 3: PROCESS ROUND 2 (Reprocess)               │
│  ├─ For tickets that need reprocessing:            │
│  │   ├─ Re-detect Association with new data        │
│  │   ├─ Check if new groups formed                 │
│  │   └─ Call SP: CTS_DC_MM_RuleArbitrage_Process   │
│  └─ Returns: Additional Complete matches           │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ Phase 4: COMPLETE & SAVE                           │
│  ├─ Merge results from Round 1 + Round 2           │
│  ├─ Assign GroupID to detected groups              │
│  ├─ Call SP: CTS_DC_MM_RuleArbitrage_Complete      │
│  │   ├─ INSERT into CTSMatchMonitor (Reason='AR')  │
│  │   └─ INSERT into CTSMatchMonitorDetail          │
│  └─ Update detection timestamp                     │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ Phase 5: CLEAN STAGING                             │
│  ├─ DELETE processed tickets from staging          │
│  ├─ WHERE SequenceID <= MaxSequenceID              │
│  └─ Prepare for next run                           │
└─────────────────────────────────────────────────────┘
```

---

## 📊 Detection Criteria

### 1. **Association Detection (3 Criteria)**

| Criterion | Description | Priority |
|-----------|-------------|----------|
| **Device** | Same device fingerprint across platforms | High |
| **AI** | AI-identified patterns linking customers | High |
| **IP** | Same IP address within time window | Medium |

> **Note**: Unlike Group Betting (5 criteria) or Parlay (4 criteria), Arbitrage uses only **3 criteria** - same as Hedging.

### 2. **Opposite Bet Detection**

```sql
-- Example: Detect opposite bets on same match
Match: Liverpool vs Man City (Asian Handicap)

Group 1: Customer A, B, C
- Bet: Liverpool -0.5 @ Platform Alpha
- Stake: $500 each

Group 2: Customer D, E (Associated with Group 1)
- Bet: Man City +0.5 @ Platform Maxbet  
- Stake: $500 each

→ Detected as Arbitrage if odds favorable
```

### 3. **Agent Detection**

Special handling for specific agents:
- **Alpha (SubscriberID = 168)**
- **Maxbet (SubscriberID = 169)**

Arbitrage is more common across these platforms due to odds differences.

### 4. **Time-Based Grouping**

```
TimeStep = 300 seconds (5 minutes)

Tickets within same TimeGroup:
- Ticket 1: 14:00:00
- Ticket 2: 14:02:30 → Same group
- Ticket 3: 14:04:59 → Same group
- Ticket 4: 14:05:01 → New group
```

### 5. **Stake Threshold**

```
MinStake per customer (configurable):
- Major League: $500
- Minor League: $200

Only consider customers with Stake >= MinStake
```

---

## 🗄️ Database Operations

### **Stored Procedures**

| SP Name | Purpose | Input | Output |
|---------|---------|-------|--------|
| `CTS_DC_MatchMonitor_RuleArbitrage_Get` | Get staging matches | `ip_LiveIndicator` | Match groups + MaxSequenceID |
| `CTS_DC_MatchMonitor_RuleArbitrage_Process` | Process association detection | Match info, CustGroup JSON | Complete + Reprocess lists |
| `CTS_DC_MatchMonitor_RuleArbitrage_Complete` | Save detected arbitrage | TransGroupJson | INSERT to CTSMatchMonitor |
| `CTS_DC_MatchMonitor_RuleArbitrage_TransClean` | Clean processed tickets | MaxSequenceID | DELETE from staging |

### **Tables Used**

#### Input:
- `MatchMonitorStagingArbitrageNonLive` (Pool 2004) - Source of tickets

#### Output:
- `CTSMatchMonitor` - Detected matches (Reason = 'AR')
- `CTSMatchMonitorDetail` - Ticket details

#### Configuration:
- `MatchMonitorRuleSetting` - Rule settings (RuleGroupID = 5)
- `SystemParameter` - Last scanned SequenceID (ID = 128)

---

## 📈 Key Components

### 1. **API Endpoint**

```csharp
// fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS.JobService/Controllers/MatchMonitorController.cs

[HttpPost("MatchMonitorProcessRuleArbitrageNonLive")]
public async Task<bool> MatchMonitorRuleArbitrageNonLive([FromForm] int numberOfThread)
{
    return await this.matchMonitorJobService.ProcessRuleArbitrage(false, numberOfThread);
}
```

### 2. **Service Layer**

```csharp
// fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS.JobService/Services/MatchMonitorJobService.cs

public Task<bool> ProcessRuleArbitrage(bool isLive, int numberOfThread)
{
    try
    {
        var matchMonitorRule = _ruleArbitrageService.GetMatchRuleArbitrage(isLive);
        
        if (matchMonitorRule != null && matchMonitorRule.MaxSequenceID.HasValue)
        {
            matchMonitorRule.MatchStagingList?
                .AsParallel()
                .WithDegreeOfParallelism(numberOfThread)
                .ForAll(matchInfo =>
                {
                    _ruleArbitrageService
                        .GetInstanceProcessArbitrageService()
                        .PrepareProcess(matchInfo, isLive)
                        .ProcessRound1()
                        .ProcessRound2()
                        .Complete(matchMonitorRule.MaxSequenceID.Value)
                        .WriteLogSentryIfError(nameof(ProcessRuleArbitrage));
                });
            
            _ruleArbitrageService.CleanTransRuleArbitrage(isLive, matchMonitorRule.MaxSequenceID.Value);
        }
        
        return Task.FromResult(true);
    }
    catch (Exception ex)
    {
        Utilities.LogSentryError(serviceName, ex.Message, string.Empty, ex);
        return Task.FromResult(false);
    }
}
```

### 3. **Process Service**

```csharp
// fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS/Features/MatchMonitor/MatchMonitorArbitrage/MatchMonitorRuleArbitrageProcessService.cs

public IMatchMonitorRuleProcessService ProcessRound1()
{
    if (MatchStaging != null && MatchStaging.MatchGroupStagingList.IsNotNullOrEmpty())
    {
        var matchProcessesRound1 =
            MatchStaging.MatchGroupStagingList
                .Select(matchInfo => ProcessWithAssociationRound1(matchInfo, IsLive))
                .Where(matchInfo => matchInfo != null)
                .ToList();
        
        MatchProcesses.AddRange(matchProcessesRound1);
    }
    
    return this;
}

private MatchProcessRuleArbitrageModel ProcessWithAssociationRound1(MatchStagingRuleArbitrageEntity matchInfo, bool isLive)
{
    // Detect Association: Device, AI, IP (3 criteria)
    var assDetectionHasGroupID = DetectAssociation(
        matchInfo.CTSCustIDList, 
        matchInfo.AgentDetect_CTSCustIDList
    )?.Where(c => c.GroupID != null);
    
    if (assDetectionHasGroupID.IsNotNullOrEmpty())
    {
        return ProcessRuleArbitrage(
            isLive, 
            matchInfo, 
            matchInfo.SequenceIDList, 
            JsonConvert.SerializeObject(assDetectionHasGroupID)
        );
    }
    
    return null;
}

private IEnumerable<DetectAssociationMergeGroupEntity> DetectAssociation(string ctsCustIDList, string agentCTSCustIds)
{
    var param = new DetectAssociationParamModel
    {
        CTSCustIds = ctsCustIDList,
        AgentCTSCustIds = agentCTSCustIds,
        IsDevice = true,  // ✅
        IsAI = true,      // ✅
        IsIP = true       // ✅
    };
    
    return _assDetect.DetectAssociation(param);
}
```

---

## 🔑 Key Concepts

### 1. **NonLive Only**

```
⚠️ IMPORTANT: Arbitrage detection ONLY runs for NonLive matches!

Reason:
- Arbitrage requires odds comparison across platforms
- Live odds change too rapidly
- Need settled matches to verify patterns
```

### 2. **2-Round Processing**

```
Round 1:
- Initial association detection
- Process all matches in parallel
- Returns: Complete + Reprocess lists

Round 2:
- Reprocess tickets that need more data
- Re-detect association with updated info
- Returns: Additional Complete matches

Why 2 rounds?
- Some associations only visible after Round 1 processing
- Example: New customers added mid-processing
```

### 3. **Group Detection Logic**

```sql
-- Stored Procedure: CTS_DC_MatchMonitor_RuleArbitrage_Process

Step 1: Parse CustGroup JSON
  [{"CustID": 12345, "GroupID": 1}, ...]

Step 2: Get all tickets for these customers
  WHERE SequenceID IN (...)
  AND CustID IN (CustGroup)

Step 3: Time-based grouping
  TimeGroupID = FLOOR(TransDateToSecond / TimeStep)
  
Step 4: Check opposite bets
  GROUP BY TimeGroupID, Betteam
  HAVING COUNT(DISTINCT Betteam) > 1  ← Opposite bets!

Step 5: Validate stake threshold
  SUM(Stake) >= MinStake per customer
```

### 4. **Agent-Specific Detection**

```
Alpha (SubscriberID = 168):
- Platform A with specific odds

Maxbet (SubscriberID = 169):
- Platform B with different odds

Arbitrage commonly occurs between these platforms
due to odds differences.
```

### 5. **Fluent Interface Pattern**

```csharp
_ruleArbitrageService
    .GetInstanceProcessArbitrageService()
    .PrepareProcess(matchInfo, isLive)    // Step 1: Setup
    .ProcessRound1()                      // Step 2: First pass
    .ProcessRound2()                      // Step 3: Reprocess
    .Complete(maxSequenceID)              // Step 4: Save results
    .WriteLogSentryIfError(nameof(...));  // Step 5: Error logging
```

---

## ⏱️ Execution Schedule

| Job | Frequency | Batch Size | Parallelism |
|-----|-----------|------------|-------------|
| **Arbitrage Detection (NonLive)** | Every 5 minutes | 5000 matches | 4 threads |

> **Note**: Only NonLive supported. No Live detection.

---

## 🚨 Detection Example

### Scenario: Cross-Platform Arbitrage

```
Match: Liverpool vs Man City
Bettype: Asian Handicap (BettypeID = 1)
HDP: -0.5 / +0.5

Platform Alpha (SubscriberID = 168):
  Customer A: Bet Liverpool -0.5 @ 2.10 odds, Stake $1000
  Customer B: Bet Liverpool -0.5 @ 2.10 odds, Stake $1000
  Customer C: Bet Liverpool -0.5 @ 2.10 odds, Stake $1000

Platform Maxbet (SubscriberID = 169):
  Customer D: Bet Man City +0.5 @ 2.05 odds, Stake $1500
  Customer E: Bet Man City +0.5 @ 2.05 odds, Stake $1500

Association Detection:
  - Customer A, B, C: Same Device ID (abc123)
  - Customer D, E: Same Device ID (xyz789)
  - Customer A & D: Same IP address
  - Customer B & E: AI detected association

Result:
  → All 5 customers linked into 1 group
  → Opposite bets detected (Liverpool vs Man City)
  → Total stake: $6000
  → Match marked as Arbitrage (Reason = 'AR')
  → All customers flagged for review
```

---

## 📊 Performance Characteristics

| Metric | Value |
|--------|-------|
| **Parallel Processing** | 4 threads (default) |
| **Batch Size** | 5000 matches per run |
| **Association Criteria** | 3 criteria (Device, AI, IP) |
| **Processing Rounds** | 2 rounds (Initial + Reprocess) |
| **Sleep Time** | 50ms between matches |
| **Max Delay** | ~5 minutes from ticket settlement |

---

## 🔗 Related Documentation

- [Insert Ticket Detail](../InsertTicketDetail/README.md) - Inserts tickets to Pool 2004
- [Hedging Detection](../Hedging/README.md) - Similar 3-criteria association
- [Group Betting Detection](../GroupBetting/README.md) - Uses 5 criteria
- [Match Monitor Classification (General)](../../General/MatchMonitorClassification/README.md) - CC assignment

---

## 📝 Notes

1. **NonLive Only**: Arbitrage detection ONLY runs for settled matches (NonLive). No live detection.
2. **3 Criteria**: Uses Device, AI, IP (same as Hedging) - fewer than Group Betting (5) or Parlay (4).
3. **Agent Detection**: Special handling for Alpha (168) and Maxbet (169) platforms.
4. **Cross-Platform**: Designed to detect betting across multiple bookmakers.
5. **2 Rounds**: Processes twice to catch associations that emerge during processing.
6. **Time-Based Grouping**: Groups tickets within TimeStep window (default 5 minutes).
7. **Stake Threshold**: Only detects customers with sufficient stake amount.
8. **Pool 2004**: Reads from `MatchMonitorStagingArbitrageNonLive` staging table.

---

## 🎯 Detection vs Other Rules

| Feature | Group Betting | Saba GB | Fixed Game | Hedging | Parlay | **Arbitrage** |
|---------|--------------|---------|-----------|---------|--------|--------------|
| **Live Support** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ❌ **NonLive Only** |
| **Association Criteria** | 5 | 4 | ❌ None | 3 | 4 | **3** |
| **Cross-Platform** | ❌ No | ❌ No | ❌ No | ✅ Yes | ❌ No | **✅ Yes** |
| **Opposite Bets** | ❌ No | ❌ No | ❌ No | ✅ Yes | ❌ No | **✅ Yes** |
| **Agent Detection** | ❌ No | ❌ No | ❌ No | ✅ Yes | ❌ No | **✅ Yes** |
| **Staging Pool** | 1001/2001 | 1002/2002 | 1004/2005 | 1003/2003 | Separate | **2004** |
| **Reason Code** | GB | GB | FG | HD | PL | **AR** |

---

**Last Updated**: 2025-11-19  
**Author**: Analysis Team  
**Related Module**: Match Monitor

