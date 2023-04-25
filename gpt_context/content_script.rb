# The ContentScript class is responsible for extracting context from Zendesk pages and filtering sensitive information.

class ContentScript
  def initialize
    # Set up the message listener when a new instance is created.
    setup_message_listener
  end

  # Extract context from elements with the `data-test-id="omni-log-message-content"` attribute.
  def extract_context
    notes = []
    omni_log_elements = `Array.from(document.querySelectorAll('[data-test-id="omni-log-message-content"]'))`
    omni_log_elements.each do |omni_log_element|
      note = ''
      content_elements = `Array.from(#{omni_log_element}.querySelectorAll(':scope > *'))`
      content_elements.each_with_index do |content_element, index|
        text_content = `#{content_element}.innerText`.strip
        text_content += "\n" if index < content_elements.length - 1
        note += text_content
      end
      notes << filter_sensitive_information(note.strip)
    end
    notes
  end

  # Apply filters to the extracted text to remove sensitive information.
  def filter_sensitive_information(text)
    return nil if text.nil?
    Filter.apply_filters(text)
  end

  # Set up a message listener to handle the 'gather_context' action, which triggers the extraction and filtering process when the "Gather Context" button is clicked in the popup.
  def setup_message_listener
    %x{
      chrome.runtime.onMessage.addListener(function(request, sender, sendResponse) {
        if (request.action == 'gather_context') {
          try {
            var extracted_content = #{gather_context_and_copy_to_clipboard};
            sendResponse({success: true, content: extracted_content});
          } catch (error) {
            console.error('Error in ContentScript:', error);
            sendResponse({success: false});
          }
          return true;
        }
      });
    }
  end
  
  # Gather context from the Zendesk page and send the extracted content as a response.
  def gather_context_and_copy_to_clipboard
    context = extract_context
  
    extracted_context = "Context:\n"
    context.each_with_index do |note, index|
      extracted_context += "\n- Note #{index + 1}:\n  #{note.gsub("\n", "\n  ")}\n"
    end
  
    extracted_context
  end
end

# The Filter class contains methods for filtering sensitive information such as names, common names, emails, and URLs.
class Filter
  # Filter out names from the given text.
  def self.filter_name(text)
    return nil if text.nil?
    text.gsub(/\b[A-Z][a-z]*\s*[A-Z][a-z]*\b(?=[^a-zA-Z\d\s]|$)/, '[redacted-n]')
  end

  # Filter out common names from the given text.
  def self.filter_common_name(text)
    return nil if text.nil?
    first_name_regex = Regexp.new(`window.COMMON_FIRST_NAMES`.join('|'), 'i')
    last_name_regex = Regexp.new(`window.COMMON_LAST_NAMES`.join('|'), 'i')
    name_regex = Regexp.union(first_name_regex, last_name_regex)
    text.gsub(/\b#{name_regex}\b/i, '[redacted-cn]')
  end

  # Filter out email addresses from the given text.
  def self.filter_email(text)
    return nil if text.nil?
    text.gsub(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z]{2,}\b/i, '[redacted-e]')
  end

  # Filter out URLs from the given text.
  def self.filter_url(text)
    return nil if text.nil?
  
    ignored_url_patterns = [
      /https?:\/\/getguru\.com/,
      /https?:\/\/bit\.ly/
    ]
  
    ignored_url_regex = Regexp.union(ignored_url_patterns)
  
    text.gsub(ignored_url_regex, '[redacted-u]')
  end

  # Apply all the filters to the given text.
  def self.apply_filters(text)
    return nil if text.nil?
    filtered_text = filter_name(text)
    filtered_text = filter_common_name(filtered_text)
    filtered_text = filter_email(filtered_text)
    #filtered_text = filter_url(filtered_text)
    filtered_text
  end
end

# Create a new ContentScript instance, which sets up the message listener and makes the script ready to receive messages from the popup script.
content_script = ContentScript.new