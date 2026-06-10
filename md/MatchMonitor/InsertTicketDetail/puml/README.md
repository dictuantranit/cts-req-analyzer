# 📥 Match Monitor - Insert Ticket Detail

## 📋 Overview

**Insert Ticket Detail** is the **FIRST and MOST CRITICAL** background job in Match Monitor system. It scans tickets from **MainDB (SQL Server)** and inserts them into **staging tables** in **CTS MySQL database** for later processing by detection rules (Group Betting, Saba GB, Fixed Game, Hedging, etc.).

---

## 🎯 Purpose

| Purpose | Description |
|---------|-------------|
| **Data Ingestion** | Fetch new tickets from MainDB based on `SequenceID` |
| **Staging Preparation** | Prepare tickets in staging tables for multiple detection rules |
| **Parallel Processing** | Insert tickets into 6 staging pools simultaneously |
| **Incremental Scan** | Only fetch tickets with `SequenceID > LastScannedSequenceID` |
| **Support Live/NonLive** | Separate processing for live and non-live matches |

---

## 🔄 Workflow (6 Steps)

```
┌────────────────────────────────────────────────────────────┐
│  1. START - API Endpoint Called                           │
│     ├─ Live:    MatchMonitorInsertTicketDetailLive        │
│     └─ NonLive: MatchMonitorInsertTicketDetailNonLive     │
└────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────┐
│  2. GET LAST SCANNED SEQUENCE ID                          │
│     ├─ Read from SystemParameter table                    │
│     ├─ Live:    MatchMonitorLastScannedTrans             │
│     └─ NonLive: MatchMonitorLastScannedTransNoneLive     │
└────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────┐
│  3. GET BETTYPE SETTINGS                                  │
│     ├─ Query SportBettypeSetting table                    │
│     ├─ Filter by FunctionID = MMBetType                   │
│     └─ Get enabled sport/bettype combinations             │
└────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────┐
│  4. GET MATCH TRANS FROM MAINDB                           │
│     ├─ Call SP: CTS_DC_MatchMonitor_Details_Get           │
│     ├─ WHERE SequenceID > LastScannedSequenceID           │
│     ├─ LIMIT: batchSize (default 5000)                    │
│     └─ Return: List<TicketDetailEntity>                   │
└────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────┐
│  5. INSERT TO STAGING (PARALLEL)                          │
│     ├─ Serialize tickets to JSON                          │
│     ├─ Insert into 6 pools simultaneously (AsParallel)    │
│     ├─ Call SP: CTS_DC_MatchMonitor_Staging_Insert        │
│     └─ Pools: 1001-1004 (Live) / 2001-2006 (NonLive)     │
└────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────┐
│  6. UPDATE LAST SCANNED SEQUENCE ID                       │
│     ├─ Get Max(SequenceID) from fetched tickets           │
│     └─ Update SystemParameter for next scan               │
└────────────────────────────────────────────────────────────┘
```

---

## 🗂️ Staging Pools

| Pool Type | Pool ID | Rule Target | Description |
|-----------|---------|-------------|-------------|
| **LIVE** | 1001 | Group Betting | Standard group betting (all sports) |
| | 1002 | Saba Group Betting | Saba-specific group betting |
| | 1003 | Hedging | Opposite-side betting detection |
| | 1004 | Fixed Game | Match-fixing detection |
| **NON-LIVE** | 2001 | Group Betting | Standard group betting (all sports) |
| | 2002 | Saba Group Betting | Saba-specific group betting |
| | 2003 | Hedging | Opposite-side betting detection |
| | 2004 | Arbitrage | Arbitrage betting detection |
| | 2005 | Fixed Game | Match-fixing detection |
| | 2006 | Irrigation | Irrigation rule detection |

> **Note**: All pools receive **THE SAME tickets**. Each rule will filter and process tickets based on their own criteria.

---

## 📊 Key Components

### 1. **API Endpoints**

```csharp
// fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS.JobService/Controllers/MatchMonitorController.cs

[HttpPost("MatchMonitorInsertTicketDetailLive")]
public async Task<bool> MatchMonitorInsertTicketDetailLive([FromForm] int size)
{
    return await this.matchMonitorJobService.InsertTicketDetail(size, true);
}

[HttpPost("MatchMonitorInsertTicketDetailNonLive")]
public async Task<bool> MatchMonitorInsertTicketDetailNonLive([FromForm] int size)
{
    return await this.matchMonitorJobService.InsertTicketDetail(size, false);
}
```

### 2. **Service Layer (Fluent Interface)**

```csharp
// fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS.JobService/Services/MatchMonitorJobService.cs

public Task<bool> InsertTicketDetail(int batchSize, bool isLive)
{
    try
    {
        _serviceProvider.GetService<IMatchMonitorStagingService>()
            .Start(batchSize, isLive)
            .GetLastScannedSequenceID()
            .GetMatchTrans()
            .InsertMatchMonitorStagingWithParallel()
            .UpdateLastScannedSequenceID();
    }
    catch (Exception ex)
    {
        Utilities.LogSentryError(serviceName, ex.Message, string.Empty, ex);
        return Task.FromResult(false);
    }
    return Task.FromResult(true);
}
```

### 3. **Data Access Layer**

```csharp
// fanex.nap.spu.cts/src/Fanex.NAP.SPU.CTS/Features/MatchMonitor/MatchMonitorStaging/MatchMonitorStagingDataAccess.cs

public IEnumerable<TicketDetailEntity> GetMatchTrans(
    long lastScannedSequenceID, 
    int batchSize, 
    bool isLive, 
    string betTypeInfos)
{
    var criteria = new MatchTransGetCriteria
    {
        QueryType = (int)Consts.MatchMonitorQueryTypes.Service,
        LastScannedSequenceID = lastScannedSequenceID,
        BatchSize = batchSize,
        IsLive = isLive,
        ListSportBettype = betTypeInfos
    };
    return repository.Fetch<TicketDetailEntity>(criteria);
}

public void InsertMatchMonitorStaging(string matchTransJson, bool isLive, int poolType)
{
    var criteria = new MatchMonitorStagingInsertCriteria
    {
        MatchTransJson = matchTransJson,
        IsLive = isLive,
        PoolType = poolType
    };
    repository.Execute(criteria);
}
```

---

## 🗄️ Database Operations

### 1. **Read from MainDB (SQL Server)**

**Stored Procedure**: `CTS_DC_MatchMonitor_Details_Get`

**Input Parameters**:
- `@ip_QueryType` = 1 (Service)
- `@ip_LastScannedSequenceID` = Last scanned SequenceID
- `@ip_BatchSize` = 5000 (default)
- `@ip_IsLive` = true/false
- `@ip_ListSportBettype` = JSON array of enabled sport/bettype

**Output**: List of `TicketDetailEntity` with:
- `SequenceID` (for incremental scan)
- `TransID`, `CustID`, `Stake`, `Odds`
- `MatchID`, `LeagueID`, `SportType`, `BettypeID`
- `LiveHomeScore`, `LiveAwayScore`
- `KickOffTime`, `EventStatus`

### 2. **Write to CTS MySQL**

**Stored Procedure**: `CTS_DC_MatchMonitor_Staging_Insert`

**Input Parameters**:
- `@ip_LiveIndicator` = true/false
- `@ip_PoolType` = 1001-2006
- `@ip_TransList` = JSON array of tickets

**Process**:
1. Parse JSON to temporary table `Temp_Staging`
2. Join with `MatchMonitorRuleSetting` to filter tickets
3. Calculate `ScoreDiff` = (LiveHomeScore × 10000) + LiveAwayScore
4. Calculate `HDP` = Hdp1 - Hdp2
5. Insert into staging table based on `PoolType`

---

## 🔍 Key Concepts

### 1. **Incremental Scan**

- Uses `SequenceID` to track progress
- Only fetch tickets with `SequenceID > LastScannedSequenceID`
- After processing, update `LastScannedSequenceID = Max(SequenceID)`

### 2. **Parallel Pool Insertion**

```csharp
Enum.GetValues(PoolEnumType)
    .Cast<int>()
    .AsParallel()  // ← Parallel execution
    .ForAll(poolType => InsertMatchMonitorStaging(ticketStagingJson, IsLive, poolType));
```

**6 pools** are written **simultaneously** to improve performance.

### 3. **Fluent Interface Pattern**

```csharp
_serviceProvider.GetService<IMatchMonitorStagingService>()
    .Start(batchSize, isLive)              // Step 1
    .GetLastScannedSequenceID()            // Step 2
    .GetMatchTrans()                       // Step 3
    .InsertMatchMonitorStagingWithParallel() // Step 4
    .UpdateLastScannedSequenceID();        // Step 5
```

Each method returns `this` to enable chaining.

### 4. **Live vs Non-Live**

| Aspect | Live | Non-Live |
|--------|------|----------|
| **Parameter** | `MatchMonitorLastScannedTrans` | `MatchMonitorLastScannedTransNoneLive` |
| **Pools** | 1001-1004 (4 pools) | 2001-2006 (6 pools) |
| **Frequency** | Every 5 minutes | Every 5 minutes |
| **Match Status** | `EventStatus = 'running'` | `EventStatus = 'settled'` |

---

## ⏱️ Execution Schedule

| Job | Frequency | Batch Size |
|-----|-----------|------------|
| **Insert Ticket Detail (Live)** | Every 5 minutes | 5000 tickets |
| **Insert Ticket Detail (NonLive)** | Every 5 minutes | 5000 tickets |

---

## 🚨 Error Handling

```csharp
try
{
    // ... fluent chain ...
}
catch (Exception ex)
{
    Utilities.LogSentryError(serviceName, ex.Message, string.Empty, ex);
    return Task.FromResult(false);
}
return Task.FromResult(true);
```

- Any error in the chain will be logged to Sentry
- Returns `false` to indicate failure
- Does NOT update `LastScannedSequenceID` if error occurs

---

## 📈 Performance Characteristics

| Metric | Value |
|--------|-------|
| **Batch Size** | 5000 tickets per scan |
| **Parallel Pools** | 6 pools (Live: 4, NonLive: 6) |
| **Scan Frequency** | Every 5 minutes |
| **Max Delay** | ~5 minutes from ticket creation |

---

## 🔗 Related Documentation

- [Group Betting Detection](../GroupBetting/README.md) - Uses Pool 1001/2001
- [Saba Group Betting Detection](../SabaGroupBetting/README.md) - Uses Pool 1002/2002
- [Hedging Detection](../Hedging/README.md) - Uses Pool 1003/2003
- [Fixed Game Detection](../FixedGame/README.md) - Uses Pool 1004/2005

---

## 📝 Notes

1. **Staging is NOT detection**: This job only inserts tickets into staging. Detection happens in separate jobs.
2. **Same tickets, multiple pools**: All tickets are inserted into ALL pools. Each rule filters as needed.
3. **SequenceID is critical**: Ensures no tickets are missed or duplicated.
4. **Parallel insertion**: 6 pools are written simultaneously to improve performance.
5. **Live ≠ Real-time**: Even "live" tickets have ~5 minute delay due to scan frequency.

---

**Last Updated**: 2025-01-19  
**Author**: Analysis Team  
**Related Module**: Match Monitor

