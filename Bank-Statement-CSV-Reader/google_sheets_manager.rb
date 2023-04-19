require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'yaml'

class GoogleSheetsManager
  def initialize
    @script_directory = File.dirname(File.realdirpath(__FILE__))
    @config = YAML.load_file(File.join(@script_directory, 'config.yml'))

    @spreadsheet_id = @config['spreadsheet_id'].freeze
    @scope = Google::Apis::SheetsV4::AUTH_SPREADSHEETS
    @token_path = File.join(@script_directory, @config['token_path']).freeze

    @sheets_api = Google::Apis::SheetsV4::SheetsService.new
    @sheets_api.client_options.application_name = 'Transaction_Categorizer'
    @sheets_api.authorization = authorize
  end

  def authorize
    FileUtils.mkdir_p(File.dirname(@token_path))

    credentials = File.join(@script_directory, 'credentials.json')
    client_id = Google::Auth::ClientId.from_file(credentials)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: @token_path)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, @scope, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: 'urn:ietf:wg:oauth:2.0:oob')
      puts "Open the following URL in the browser and enter the resulting code: #{url}"
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(user_id: user_id, code: code, base_url: 'urn:ietf:wg:oauth:2.0:oob')
    end
    credentials
  end

  def create_and_populate_sheet(sheet_name, month_year, category_totals)
    sheet_created = false
    unless sheet_exists?(sheet_name)
      create_yearly_sheet(sheet_name)
      initialize_sheet_structure(sheet_name)
      sheet_created = true
    end

    if sheet_created || sheet_empty?(sheet_name) # Call to the method to check if the sheet is empty
      initialize_sheet_structure(sheet_name)
    end

    # Update the cells for Subtotal categories
    [['Pay', 'C3'],['Rent', 'C8'], ['Phone', 'C9'], ['Internet', 'C10'], ['Insurance', 'C11'], ['Hydro', 'C12']].each do |name, cell|
      update_monthly_total(sheet_name, month_year, category_totals, name, cell)
    end

    # Update the cells for Property related categories
    [['Property Income', 'C16'], ['Property Tax', 'C17'], ['Maintenance', 'C18'], ['Management Fee', 'C19'], ['Mortgage', 'C20']].each do |name, cell|
      update_monthly_total(sheet_name, month_year, category_totals, name, cell)
    end

    # Add Credit/Debit and Splitwise categories
    update_monthly_total(sheet_name, month_year, category_totals, 'Debit and Credit', 'C28')
    update_monthly_total(sheet_name, month_year, category_totals, 'Splitwise', 'C29')
    puts "\nAll done!! Go check out how it went :)\n"
  end

  private

  def find_or_append_month(sheet_name, month_year)
    month_number = Date.strptime(month_year, '%m-%Y').month
    month_index = month_number + 1

    last_existing_column = last_column(sheet_name)

    (last_existing_column + 1..month_index).each do |column|
      column_letter = (column + 64).chr
      insert_month_column(sheet_name, column_letter, column) unless column_exists?(sheet_name, column_letter)
    end

    month_column = (month_index + 64).chr
    month_column
  end

  def last_column(sheet_name)
    range = "#{sheet_name}!1:1"
    response = @sheets_api.get_spreadsheet_values(@spreadsheet_id, range)
    last_column = 0
    response.values.first.each_with_index do |value, index|
      last_column = index unless value.empty?
    end
    last_column
  end

  def column_exists?(sheet_name, column_letter)
    range = "#{sheet_name}!#{column_letter}1"
    response = @sheets_api.get_spreadsheet_values(@spreadsheet_id, range)
    !response.values.nil? && !response.values.flatten.empty?
  end

  def insert_month_column(sheet_name, month_column, month_number)
    month_name = Date::MONTHNAMES[month_number]

    range = "#{sheet_name}!#{month_column}1:#{month_column}100"
    value_range = Google::Apis::SheetsV4::ValueRange.new(
      values: [[''], [month_name]] + Array.new(98, [''])
    )

    @sheets_api.update_spreadsheet_value(
      @spreadsheet_id, range, value_range, value_input_option: 'RAW'
    )
  end

  def sheet_exists?(sheet_name)
    spreadsheet = @sheets_api.get_spreadsheet(@spreadsheet_id)
    spreadsheet.sheets.any? { |sheet| sheet.properties.title == sheet_name }
  end

  def sheet_empty?(sheet_name)
    range = "#{sheet_name}!A1:Z"
    response = @sheets_api.get_spreadsheet_values(@spreadsheet_id, range)
    response.values.nil? || response.values.empty?
  end

  def create_yearly_sheet(sheet_name)
    add_sheet_request = Google::Apis::SheetsV4::AddSheetRequest.new
    add_sheet_request.properties = Google::Apis::SheetsV4::SheetProperties.new(title: sheet_name)
    request = Google::Apis::SheetsV4::Request.new(add_sheet: add_sheet_request)

    batch_update = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new(requests: [request])
    @sheets_api.batch_update_spreadsheet(@spreadsheet_id, batch_update)
  end

  def update_monthly_total(sheet_name, month_year, category_totals, category, cell)
    if category_totals.key?(category)
      value = category_totals[category]
    else
      value = 0
    end

    month_column = find_or_append_month(sheet_name, month_year)

    # Properly format the range string with stripped whitespaces
    range = "#{sheet_name}!#{month_column}#{cell[1..-1]}"

    value_range = Google::Apis::SheetsV4::ValueRange.new(values: [[value]])
    @sheets_api.update_spreadsheet_value(@spreadsheet_id, range, value_range, value_input_option: 'RAW')
  end

  def initialize_sheet_structure(sheet_name)
    # Create headers with months
    header = [''] + (1..12).to_a.flat_map { |month| [Date::MONTHNAMES[month]] }

    # Row titles for categories and subtotals
    row_titles = [
      ['Income:'],
      ['Pay'],
      ['Other'],
      ['Subtotal:'],
      [''],
      ['Fixed Expenses:'],
      ['Rent'],
      ['Phone'],
      ['Internet'],
      ['Insurance'],
      ['Hydro'],
      ['Subtotal'],
      [''],
      ['Property:'],
      ['Property Income'],
      ['Property Tax'],
      ['Maintenance'],
      ['Management Fee'],
      ['Mortgage'],
      ['Subtotal:'],
      [''],
      ['Spending Amount'],
      ['Target save'],
      ['Left to spend:'],
      [''],
      ['Actual Amount Spent:'],
      ['Debit and Credit'],
      ['Splitwise'],
      ['Total:']
    ]

    # Convert the index to the column name (i.e., 1 => 'B' and 23 => 'X')
    last_column_letter = (12 + 65).chr
    last_row_number = row_titles.length + 1

    # Append data to the sheet
    range = "#{sheet_name}!A1:#{last_column_letter}1"
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: [header])
    @sheets_api.update_spreadsheet_value(@spreadsheet_id, range, value_range, value_input_option: 'RAW')

    range = "#{sheet_name}!A2:#{last_column_letter}#{last_row_number}"
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: row_titles)
    @sheets_api.update_spreadsheet_value(@spreadsheet_id, range, value_range, value_input_option: 'RAW')
  end
end
