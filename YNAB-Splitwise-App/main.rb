require 'splitwise'
require 'ynab'
require 'yaml'
require 'json'
require 'digest/md5'

require_relative 'splitwise_auth'
require_relative 'ynab_auth'

skip_sync_question = ARGV.include?('-s')
$script_directory = File.dirname(File.realdirpath(__FILE__))

def get_category_id(keyword, category_map, default_category_id)
  category_map.detect { |category| category['keywords']&.map(&:downcase)&.include?(keyword.downcase) }&.fetch('id', default_category_id) || default_category_id
end

def load_configs
  settings = YAML.load_file(File.join($script_directory, 'config.yml'))
  category_map = YAML.load_file(File.join($script_directory, 'category_map.yml'))
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

def load_mapping_file(mapping_file = 'mapping.json')
  mapping_path = File.expand_path(mapping_file, $script_directory)
  if File.exist?(mapping_path) # Changed this line
    JSON.parse(File.read(mapping_path))
  else
    puts "Mapping file not found at #{mapping_path}."
    {}
  end
rescue StandardError => e
  puts "Failed to load mapping file: #{e.message}"
  {}
end

def write_mapping_file(mapping, mapping_file = 'mapping.json')
  mapping_path = File.join($script_directory, mapping_file)
  begin
    File.write(mapping_path, mapping.to_json)
  rescue StandardError => e
    puts "Failed to write mapping file: #{e.message}"
  end
end

def retrieve_recent_transaction_data(ynab_client, budget_id, account_id)
  ynab_client.transactions.get_transactions(
    budget_id, account_id: account_id, sort_by: 'date', sort_order: 'desc', per_page: 1
  ).data.transactions.last&.date
rescue StandardError => e
  puts "Failed to retrieve last transaction date from YNAB: #{e.message}"
  nil
end

def update_mapping_statuses(mapping, ynab_transactions, splitwise_expenses)
  updated_mapping = mapping.dup

  updated_mapping.each do |splitwise_id, map_data|
    ynab_id = map_data['ynab_id']
    relationship_status = map_data['status']

    ynab_match = ynab_transactions.any? { |transaction| transaction.id == ynab_id }
    splitwise_match = splitwise_expenses.any? { |expense| expense.id.to_s == splitwise_id }

    if relationship_status != 'ignored'
      if ynab_match && !splitwise_match
        updated_mapping.delete(splitwise_id) # Scenario 2
      elsif !ynab_match && splitwise_match
        map_data['status'] = 'deleted' # Scenario 3
      # Scenario 4 and 4.a are handled in the sync_transactions method and don't need to be addressed here
      end
    elsif relationship_status == 'ignored' && !ynab_match && !splitwise_match
      #updated_mapping.delete(splitwise_id)
    end
  end
  updated_mapping
end

def filter_initial_transactions(splitwise_expenses, mapping)
  splitwise_expenses.reject do |expense|
    splitwise_id = expense.id.to_s
    splitwise_match = mapping.key?(splitwise_id)

    splitwise_match
  end
end

def generate_initial_mapping(splitwise_auth, ynab_client, account_id, since_date = nil, api_call_data)
  mapping = {}
  unmatched_transactions = []

  page = 1
  per_page = 100

  loop do
    previous_mapping_size = mapping.size

    puts "Fetching Splitwise expenses..."
    all_splitwise_expenses = splitwise_auth.get_expenses(since_date, page, per_page)
    puts "Fetched #{all_splitwise_expenses.size} Splitwise expenses."
    break if all_splitwise_expenses.empty?

    puts "Fetching YNAB transactions..."
    all_ynab_transactions = ynab_client.transactions.get_transactions(api_call_data[:budget_id], account_id: account_id, since_date: since_date, per_page: per_page).data.transactions
    puts "Fetched #{all_ynab_transactions.size} YNAB transactions."

    all_splitwise_expenses.each do |splitwise_expense|
      memo = "#{splitwise_expense.description} (Total: $#{splitwise_expense.total})".downcase.strip
      amount = (splitwise_expense.amount.to_f * 1000).round(0)

      ynab_transaction = all_ynab_transactions.find do |transaction|
        transaction.memo&.downcase&.strip == memo &&
        transaction.amount == amount &&
        transaction.date.to_s == splitwise_expense.date.to_s
      end

      if ynab_transaction
        mapping[splitwise_expense.id.to_s] = { 'ynab_id' => ynab_transaction.id, 'status' => ynab_transaction.deleted ? 'deleted' : 'active' }
      else
        unmatched_transactions << splitwise_expense unless unmatched_transactions.include?(splitwise_expense)
      end
    end

    if mapping.size == previous_mapping_size
      puts "No new transactions to map. Stopping."
      break
    end

    # Display progress in the command line
    puts "Page #{page} processed. Transactions mapped: #{mapping.size}"

    page += 1
  end

  puts "Splitwise transactions that could not be matched with YNAB transactions:"
  unmatched_transactions.each { |expense| STDERR.puts "- '#{expense.description}' (ID: #{expense.id})" }

  write_mapping_file(mapping)
  puts "Mapping of all transactions has finished."
  puts "Run the import again to start importing transactions!"
  exit
end

def import_initial_transactions_into_ynab(ynab_client, budget_id, filtered_expenses, category_map, settings, api_call_data, mapping)
  new_transactions = []

  filtered_expenses.each do |expense|
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
      import_id: generate_import_id(expense)
    }

    new_transactions << new_transaction
  end

  if new_transactions.any?
    transaction_service = YNAB::TransactionsApi.new
    new_transactions.each do |new_transaction|
      ynab_response = transaction_service.create_transaction(budget_id, {transaction: new_transaction})
      created_transaction = ynab_response.data.transaction
      splitwise_id = created_transaction.import_id[/_(\d+)/, 1]
      mapping[splitwise_id] = {'ynab_id' => created_transaction.id, 'status' => 'active'}
    end
    puts "Imported #{new_transactions.size} new transaction/s."
    write_mapping_file(mapping)
  else
    puts "There are no new transactions to import :)"
  end
rescue StandardError => e
  puts "Failed to import/update transactions in YNAB: #{e.message}"
end

def import_sync_transactions_into_ynab(ynab_client, budget_id, category_map, settings, api_call_data, mapping, missing_or_deleted_transactions, update_required_transactions)
  recreate_transactions = []
  update_transactions = []

  missing_or_deleted_transactions.each do |transaction_data|
    amount = (transaction_data.amount.to_f * 1000).round(0)
    category_id = get_category_id(transaction_data.category, category_map, settings['settings']['ynab_default_category_id'])
    memo = "#{transaction_data.description} (Total: $#{transaction_data.total})"

    recreate_transaction = {
      id: transaction_data.id,
      account_id: api_call_data[:account_id],
      date: transaction_data.date.to_s,
      amount: amount,
      payee_name: transaction_data.payee_name,
      category_id: category_id,
      memo: memo,
      cleared: 'cleared',
      import_id: generate_import_id(transaction_data)
    }
    recreate_transactions << recreate_transaction
  end

  update_required_transactions.each do |transaction_data|
    ynab_id = mapping[transaction_data.id.to_s]['ynab_id']
    amount = (transaction_data.amount.to_f * 1000).round(0)
    category_id = get_category_id(transaction_data.category, category_map, settings['settings']['ynab_default_category_id'])
    memo = "#{transaction_data.description} (Total: $#{transaction_data.total})"

    update_transaction = {
      id: ynab_id,
      account_id: api_call_data[:account_id],
      date: transaction_data.date.to_s,
      amount: amount,
      payee_name: transaction_data.payee_name,
      category_id: category_id,
      memo: memo,
      cleared: 'uncleared',
    }

    update_transactions << update_transaction
  end

  transaction_service = YNAB::TransactionsApi.new
  recreate_transactions.each do |transaction|
    ynab_response = transaction_service.create_transaction(budget_id, {transaction: transaction})
    created_transaction = ynab_response.data.transaction
    splitwise_id = transaction[:id]
    mapping[splitwise_id] = {'ynab_id' => created_transaction.id, 'status' => 'active'}
  end
  puts "Recreated #{recreate_transactions.size} transaction/s."

  update_transactions.each do |transaction|
    transaction_service.update_transaction(budget_id, transaction[:id], {transaction: transaction})
  end
  puts "Updated #{update_transactions.size} transaction/s."

rescue StandardError => e
  puts "Failed to import/update transactions in YNAB: #{e.message}"
end

def generate_import_id(expense, timestamp = Time.now.to_i)
  "#{timestamp}_splitwise_#{expense.id}"
end

def sync_transactions(splitwise_expenses, ynab_transactions, ynab_client, budget_id, account_id, category_map, default_category_id, api_call_data, settings, mapping)
  missing_or_deleted_transactions = []
  update_required_transactions = []

  splitwise_expenses.each do |transaction|
    splitwise_id = transaction.id.to_s
    if mapping.key?(splitwise_id)
      if ['active'].include?(mapping[splitwise_id]['status']) # Change to ['active', 'updated'] if you want to include the updated status to show in "Update_Required" transactions
        ynab_id = mapping[splitwise_id]['ynab_id']
        ynab_related_transaction = ynab_transactions.find { |t| t.id == ynab_id }
        ynab_amount = (transaction.amount.to_f * 1000).round(0)
        memo = "#{transaction.description} (Total: $#{transaction.total})"
        updated = false
        updated ||= ynab_related_transaction.amount != ynab_amount
        updated ||= ynab_related_transaction.memo&.downcase&.strip != memo.downcase.strip

        update_required_transactions << transaction if updated
      elsif mapping[splitwise_id]['status'] == 'deleted'
        if transaction.date <= Date.today
          missing_or_deleted_transactions << transaction
        end
      end
    else
      if transaction.date <= Date.today
        missing_or_deleted_transactions << transaction
      end
    end
  end

  # Handle missing/deleted transactions if any
  if missing_or_deleted_transactions.any?
    puts "Missing or deleted transactions found for import:"
    missing_or_deleted_transactions.each_with_index do |transaction_data, index|
      puts "#{index + 1}. #{transaction_data.description} (#{transaction_data.date}): $#{transaction_data.amount}"
    end

    begin
      puts "\nEnter the numbers of the missing/deleted transactions you want to import/re-create followed by commas (e.g., '1,3,5') or 'all' to import all transactions:"
      puts "Enter 'ignore' to mark transactions as ignored, or 'cancel' to cancel the import and exit the program:"
      missing_input = $stdin.gets.chomp.downcase

      case missing_input
      when 'cancel'
        puts "Exiting program."
        exit
      when 'ignore'
        ignored_transactions_number = missing_or_deleted_transactions.size
        missing_or_deleted_transactions.delete_if do |transaction_data|
          splitwise_id = transaction_data.id.to_s
          mapping[splitwise_id]['status'] = 'ignored'
          true
        end
        # Save updated mapping
        write_mapping_file(mapping)
        puts "Ignored #{ignored_transactions_number} transaction/s."
      when 'all'
        # No need to modify the missing_or_deleted_transactions array (keep all)
      else
        missing_indices = missing_input.split(',').map(&:strip).map(&:to_i)
        missing_or_deleted_transactions.select!.with_index { |_, i| missing_indices.include?(i + 1) }
      end
    rescue ArgumentError => e
      puts e.message
      retry
    end
  end

  # Handle update transactions if any
  if update_required_transactions.any?
    puts "Update required for transactions:"
    update_required_transactions.each_with_index do |transaction_data, index|
      puts "#{index + 1}. #{transaction_data.description} (#{transaction_data.date}): $#{transaction_data.amount}"
    end

    begin
      puts "\nEnter the numbers of the update transactions you want to update followed by commas (e.g., '2,4,6') or 'all' to update all transactions:"
      puts "Enter 'cancel' to cancel the import and exit the program:"
      update_input = $stdin.gets.chomp.downcase

      if update_input == 'cancel'
        puts "Exiting program."
        exit
      elsif update_input != 'all'
        update_indices = update_input.split(',').map(&:strip).map(&:to_i)
        update_required_transactions.select!.with_index { |_, i| update_indices.include?(i + 1) }
      end
    rescue ArgumentError => e
      puts e.message
      retry
    end
  end

  transactions_to_import = missing_or_deleted_transactions + update_required_transactions

  if transactions_to_import.any?
    mapping = load_mapping_file
    import_sync_transactions_into_ynab(ynab_client, budget_id, category_map, settings, api_call_data, mapping, missing_or_deleted_transactions, update_required_transactions)

    # Update mapping statuses for successfully imported/updated transactions
    update_required_transactions.each do |transaction_data|
      splitwise_id = transaction_data.id.to_s
      mapping[splitwise_id]['status'] = 'updated'
    end

    # Save updated mapping
    write_mapping_file(mapping)
  else
    puts "All transactions are up to date and synced :)"
  end
end

settings, category_map = load_configs
splitwise_auth = initialize_splitwise
ynab_auth = initialize_ynab
api_call_data = ynab_auth.api_call_data

last_transaction_date = retrieve_recent_transaction_data(ynab_auth.ynab_api_working? ? YNAB::API.new(api_call_data[:access_token]) : nil, api_call_data[:budget_id], api_call_data[:account_id])

# Retrieve expenses
splitwise_expenses = splitwise_auth.get_expenses(last_transaction_date)
ynab_transactions = ynab_auth.ynab_api_working? ? YNAB::API.new(api_call_data[:access_token]).transactions.get_transactions(api_call_data[:budget_id], account_id: api_call_data[:account_id], since_date: last_transaction_date, per_page: 1000).data.transactions : []

# Load mapping and update transaction statuses
mapping = load_mapping_file
mapping = update_mapping_statuses(mapping, ynab_transactions, splitwise_expenses)
write_mapping_file(mapping)

# Load mapping and import new transactions into YNAB
if mapping.empty? && !skip_sync_question
  puts "Enter the earliest date for transactions to be included in mapping.json (YYYY-MM-DD) or leave blank for all transactions:"
  since_date_input = $stdin.gets.chomp
  since_date = since_date_input.empty? ? nil : Date.parse(since_date_input)

  puts "Generating initial mapping for all legacy transactions starting from #{since_date.nil? ? 'the beginning' : since_date}..."
  generate_initial_mapping(splitwise_auth, ynab_auth.ynab_api_working? ? YNAB::API.new(api_call_data[:access_token]) : nil, api_call_data[:account_id], since_date, api_call_data)
  mapping = load_mapping_file
end

# Filter out transactions that are not missing or deleted from Splitwise expenses
filtered_initial_transactions = filter_initial_transactions(splitwise_expenses, mapping)

# Initial import of new transactions into YNAB
import_initial_transactions_into_ynab(ynab_auth.ynab_api_working? ? YNAB::API.new(api_call_data[:access_token]) : nil, api_call_data[:budget_id], filtered_initial_transactions, category_map, settings, api_call_data, mapping)

# Save updated mapping
write_mapping_file(mapping)

if skip_sync_question
  puts "Sync transactions functionality has been skipped by run-command"
else
  begin
    puts "Do you want to perform a sync operation? (y/n)"
    perform_sync_input = $stdin.gets.chomp.downcase
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
    start_date = Date.parse($stdin.gets.chomp)
    raise ArgumentError, "The earliest date that can be entered is 2023-03-30" if start_date < Date.parse("2023-01-01")
  rescue ArgumentError => e
    puts e.message
    retry
  end
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
    sync_transactions(splitwise_expenses, ynab_transactions, ynab_client, api_call_data[:budget_id], api_call_data[:account_id], category_map, settings['settings']['ynab_default_category_id'], api_call_data, settings, mapping)
  rescue YNAB::ApiError => e
    puts "An error occurred while syncing transactions: #{e}"
  end
end
