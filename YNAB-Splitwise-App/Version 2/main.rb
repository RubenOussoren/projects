require 'splitwise'
require 'ynab'
require 'yaml'
require 'digest/md5'

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
  new_transactions = []
  update_transactions = []

  transactions.each do |transaction_data|
    expense = transaction_data[:expense]
    is_deleted = transaction_data[:is_deleted]

    if expense.is_a?(Hash)
      if expense.key?(:id) && !expense[:id].nil?
        update_transactions << expense
      else
        new_transactions << expense
      end
    else
      amount = (expense.amount.to_f * 1000).round(0)
      category_id = get_category_id(expense.category, category_map, settings['settings']['ynab_default_category_id'])
      memo = "#{expense.description} (Total: $#{expense.total})"

      new_transaction = {
        account_id: api_call_data[:account_id],
        date: expense.date.to_s,
        amount: amount,
        payee_name: expense.payee_name,
        category_id: category_id,
        memo: memo,
        cleared: 'cleared',
        import_id: generate_import_id(expense, is_deleted)
      }

      new_transactions << new_transaction
    end
  end

  if new_transactions.any?
    transaction_service = YNAB::TransactionsApi.new
    new_transactions.each do |new_transaction|
      transaction_service.create_transaction(budget_id, {transaction: new_transaction})
    end
    puts "Imported #{new_transactions.size} new transactions."
  end

  if update_transactions.any?
    update_transactions.each do |transaction|
      transaction_service = YNAB::TransactionsApi.new
      transaction_service.update_transaction(budget_id, transaction[:id], {transaction: transaction})
    end
    puts "Updated #{update_transactions.size} transactions."
  end
rescue StandardError => e
  puts "Failed to import/update transactions in YNAB: #{e.message}"
end

def create_splitwise_transactions_hash(splitwise_expenses)
  splitwise_transactions_hash = {}

  splitwise_expenses.each do |expense|
    next unless expense.amount.to_f != 0

    key = [
      expense.date.to_s,
      "#{expense.description} (Total: $#{expense.total})".downcase.strip,
      (expense.amount.to_f * 1000).round(0)
    ]
    splitwise_transactions_hash["splitwise_#{expense.id}"] = { key: key, expense: expense }
  end

  splitwise_transactions_hash
end

def create_ynab_transactions_hash(ynab_transactions)
  ynab_transactions_hash = {}

  ynab_transactions.each do |transaction|
    key = [
      transaction.date.to_s,
      transaction.memo&.downcase&.strip,
      transaction.amount
    ]
    ynab_transactions_hash[transaction.import_id] = { key: key, transaction: transaction }
  end

  ynab_transactions_hash
end

def generate_import_id(expense, is_deleted = false, timestamp = Time.now.to_i, check_alternative = false)
  import_id_prefix = is_deleted ? "deleted_" : ""
  timestamp_suffix = check_alternative ? "" : "_#{timestamp}"
  "#{import_id_prefix}splitwise_#{expense.id}#{timestamp_suffix}"
end

def sync_transactions(splitwise_expenses, ynab_transactions, ynab_client, budget_id, account_id, category_map, default_category_id, api_call_data, settings)
  splitwise_transactions_hash = create_splitwise_transactions_hash(splitwise_expenses)
  ynab_transactions_hash = create_ynab_transactions_hash(ynab_transactions)

  missing_or_deleted_transactions = []
  update_required_transactions = []

  splitwise_transactions_hash.each do |import_id, splitwise_data|
    expense = splitwise_data[:expense]
    ynab_data = ynab_transactions_hash[import_id]

    if ynab_data
      # Matched by import_id
      ynab_transaction = ynab_data[:transaction]
    else
      # No match by import_id, perform legacy comparison
      ynab_key_match = ynab_transactions_hash.values.find { |data| data[:key] == splitwise_data[:key] }
      ynab_transaction = ynab_key_match ? ynab_key_match[:transaction] : nil
    end

    if ynab_transaction
      if ynab_transaction.deleted
        missing_or_deleted_transactions << { expense: expense, is_deleted: true }
      else
        # Check if an update is required for the matched ynab_transaction
        updated = false

        ynab_amount = (expense.amount.to_f * 1000).round(0)
        updated ||= ynab_transaction.amount != ynab_amount

        memo = "#{expense.description} (Total: $#{expense.total})"
        updated ||= ynab_transaction.memo&.downcase&.strip != memo.downcase.strip

        update_required_transactions << expense if updated
      end
    else
      missing_or_deleted_transactions << { expense: expense, is_deleted: false }
    end
  end

  # Display the summary of each scenario
  puts "Missing or deleted transactions found for import: #{missing_or_deleted_transactions.count}"
  puts "Update required for transactions: #{update_required_transactions.count}"

  # Confirm with the user whether to perform the import
  puts "\nDo you want to import/update the transactions based on the scenarios above? (y/n)"
  import_input = gets.chomp.downcase

  if import_input == 'y'
    transactions_to_import = missing_or_deleted_transactions + update_required_transactions
    import_expenses_into_ynab(ynab_client, budget_id, transactions_to_import, category_map, settings, api_call_data)
  else
    puts "No action taken. Exiting program."
  end
end

settings, category_map = load_configs
splitwise_auth = initialize_splitwise
ynab_auth = initialize_ynab
api_call_data = ynab_auth.api_call_data

last_transaction_date = retrieve_recent_transaction_data(ynab_auth.ynab_api_working? ? YNAB::API.new(api_call_data[:access_token]) : nil, api_call_data[:budget_id], api_call_data[:account_id])

# Retrieve expenses
splitwise_expenses = splitwise_auth.get_expenses(last_transaction_date)
ynab_transactions = ynab_auth.ynab_api_working? ? YNAB::API.new(api_call_data[:access_token]).transactions.get_transactions(api_call_data[:budget_id], account_id: api_call_data[:account_id], per_page: 1000).data.transactions : []

# Create YNAB and Splitwise transactions hashes
ynab_transactions_hash = create_ynab_transactions_hash(ynab_transactions)
splitwise_transactions_hash = create_splitwise_transactions_hash(splitwise_expenses)

# Filter out transactions that are not missing or deleted from Splitwise expenses
filtered_expenses = splitwise_transactions_hash.reject do |import_id, splitwise_data|
  ynab_data = ynab_transactions_hash[import_id]
  ynab_data || (ynab_key_match = ynab_transactions_hash.values.find { |data| data[:key] == splitwise_data[:key] })
end

# Import new transactions into YNAB
import_expenses_into_ynab(ynab_auth.ynab_api_working? ? YNAB::API.new(api_call_data[:access_token]) : nil, api_call_data[:budget_id], filtered_expenses.map { |_, data| {expense: data[:expense], is_deleted: data[:is_deleted]} }, category_map, settings, api_call_data)

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
