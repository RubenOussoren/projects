require 'set'

# Function to process a single file
def process_file(file_name)
  raw_data = File.readlines(file_name)

  # Remove single quotes, filter out one-letter names, and sort alphabetically
  raw_data.map do |line|
    word = line.downcase.gsub("'", "").strip.chomp(',')
    word.length > 1 ? word : nil
  end.compact
end

# Read common_english_names.txt and english_words_common.txt files
common_english_names_file = "common_english_names.txt"
english_words_common_file = "english_words_common.txt"
common_english_names = Set.new(process_file(common_english_names_file))
english_words_common = Set.new(process_file(english_words_common_file))

# Remove names from the english_words_common set
english_words_common -= common_english_names

# Convert the set to an array, remove duplicates, and sort alphabetically
unique_sorted_english_words = english_words_common.to_a.uniq.sort

# Add single quotes and a comma back to each word
formatted_english_words = unique_sorted_english_words.map { |word| "#{word}" }

# Write the modified data to a new text file
File.open('final_english_words_common.txt', 'w') do |file|
  formatted_english_words.each { |line| file.puts(line) }
end