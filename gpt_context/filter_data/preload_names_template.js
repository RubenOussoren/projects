chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'get_common_names') {
      sendResponse({
        COMMON_FIRST_NAMES: [
            'John',
        ],
        COMMON_LAST_NAMES: [
            'Smith',
        ],
    });
  }
});