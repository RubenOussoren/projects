# GPT Context Chrome Extension

## Overview

GPT Context is a Chrome extension designed to help Shopify employees gather context from Zendesk tickets and filter sensitive information, such as names and email addresses. The extension adds a "Copy Context" button to the browser toolbar. When clicked, it extracts relevant text from the Zendesk page, filters out sensitive information, and copies the extracted content to the user's clipboard.

## Features

- Extracts relevant text from Zendesk pages
- Filters out sensitive information (e.g., names, emails)
- Copies the extracted content to the user's clipboard

## How it works

The extension consists of the following components:

1. `manifest.json`: Configures the extension, including content scripts, background scripts, popup, and permissions.
2. `popup.html`: Contains the structure for the extension's popup, including the "Gather Context" button.
3. `popup_script.js`: Sets up the event listener for the "Gather Context" button and sends a message to the content script to gather context when the button is clicked.
4. `content_script.rb`: Contains the `ContentScript` class, which handles context extraction and filtering. It also sets up a message listener to handle the 'gather_context' action, which triggers the extraction and filtering process when the "Gather Context" button is clicked in the popup.

The extension works by injecting the content script into the Zendesk pages. When the user clicks the "Gather Context" button in the popup, a message is sent to the content script to gather context. The content script extracts the ticket content, filters sensitive information, and sends the extracted content back to the popup script. The popup script then copies the content to the user's clipboard.

## Installation

1. Download the extension files and unzip them to a folder on your computer.
2. Open Chrome and navigate to `chrome://extensions`.
3. Enable "Developer mode" by toggling the switch in the top right corner.
4. Click "Load unpacked" and select the folder containing the extension files.
5. The GPT Context extension should now be installed and visible in your Chrome toolbar.

## Usage

1. Navigate to a Zendesk ticket page.
2. Click the "Gather Context" button in the Chrome toolbar.
3. The extension will extract relevant text from the page, filter out sensitive information, and copy the extracted content to your clipboard.
4. You can now paste the gathered context into another application, such as a text editor or an email client.