# Read the CSV file line by line and match the expected format
raw_data = []
File.foreach('intersurnames.csv') do |line|
  match = line.match(/^(?<last_name>[a-zA-Z]+),(?<number>\d+)/)
  next unless match

  raw_data << [match[:last_name] + ',' + match[:number]]
end

# Convert the raw data input and keep the comma
modified_data = raw_data.map do |name|
  last_name, _ = name.first.split(',')
  formatted_last_name = last_name.capitalize.gsub(/(?<=\w)([A-Z])/, &:downcase)
  "'#{formatted_last_name}',"
end
modified_data = modified_data.sort

# Write the modified data to a new file
File.open('modified_last_names.txt', 'w') do |file|
  modified_data.each { |name| file.puts(name) }
end