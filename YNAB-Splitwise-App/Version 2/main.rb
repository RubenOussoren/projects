require 'splitwise'
require 'ynab'
require 'yaml'

require_relative 'splitwise_auth'
require_relative 'ynab_auth'

def get_category_id(keyword, category_map, default_category_id)
  category_map.detect { |category| category['keywords']&.map(&:downcase)&.include?(keyword.downcase) }&.fetch('id', default_category_id) || default_category_id
end

def load_configs
  settings = YAML.load_file('config.yml')
  category_map = YAML.load_file('category_map.yml')
  [settings, category_map]
end

def initialize_splitwise
  splitwise_auth = SplitwiseAuth.new
  splitwise_auth.splitwise_api_working? ? splitwise_auth : SplitwiseAuth.new
end

def initialize_ynab
  ynab_auth = YnabAuth.new
  ynab_auth.ynab_api_working? ? ynab_auth : YnabAuth.new
end

def retrieve_recent_transaction_data(ynab_client, budget_id, account_id)
  ynab_client.transactions.get_transactions(
    budget_id, account_id: account_id, sort_by: 'date', sort_order: 'desc', per_page: 1
  ).data.transactions.last&.date
rescue StandardError => e
  puts "Failed to retrieve last transaction date from YNAB: #{e.message}"
  nil
end

def import_expenses_into_ynab(ynab_client, budget_id, transactions, category_map, settings, api_call_data)
  new_transactions_data = transactions.map do |expense|
    if expense.is_a?(Hash)
      expense
    else
      amount = (expense.amount.to_f * 1000).round(0)
      category_id = get_category_id(expense.category, category_map, settings['settings']['ynab_default_category_id'])
      memo = "#{expense.description} (Total: $#{expense.total})"

      {
        account_id: api_call_data[:account_id],
        date: expense.date.to_s,
        amount: amount,
        payee_name: expense.payee_name,
        category_id: category_id,
        memo: memo,
        cleared: 'cleared',
        import_id: expense.id.to_s
      }
    end
  end

  transactions_api = YNAB::TransactionsApi.new
  bulk_transactions = YNAB::BulkTransactions.new(transactions: new_transactions_data)
  transactions_created = transactions_api.create_transaction(budget_id, bulk_transactions).data

  successful_transactions = []
  failed_transactions = []

  transactions_created.transactions.each do |transaction|
    ynab_transaction = transactions_api.get_transaction_by_id(budget_id, transaction.id).data.transaction
    if ynab_transaction
      successful_transactions << transaction.id
    else
      failed_transactions << transaction.id
    end
  end

  unless successful_transactions.empty?
    puts "#{successful_transactions.size} transactions have been imported into YNAB."
    successful_transactions.each { |transaction_id| puts "Transaction #{transaction_id} has been imported into YNAB." }
  end

  unless failed_transactions.empty?
    puts "Failed to import transactions into YNAB:"
    failed_transactions.each { |transaction_id| puts "- Transaction #{transaction_id} failed to import" }
  end
rescue StandardError => e
  puts "Failed to import transactions into YNAB: #{e.message}"
end

def sync_transactions(splitwise_expenses, ynab_transactions, ynab_client, budget_id, account_id, category_map, default_category_id, api_call_data, settings)
  # Normalize Splitwise expenses and create a hash
  splitwise_transactions_hash = {}
  splitwise_expenses.each do |expense|
    next unless expense.amount.to_f != 0

    key = [
      expense.date.to_s,
      expense.description&.downcase&.strip,
      (expense.amount.to_f * 1000).round(0)
    ]

    splitwise_transactions_hash[key] = expense
  end

  # Normalize YNAB transactions and create a hash
  ynab_transactions_hash = {}
  ynab_transactions.each do |transaction|
    key = [
      transaction.date.to_s,
      transaction.memo&.downcase&.strip,
      transaction.amount
    ]

    ynab_transactions_hash[key] = transaction
  end

  # Get the hash keys of missing transactions
  missing_keys = splitwise_transactions_hash.keys - ynab_transactions_hash.keys

  if missing_keys.any?
    puts "Missing transactions in YNAB:"

    missing_transactions = missing_keys.map do |key|
      expense = splitwise_transactions_hash[key]
      amount = (expense.amount.to_f * 1000).round(0)
      category_id = get_category_id(expense.category, category_map, default_category_id)
      memo = "#{expense.description} (Total: $#{expense.total})"

      {
        account_id: api_call_data[:account_id],
        date: expense.date.to_s,
        amount: amount,
        payee_name: expense.payee_name,
        category_id: category_id,
        memo: memo,
        cleared: 'cleared',
        import_id: expense.id.to_s
      }
    end

    # Call the import_transactions_to_ynab method to import the missing transactions
    import_expenses_into_ynab(ynab_client, budget_id, missing_transactions, category_map, settings, api_call_data)
  else
    puts "All transactions are up to date."
  end
end

settings, category_map = load_configs
splitwise_auth = initialize_splitwise
ynab_auth = initialize_ynab
api_call_data = ynab_auth.api_call_data

last_transaction_date = retrieve_recent_transaction_data(ynab_auth.ynab_api_working? ? YNAB::API.new(api_call_data[:access_token]) : nil, api_call_data[:budget_id], api_call_data[:account_id])

# Retrieve expenses
splitwise_expenses = splitwise_auth.get_expenses(last_transaction_date)

# Import new transactions into YNAB first
import_expenses_into_ynab(ynab_auth.ynab_api_working? ? YNAB::API.new(api_call_data[:access_token]) : nil, api_call_data[:budget_id], splitwise_expenses, category_map, settings, api_call_data)

begin
  puts "Do you want to perform a sync operation? (y/n)"
  perform_sync_input = gets.chomp.downcase
  raise ArgumentError, "Invalid input. Please enter 'y' or 'n'." unless ['y', 'n'].include?(perform_sync_input)
  if perform_sync_input == 'n'
    puts "Exiting program."
    exit
  end
  perform_sync = perform_sync_input == 'y'
rescue ArgumentError => e
  puts e.message
  retry
end

begin
  puts "Enter the start date for transaction comparison (YYYY-MM-DD):"
  start_date = Date.parse(gets.chomp)
  raise ArgumentError, "The earliest date that can be entered is 2023-03-30" if start_date < Date.parse("2023-01-01")
rescue ArgumentError => e
  puts e.message
  retry
end

if perform_sync
  begin
    ynab_client = YNAB::API.new(api_call_data[:access_token])
    # Retrieve expenses and transactions
    splitwise_expenses = splitwise_auth.get_expenses(last_transaction_date)
    ynab_transactions = ynab_client.transactions.get_transactions(
      api_call_data[:budget_id],
      account_id: api_call_data[:account_id],
      since_date: start_date.to_s,
      per_page: 1000
    ).data.transactions

    # Perform sync
    sync_transactions(splitwise_expenses, ynab_transactions, ynab_client, api_call_data[:budget_id], api_call_data[:account_id], category_map, settings['settings']['ynab_default_category_id'], api_call_data, settings)
  rescue YNAB::ApiError => e
    puts "An error occurred while syncing transactions: #{e}"
  end
end

# Import new transactions into YNAB
import_expenses_into_ynab(ynab_auth.ynab_api_working? ? YNAB::API.new(api_call_data[:access_token]) : nil, api_call_data[:budget_id], splitwise_expenses, category_map, settings, api_call_data)
