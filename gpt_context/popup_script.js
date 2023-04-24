class PopupScript {
  constructor() {
    this.setupGatherContextButton();
  }

  setupGatherContextButton() {
    const button = document.getElementById('gather-context');
    button.addEventListener('click', this.gatherContextHandler);
  }

  gatherContextHandler() {
    chrome.tabs.query({ active: true, currentWindow: true }, function (tabs) {
      chrome.tabs.sendMessage(tabs[0].id, { action: 'gather_context' }, function (response) {
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

const popupScript = new PopupScript();