# Read the CSV file line by line and match the expected format
raw_data = []
File.foreach('interall.csv') do |line|
  match = line.match(/^(?<first_name>[a-zA-Z]+),(?<number>\d+)/)
  next unless match

  raw_data << [match[:first_name] + ',' + match[:number]]
end

# Convert the raw data input and keep the comma
modified_data = raw_data.map do |name|
  first_name, _ = name.first.split(',')
  formatted_first_name = first_name.capitalize.gsub(/(?<=\w)([A-Z])/, &:downcase)
  "'#{formatted_first_name}',"
end
modified_data = modified_data.sort

# Write the modified data to a new file
File.open('modified_first_names.txt', 'w') do |file|
  modified_data.each { |name| file.puts(name) }
end