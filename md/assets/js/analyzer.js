// CTS Requirement Analyzer - JavaScript

// API Configuration
const API_CONFIG = {
    baseUrl: 'http://localhost:8000',  // Change this to your API server URL
    apiKey: 'my-secret-key-123'        // Change this to your actual API key
};

// DOM Elements
let requirementInput;
let contextCountInput;
let analyzeBtn;
let reindexBtn;
let indexStatus;
let resultContainer;
let analysisContent;
let sourcesList;
let loadingIndicator;
let errorContainer;
let errorMessage;

// Initialize
document.addEventListener('DOMContentLoaded', function () {
    // Get DOM elements
    requirementInput = document.getElementById('requirementInput');
    contextCountInput = document.getElementById('contextCount');
    analyzeBtn = document.getElementById('analyzeBtn');
    reindexBtn = document.getElementById('reindexBtn');
    indexStatus = document.getElementById('indexStatus');
    resultContainer = document.getElementById('resultContainer');
    analysisContent = document.getElementById('analysisContent');
    sourcesList = document.getElementById('sourcesList');
    loadingIndicator = document.getElementById('loadingIndicator');
    errorContainer = document.getElementById('errorContainer');
    errorMessage = document.getElementById('errorMessage');

    // Event listeners
    analyzeBtn.addEventListener('click', analyzeRequirement);
    reindexBtn.addEventListener('click', reindexDocuments);

    // Allow Enter key to submit (with Ctrl/Cmd)
    requirementInput.addEventListener('keydown', function (e) {
        if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
            analyzeRequirement();
        }
    });

    // Check health status on load
    checkHealthStatus();
});

// Analyze requirement function
async function analyzeRequirement() {
    const requirement = requirementInput.value.trim();
    const k = parseInt(contextCountInput.value);

    // Validation
    if (!requirement) {
        showError('Please enter a requirement to analyze.');
        return;
    }

    if (k < 1 || k > 20) {
        showError('Number of context documents must be between 1 and 20.');
        return;
    }

    // Hide previous results/errors
    hideResults();
    hideError();

    // Show loading
    showLoading();

    // Disable button
    analyzeBtn.disabled = true;

    try {
        // Call API
        const response = await fetch(`${API_CONFIG.baseUrl}/api/analyze`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-API-Key': API_CONFIG.apiKey
            },
            body: JSON.stringify({
                requirement: requirement,
                k: k
            })
        });

        // Check response
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || `HTTP error! status: ${response.status}`);
        }

        // Parse result
        const result = await response.json();

        // Display result
        displayResult(result);

    } catch (error) {
        console.error('Error analyzing requirement:', error);
        showError(`Failed to analyze requirement: ${error.message}`);
    } finally {
        // Hide loading and re-enable button
        hideLoading();
        analyzeBtn.disabled = false;
    }
}

// Display analysis result
function displayResult(result) {
    // Format and display analysis
    analysisContent.innerHTML = formatMarkdown(result.analysis);

    // Display sources
    sourcesList.innerHTML = '';
    result.relevant_sources.forEach(source => {
        const sourceItem = document.createElement('div');
        sourceItem.className = 'source-item';
        sourceItem.textContent = `📄 ${source}`;
        sourcesList.appendChild(sourceItem);
    });

    // Show result container
    resultContainer.style.display = 'block';

    // Scroll to result
    resultContainer.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

// Simple markdown formatter (basic support)
function formatMarkdown(text) {
    // Convert markdown to HTML (basic implementation)
    let html = text;

    // Headers
    html = html.replace(/^### (.*$)/gim, '<h3>$1</h3>');
    html = html.replace(/^## (.*$)/gim, '<h2>$1</h2>');
    html = html.replace(/^# (.*$)/gim, '<h1>$1</h1>');

    // Bold
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');

    // Lists
    html = html.replace(/^\* (.*$)/gim, '<li>$1</li>');
    html = html.replace(/(<li>.*<\/li>)/s, '<ul>$1</ul>');

    // Line breaks
    html = html.replace(/\n/g, '<br>');

    return html;
}

// Show loading indicator
function showLoading() {
    loadingIndicator.style.display = 'block';
}

// Hide loading indicator
function hideLoading() {
    loadingIndicator.style.display = 'none';
}

// Show error message
function showError(message) {
    errorMessage.textContent = message;
    errorContainer.style.display = 'block';

    // Scroll to error
    errorContainer.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

// Hide error message
function hideError() {
    errorContainer.style.display = 'none';
}

// Hide results
function hideResults() {
    resultContainer.style.display = 'none';
}

// Check health status
async function checkHealthStatus() {
    indexStatus.textContent = 'Checking status...';
    indexStatus.className = 'index-status checking';

    try {
        const response = await fetch(`${API_CONFIG.baseUrl}/api/health`);

        if (!response.ok) {
            throw new Error('Failed to check health status');
        }

        const health = await response.json();

        if (health.vector_db_exists) {
            indexStatus.textContent = '✅ Ready - Vector database is initialized';
            indexStatus.className = 'index-status ready';
        } else {
            indexStatus.textContent = '⚠️ Not Ready - Please rebuild index first';
            indexStatus.className = 'index-status not-ready';
        }
    } catch (error) {
        console.error('Error checking health:', error);
        indexStatus.textContent = '❌ Error - Cannot connect to API server';
        indexStatus.className = 'index-status not-ready';
    }
}

// Reindex documents
async function reindexDocuments() {
    // Confirm action
    if (!confirm('This will rebuild the entire vector database. This may take a few minutes. Continue?')) {
        return;
    }

    // Hide previous results/errors
    hideResults();
    hideError();

    // Update status
    indexStatus.textContent = '🔄 Rebuilding index...';
    indexStatus.className = 'index-status checking';

    // Disable buttons
    reindexBtn.disabled = true;
    analyzeBtn.disabled = true;

    try {
        const response = await fetch(`${API_CONFIG.baseUrl}/api/reindex`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-API-Key': API_CONFIG.apiKey
            },
            body: JSON.stringify({})
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || `HTTP error! status: ${response.status}`);
        }

        const result = await response.json();

        // Show success message
        indexStatus.textContent = `✅ Success - Indexed ${result.documents_processed} documents`;
        indexStatus.className = 'index-status ready';

        // Show success notification
        alert(`Reindex completed successfully!\n\nDocuments processed: ${result.documents_processed}\nPath: ${result.docs_path}`);

    } catch (error) {
        console.error('Error reindexing:', error);
        indexStatus.textContent = '❌ Reindex failed';
        indexStatus.className = 'index-status not-ready';
        showError(`Failed to reindex: ${error.message}`);
    } finally {
        // Re-enable buttons
        reindexBtn.disabled = false;
        analyzeBtn.disabled = false;
    }
}
