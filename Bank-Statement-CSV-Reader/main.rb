#!/usr/bin/env ruby

require_relative 'transaction_manager'
require_relative 'google_sheets_manager'

def main
  # Collect user input for CSV filenames
  credit_transactions_csv = input_csv_filename('Credit')
  debit_transactions_csv = input_csv_filename('Debit')

  # Collect user input for date range
  month, year = input_month_and_year
  start_date = Date.new(year, month, 1)
  end_date = Date.new(year, month, -1)
  month_year = format('%02d-%d', month, year)

  # Initialize TransactionManager with the CSV files and date range
  transaction_manager = TransactionManager.new(credit_transactions_csv, debit_transactions_csv, start_date, end_date)

  # Categorize transactions (Prompt user when required)
  transaction_manager.categorize_transactions

  # Calculate totals for each category
  category_totals = transaction_manager.calculate_category_totals

  # Initialize GoogleSheetsManager
  google_sheets_manager = GoogleSheetsManager.new
  sheet_name = "Transactions #{year}"

  # Insert categorized data into Google Sheets
  google_sheets_manager.create_and_populate_sheet(sheet_name, month_year, category_totals)
end

def input_csv_filename(type)
  filename = ""
  while filename.empty?
    puts "Please enter the #{type} transactions CSV filename (E.g., #{type.downcase}_transactions):"
    input = gets.chomp.strip + ".csv"
    csv_path = File.join('csv_files', input)
    if File.exist?(csv_path)
      filename = csv_path
    else
      puts "File not found. Please try again."
    end
  end
  filename
end

def input_month_and_year
  puts "Please enter the month and year as MM-YYYY for the transactions (e.g., 01-2022):"
  input = gets.chomp.strip
  match_data = /(\d{1,2})-(\d{4})/.match(input)
  if match_data.nil?
    puts "Invalid input format. Please try again."
    input_month_and_year
  else
    month = match_data.captures[0].to_i
    year = match_data.captures[1].to_i
    if month > 0 && month < 13 && year > 1900
      return month, year
    else
      puts "Invalid month or year. Please try again."
      input_month_and_year
    end
  end
end

main
