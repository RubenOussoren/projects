require 'set'

# Function to process a single file
def process_file(file_name)
  raw_data = File.readlines(file_name)

  # Remove single quotes, filter out one-letter names, and sort alphabetically
  raw_data.map do |line|
    name = line.gsub("'", "").strip.chomp(',')
    name.length > 1 ? name : nil
  end.compact
end

# Read common_words.txt file
common_words_file = "final_english_words_common.txt"
common_words = Set.new(File.readlines(common_words_file).map { |word| word.strip.downcase })

# Process the first_names.txt and last_names.txt files
first_names_file = "first_names.txt"
last_names_file = "last_names.txt"
all_first_names = process_file(first_names_file)
all_last_names = process_file(last_names_file)

# Remove duplicate names case-insensitively and sort alphabetically
unique_sorted_first_names = all_first_names.uniq { |name| name.downcase }.sort_by(&:downcase)
unique_sorted_last_names = all_last_names.uniq { |name| name.downcase }.sort_by(&:downcase)

# Remove common words from both lists after removing duplicates
unique_sorted_first_names = unique_sorted_first_names.reject { |name| common_words.include?(name.downcase) }
unique_sorted_last_names = unique_sorted_last_names.reject { |name| common_words.include?(name.downcase) }

# Convert unique_sorted_first_names to a Set with downcased names for faster lookup
unique_sorted_first_names_set = Set.new(unique_sorted_first_names.map(&:downcase))

# Remove duplicates between the two lists case-insensitively, keeping duplicates in the first_names list
unique_sorted_last_names = unique_sorted_last_names.reject { |last_name| unique_sorted_first_names_set.include?(last_name.downcase) }

# Add single quotes and a comma back to each name
formatted_first_names = unique_sorted_first_names.map { |name| "'#{name}'," }
formatted_last_names = unique_sorted_last_names.map { |name| "'#{name}'," }

# Write the modified data to new text files
File.open('final_first_names.txt', 'w') do |file|
  formatted_first_names.each { |line| file.puts(line) }
end

File.open('final_last_names.txt', 'w') do |file|
  formatted_last_names.each { |line| file.puts(line) }
end