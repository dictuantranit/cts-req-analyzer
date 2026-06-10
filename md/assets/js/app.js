// CTS Technical Documentation - JavaScript

// Flow data structure
const flowData = {
    "Website Pages": [
        {
            name: "MatchMonitor",
            title: "🎯 Match Monitor Page",
            description: "Complete page documentation with data lineage tracing and user interaction flows",
            isExternalPage: true,
            pageUrl: "Website/MatchMonitor/MatchMonitor.html",
            folder: "Website/MatchMonitor",
            features: ["Data Lineage", "Field Mapping", "API Flows", "User Flows"]
        },
        {
            name: "DangerMonitor",
            title: "🔍 Danger Monitor Search",
            description: "Search and display matches with high danger level",
            folder: "Website/DangerMonitor",
            diagrams: [
                { file: "DangerMonitor_Diagrams_01_MainFlow.svg", title: "Main Flow" },
                { file: "DangerMonitor_Diagrams_02_Sequence_NoAssociation.svg", title: "Sequence - No Association" },
                { file: "DangerMonitor_Diagrams_03_Sequence_WithAssociation.svg", title: "Sequence - With Association" },
                { file: "DangerMonitor_Diagrams_04_Sequence_DetailPage.svg", title: "Sequence - Detail Page" },
                { file: "DangerMonitor_Diagrams_05_Component.svg", title: "Component Diagram" },
                { file: "DangerMonitor_Diagrams_06_DatabaseFlow.svg", title: "Database Flow" },
                { file: "DangerMonitor_Diagrams_07_DatabaseFlow_Detailed.svg", title: "Database Flow Detailed" },
                { file: "DangerMonitor_Diagrams_08_SP_Operations_Detail.svg", title: "SP Operations Detail" },
                { file: "DangerMonitor_Diagrams_09_SP_GetFilter_Detailed.svg", title: "SP GetFilter Detailed" },
                { file: "DangerMonitor_Diagrams_10_SP_GetTicket_Detailed.svg", title: "SP GetTicket Detailed" },
                { file: "DangerMonitor_Diagrams_11_SP_Associations_Get_Detailed.svg", title: "SP Associations Get Detailed" },
                { file: "DangerMonitor_Diagrams_12_SP_Association_GetByUserNameList_Detailed.svg", title: "SP Association GetByUserNameList Detailed" }
            ]
        }
    ],
    "Match Monitor": [
        {
            name: "InsertTicketDetail",
            title: "📥 Insert Ticket Detail",
            description: "FIRST STEP - Scan tickets from MainDB and insert into staging tables for all detection rules (Live/NonLive) - runs every 5 minutes with batch size 5000",
            folder: "MatchMonitor/InsertTicketDetail",
            diagrams: [
                { file: "InsertTicketDetail_MainFlow.svg", title: "Main Flow (6 Steps: Get SequenceID → Get Bettype Settings → Get Tickets → Insert Staging → Update SequenceID)" },
                { file: "InsertTicketDetail_Sequence.svg", title: "Sequence Diagram (MainDB → CTS Staging Tables)" }
            ]
        },
        {
            name: "GroupBetting",
            title: "🎯 Group Betting Detection",
            description: "Detect and analyze group betting patterns using 5 association detection criteria (Device, AI, IP, 3 Matches Last 7 Days, IP Last 3 Days) with sport-specific configuration",
            folder: "MatchMonitor/GroupBetting",
            diagrams: [
                { file: "MatchMonitorGroupBetting_MainFlow.svg", title: "Main Flow (2 Phases)" },
                { file: "MatchMonitorGroupBetting_Sequence.svg", title: "Sequence Diagram" },
                { file: "MatchMonitorGroupBetting_StagingFlow.svg", title: "Phase 1: Staging Flow" },
                { file: "MatchMonitorGroupBetting_ProcessingFlow.svg", title: "Phase 2: Processing Flow" },
                { file: "MatchMonitorGroupBetting_AssociationDetection.svg", title: "Association Detection Logic (5 Criteria)" },
                { file: "MatchMonitorGroupBetting_DatabaseFlow.svg", title: "Database Flow (All SPs)" },
                { file: "MatchMonitorGroupBetting_CompleteFlow.svg", title: "Complete Flow (End-to-End)" }
            ]
        },
        {
            name: "SabaGroupBetting",
            title: "🎲 Saba Group Betting Detection",
            description: "Specialized group betting detection for Saba platform with simplified configuration (4 always-on criteria) and MappingCustDictionary for CustID mapping",
            folder: "MatchMonitor/SabaGroupBetting",
            diagrams: [
                { file: "SabaGroupBetting_MainFlow.svg", title: "Main Flow (Saba-Specific)" },
                { file: "SabaGroupBetting_Sequence.svg", title: "Sequence Diagram" },
                { file: "SabaGroupBetting_MappingDictionary.svg", title: "MappingCustDictionary Logic" },
                { file: "SabaGroupBetting_AssociationDetection.svg", title: "Simplified Association Detection (4 Criteria)" },
                { file: "SabaGroupBetting_DatabaseFlow.svg", title: "Database Flow (Get, Complete, Clean SPs)" }
            ]
        },
        {
            name: "FixedGame",
            title: "🚨 Fixed Game Detection",
            description: "Detect matches with suspicious betting patterns indicating potential match-fixing using ticket volume, stake patterns, and odds spread analysis (no association detection)",
            folder: "MatchMonitor/FixedGame",
            diagrams: [
                { file: "FixedGame_MainFlow.svg", title: "Main Flow (4 Phases)" },
                { file: "FixedGame_Sequence.svg", title: "Sequence Diagram" },
                { file: "FixedGame_DetectionLogic.svg", title: "Detection Criteria Logic (5 Rules)" },
                { file: "FixedGame_DatabaseFlow.svg", title: "Database Flow (All SPs)" }
            ]
        },
        {
            name: "Parlay",
            title: "🎲 Parlay Group Betting Detection",
            description: "Detect group betting in Parlay/Combo bets (Mix Parlay) using 4 association criteria (Device, AI, IP, 3 Matches Last 7 Days) - specialized for multi-match combination bets from MainDB",
            folder: "MatchMonitor/Parlay",
            diagrams: [
                { file: "Parlay_MainFlow.svg", title: "Main Flow (6 Phases)" },
                { file: "Parlay_Sequence.svg", title: "Sequence Diagram" },
                { file: "Parlay_DataFlow.svg", title: "Data Flow (MainDB to CTS to Website)" },
                { file: "Parlay_AssociationDetection.svg", title: "Association Detection Logic (4 Criteria)" }
            ]
        },
        {
            name: "Hedging",
            title: "⚖️ Hedging Detection",
            description: "Detect customers betting on opposite sides to minimize risk using 3 association criteria (Device, AI, IP) with IsHedging flag check, Agent detection (Alpha/Maxbet), and customer classification validation",
            folder: "MatchMonitor/Hedging",
            diagrams: [
                { file: "Hedging_MainFlow.svg", title: "Main Flow (5 Phases with 2-Level Parallelism)" },
                { file: "Hedging_Sequence.svg", title: "Sequence Diagram" },
                { file: "Hedging_AssociationDetection.svg", title: "Association Detection Logic (3 Criteria + Agent Check)" },
                { file: "Hedging_IsHedgingCheck.svg", title: "IsHedging Flag Check Logic" }
            ]
        },
        {
            name: "Arbitrage",
            title: "💹 Arbitrage Detection",
            description: "Detect customers exploiting odds differences between bookmakers (cross-platform) using 3 association criteria (Device, AI, IP) with Agent detection (Alpha/Maxbet) - NonLive only, 2-round processing",
            folder: "MatchMonitor/Arbitrage",
            diagrams: [
                { file: "Arbitrage_MainFlow.svg", title: "Main Flow (5 Phases: Get Staging → Round 1 → Round 2 → Complete → Clean)" },
                { file: "Arbitrage_Sequence.svg", title: "Sequence Diagram (2-Round Processing)" },
                { file: "Arbitrage_AssociationDetection.svg", title: "Association Detection Logic (3 Criteria + Agent Check)" },
                { file: "Arbitrage_DatabaseFlow.svg", title: "Database Flow (All SPs: Get, Process, Complete, Clean)" }
            ]
        },
        {
            name: "Irrigation",
            title: "💧 Irrigation Detection",
            description: "Detect single customer betting patterns with wide odds spread (money laundering) - SIMPLEST rule with NO association detection, only individual customer analysis - NonLive only",
            folder: "MatchMonitor/Irrigation",
            diagrams: [
                { file: "Irrigation_MainFlow.svg", title: "Main Flow (4 Phases: Get Staging → Process → Complete → Clean)" },
                { file: "Irrigation_Sequence.svg", title: "Sequence Diagram (NO Association Detection)" },
                { file: "Irrigation_DetectionLogic.svg", title: "Detection Logic (Odds Spread Calculation: Same Sign vs Mixed Sign)" },
                { file: "Irrigation_DatabaseFlow.svg", title: "Database Flow (All SPs - Simplest Flow)" }
            ]
        }
    ],
    "Classification By General": [
        {
            name: "RealtimeCheckChangeClassification",
            title: "⚡ Realtime Check Change Classification",
            description: "Monitor and classify customers when suspicious changes are detected in realtime",
            folder: "General/RealtimeCheckChangeClassification",
            diagrams: [
                { file: "RealtimeCheckChangeClassification_MainFlow.svg", title: "Main Business Flow" },
                { file: "RealtimeCheckChangeClassification_Sequence.svg", title: "Sequence Diagram" },
                { file: "RealtimeCheckChangeClassification_DatabaseFlow.svg", title: "Database Flow" },
                { file: "RealtimeCheckChangeClassification_SP_CheckChange_Detailed.svg", title: "SP CheckChange Detailed" },
                { file: "RealtimeCheckChangeClassification_SP_UpdateLastTrans_Detailed.svg", title: "SP UpdateLastTrans Detailed" }
            ]
        },
        {
            name: "RealtimeClassification",
            title: "⏱️ Realtime Classification",
            description: "Classify new betting customers in realtime as they place bets",
            folder: "General/RealtimeClassification",
            diagrams: [
                { file: "RealtimeClassification_MainFlow.svg", title: "Main Business Flow" },
                { file: "RealtimeClassification_Sequence.svg", title: "Sequence Diagram" },
                { file: "RealtimeClassification_DatabaseFlow.svg", title: "Database Flow" },
                { file: "RealtimeClassification_SP_GetChanges_Detailed.svg", title: "SP GetChanges Detailed" },
                { file: "RealtimeClassification_SP_GetCategory_Detailed.svg", title: "SP GetCategory Detailed" },
                { file: "RealtimeClassification_SP_Preprocess_Detailed.svg", title: "SP Preprocess Detailed" }
            ]
        },
        {
            name: "NormalAccountClassification",
            title: "📊 Normal Account Classification",
            description: "Classify normal accounts from Normal Pool based on performance analysis",
            folder: "General/NormalAccountClassification",
            diagrams: [
                { file: "NormalAccountClassification_MainFlow.svg", title: "Main Business Flow" },
                { file: "NormalAccountClassification_Sequence.svg", title: "Sequence Diagram" },
                { file: "NormalAccountClassification_DatabaseFlow.svg", title: "Database Flow" },
                { file: "NormalAccountClassification_SP_GetPool_Detailed.svg", title: "SP GetPool Detailed" },
                { file: "NormalAccountClassification_SP_GetCategory_Detailed.svg", title: "SP GetCategory Detailed" },
                { file: "NormalAccountClassification_SP_Classify_Detailed.svg", title: "SP Classify Detailed" },
                { file: "NormalAccountClassification_SP_Clear_Detailed.svg", title: "SP Clear Detailed" }
            ]
        },
        {
            name: "NormalAccountInsert",
            title: "📥 Normal Account Insert",
            description: "Insert classified normal accounts and push to external systems with advanced tagging logic",
            folder: "General/NormalAccountInsert",
            diagrams: [
                { file: "NormalAccountInsert_MainFlow.svg", title: "Main Business Flow" },
                { file: "NormalAccountInsert_TaggingFlow.svg", title: "Customer Tagging Flow" },
                { file: "NormalAccountInsert_ParallelTasks.svg", title: "Parallel Tasks Flow" }
            ]
        },
        {
            name: "DailyProblemClassification",
            title: "⚠️ Daily Problem Classification",
            description: "Classify problem accounts daily based on win/loss performance and behavior patterns",
            folder: "General/DailyProblemClassification",
            diagrams: [
                { file: "DailyProblemClassification_MainFlow.svg", title: "Main Business Flow" },
                { file: "DailyProblemClassification_Sequence.svg", title: "Sequence Diagram" },
                { file: "DailyProblemClassification_DatabaseFlow.svg", title: "Database Flow" },
                { file: "DailyProblemClassification_SP_GetFromQueue.svg", title: "SP GetFromQueue Detailed" },
                { file: "DailyProblemClassification_SP_PAClassification.svg", title: "SP PAClassification Detailed" },
                { file: "DailyProblemClassification_SP_InsertProbation.svg", title: "SP InsertProbation Detailed" },
                { file: "DailyProblemClassification_SP_Complete.svg", title: "SP Complete Detailed" }
            ]
        },
        {
            name: "ProbationClassification",
            title: "⏳ Probation Classification",
            description: "Scan and classify probation customers to add them to Normal Pool after observation period",
            folder: "General/ProbationClassification",
            diagrams: [
                { file: "ProbationClassification_MainFlow.svg", title: "Main Business Flow" },
                { file: "ProbationClassification_Sequence.svg", title: "Sequence Diagram" },
                { file: "ProbationClassification_DatabaseFlow.svg", title: "Database Flow" },
                { file: "ProbationClassification_SP_GetProbationScan.svg", title: "SP GetProbationScan Detailed" },
                { file: "ProbationClassification_SP_ProbationPreprocess.svg", title: "SP ProbationPreprocess Detailed" }
            ]
        },
        {
            name: "DailyDangerousClassification",
            title: "🚨 Daily Dangerous Classification",
            description: "Detect and classify dangerous customers daily using AI/ML integration and multi-criteria analysis",
            folder: "General/DailyDangerousClassification",
            diagrams: [
                { file: "DailyDangerousClassification_MainFlow.svg", title: "Main Business Flow" },
                { file: "DailyDangerousClassification_Sequence.svg", title: "Sequence Diagram" },
                { file: "DailyDangerousClassification_DatabaseFlow.svg", title: "Database Flow" },
                { file: "DailyDangerousClassification_SP_GetDangerousDetection.svg", title: "SP GetDangerousDetection Detailed" }
            ]
        },
        {
            name: "DailyRobotClassification",
            title: "🤖 Daily Robot Classification",
            description: "Detect and classify robot/AI accounts using dual detection systems (TW Robot + AI Detection)",
            folder: "General/DailyRobotClassification",
            diagrams: [
                { file: "AIRobotDetection_MainFlow.svg", title: "AI Robot Detection - Main Flow" },
                { file: "AIRobotDetection_Sequence.svg", title: "AI Robot Detection - Sequence" },
                { file: "TWRobotAccount_MainFlow.svg", title: "TW Robot Classification - Main Flow" },
                { file: "TWRobotAccount_Sequence.svg", title: "TW Robot Classification - Sequence" },
                { file: "DailyRobotClassification_DatabaseFlow.svg", title: "Combined Database Flow" },
                { file: "DailyRobotClassification_SP_AIRobotDetection.svg", title: "SP AI Robot Detection Detailed" },
                { file: "DailyRobotClassification_SP_TWRobotList.svg", title: "SP TW Robot List Detailed" }
            ]
        },
        {
            name: "MatchMonitorClassification",
            title: "🎯 Match Monitor Classification",
            description: "Detect and classify group betting patterns across matches (General version)",
            folder: "General/MatchMonitorClassification",
            diagrams: [
                { file: "MatchMonitorClassification_MainFlow.svg", title: "Main Business Flow (2 Jobs)" },
                { file: "MatchMonitorClassification_Sequence.svg", title: "Sequence Diagram" },
                { file: "MatchMonitorClassification_DatabaseFlow.svg", title: "Database Flow" },
                { file: "MatchMonitorClassification_SP_GetMatches.svg", title: "SP GetMatches Detailed" },
                { file: "MatchMonitorClassification_SP_Classify.svg", title: "SP Classify Detailed" },
                { file: "MatchMonitorClassification_SP_Completed.svg", title: "SP Completed Detailed" }
            ]
        }
    ],
    "Classification By Sport": [
        {
            name: "MatchMonitorClassificationBySport",
            title: "🎯 Match Monitor Classification",
            description: "Classify customers based on Match Monitor data to detect Group Betting",
            folder: "BySport/MatchMonitorClassificationBySport",
            diagrams: [
                { file: "MatchMonitorClassificationBySport_MainFlow.svg", title: "Main Business Flow" },
                { file: "MatchMonitorClassificationBySport_Sequence.svg", title: "Sequence Diagram" },
                { file: "MatchMonitorClassificationBySport_DatabaseFlow.svg", title: "Database Flow" },
                { file: "MatchMonitorClassificationBySport_SP_Classify_Detailed.svg", title: "SP Classify Detailed" },
                { file: "MatchMonitorClassificationBySport_SP_Insert_Detailed.svg", title: "SP Insert Detailed" }
            ]
        },
        {
            name: "DailyProblemClassificationBySport",
            title: "🔄 Daily Problem Classification",
            description: "Classify problem accounts daily based on win/loss performance",
            folder: "BySport/DailyProblemClassificationBySport",
            diagrams: [
                { file: "DailyProblemClassificationBySport_MainFlow.svg", title: "Main Business Flow" },
                { file: "DailyProblemClassificationBySport_Sequence.svg", title: "Sequence Diagram" },
                { file: "DailyProblemClassificationBySport_DatabaseFlow.svg", title: "Database Flow" },
                { file: "DailyProblemClassificationBySport_SP_GetFromQueue_Detailed.svg", title: "SP GetFromQueue Detailed" },
                { file: "DailyProblemClassificationBySport_SP_Insert_Detailed.svg", title: "SP Insert Detailed" },
                { file: "DailyProblemClassificationBySport_SP_GetLosingPerformance_Detailed.svg", title: "SP GetLosingPerformance Detailed" }
            ]
        },
        {
            name: "RealtimeClassificationBySport",
            title: "⏱️ Realtime Classification",
            description: "Classify customers in realtime when data changes occur",
            folder: "BySport/RealtimeClassificationBySport",
            diagrams: [
                { file: "RealtimeClassificationBySport_MainFlow.svg", title: "Main Business Flow" },
                { file: "RealtimeClassificationBySport_Sequence.svg", title: "Sequence Diagram" },
                { file: "RealtimeClassificationBySport_DatabaseFlow.svg", title: "Database Flow" },
                { file: "RealtimeClassificationBySport_SP_GetChanges_Detailed.svg", title: "SP GetChanges Detailed" },
                { file: "RealtimeClassificationBySport_SP_GetCategory_Detailed.svg", title: "SP GetCategory Detailed" },
                { file: "RealtimeClassificationBySport_SP_Preprocess_Detailed.svg", title: "SP Preprocess Detailed" }
            ]
        },
        {
            name: "DailyNormalClassificationBySport",
            title: "🔄 Daily Normal Classification",
            description: "Scan and preprocess normal accounts daily to add them to Normal Pool",
            folder: "BySport/DailyNormalClassificationBySport",
            diagrams: [
                { file: "DailyNormalClassificationBySport_MainFlow.svg", title: "Main Business Flow" },
                { file: "DailyNormalClassificationBySport_Sequence.svg", title: "Sequence Diagram" },
                { file: "DailyNormalClassificationBySport_DatabaseFlow.svg", title: "Database Flow" },
                { file: "DailyNormalClassificationBySport_SP_GetNormal_Detailed.svg", title: "SP GetNormal Detailed" },
                { file: "DailyNormalClassificationBySport_SP_Preprocess_Detailed.svg", title: "SP Preprocess Detailed" }
            ]
        },
        {
            name: "NormalAccountClassificationBySport",
            title: "📊 Normal Account Classification",
            description: "Classify normal accounts from Normal Pool based on performance data",
            folder: "BySport/NormalAccountClassificationBySport",
            diagrams: [
                { file: "NormalAccountClassificationBySport_MainFlow.svg", title: "Main Business Flow" },
                { file: "NormalAccountClassificationBySport_Sequence.svg", title: "Sequence Diagram" },
                { file: "NormalAccountClassificationBySport_DatabaseFlow.svg", title: "Database Flow" },
                { file: "NormalAccountClassificationBySport_SP_GetNormalPool_Detailed.svg", title: "SP GetNormalPool Detailed" },
                { file: "NormalAccountClassificationBySport_SP_GetCurrentCategory_Detailed.svg", title: "SP GetCurrentCategory Detailed" },
                { file: "NormalAccountClassificationBySport_SP_Classify_Detailed.svg", title: "SP Classify Detailed" },
                { file: "NormalAccountClassificationBySport_SP_Clear_Detailed.svg", title: "SP Clear Detailed" }
            ]
        },
        {
            name: "ProbationClassificationBySport",
            title: "⏳ Probation Classification",
            description: "Scan and preprocess probation customers to add them to Normal Pool",
            folder: "BySport/ProbationClassificationBySport",
            diagrams: [
                { file: "ProbationClassificationBySport_MainFlow.svg", title: "Main Business Flow" },
                { file: "ProbationClassificationBySport_Sequence.svg", title: "Sequence Diagram" },
                { file: "ProbationClassificationBySport_DatabaseFlow.svg", title: "Database Flow" },
                { file: "ProbationClassificationBySport_SP_ProbationScan_Get_Detailed.svg", title: "SP ProbationScan Get Detailed" },
                { file: "ProbationClassificationBySport_SP_Preprocess_Detailed.svg", title: "SP Preprocess Detailed" }
            ]
        },
        {
            name: "NormalAccountInsertBySport",
            title: "📥 Normal Account Insert",
            description: "Insert and manage normal account customer information by sport",
            folder: "BySport/NormalAccountInsertBySport",
            diagrams: [
                { file: "NormalAccountInsertBySport_MainFlow.svg", title: "Main Business Flow" },
                { file: "NormalAccountInsertBySport_Sequence.svg", title: "Sequence Diagram" },
                { file: "NormalAccountInsertBySport_DatabaseFlow.svg", title: "Database Flow" },
                { file: "NormalAccountInsertBySport_SP_Get_Detailed.svg", title: "SP Get Detailed" },
                { file: "NormalAccountInsertBySport_SP_Insert_Detailed.svg", title: "SP Insert Detailed" },
                { file: "NormalAccountInsertBySport_SP_Complete_Detailed.svg", title: "SP Complete Detailed" }
            ]
        }
    ]
};

let currentFlow = null;

// Render all flow categories
function renderFlows() {
    const container = document.getElementById('flowContainer');
    container.innerHTML = '';

    Object.keys(flowData).forEach(categoryName => {
        const category = document.createElement('div');
        category.className = 'category';

        const categoryTitle = document.createElement('div');
        categoryTitle.className = 'category-title';
        categoryTitle.innerHTML = `<span class="category-icon">📁</span> ${categoryName}`;

        const flowGrid = document.createElement('div');
        flowGrid.className = 'flow-grid';

        flowData[categoryName].forEach(flow => {
            const card = document.createElement('div');
            card.className = 'flow-card';

            // Check if this is an external page (website page)
            if (flow.isExternalPage) {
                card.onclick = () => window.location.href = flow.pageUrl;
                card.innerHTML = `
                    <div class="flow-card-title">
                        ${flow.title}
                    </div>
                    <div class="flow-card-description">${flow.description}</div>
                    <div class="flow-card-stats">
                        <div class="stat-item">
                            <span>📄</span>
                            <span>2 tabs</span>
                        </div>
                        <div class="stat-item">
                            <span>🔗</span>
                            <span>Interactive page</span>
                        </div>
                    </div>
                `;
            } else {
                card.onclick = () => showFlowDetail(flow);
                card.innerHTML = `
                    <div class="flow-card-title">
                       ${flow.title}
                    </div>
                    <div class="flow-card-description">${flow.description}</div>
                    <div class="flow-card-stats">
                        <div class="stat-item">
                            <span>📊</span>
                            <span>${flow.diagrams.length} diagrams</span>
                        </div>
                    </div>
                `;
            }

            flowGrid.appendChild(card);
        });

        category.appendChild(categoryTitle);
        category.appendChild(flowGrid);
        container.appendChild(category);
    });
}

// Show flow detail view
function showFlowDetail(flow) {
    currentFlow = flow;
    const container = document.getElementById('flowContainer');

    const detailHTML = `
        <div class="flow-detail active">
            <div class="flow-detail-header">
                <div>
                    <h2 class="flow-detail-title">${flow.title}</h2>
                    <p style="color: #666; margin-top: 5px;">${flow.description}</p>
                </div>
                <button class="back-button" onclick="backToHome()">← Back</button>
            </div>
            <div class="diagram-grid" id="diagramGrid">
                ${flow.diagrams.map((diagram, index) => `
                    <div class="diagram-card">
                        <div class="diagram-title">${index + 1}. ${diagram.title}</div>
                        <img src="${flow.folder}/${diagram.file}" 
                             alt="${diagram.title}"
                             class="diagram-svg"
                             onclick="openModal('${flow.folder}/${diagram.file}', '${diagram.title}')"
                             onerror="this.onerror=null; this.src='data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iNDAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iI2Y1ZjVmNSIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTYiIGZpbGw9IiM5OTkiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj5EaWFncmFtIG5vdCBmb3VuZDwvdGV4dD48L3N2Zz4='">
                        </img>
                    </div>
                `).join('')}
            </div>
        </div>
    `;

    container.innerHTML = detailHTML;
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

// Back to home view
function backToHome() {
    currentFlow = null;
    renderFlows();
    document.getElementById('searchBox').value = '';
}

// Open modal with diagram
function openModal(svgPath, title) {
    const modal = document.getElementById('diagramModal');
    const modalContent = document.getElementById('modalContent');

    modalContent.innerHTML = `
        <h2 style="margin-bottom: 20px; color: #667eea;">${title}</h2>
        <img src="${svgPath}" class="modal-svg" alt="${title}">
    `;

    modal.classList.add('active');
}

// Close modal
function closeModal() {
    const modal = document.getElementById('diagramModal');
    modal.classList.remove('active');
}

// Event Listeners
document.addEventListener('DOMContentLoaded', function() {
    // Initialize
    renderFlows();

    // Close modal when clicking outside
    document.getElementById('diagramModal').addEventListener('click', function (e) {
        if (e.target === this) {
            closeModal();
        }
    });

    // Search functionality
    document.getElementById('searchBox').addEventListener('input', function (e) {
        const searchTerm = e.target.value.toLowerCase();
        const cards = document.querySelectorAll('.flow-card');
        let hasResults = false;

        cards.forEach(card => {
            const text = card.textContent.toLowerCase();
            if (text.includes(searchTerm)) {
                card.style.display = 'block';
                hasResults = true;
            } else {
                card.style.display = 'none';
            }
        });

        // Show no results message
        const categories = document.querySelectorAll('.category');
        categories.forEach(category => {
            const grid = category.querySelector('.flow-grid');
            const visibleCards = Array.from(grid.querySelectorAll('.flow-card'))
                .filter(card => card.style.display !== 'none');

            if (visibleCards.length === 0 && searchTerm) {
                if (!category.querySelector('.no-results')) {
                    const noResults = document.createElement('div');
                    noResults.className = 'no-results';
                    noResults.textContent = 'No results found';
                    grid.appendChild(noResults);
                }
            } else {
                const noResults = category.querySelector('.no-results');
                if (noResults) {
                    noResults.remove();
                }
            }
        });
    });

    // Keyboard shortcuts
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            if (document.getElementById('diagramModal').classList.contains('active')) {
                closeModal();
            } else if (currentFlow) {
                backToHome();
            }
        }
    });
});
