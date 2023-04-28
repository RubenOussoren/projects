Opal.queue(function(Opal) {/* Generated by Opal 1.7.3 */
  var $klass = Opal.klass, $def = Opal.def, $send = Opal.send, $truthy = Opal.truthy, $rb_lt = Opal.rb_lt, $rb_minus = Opal.rb_minus, $rb_plus = Opal.rb_plus, $eqeqeq = Opal.eqeqeq, $hash2 = Opal.hash2, $thrower = Opal.thrower, $nesting = [], $$ = Opal.$r($nesting), nil = Opal.nil, content_script = nil;

  Opal.add_stubs('new,setup_message_listener,each,each_with_index,strip,<,-,length,+,filter_sensitive_information,empty?,<<,nil?,apply_filters,gather_context_and_copy_to_clipboard,===,extract_all_context,extract_internal_context,extract_public_context,gsub,attr_reader,load_common_names_from_preload_names,load_common_names_from_js_object,insert,search,union,filter_common_name,filter_email,filter_url,attr_accessor,each_char,downcase,children,[],[]=,is_end_of_word=,is_end_of_word');
  
  (function($base, $super, $parent_nesting) {
    var self = $klass($base, $super, 'ContentScript');

    var $nesting = [self].concat($parent_nesting), $$ = Opal.$r($nesting), $proto = self.$$prototype;

    $proto.filter = nil;
    
    
    $def(self, '$initialize', function $$initialize() {
      var self = this;

      
      self.filter = $$('Filter').$new();
      return self.$setup_message_listener();
    });
    
    $def(self, '$debug', function $$debug(message) {
      
      return console.log(message);
    });
    
    $def(self, '$extract_all_context', function $$extract_all_context() {
      var self = this, notes = nil, omni_log_elements = nil;

      
      notes = [];
      omni_log_elements = Array.from(document.querySelectorAll('[data-test-id="omni-log-message-content"]'));
      $send(omni_log_elements, 'each', [], function $$1(omni_log_element){var self = $$1.$$s == null ? this : $$1.$$s, note = nil, content_elements = nil, filtered_note = nil;

        
        if (omni_log_element == null) omni_log_element = nil;
        note = "";
        content_elements = Array.from(omni_log_element.querySelectorAll(':scope > *'));
        $send(content_elements, 'each_with_index', [], function $$2(content_element, index){var text_content = nil;

          
          if (content_element == null) content_element = nil;
          if (index == null) index = nil;
          text_content = (content_element.innerText).$strip();
          if ($truthy($rb_lt(index, $rb_minus(content_elements.$length(), 1)))) {
            text_content = $rb_plus(text_content, "\n")
          };
          return (note = $rb_plus(note, text_content));});
        filtered_note = self.$filter_sensitive_information(note.$strip());
        if ($truthy(filtered_note['$empty?']())) {
          return nil
        } else {
          return notes['$<<'](filtered_note)
        };}, {$$s: self});
      return notes;
    });
    
    $def(self, '$extract_internal_context', function $$extract_internal_context() {
      var self = this, notes = nil, omni_log_elements = nil;

      
      notes = [];
      omni_log_elements = Array.from(document.querySelectorAll('[data-test-id="omni-log-message-content"]'));
      $send(omni_log_elements, 'each', [], function $$3(omni_log_element){var self = $$3.$$s == null ? this : $$3.$$s, note = nil, content_elements = nil, filtered_note = nil;

        
        if (omni_log_element == null) omni_log_element = nil;
        if ($truthy(omni_log_element.closest('article').querySelector('[data-test-id="omni-log-internal-note-tag"]'))) {
          
          note = "";
          content_elements = Array.from(omni_log_element.querySelectorAll(':scope > *'));
          $send(content_elements, 'each_with_index', [], function $$4(content_element, index){var text_content = nil;

            
            if (content_element == null) content_element = nil;
            if (index == null) index = nil;
            text_content = (content_element.innerText).$strip();
            if ($truthy($rb_lt(index, $rb_minus(content_elements.$length(), 1)))) {
              text_content = $rb_plus(text_content, "\n")
            };
            return (note = $rb_plus(note, text_content));});
          filtered_note = self.$filter_sensitive_information(note.$strip());
          if ($truthy(filtered_note['$empty?']())) {
            return nil
          } else {
            return notes['$<<'](filtered_note)
          };
        } else {
          return nil
        };}, {$$s: self});
      return notes;
    });
    
    $def(self, '$extract_public_context', function $$extract_public_context() {
      var self = this, notes = nil, omni_log_elements = nil;

      
      notes = [];
      omni_log_elements = Array.from(document.querySelectorAll('[data-test-id="omni-log-message-content"]'));
      $send(omni_log_elements, 'each', [], function $$5(omni_log_element){var self = $$5.$$s == null ? this : $$5.$$s, note = nil, content_elements = nil, filtered_note = nil;

        
        if (omni_log_element == null) omni_log_element = nil;
        if ($truthy(omni_log_element.closest('article').querySelector('[data-test-id="omni-log-internal-note-tag"]'))) {
          return nil
        } else {
          
          note = "";
          content_elements = Array.from(omni_log_element.querySelectorAll(':scope > *'));
          $send(content_elements, 'each_with_index', [], function $$6(content_element, index){var text_content = nil;

            
            if (content_element == null) content_element = nil;
            if (index == null) index = nil;
            text_content = (content_element.innerText).$strip();
            if ($truthy($rb_lt(index, $rb_minus(content_elements.$length(), 1)))) {
              text_content = $rb_plus(text_content, "\n")
            };
            return (note = $rb_plus(note, text_content));});
          filtered_note = self.$filter_sensitive_information(note.$strip());
          if ($truthy(filtered_note['$empty?']())) {
            return nil
          } else {
            return notes['$<<'](filtered_note)
          };
        };}, {$$s: self});
      return notes;
    });
    
    $def(self, '$filter_sensitive_information', function $$filter_sensitive_information(text) {
      var self = this;

      
      if ($truthy(text['$nil?']())) {
        return nil
      };
      return self.filter.$apply_filters(text);
    });
    
    $def(self, '$setup_message_listener', function $$setup_message_listener() {
      var self = this;

      
      chrome.runtime.onMessage.addListener(function(request, sender, sendResponse) {
        var extracted_content;
        try {
          switch (request.action) {
            case 'copy-all-context':
              extracted_content = self.$gather_context_and_copy_to_clipboard("all");
              break;
            case 'copy-internal-context':
              extracted_content = self.$gather_context_and_copy_to_clipboard("internal");
              break;
            case 'copy-public-context':
              extracted_content = self.$gather_context_and_copy_to_clipboard("public");
              break;
            default:
              sendResponse({success: false});
              return;
          }
          sendResponse({success: true, content: extracted_content});
        } catch (error) {
          console.error('Error in ContentScript:', error);
          sendResponse({success: false});
        }
        return true;
      });
    
    });
    return $def(self, '$gather_context_and_copy_to_clipboard', function $$gather_context_and_copy_to_clipboard(context_type) {
      var self = this, context = nil, $ret_or_1 = nil, extracted_context = nil;

      
      context = ($eqeqeq("all", ($ret_or_1 = context_type)) ? (self.$extract_all_context()) : ($eqeqeq("internal", $ret_or_1) ? (self.$extract_internal_context()) : ($eqeqeq("public", $ret_or_1) ? (self.$extract_public_context()) : ([]))));
      extracted_context = "Context:\n";
      $send(context, 'each_with_index', [], function $$7(note, index){
        
        if (note == null) note = nil;
        if (index == null) index = nil;
        return (extracted_context = $rb_plus(extracted_context, "\n- Note " + ($rb_plus(index, 1)) + ":\n  " + (note.$gsub("\n", "\n  ")) + "\n"));});
      return extracted_context;
    });
  })($nesting[0], null, $nesting);
  (function($base, $super, $parent_nesting) {
    var self = $klass($base, $super, 'Filter');

    var $nesting = [self].concat($parent_nesting), $$ = Opal.$r($nesting);

    
    self.$attr_reader("common_first_names_trie", "common_last_names_trie");
    
    $def(self, '$initialize', function $$initialize() {
      var self = this;

      
      self.common_first_names_trie = $$('Trie').$new();
      self.common_last_names_trie = $$('Trie').$new();
      return self.$load_common_names_from_preload_names();
    });
    
    $def(self, '$load_common_names_from_preload_names', function $$load_common_names_from_preload_names() {
      var self = this;

      
      chrome.runtime.sendMessage({action: 'get_common_names'}, function(response) {
        if (chrome.runtime.lastError) {
          console.error('Error loading common names:', chrome.runtime.lastError);
          return;
        }
        if (response.COMMON_FIRST_NAMES && response.COMMON_LAST_NAMES) {
          self.$load_common_names_from_js_object(response.COMMON_FIRST_NAMES, response.COMMON_LAST_NAMES);
        } else {
          console.error('Error: common names not found in response');
        }
      });
    
    });
    
    $def(self, '$load_common_names_from_js_object', function $$load_common_names_from_js_object(first_names, last_names) {
      var self = this;

      
      $send(first_names, 'each', [], function $$8(name){var self = $$8.$$s == null ? this : $$8.$$s;
        if (self.common_first_names_trie == null) self.common_first_names_trie = nil;

        
        if (name == null) name = nil;
        return self.common_first_names_trie.$insert(name);}, {$$s: self});
      return $send(last_names, 'each', [], function $$9(name){var self = $$9.$$s == null ? this : $$9.$$s;
        if (self.common_last_names_trie == null) self.common_last_names_trie = nil;

        
        if (name == null) name = nil;
        return self.common_last_names_trie.$insert(name);}, {$$s: self});
    });
    
    $def(self, '$debug', function $$debug(message) {
      
      return console.log(message);
    });
    
    $def(self, '$filter_common_name', function $$filter_common_name(text) {
      var self = this;

      return $send(text, 'gsub', [/\b[a-zA-Z]+\b/], function $$10(word){var self = $$10.$$s == null ? this : $$10.$$s;
        if (self.common_last_names_trie == null) self.common_last_names_trie = nil;
        if (self.common_first_names_trie == null) self.common_first_names_trie = nil;

        
        if (word == null) word = nil;
        if (($truthy(self.common_first_names_trie.$search(word)) || ($truthy(self.common_last_names_trie.$search(word))))) {
          return "[redacted-n]"
        } else {
          return word
        };}, {$$s: self})
    });
    
    $def(self, '$filter_email', function $$filter_email(text) {
      
      
      if ($truthy(text['$nil?']())) {
        return nil
      };
      return text.$gsub(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z]{2,}\b/i, "[redacted-e]");
    });
    
    $def(self, '$filter_url', function $$filter_url(text) {
      var ignored_url_patterns = nil, ignored_url_regex = nil;

      
      if ($truthy(text['$nil?']())) {
        return nil
      };
      ignored_url_patterns = [/https?:\/\/getguru\.com/, /https?:\/\/bit\.ly/];
      ignored_url_regex = $$('Regexp').$union(ignored_url_patterns);
      return text.$gsub(ignored_url_regex, "[redacted-u]");
    });
    return $def(self, '$apply_filters', function $$apply_filters(text) {
      var self = this, filtered_text = nil;

      
      if ($truthy(text['$nil?']())) {
        return nil
      };
      filtered_text = self.$filter_common_name(text);
      filtered_text = self.$filter_email(filtered_text);
      return self.$filter_url(filtered_text);
    });
  })($nesting[0], null, $nesting);
  (function($base, $super) {
    var self = $klass($base, $super, 'TrieNode');

    
    
    self.$attr_accessor("children", "is_end_of_word");
    return $def(self, '$initialize', function $$initialize() {
      var self = this;

      
      self.children = $hash2([], {});
      return (self.is_end_of_word = false);
    });
  })($nesting[0], null);
  (function($base, $super, $parent_nesting) {
    var self = $klass($base, $super, 'Trie');

    var $nesting = [self].concat($parent_nesting), $$ = Opal.$r($nesting), $proto = self.$$prototype;

    $proto.root = nil;
    
    
    $def(self, '$initialize', function $$initialize() {
      var self = this;

      return (self.root = $$('TrieNode').$new())
    });
    
    $def(self, '$insert', function $$insert(word) {
      var $a, self = this, node = nil;

      
      node = self.root;
      $send(word.$downcase(), 'each_char', [], function $$11(char$){var $logical_op_recvr_tmp_1 = nil, $ret_or_1 = nil;

        
        if (char$ == null) char$ = nil;
        
        $logical_op_recvr_tmp_1 = node.$children();
        if ($truthy(($ret_or_1 = $logical_op_recvr_tmp_1['$[]'](char$)))) {
          $ret_or_1
        } else {
          $logical_op_recvr_tmp_1['$[]='](char$, $$('TrieNode').$new())
        };;
        return (node = node.$children()['$[]'](char$));});
      return ($a = [true], $send(node, 'is_end_of_word=', $a), $a[$a.length - 1]);
    });
    return $def(self, '$search', function $$search(word) {try { var $t_return = $thrower('return'); 
      var self = this, node = nil;

      
      node = self.root;
      $send(word.$downcase(), 'each_char', [], function $$12(char$){
        
        if (char$ == null) char$ = nil;
        if (!$truthy(node.$children()['$[]'](char$))) {
          $t_return.$throw(false)
        };
        return (node = node.$children()['$[]'](char$));}, {$$ret: $t_return});
      return node.$is_end_of_word();} catch($e) {
        if ($e === $t_return) return $e.$v;
        throw $e;
      }
    });
  })($nesting[0], null, $nesting);
  return (content_script = $$('ContentScript').$new());
});
