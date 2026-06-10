# Fixed Game Detection 🎯🚨

## 📋 Overview

**Fixed Game Detection** is a Match Monitor rule designed to identify matches with suspicious betting patterns that indicate potential match-fixing or sold matches. Unlike Group Betting detection, this rule focuses on analyzing **betting volume, stake patterns, and odds movements** within a short time window.

## 🎯 Purpose

Detect matches where:
- Large number of tickets are placed in a short time window
- High percentage of tickets have high stakes
- Odds spread is significant (indicating coordinated betting)
- All bets are on the same outcome or opposite outcomes with suspicious patterns

## 🔑 Key Characteristics

### 📊 Detection Criteria

The Fixed Game detection uses **5 main criteria**:

1. **TotalTicket** (Total Ticket Count)
   - Minimum number of tickets required in the time window
   - Default: **40 tickets**
   - Detects sudden surge in betting activity

2. **TimeStep** (Time Window)
   - Duration in seconds to group tickets
   - Default: **420 seconds (7 minutes)**
   - Groups tickets that occur within this time frame

3. **HighStake** (High Stake Threshold)
   - Minimum stake amount to be considered "high stake"
   - Default: **500 USD**
   - Identifies significant bets

4. **HighStakeTicketPercent** (High Stake Percentage)
   - Minimum percentage of high-stake tickets required
   - Default: **35%** (0.35)
   - Ensures significant portion of tickets are high-value

5. **OddsSpread** (Odds Spread Threshold)
   - Minimum percentage difference between max and min odds
   - Default: **10%**
   - Two formulas:
     - **Same Sign Odds**: `ABS(ABS(MaxOdds) - ABS(MinOdds)) * 100 >= OddsSpread`
     - **Different Sign Odds**: `((1 - ABS(MinNegativeOdds)) + (1 - ABS(MinPositiveOdds))) * 100 >= OddsSpread`

### 🏅 Supported Sports

| Sport | SportType | RuleGroupID | Reason | ReasonName |
|-------|-----------|-------------|--------|------------|
| ⚽ Soccer | 1 | 2 | 3 | Fixed Game |
| 🏀 Basketball | 2 | 2 | 3 | Fixed Game |
| 🎮 E-Sports | 43 | 2 | 3 | Fixed Game |

### 📂 Database Tables

#### Staging Tables (Input)
- **MatchMonitorStagingFixedGameLive** - Live match tickets
- **MatchMonitorStagingFixedGameNonLive** - Non-live match tickets

#### Result Tables (Output)
- **MatchMonitor** - Detected matches
- **MatchMonitorDetails** - Ticket and customer details

## 🔄 Processing Flow

### Phase 1: Get Matches to Process
1. Read `SystemParameter` to get last processed SequenceID
   - Live: ParameterID = **100**
   - NonLive: ParameterID = **101**
2. Get batch size from `SystemParameter`
   - Live: ParameterID = **126** (default: 5000)
   - NonLive: ParameterID = **127** (default: 5000)
3. Query staging table for new tickets
4. Group tickets by **MatchID, ScoreDiff, BettypeID, BetID, HDP, Betteam**
5. Return distinct match keys

### Phase 2: Process Each Match (Parallel)
1. **Get Rule Settings** based on SportType
   ```sql
   SELECT TimeStep, TotalTicket, HighStake, HighStakeTicketPercent, OddsSpread, Reason
   FROM MatchMonitorRuleSetting
   WHERE SportType = ? AND RuleGroupID = 2 AND RuleStatus = 1
   ```

2. **Calculate Time Window Start**
   ```sql
   SELECT TO_SECONDS(TIMESTAMPADD(SECOND, TimeStep, TransDate)) AS FromTransDate
   FROM Staging
   WHERE MatchID = ? AND ScoreDiff = ? AND BettypeID = ? ...
   ORDER BY TransDate
   LIMIT 1
   ```

3. **Load All Tickets** into temporary table `Temp_Trans`
   - Columns: TimeToSecond, TransID, SequenceID, CustID, Stake, Odds, SignNumber

4. **Group Tickets by Time Windows**
   - Group tickets by `TimeToSecond` using `TimeStep` intervals
   - Calculate for each group:
     - TotalTicket (COUNT)
     - TotalHighStake (COUNT WHERE Stake >= HighStake)
     - MinOdds, MaxOdds
     - MinNegativeOdds, MinPositiveOdds
     - MinSignNumber, MaxSignNumber

5. **Apply Detection Rules**
   
   **Rule A: Same Sign Odds** (All bets on same outcome)
   ```sql
   WHERE TotalTicket > Rule_TotalTicket
     AND (TotalHighStake / TotalTicket) > Rule_HighStakeTicketPercent
     AND ABS(ABS(MaxOdds) - ABS(MinOdds)) * 100 >= Rule_OddsSpread
     AND TimeToSecond >= FromTransDate
     AND MinSignNumber = MaxSignNumber  -- Same sign
   ```

   **Rule B: Different Sign Odds** (Bets on both outcomes)
   ```sql
   WHERE TotalTicket > Rule_TotalTicket
     AND (TotalHighStake / TotalTicket) > Rule_HighStakeTicketPercent
     AND ((1 - ABS(MinNegativeOdds)) + (1 - ABS(MinPositiveOdds))) * 100 >= Rule_OddsSpread
     AND TimeToSecond >= FromTransDate
     AND MinSignNumber != MaxSignNumber  -- Different signs
   ```

6. **Output Detected Tickets**
   ```sql
   SELECT Reason, GROUP_CONCAT(DISTINCT TransID), GROUP_CONCAT(DISTINCT CustID)
   ```

### Phase 3: Complete and Save
1. **Check if match already exists** in `MatchMonitorDetails`
   - If exists: **Merge** new tickets with existing tickets (UNION)
   - If not exists: **Insert** new record

2. **Update MatchMonitorDetails**
   ```sql
   INSERT INTO MatchMonitorDetails
   (MatchID, IsMajorLeague, LiveIndicator, ScoreDiff, BettypeID, BetID, Betteam, HDP,
    EventDate, LiveHomeScore, LiveAwayScore, ListCustID, ListTransID, Reason, GroupID)
   ```

3. **Update MatchMonitor**
   ```sql
   INSERT IGNORE INTO MatchMonitor
   (MatchID, IsMajorLeague, BettypeID, BetID, LiveIndicator, EventDate, KickOffTime,
    EventStatus, HomeID, AwayID, LeagueID, LeagueName, Sporttype, Reason)
   ```

### Phase 4: Clean Staging Data
1. Delete processed tickets from staging tables
   ```sql
   DELETE FROM MatchMonitorStagingFixedGame[Live/NonLive]
   WHERE SequenceID <= MaxSequenceID
   ```

## 🔁 Execution Schedule

### Background Jobs

| Job Name | API Endpoint | Schedule | Mode | Parallel Threads |
|----------|-------------|----------|------|------------------|
| Fixed Game Detection (Live) | `/api/MatchMonitor/MatchMonitorProcessRuleFixedGameLive` | Every 5 minutes | Live | Configurable |
| Fixed Game Detection (NonLive) | `/api/MatchMonitor/MatchMonitorProcessRuleFixedGameNonLive` | Every 5 minutes | NonLive | Configurable |

## 📊 Stored Procedures

### SP 1: Get Matches to Process
**Name**: `CTS_DC_MatchMonitor_RuleFixedGame_Get`

**Parameters**:
- `ip_LiveIndicator` (BOOLEAN) - Live (1) or NonLive (0)
- `op_MaxSequenceID` (BIGINT UNSIGNED) - OUTPUT: Max SequenceID processed

**Returns**: List of distinct match keys to process

### SP 2: Process Match
**Name**: `CTS_DC_MatchMonitor_RuleFixedGame_Process`

**Parameters**:
- `ip_LiveIndicator` (BOOLEAN)
- `ip_MaxSequenceID` (BIGINT UNSIGNED)
- `ip_MatchID` (INT UNSIGNED)
- `ip_ScoreDiff` (INT)
- `ip_BettypeID` (INT UNSIGNED)
- `ip_BetID` (BIGINT)
- `ip_HDP` (DECIMAL 8,4)
- `ip_Betteam` (VARCHAR 50)

**Returns**: JSON with detected tickets
```json
{
  "Reason": 3,
  "TransIDList": "1001,1002,1003",
  "CustIDList": "5001,5002,5003"
}
```

### SP 3: Complete and Save
**Name**: `CTS_DC_MatchMonitor_RuleFixedGame_Complete`

**Parameters**:
- `ip_LiveIndicator` (BOOLEAN)
- `ip_MaxSequenceID` (BIGINT UNSIGNED)
- `ip_MatchID` (INT)
- `ip_ScoreDiff` (INT)
- `ip_BettypeID` (INT)
- `ip_BetID` (BIGINT)
- `ip_HDP` (DECIMAL 8,4)
- `ip_Betteam` (VARCHAR 10)
- `ip_TransGroup` (JSON) - Array of detected groups

### SP 4: Clean Staging
**Name**: `CTS_DC_MatchMonitor_RuleFixedGame_StagingClean`

**Parameters**:
- `ip_LiveIndicator` (BOOLEAN)
- `ip_MaxSequenceID` (BIGINT UNSIGNED)

## 🎯 Key Differences from Group Betting

| Feature | Fixed Game | Group Betting |
|---------|-----------|---------------|
| **Detection Focus** | Ticket patterns (volume, stake, odds) | Customer associations (Device, AI, IP) |
| **Time Window** | TimeStep (7 minutes) | Multiple criteria with different windows |
| **Association Detection** | ❌ No | ✅ Yes (5 criteria) |
| **Odds Analysis** | ✅ Yes (OddsSpread) | ❌ No |
| **High Stake Analysis** | ✅ Yes (HighStakeTicketPercent) | ❌ No |
| **Parallel Processing** | ✅ By match key | ✅ By match |
| **Result Merging** | ✅ Merge with existing | ✅ Merge with existing |

## 📝 Example Detection Scenario

**Scenario**: A soccer match with suspicious betting pattern

### Input Tickets (within 7 minutes)
| TransID | CustID | Stake | Odds | Betteam | TransDate |
|---------|--------|-------|------|---------|-----------|
| 1001 | 5001 | 1000 | 1.85 | h | 10:00:00 |
| 1002 | 5002 | 800 | 1.83 | h | 10:01:30 |
| 1003 | 5003 | 1200 | 1.87 | h | 10:02:45 |
| ... | ... | ... | ... | ... | ... |
| 1045 | 5045 | 900 | 1.84 | h | 10:06:30 |

**Total**: 45 tickets (> 40) ✅  
**High Stake Tickets**: 18 (40% > 35%) ✅  
**OddsSpread**: ABS(1.87 - 1.83) * 100 = 4% ... (needs more analysis)  
**Same Sign**: All bets on Home team ✅

### Detection Result
```json
{
  "Reason": 3,
  "TransIDList": "1001,1002,1003,...,1045",
  "CustIDList": "5001,5002,5003,...,5045"
}
```

### Database Update
- **MatchMonitor**: New record with Reason = 3 (Fixed Game)
- **MatchMonitorDetails**: Record with 45 TransIDs and 45 CustIDs

## 🚀 Technical Implementation

### C# Service Layer
**File**: `fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS/Features/MatchMonitor/MatchMonitorServices.cs`

**Key Methods**:
```csharp
public interface IMatchMonitorServices
{
    MatchMonitorRuleFixedGameModel GetMatchRuleFixedGame(bool isLive);
    
    IEnumerable<MatchCompleteRuleFixedGameModel> ProcessRuleFixedGame(
        bool isLive, UInt64 maxTransId, MatchStagingRuleFixedGameModel matchinfo);
    
    void CompleteTransRuleFixedGame(MatchCompleteRuleFixedGameParameterModel para);
    
    void CleanTransRuleFixedGame(bool isLive, UInt64 maxSequenceID);
}
```

### Job Service Layer
**File**: `fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS.JobService/Services/MatchMonitorJobService.cs`

**Processing Flow**:
```csharp
public Task<bool> ProcessRuleFixedGame(bool isLive, int numberOfThread)
{
    var matchMonitorRule = _matchMonitorServices.GetMatchRuleFixedGame(isLive);
    
    matchMonitorRule.MatchStagingList
        .AsParallel()
        .WithDegreeOfParallelism(numberOfThread)
        .ForAll(matchInfo =>
        {
            var matchRuleCompleted = _matchMonitorServices.ProcessRuleFixedGame(
                isLive, matchMonitorRule.MaxSequenceID, matchInfo);
            
            if (matchRuleCompleted != null && matchRuleCompleted.Any())
            {
                _matchMonitorServices.CompleteTransRuleFixedGame(new MatchCompleteRuleFixedGameParameterModel
                {
                    IsLive = isLive,
                    MatchInfo = matchInfo,
                    TransGroupJson = JsonConvert.SerializeObject(matchRuleCompleted),
                    MaxSequenceID = matchMonitorRule.MaxSequenceID
                });
            }
        });
    
    _matchMonitorServices.CleanTransRuleFixedGame(isLive, matchMonitorRule.MaxSequenceID);
}
```

## 📚 Related Documentation

- [Match Monitor Group Betting](../GroupBetting/README.md) - Group betting detection
- [Match Monitor Saba Group Betting](../SabaGroupBetting/README.md) - Saba-specific group betting
- [Match Monitor Classification (General)](../../General/MatchMonitorClassification/README.md) - Customer classification after detection
- [Match Monitor Classification (By Sport)](../../BySport/MatchMonitorClassificationBySport/README.md) - Sport-specific customer classification

## 📊 Diagrams

See `puml/` folder for PlantUML diagrams:
- `FixedGame_01_MainFlow.puml` - Main processing flow
- `FixedGame_02_Sequence.puml` - Sequence diagram
- `FixedGame_03_DetectionLogic.puml` - Detection criteria logic
- `FixedGame_04_DatabaseFlow.puml` - Database operations

## 🔧 Configuration

### System Parameters

| ParameterID | Parameter Name | Description | Default Value |
|-------------|----------------|-------------|---------------|
| 100 | MatchMonitor_FixedGameLive_LastSequenceID | Last processed SequenceID (Live) | 0 |
| 101 | MatchMonitor_FixedGameNonLive_LastSequenceID | Last processed SequenceID (NonLive) | 0 |
| 126 | MatchMonitor_FixedGameLive_BatchSize | Batch size for live processing | 5000 |
| 127 | MatchMonitor_FixedGameNonLive_BatchSize | Batch size for non-live processing | 5000 |

### Rule Settings (MatchMonitorRuleSetting)

| Field | Soccer | Basketball | E-Sports |
|-------|--------|------------|----------|
| RuleGroupID | 2 | 2 | 2 |
| Reason | 3 | 3 | 3 |
| SportType | 1 | 2 | 43 |
| TotalTicket | 40 | 40 | 40 |
| TimeStep | 420 sec | 420 sec | 420 sec |
| HighStake | 500 | 500 | 500 |
| HighStakeTicketPercent | 0.35 | 0.35 | 0.35 |
| OddsSpread | 10 | 10 | 10 |
| LeagueType | 0 (Others League) | 0 | 0 |

---

**Last Updated**: November 2024  
**Maintained By**: CTS Development Team

