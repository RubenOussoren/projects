require 'csv'

# Read the CSV file
raw_data = CSV.read('last_name.csv')

# Add single quotes around each name and keep the comma
modified_data = raw_data.map { |name| "'#{name.first}'," }
modified_data = modified_data.sort

# Write the modified data to a new file
File.open('modified_names.txt', 'w') do |file|
  modified_data.each { |name| file.puts(name) }
end



# Function to process a single file
#def process_file(file_name)
#    raw_data = File.readlines(file_name)
#  
#    # Add single quotes around each name, remove gender and count, and keep the comma
#    raw_data.map do |line|
#      name, _gender, _count = line.split(',')
#      "'#{name}',"
#    end
#  end
  
  # Process all files from yob1990.txt to yob2021.txt and concatenate the results
#  all_modified_data = (1993..1993).flat_map do |year|
#    file_name = "yob#{year}.txt"
#    process_file(file_name)
#  end
  
  # Remove duplicate names and sort alphabetically
#  unique_sorted_data = all_modified_data.uniq.sort
  
  # Write the modified data to a new text file
#  File.open('unique_sorted_names.txt', 'w') do |file|
#    unique_sorted_data.each { |line| file.puts(line) }
#  end