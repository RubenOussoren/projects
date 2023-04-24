class PopupScript {
  constructor() {
    // Set up the "Gather Context" button event listener
    this.setupGatherContextButton();
  }

  // Set up the event listener for the "Gather Context" button
  setupGatherContextButton() {
    const button = document.getElementById('gather-context');
    button.addEventListener('click', this.gatherContextHandler);
  }

  // Event handler for the "Gather Context" button click
  gatherContextHandler() {
    // Query the active tab in the current window
    chrome.tabs.query({ active: true, currentWindow: true }, function (tabs) {
      // Send a message to the content script in the active tab with the 'gather_context' action
      chrome.tabs.sendMessage(tabs[0].id, { action: 'gather_context' }, function (response) {
        // If the response is successful, copy the content to the clipboard
        if (response && response.success) {
          navigator.clipboard.writeText(response.content).then(function() {
            alert('Content gathered and copied to clipboard.');
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