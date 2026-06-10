# 💧 Match Monitor - Irrigation Detection

## 📋 Overview

**Irrigation Detection** (Tưới tiền) identifies suspicious betting patterns where a **single customer** places multiple bets with **wide odds spread** on the **same match/bettype/side** within a **short time window**. This pattern suggests the customer is "irrigating money" (laundering or testing the system).

---

## 🎯 Purpose

| Purpose | Description |
|---------|-------------|
| **Single Customer Detection** | Focus on INDIVIDUAL customer behavior (no association) |
| **Odds Spread Analysis** | Detect wide odds variation in multiple bets |
| **Time-Based Grouping** | Bets within short time window (default 180 seconds) |
| **Stake Accumulation** | Total stake exceeds threshold |
| **Money Laundering Detection** | Identify potential money irrigation patterns |

---

## 🔍 What is Irrigation?

**Irrigation Pattern** occurs when a customer:
1. Places **multiple bets** on the **same match + bettype + side**
2. Within a **short time window** (e.g., 3 minutes)
3. With **significantly different odds** (wide spread)
4. **Total stake** exceeds threshold (e.g., $1000)

**Example:**
```
Match: Liverpool vs Man City (Asian Handicap)
Customer: User123
Bettype: Asian Handicap (BettypeID = 1)
Side: Home (Liverpool)

Bet Sequence (within 3 minutes):
- 14:00:00 | Bet Liverpool -0.5 @ 0.95 odds | $200
- 14:01:30 | Bet Liverpool -0.5 @ 1.10 odds | $300
- 14:02:45 | Bet Liverpool -0.5 @ 0.85 odds | $500

Analysis:
- Same customer: User123 ✅
- Same match/bettype/side ✅
- Time window: 2:45 (< 3 min) ✅
- Total stake: $1000 ✅
- Odds spread: |1.10 - 0.85| = 0.25 = 25% (> threshold 28%) ❌

→ NOT detected (odds spread too low)

BUT if odds were:
- 14:00:00 | @ 0.80 odds | $200
- 14:01:30 | @ 1.20 odds | $300
- 14:02:45 | @ 0.85 odds | $500

Odds spread: |1.20 - 0.80| = 0.40 = 40% (> 28%) ✅
→ DETECTED as Irrigation! 💧
```

---

## 🔄 Workflow (4 Phases)

```
┌─────────────────────────────────────────────────────┐
│ Phase 1: GET STAGING MATCHES                       │
│  ├─ Read from MatchMonitorStagingIrrigationNonLive │
│  ├─ Group by: Match, ScoreDiff, Bettype, BetID,    │
│  │             HDP, Betteam                         │
│  └─ WHERE SequenceID > LastScannedSequenceID       │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ Phase 2: PROCESS EACH MATCH (Parallel)             │
│  ├─ For each match group:                          │
│  │   ├─ Get all tickets for match                  │
│  │   ├─ Group by Customer (CustID)                 │
│  │   ├─ Time-based grouping (TimeStep)             │
│  │   ├─ Calculate odds spread per customer         │
│  │   ├─ Validate: Total Stake >= Threshold         │
│  │   ├─ Validate: Odds Spread >= Threshold         │
│  │   └─ Call SP: CTS_DC_MM_RuleIrrigation_Process  │
│  └─ Returns: Completed groups (if detected)        │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ Phase 3: COMPLETE & SAVE                           │
│  ├─ Serialize detected groups to JSON              │
│  ├─ Call SP: CTS_DC_MM_RuleIrrigation_Complete     │
│  │   ├─ INSERT into CTSMatchMonitor (Reason='IR')  │
│  │   └─ INSERT into CTSMatchMonitorDetail          │
│  └─ Update detection timestamp                     │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ Phase 4: CLEAN STAGING                             │
│  ├─ DELETE processed tickets from staging          │
│  ├─ WHERE SequenceID <= MaxSequenceID              │
│  └─ Prepare for next run                           │
└─────────────────────────────────────────────────────┘
```

---

## 📊 Detection Criteria

### 1. **Single Customer Focus**

```
⚠️ KEY DIFFERENCE: NO Association Detection!

Unlike other rules:
- Group Betting: 5 association criteria
- Saba GB: 4 association criteria
- Hedging: 3 association criteria
- Arbitrage: 3 association criteria
- Parlay: 4 association criteria

Irrigation: 0 association criteria ✅
→ Only detect INDIVIDUAL customer patterns
```

### 2. **Same Match/Bettype/Side**

```sql
-- Must be on same:
- MatchID
- ScoreDiff (live score at bet time)
- BettypeID
- BetID
- HDP (Handicap value)
- Betteam (h/a/d - Home/Away/Draw)

Example:
Match: Liverpool vs Man City
Bettype: Asian Handicap (1)
BetID: 0
HDP: -0.5
Betteam: 'h' (Home - Liverpool)

→ All bets must match these criteria
```

### 3. **Time-Based Grouping**

```
TimeStep = 180 seconds (3 minutes)

Customer bets:
- Bet 1: 14:00:00
- Bet 2: 14:02:30 → Same group (within 180s)
- Bet 3: 14:04:00 → New group (> 180s from Bet 1)

Logic:
IF (NewBet.TransDate - OldGroup.MaxTransDate) <= TimeStep
THEN Add to existing group
ELSE Create new group
```

### 4. **Total Stake Threshold**

```
MinStake = $1000 (default)

Customer bets:
- Bet 1: $200
- Bet 2: $300
- Bet 3: $400
Total: $900 ❌ (< $1000, not detected)

Customer bets:
- Bet 1: $300
- Bet 2: $400
- Bet 3: $400
Total: $1100 ✅ (>= $1000, check odds spread)
```

### 5. **Odds Spread Calculation**

**Two scenarios:**

#### Scenario A: Same Sign Odds (all positive OR all negative)

```
Formula: |MAX(Odds) - MIN(Odds)| * 100 >= OddsSpread

Example 1 - All Positive:
Bets: @ 1.20, @ 0.95, @ 1.10 odds
Spread: |1.20 - 0.95| * 100 = 25%
Threshold: 28%
Result: 25% < 28% ❌ Not detected

Example 2 - All Negative:
Bets: @ -0.80, @ -0.95, @ -1.10 odds
Spread: |-0.80 - (-1.10)| * 100 = 30%
Threshold: 28%
Result: 30% >= 28% ✅ Detected!
```

#### Scenario B: Mixed Sign Odds (positive AND negative)

```
Formula: ((1 - MIN(Positive)) + (1 - MIN(Negative))) * 100 >= OddsSpread

Example:
Bets: @ 1.20 (positive), @ -0.90 (negative), @ 0.85 (positive)

MinPositive = 0.85
MinNegative = -0.90

Spread: ((1 - 0.85) + (1 - 0.90)) * 100
      = (0.15 + 0.10) * 100
      = 25%

Threshold: 28%
Result: 25% < 28% ❌ Not detected
```

---

## 🗄️ Database Operations

### **Stored Procedures**

| SP Name | Purpose | Input | Output |
|---------|---------|-------|--------|
| `CTS_DC_MatchMonitor_RuleIrrigation_Get` | Get staging matches | `ip_LiveIndicator` | Match groups + MaxSequenceID |
| `CTS_DC_MatchMonitor_RuleIrrigation_Process` | Detect irrigation pattern | Match info, MaxSequenceID | Detected customer groups |
| `CTS_DC_MatchMonitor_RuleIrrigation_Complete` | Save detected irrigation | TransGroupJson | INSERT to CTSMatchMonitor |
| `CTS_DC_MatchMonitor_RuleIrrigation_TransClean` | Clean processed tickets | MaxSequenceID | DELETE from staging |

### **Tables Used**

#### Input:
- `MatchMonitorStagingIrrigationNonLive` (Pool 2006) - Source of tickets

#### Output:
- `CTSMatchMonitor` - Detected matches (Reason = 'IR')
- `CTSMatchMonitorDetail` - Ticket details

#### Configuration:
- `MatchMonitorRuleSetting` - Rule settings (RuleGroupID = 4)
  - TimeStep: 180 seconds (3 minutes)
  - TotalStake: $1000
  - OddsSpread: 28%
- `SystemParameter` - Last scanned SequenceID (ID = 125)

---

## 📈 Key Components

### 1. **API Endpoint**

```csharp
// fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS.JobService/Controllers/MatchMonitorController.cs

[HttpPost("MatchMonitorProcessRuleIrrigationNonLive")]
public async Task<bool> MatchMonitorRuleIrrigationNonLive([FromForm] int numberOfThread)
{
    return await this.matchMonitorJobService.ProcessRuleIrrigation(false, numberOfThread);
}
```

### 2. **Service Layer**

```csharp
// fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS.JobService/Services/MatchMonitorJobService.cs

public Task<bool> ProcessRuleIrrigation(bool isLive, int numberOfThread)
{
    try
    {
        var matchMonitorRule = _matchMonitorServices.GetMatchMonitorRuleIrrigation(isLive);
        
        if (matchMonitorRule != null && matchMonitorRule.MaxSequenceID != 0)
        {
            matchMonitorRule
                .MatchStagingList
                .AsParallel()
                .WithDegreeOfParallelism(numberOfThread)
                .ForAll(matchInfo =>
                {
                    var matchRuleCompleted = _matchMonitorServices.InsertMatchMonitorRuleIrrigation(
                        isLive, 
                        matchMonitorRule.MaxSequenceID, 
                        matchInfo
                    );
                    
                    if (matchRuleCompleted != null && matchRuleCompleted.Any())
                    {
                        _matchMonitorServices.UpdateMatchMonitorRuleIrrigationComplete(
                            new MatchMonitorRuleIrrigationCompleteParaModel
                            {
                                IsLive = isLive,
                                MatchInfo = matchInfo,
                                TransGroupJson = JsonConvert.SerializeObject(matchRuleCompleted),
                                MaxSequenceID = matchMonitorRule.MaxSequenceID
                            }
                        );
                    }
                    
                    Thread.Sleep(MatchMonitor_SleepTimes);
                });
        }
        
        _matchMonitorServices.CleanTransRuleIrrigation(isLive, matchMonitorRule.MaxSequenceID);
        
        return Task.FromResult(true);
    }
    catch (Exception ex)
    {
        Utilities.LogSentryError(serviceName, ex.Message, string.Empty, ex);
        return Task.FromResult(false);
    }
}
```

---

## 🔑 Key Concepts

### 1. **NonLive Only**

```
⚠️ IMPORTANT: Irrigation detection ONLY runs for NonLive matches!

Reason:
- Need stable odds for spread calculation
- Live odds change too rapidly
- Pattern analysis requires settled data
```

### 2. **No Association Detection**

```
SIMPLEST detection rule in Match Monitor:

✅ Focus: Single customer behavior
✅ No Device detection
✅ No AI detection
✅ No IP detection
✅ No cross-customer grouping

Just detect: "Is THIS customer irrigating money?"
```

### 3. **Old Group vs New Group**

```sql
-- Stored Procedure Logic:

Step 1: Get Old Groups (from previous runs)
  - Customer's existing groups
  - MaxTransDate per customer
  - Aggregate stats (TotalStake, Odds range)

Step 2: Get New Groups (current batch)
  - New bets in this run
  - MinTransDate per customer
  - Aggregate stats

Step 3: Merge if within TimeStep
  IF NewGroup.MinTransDate - OldGroup.MaxTransDate <= TimeStep
  THEN Merge into same group
  ELSE Create new group

Step 4: Validate Detection Criteria
  - Total Stake >= Threshold
  - Odds Spread >= Threshold
```

### 4. **Odds Sign Handling**

```
Positive Odds: 0.85, 1.10, 1.20 (European/Decimal)
Negative Odds: -0.80, -0.95, -1.10 (American/Malaysian)

Detection handles BOTH:
- Same sign: Simple max-min difference
- Mixed sign: Complex formula with minimums
```

---

## ⏱️ Execution Schedule

| Job | Frequency | Batch Size | Parallelism |
|-----|-----------|------------|-------------|
| **Irrigation Detection (NonLive)** | Every 5 minutes | 5000 matches | 4 threads |

> **Note**: Only NonLive supported. No Live detection.

---

## 🚨 Detection Example

### Scenario: Money Irrigation Pattern

```
Match: Liverpool vs Man City
Bettype: Asian Handicap (BettypeID = 1)
HDP: -0.5
Betteam: 'h' (Home - Liverpool)
SportType: Soccer (1)

Customer: User12345

Bet Sequence:
┌─────────────────────────────────────────────────┐
│ Time      │ Odds   │ Stake  │ SignNumber       │
├─────────────────────────────────────────────────┤
│ 14:00:00  │ -0.80  │ $200   │ -1 (negative)    │
│ 14:01:30  │  1.20  │ $400   │  1 (positive)    │
│ 14:02:45  │  0.85  │ $500   │  1 (positive)    │
└─────────────────────────────────────────────────┘

Analysis:
1. Same Customer: User12345 ✅
2. Same Match/Bettype/Side ✅
3. Time Window: 2:45 (165 seconds < 180s) ✅
4. Total Stake: $1100 (>= $1000) ✅
5. Odds Spread (Mixed Sign):
   MinPositive = 0.85
   MinNegative = -0.80
   
   Spread = ((1 - 0.85) + (1 - 0.80)) * 100
          = (0.15 + 0.20) * 100
          = 35%
   
   Threshold = 28%
   Result: 35% >= 28% ✅

Result:
→ DETECTED as Irrigation! 💧
→ INSERT CTSMatchMonitor (Reason = 'IR')
→ Customer flagged for review
```

---

## 📊 Performance Characteristics

| Metric | Value |
|--------|-------|
| **Parallel Processing** | 4 threads (default) |
| **Batch Size** | 5000 matches per run |
| **Association Criteria** | 0 (NO association) |
| **Detection Focus** | Single customer only |
| **Time Window** | 180 seconds (3 minutes) |
| **Sleep Time** | 50ms between matches |
| **Max Delay** | ~5 minutes from ticket settlement |

---

## 🔗 Related Documentation

- [Insert Ticket Detail](../InsertTicketDetail/README.md) - Inserts tickets to Pool 2006
- [Group Betting Detection](../GroupBetting/README.md) - Uses 5 association criteria
- [Fixed Game Detection](../FixedGame/README.md) - Also no association, but different focus
- [Match Monitor Classification (General)](../../General/MatchMonitorClassification/README.md) - CC assignment

---

## 📝 Notes

1. **NonLive Only**: Irrigation detection ONLY runs for settled matches (NonLive). No live detection.
2. **No Association**: Simplest rule - NO association detection. Only analyzes individual customers.
3. **Odds Spread Focus**: Key metric is odds variation within customer's bets.
4. **Time-Based Grouping**: Groups bets within TimeStep window (default 180 seconds).
5. **Stake Threshold**: Only detects customers with sufficient total stake ($1000).
6. **Two Odds Formulas**: Different calculations for same-sign vs mixed-sign odds.
7. **Pool 2006**: Reads from `MatchMonitorStagingIrrigationNonLive` staging table.
8. **Reason Code**: Detected matches marked with `Reason = 'IR'` in CTSMatchMonitor.
9. **Money Laundering**: Primary use case is detecting money irrigation/laundering patterns.

---

## 🎯 Detection vs Other Rules

| Feature | Group Betting | Saba GB | Fixed Game | Hedging | Parlay | Arbitrage | **Irrigation** |
|---------|--------------|---------|-----------|---------|--------|-----------|---------------|
| **Live Support** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ❌ NonLive | ❌ **NonLive Only** |
| **Association Criteria** | 5 | 4 | ❌ None | 3 | 4 | 3 | ❌ **None (0)** |
| **Detection Scope** | Multi-customer | Multi-customer | Match-level | Multi-customer | Multi-customer | Multi-customer | **Single customer** |
| **Key Metric** | Association | Association | Volume/Stake | Opposite bets | Association | Odds difference | **Odds Spread** |
| **Time Grouping** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes | ✅ **Yes (180s)** |
| **Staging Pool** | 1001/2001 | 1002/2002 | 1004/2005 | 1003/2003 | Separate | 2004 | **2006** |
| **Reason Code** | GB | GB | FG | HD | PL | AR | **IR** |

---

**Last Updated**: 2025-11-19  
**Author**: Analysis Team  
**Related Module**: Match Monitor

