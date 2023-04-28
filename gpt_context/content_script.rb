# The ContentScript class is responsible for extracting context from Zendesk pages and filtering sensitive information.

class ContentScript
  def initialize
    # Set up the message listener when a new instance is created.
    @filter = Filter.new
    setup_message_listener
  end

  def debug(message)
    %x{console.log(message)}
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
      filtered_note = filter_sensitive_information(note.strip)
      notes << filtered_note unless filtered_note.empty?
    end
    notes
  end

  # Apply filters to the extracted text to remove sensitive information.
  def filter_sensitive_information(text)
    return nil if text.nil?
    @filter.apply_filters(text)
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
  attr_reader :common_first_names_trie, :common_last_names_trie

  def initialize
    # Initialize the Trie for common first and last names
    @common_first_names_trie = Trie.new
    @common_last_names_trie = Trie.new
  
    # Load common names from the preload_names script
    load_common_names_from_preload_names
  end

  def load_common_names_from_preload_names
    %x{
      chrome.runtime.sendMessage({action: 'get_common_names'}, function(response) {
        if (chrome.runtime.lastError) {
          console.error('Error loading common names:', chrome.runtime.lastError);
          return;
        }
        if (response.COMMON_FIRST_NAMES && response.COMMON_LAST_NAMES) {
          #{load_common_names_from_js_object(`response.COMMON_FIRST_NAMES`, `response.COMMON_LAST_NAMES`)};
        } else {
          console.error('Error: common names not found in response');
        }
      });
    }
  end
  
  def load_common_names_from_js_object(first_names, last_names)
    first_names.each { |name| @common_first_names_trie.insert(name) }
    last_names.each { |name| @common_last_names_trie.insert(name) }
  end

  def debug(message)
    %x{console.log(message)}
  end

  # Filter out common names from the given text.
  def filter_common_name(text)
    text.gsub(/\b[a-zA-Z]+\b/) do |word|
      if @common_first_names_trie.search(word) || @common_last_names_trie.search(word)
        '[redacted-n]'
      else
        word
      end
    end
  end

  # Filter out names from the given text.
  #def self.filter_name(text)
  #  return nil if text.nil?
  #  text.gsub(/\b[A-Z][a-z]*\s*[A-Z][a-z]*\b(?=[^a-zA-Z\d\s]|$)/, '[redacted-sn]')
  #end

  # Filter out email addresses from the given text.
  def filter_email(text)
    return nil if text.nil?
    text.gsub(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z]{2,}\b/i, '[redacted-e]')
  end

  # Filter out URLs from the given text.
  def filter_url(text)
    return nil if text.nil?
  
    ignored_url_patterns = [
      /https?:\/\/getguru\.com/,
      /https?:\/\/bit\.ly/
    ]
  
    ignored_url_regex = Regexp.union(ignored_url_patterns)
  
    text.gsub(ignored_url_regex, '[redacted-u]')
  end

  # Apply all the filters to the given text.
  def apply_filters(text)
    return nil if text.nil?
    #filtered_text = filter_name(filtered_text)
    filtered_text = filter_common_name(text)
    filtered_text = filter_email(filtered_text)
    filtered_text = filter_url(filtered_text)
    filtered_text
  end
end

class TrieNode
  attr_accessor :children, :is_end_of_word

  def initialize
    @children = {}
    @is_end_of_word = false
  end
end
class Trie
  def initialize
    @root = TrieNode.new
  end

  def insert(word)
    node = @root
    word.downcase.each_char do |char|
      node.children[char] ||= TrieNode.new
      node = node.children[char]
    end
    node.is_end_of_word = true
  end

  def search(word)
    node = @root
    word.downcase.each_char do |char|
      return false unless node.children[char]
      node = node.children[char]
    end
    node.is_end_of_word
  end
end

# Create a new ContentScript instance, which sets up the message listener and makes the script ready to receive messages from the popup script.
content_script = ContentScript.new