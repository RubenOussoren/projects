class PopupScript {
  constructor() {
    // Set up the context copying buttons event listeners
    this.setupCopyAllContextButton();
    this.setupCopyInternalContextButton();
    this.setupCopyPublicContextButton();
  }

  // Set up the event listener for the context copying buttons
  setupCopyAllContextButton() {
    const button = document.getElementById('copy-all-context');
    button.addEventListener('click', this.copyALLContextHandler);
  }

  setupCopyInternalContextButton() {
    const button = document.getElementById('copy-internal-context');
    button.addEventListener('click', this.copyInternalContextHandler);
  }
  
  setupCopyPublicContextButton() {
    const button = document.getElementById('copy-public-context');
    button.addEventListener('click', this.copyPublicContextHandler);
  }

  // Event handler for the context copying buttons click
  copyALLContextHandler() {
    // Query the active tab in the current window
    chrome.tabs.query({ active: true, currentWindow: true }, function (tabs) {
      // Send a message to the content script in the active tab with the 'gather_context' action
      chrome.tabs.sendMessage(tabs[0].id, { action: 'copy-all-context' }, function (response) {
        // If the response is successful, copy the content to the clipboard
        if (response && response.success) {
          navigator.clipboard.writeText(response.content).then(function() {
            alert('Copied all context to clipboard.');
          }, function(err) {
            alert('Failed to copy content to clipboard.');
          });
        } else {
          alert('Failed to gather content.');
        }
      });
    });
  }

  copyInternalContextHandler() {
    chrome.tabs.query({ active: true, currentWindow: true }, function (tabs) {
      chrome.tabs.sendMessage(tabs[0].id, { action: 'copy-internal-context' }, function (response) {
        if (response && response.success) {
          navigator.clipboard.writeText(response.content).then(function() {
            alert('Copied internal context to clipboard.');
          }, function(err) {
            alert('Failed to copy content to clipboard.');
          });
        } else {
          alert('Failed to gather content.');
        }
      });
    });
  }

  copyPublicContextHandler() {
    chrome.tabs.query({ active: true, currentWindow: true }, function (tabs) {
      chrome.tabs.sendMessage(tabs[0].id, { action: 'copy-public-context' }, function (response) {
        if (response && response.success) {
          navigator.clipboard.writeText(response.content).then(function() {
            alert('Copied public context to clipboard.');
          }, function(err) {
            alert('Failed to copy content to clipboard.');
          });
        } else {
          alert('Failed to gather content.');
        }
      });
    });
  }
}

// Create a new PopupScript instance
const popupScript = new PopupScript();