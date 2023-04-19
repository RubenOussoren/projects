require 'csv'
require 'date'
require_relative 'splitwise_auth'

class TransactionManager
  attr_reader :transactions

  def initialize(csv_credit_file, csv_debit_file, start_date, end_date)
    @splitwise_auth = SplitwiseAuth.new
    @credit_transactions = read_csv(csv_credit_file)
    @debit_transactions = read_csv(csv_debit_file)
    @transactions = []
    @start_date = start_date
    @end_date = end_date
  end

  def read_csv(file)
    CSV.read(file, headers: false, converters: :numeric)
  end

  def categorize_transactions
    fetch_splitwise_transactions
    merge_transactions
    categorize_transactions_manually
  end

  def calculate_category_totals
    totals = {
      'Phone' => @totals[:phone],
      'Internet' => @totals[:internet],
      'Insurance' => @totals[:insurance],
      'Hydro' => @totals[:hydro],
      'Splitwise' => @totals[:splitwise_total],
      'Pay' => 0,
      'Rent' => 0,
      'Property Income' => 0,
      'Property Tax' => 0,
      'Maintenance' => 0,
      'Mortgage' => 0,
      'Debit and Credit' => 0,
      'Management Fee' => 0
    }

    @transactions.each do |transaction|
      category = transaction[:category]
      inflow = transaction[:inflow].nil? ? 0.0 : transaction[:inflow]
      outflow = transaction[:outflow].nil? ? 0.0 : transaction[:outflow]
      amount = inflow - outflow

      # Skip if the category is 'Ignore' or not in the desired categories
      next if category == 'Ignore' || !totals.key?(category)

      if category == 'Property Income'
        totals['Property Income'] += amount * 0.95
        totals['Management Fee'] += amount * 0.05
      else
        totals[category] += amount
      end
    end

    totals
  end

  private

  def fetch_splitwise_transactions
    splitwise_transactions = @splitwise_auth.get_expenses(@start_date, @end_date)

    # Define category totals
    @totals = {
      phone: 0,
      internet: 0,
      insurance: 0,
      hydro: 0,
      splitwise_total: 0
    }

    splitwise_transactions.each do |transaction|
      # Add your custom attributes to match your requirements
      transaction_data = {
        date: transaction.date,
        description: transaction.description,
        outflow: transaction.amount.to_f < 0 ? -transaction.amount.to_f : 0,
        inflow: transaction.amount.to_f > 0 ? transaction.amount.to_f : 0,
        category: transaction.category
      }

      # Process 'TV/Phone/Internet' transactions separately
      if transaction_data[:category] == 'TV/Phone/Internet'
        transaction_data = categorize_tv_phone_internet(transaction_data)
      end

      # Update total for specific categories
      case transaction_data[:category]
      when 'Insurance'
        @totals[:insurance] += transaction_data[:inflow] - transaction_data[:outflow]
      when 'Electricity'
        @totals[:hydro] += transaction_data[:inflow] - transaction_data[:outflow]
      else
        if transaction_data[:category] != 'TV/Phone/Internet'
          @totals[:splitwise_total] += transaction_data[:inflow] - transaction_data[:outflow]
        end
      end

      @transactions.push(transaction_data)
    end

    puts "Total for the selected period (excluding Phone, Internet, Insurance, and Hydro categories): #{@totals[:splitwise_total]}"
    puts "Category-wise totals: #{@totals}"
  end

  def categorize_tv_phone_internet(transaction_data)
    puts "Please choose the correct category for the '#{transaction_data[:description]}' transaction (Options: 1. Phone, 2. Internet): "
    choice = gets.chomp.to_i

    case choice
    when 1
      transaction_data[:category] = 'Phone'
    when 2
      transaction_data[:category] = 'Internet'
    else
      puts "Invalid option selected. Skipping categorization for this transaction."
    end

    transaction_data
  end

  def merge_transactions
    [@credit_transactions, @debit_transactions].each do |csv_transactions|
      csv_transactions.each do |transaction|
        next if transaction[0].nil?

        @transactions.push({
          date: Date.parse(transaction[0]),
          description: transaction[1],
          outflow: transaction[2],
          inflow: transaction[3],
          category: ''
        })
      end
    end
  end

  def categorize_transactions_manually
    puts "\nCategorizing transactions...\n"
    @transactions.each do |transaction|
      next if transaction[:category].length > 0

      puts "\n#{transaction[:date]}: #{transaction[:description]}"
      puts "Inflow: #{transaction[:inflow]}" if transaction[:inflow] && transaction[:inflow] > 0
      puts "Outflow: #{transaction[:outflow]}" if transaction[:outflow] && transaction[:outflow] > 0

      transaction[:category] = prompt_for_category
    end
    puts "\nYou've reached the end of your transactions list!!"
    puts "Please wait while we import your transactions into your Mons Sheets Budget...\n"
  end

  def prompt_for_category
    valid_categories = ["Pay", "Rent", "Property Income", "Property Tax", "Maintenance", "Mortgage", "Ignore", "Debit and Credit"]
    puts "\nSelect a category to assign:"
    valid_categories.each_with_index { |category, index| puts "#{index + 1}. #{category}" }
    input = gets.chomp.to_i

    if input > 0 && input <= valid_categories.length
      valid_categories[input - 1]
    else
      puts "\nInvalid input. Please try again.\n"
      prompt_for_category
    end
  end
end
