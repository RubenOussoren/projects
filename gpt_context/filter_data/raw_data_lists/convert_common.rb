# Read the CSV files line by line and match the expected format
raw_data = []
['common_boys.csv', 'common_girls.csv'].each do |filename|
  File.foreach(filename) do |line|
    names = line.split(',').select.with_index { |_, index| index % 3 == 2 }
    raw_data.concat(names)
  end
end

# Convert the raw data input and keep the comma
modified_data = raw_data.map do |name|
  formatted_name = name.capitalize.gsub(/(?<=\w)([A-Z])/, &:downcase)
  "#{formatted_name}"
end
modified_data = modified_data.uniq.sort

# Write the modified data to a new file
File.open('common_english_names.txt', 'w') do |file|
  modified_data.each { |name| file.puts(name) }
end