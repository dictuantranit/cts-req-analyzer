# Match Monitor Saba Group Betting Diagrams

## Overview
This directory contains PlantUML diagrams documenting the **Match Monitor Saba Group Betting Rule Processing** feature, which detects suspicious group betting patterns specifically for the **Saba Sports platform**.

## Feature Summary
**Match Monitor Saba Group Betting** is a specialized rule within the SPU (Special Processing Unit) system that:
- Detects group betting patterns for Saba platform specifically
- Uses **CustID Mapping Dictionary** (unique to Saba)
- Simplified association detection (no sport-specific settings)
- Processes matches in parallel with 2-round detection
- Same overall architecture as standard Group Betting

## Key Differences vs Standard Group Betting

| Aspect | Standard Group Betting | Saba Group Betting |
|--------|----------------------|-------------------|
| **Platform** | All platforms | Saba Sports only |
| **CustID Mapping** | Direct CTSCustID usage | Uses MappingCustDictionary |
| **Association Settings** | Sport-specific (DeviceSports, IPSports, etc.) | Fixed settings (all enabled) |
| **Detection Criteria** | 5 criteria (Device, AI, IP, 3Matches, IPLast3Days) | 4 criteria (Device, AI, IP, 3Matches) |
| **LicCustList** | Used for IPLast3Days detection | Not used |
| **Complexity** | More complex with sport configurations | Simpler, fixed configuration |

## Diagrams

1. **SabaGroupBetting_01_MainFlow.puml** - Main Business Flow (2 Phases)
2. **SabaGroupBetting_02_Sequence.puml** - Sequence Diagram (Detailed)
3. **SabaGroupBetting_03_MappingDictionary.puml** - CustID Mapping Logic
4. **SabaGroupBetting_04_ProcessingFlow.puml** - Processing Phase Flow (Round 1 & 2)
5. **SabaGroupBetting_05_AssociationDetection.puml** - Simplified Association Detection
6. **SabaGroupBetting_06_DatabaseFlow.puml** - Database Operations Flow
7. **SabaGroupBetting_07_CompleteFlow.puml** - Complete & Clean Flow

---

### 1. **SabaGroupBetting_MainFlow** (Activity Diagram)
- **Purpose**: High-level overview of Saba Group Betting detection
- **Content**: 
  - Phase 1: Staging (shared with other rules)
  - Phase 2: Processing (Saba-specific)
- **Highlights**: MappingCustDictionary usage
- **Use**: Overview for stakeholders

### 2. **SabaGroupBetting_Sequence** (Sequence Diagram)
- **Purpose**: Detailed sequence of interactions
- **Content**:
  - Controller → JobService → Service → DataAccess → Database
  - Mapping dictionary creation
  - Association detection flow
- **Components**:
  - `MatchMonitorController`
  - `MatchMonitorJobService`
  - `MMRuleSabaGBService`
  - `MMRuleSabaGBProcessService`
  - `AssociationDetectionService`
- **Use**: Technical documentation

### 3. **SabaGroupBetting_MappingDictionary** (Component Diagram)
- **Purpose**: Explain CustID Mapping logic (unique to Saba)
- **Content**:
  - Why Saba needs mapping
  - How dictionary is created
  - Usage in association detection
- **Key Concept**: CustID → CTSCustID mapping
- **Use**: Understanding Saba-specific logic

### 4. **SabaGroupBetting_ProcessingFlow** (Activity Diagram)
- **Purpose**: Detailed processing phase flow
- **Content**:
  - Get match list with mapping dictionary
  - Parallel processing (multiple threads)
  - Round 1: Initial detection
  - Round 2: Re-processing
  - Complete: Save results
  - Clean: Remove processed transactions
- **Differences from Standard**: Mapping dictionary passed to process service
- **Use**: Understanding detection logic

### 5. **SabaGroupBetting_AssociationDetection** (Component Diagram)
- **Purpose**: Simplified association detection for Saba
- **Content**:
  - Fixed detection criteria (no sport-specific)
  - IsDevice = true
  - IsAI = true
  - IsIP = true
  - Is3MatchesLast7Days = true
  - MappingCustDictionary usage
- **Key Difference**: No IPLast3Days, no sport configuration
- **Use**: Understanding Saba detection criteria

### 6. **SabaGroupBetting_DatabaseFlow** (Activity Diagram)
- **Purpose**: Database operations and SPs
- **Content**:
  - All stored procedure calls
  - Saba-specific SPs
  - Parameters and return values
- **Stored Procedures**:
  - `CTS_MatchMonitor_RuleSabaGB_Get`
  - `CTS_MatchMonitor_RuleSabaGB_Process`
  - `CTS_MatchMonitor_RuleSabaGB_Complete`
  - `CTS_MatchMonitor_RuleSabaGB_Clean`
- **Use**: Database documentation

### 7. **SabaGroupBetting_CompleteFlow** (Activity Diagram)
- **Purpose**: Complete and clean-up operations
- **Content**:
  - Same as standard Group Betting
  - Merge Round 1 & 2 results
  - Assign GroupID
  - Insert into Saba result table
  - Clean-up old data
- **Use**: Understanding result persistence

---

## Key Components

### Controllers
- **MatchMonitorController**: API endpoint controller
  - Route: `/api/matchmonitor`
  - Endpoints:
    - `POST /MatchMonitorProcessRuleSabaGroupBettingLive`
    - `POST /MatchMonitorProcessRuleSabaGroupBettingNonLive`

### Services

#### Job Services
- **MatchMonitorJobService**: Main job orchestrator
  - Methods:
    - `ProcessRuleSabaGroupBetting(isLive, numberOfThread)`

#### Business Services
- **MMRuleSabaGBService**: Saba rule service
  - Methods:
    - `GetMatchRuleSabaGB(isLive)` - Returns matches with MappingCustDictionary
    - `GetInstanceProcessSabaGBService()` - Get process service instance
    - `CleanTransRuleSabaGB(isLive, maxSequenceID)` - Clean up

- **MMRuleSabaGBProcessService**: Saba processing service
  - Interface: `IMatchMonitorRuleProcessService<MatchStagingRuleSabaGBGroupModel>`
  - Methods:
    - `PrepareProcess(matchStaging, isLive, mappingCustDictionary)` - With mapping dict!
    - `ProcessRound1()`
    - `ProcessRound2()`
    - `Complete(maxSequenceID)`
    - `WriteLogSentryIfError(functionName)`

- **AssociationDetectionService**: Detection service (shared)
  - Methods:
    - `DetectAssociation(params)` - With MappingCustDictionary

### Data Access
- **MMRuleSabaGBDataAccess**: Saba database operations

### Models

#### Processing Models
```csharp
public class MatchStagingRuleSabaGBProcessModel
{
    public ulong? MaxSequenceID { get; set; }
    public IReadOnlyDictionary<int, int> MappingCustDictionary { get; set; }  // ← Saba-specific!
    public IEnumerable<MatchStagingRuleSabaGBGroupModel> MatchStagingList { get; set; }
}

public class MatchStagingRuleSabaGBGroupModel
{
    public long MatchId { get; set; }
    public string ScoreDiff { get; set; }
    public int BetTypeID { get; set; }
    public string BetID { get; set; }
    public string BetTeam { get; set; }
    public List<MatchStagingRuleSabaGBEntity> MatchGroupStagingList { get; set; }
}
```

#### Mapping Dictionary
```csharp
// Created in MMRuleSabaGBService.GetMatchRuleSabaGB()
MappingCustDictionary = match?.CTSCustomerList
    .Select(x => new { x.CustID, x.CTSCustID })
    .Distinct()
    .ToDictionary(x => x.CustID, x => x.CTSCustID);

// Type: IReadOnlyDictionary<int, int>
// Key: CustID (int)
// Value: CTSCustID (int)
// Purpose: Map Saba CustID to CTS internal ID
```

---

## Stored Procedures

### Processing Phase

#### 1. CTS_MatchMonitor_RuleSabaGB_Get
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Get matches for Saba group betting detection  
**Input**:
- `@IsLive` (bit)

**Output**:
- `MaxSequenceID` (bigint)
- `CTSCustomerList` - For creating MappingCustDictionary
- `MatchStagingList` - Grouped matches

**Key Feature**: Returns CTSCustomerList for mapping creation

**Logic**:
```sql
-- Get MaxSequenceID
SELECT MAX(SequenceID) as MaxSequenceID
FROM CTSMatchMonitorStaging
WHERE IsLive = @IsLive 
    AND PoolType = 2  -- Saba Pool
    AND IsProcessed = 0;

-- Get Customer Mapping
SELECT DISTINCT CustID, CTSCustID
FROM CTSMatchMonitorStaging
WHERE IsLive = @IsLive 
    AND PoolType = 2
    AND IsProcessed = 0;

-- Get Match List (Grouped)
SELECT MatchID, ScoreDiff, BettypeID, BetID, Betteam,
       GROUP_CONCAT(SequenceID) as SequenceIDList,
       GROUP_CONCAT(CTSCustID) as CTSCustIDList,
       GROUP_CONCAT(CustID) as CustIDList,
       SportType
FROM CTSMatchMonitorStaging
WHERE IsLive = @IsLive 
    AND PoolType = 2
    AND IsProcessed = 0
GROUP BY MatchID, ScoreDiff, BettypeID, BetID, Betteam;
```

#### 2. CTS_MatchMonitor_RuleSabaGB_Process
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Process Saba group betting detection  
**Input**:
- `@IsLive` (bit)
- `@MatchInfo` (JSON)
- `@SequenceIDList` (string)
- `@GroupDetection` (JSON) - Association results

**Output**:
- `MatchProcessRuleSabaGBModel` (multiple result sets)

**Same logic as standard GroupBetting**

#### 3. CTS_MatchMonitor_RuleSabaGB_Complete
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Save Saba detection results  
**Input**:
- `@IsLive` (bit)
- `@MatchInfo` (JSON)
- `@MaxSequenceID` (bigint)
- `@TransGroupJson` (JSON)

**Logic**:
```sql
-- Insert into Saba result table
INSERT INTO CTSMatchMonitorRuleSabaGroupBetting (
    MatchID, GroupID, TransIDList, CustIDList,
    AssociationType, TotalAmount, TotalOdds,
    DetectionType, RuleScore, IsLive, CreatedDate
)
SELECT ...
FROM JSON_TABLE(@TransGroupJson, ...);

-- Mark as processed
UPDATE CTSMatchMonitorStaging
SET IsProcessed = 1, ProcessedDate = NOW()
WHERE SequenceID IN (...);
```

#### 4. CTS_MatchMonitor_RuleSabaGB_Clean
**Database**: CTS_DataCenter (MySQL)  
**Purpose**: Clean up old Saba transactions  
**Input**:
- `@IsLive` (bit)
- `@MaxSequenceID` (bigint)

**Logic**:
```sql
DELETE FROM CTSMatchMonitorStaging
WHERE IsLive = @IsLive
    AND PoolType = 2  -- Saba Pool
    AND IsProcessed = 1
    AND SequenceID <= @MaxSequenceID
    AND ProcessedDate < DATE_SUB(NOW(), INTERVAL 7 DAY);
```

---

## Flow Summary

### Phase 1: Staging (Shared)
Same as standard Group Betting - Insert tickets into staging with PoolType = 2 (Saba)

### Phase 2: Processing (Saba-Specific)
1. **Trigger**: HTTP POST to `/api/matchmonitor/MatchMonitorProcessRuleSabaGroupBettingLive`
2. **Get Matches**: From staging with MappingCustDictionary creation
3. **Parallel Process**: Multiple matches simultaneously
   - **Round 1**: Initial association detection (fixed criteria)
   - **Round 2**: Re-process with refined groups
4. **Complete**: Merge results, assign GroupID, save to Saba table
5. **Clean**: Remove processed transactions from Saba pool

---

## Association Detection for Saba

### Fixed Detection Criteria

```csharp
var param = new DetectAssociationParamModel
{
    CTSCustIds = ctsCustIDList,
    CustIds = custIDList,
    IsDevice = true,           // Always enabled
    IsAI = true,               // Always enabled
    IsIP = true,               // Always enabled
    Is3MatchesLast7Days = true, // Always enabled
    MappingCustDictionary = MappingCustDictionary  // Saba-specific!
};
```

### Key Differences:
- ❌ **No sport-specific settings**: All criteria always enabled
- ❌ **No IPLast3Days**: Not used for Saba
- ❌ **No LicCustList**: Not needed
- ✅ **MappingCustDictionary**: Essential for Saba CustID mapping

---

## MappingCustDictionary Explanation

### Why Needed?
Saba platform may use different customer IDs than CTS internal system. The mapping dictionary bridges this gap.

### Creation:
```csharp
// From MMRuleSabaGBService.GetMatchRuleSabaGB()
MappingCustDictionary = match?.CTSCustomerList
    .Select(x => new { x.CustID, x.CTSCustID })
    .Distinct()
    .ToDictionary(x => x.CustID, x => x.CTSCustID);
```

### Usage:
```csharp
// Passed to association detection
_assDetectService.DetectAssociation(new DetectAssociationParamModel {
    ...
    MappingCustDictionary = MappingCustDictionary
});
```

### Example:
```
Saba CustID → CTS CTSCustID
---------------------------------
101 → 5001
102 → 5002
103 → 5003
...

Dictionary: { 101: 5001, 102: 5002, 103: 5003, ... }
```

---

## Design Patterns

### 1. Fluent Interface Pattern
Same as standard Group Betting:
```csharp
_ruleSabaGBService.GetInstanceProcessSabaGBService()
    .PrepareProcess(matchInfo, isLive, mappingCustDictionary)
    .ProcessRound1()
    .ProcessRound2()
    .Complete(maxSequenceID)
    .WriteLogSentryIfError(nameof(ProcessRuleSabaGroupBetting));
```

### 2. Strategy Pattern
Implements same interface as other rules:
```csharp
public interface IMatchMonitorRuleProcessService<T>
{
    IMatchMonitorRuleProcessService PrepareProcess(T matchStaging, bool isLive, 
        IReadOnlyDictionary<int, int> mappingCustDictionary = null);
    IMatchMonitorRuleProcessService ProcessRound1();
    IMatchMonitorRuleProcessService ProcessRound2();
    IMatchMonitorRuleProcessService Complete(ulong maxSequenceID);
    void WriteLogSentryIfError(string functionName);
}
```

### 3. Parallel Processing
Same as standard:
```csharp
matchMonitorRule.MatchStagingList
    .AsParallel()
    .WithDegreeOfParallelism(numberOfThread)
    .ForAll(matchInfo => { ... });
```

---

## Performance Considerations

- **Simpler than standard**: No sport-specific configuration overhead
- **Same parallel processing**: Multi-threaded match processing
- **2-Round detection**: Ensures accuracy
- **Mapping overhead**: Additional dictionary creation, but minimal impact
- **Saba-specific pool**: PoolType = 2

---

## Error Handling

- **Sentry Logging**: All errors logged to Sentry
- **Service Name**: "Match Monitor Process Rule Saba GroupBetting Service"
- **Same error handling** as standard Group Betting

---

## Related Documentation

- [Standard Group Betting](../GroupBetting/) - Comparison reference
- [Match Monitor Analysis](../../ANALYSIS_MatchMonitor.md) - Comprehensive analysis
- [Match Monitor Controller](../../../fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS.JobService/Controllers/MatchMonitorController.cs)

---

## Online Viewer
- PlantUML Online: http://www.plantuml.com/plantuml/uml/
- VS Code Extension: PlantUML

---

## Notes
- **Saba-specific**: Only for Saba Sports platform
- **Simpler configuration**: No sport-specific settings
- **Unique mapping**: CustID → CTSCustID dictionary essential
- **Same architecture**: Follows Match Monitor rule pattern
- **Pool Type**: Uses PoolType = 2 in staging table

---

## Summary: Saba vs Standard Group Betting

### Similarities (80%):
- ✅ Same overall architecture
- ✅ 2-round detection
- ✅ Parallel processing
- ✅ Fluent interface
- ✅ Complete & clean flow

### Differences (20%):
- 🔄 **MappingCustDictionary** (Saba only)
- 🔄 **Fixed detection criteria** (no sport config)
- 🔄 **Simpler association detection** (4 vs 5 criteria)
- 🔄 **PoolType = 2** (Saba pool)
- 🔄 **No LicCustList / IPLast3Days**

---

**Version**: 1.0  
**Last Updated**: 2024-11-19  
**Author**: CTS Analysis Team  
**Platform**: Saba Sports

