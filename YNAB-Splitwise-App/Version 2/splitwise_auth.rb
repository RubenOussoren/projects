require 'splitwise'
require 'yaml'
require 'oauth'
require 'json'
require 'net/http'
require 'uri'

class SplitwiseAuth
  def initialize(access_token_file = 'splitwise_access_token.yml', consumer_key = nil, consumer_secret = nil)
    @config = YAML.load_file('config.yml')
    @consumer_key = consumer_key || @config['splitwise']['consumer_key']
    @consumer_secret = consumer_secret || @config['splitwise']['consumer_secret']
    @consumer = OAuth::Consumer.new(
      @consumer_key,
      @consumer_secret,
      site: 'https://secure.splitwise.com'
    )

    @access_token_file = access_token_file

    if File.exist?(@access_token_file)
      # Use saved access token
      access_token_data = YAML.load(File.read(@access_token_file))
      @access_token = OAuth::AccessToken.new(@consumer, access_token_data['token'], access_token_data['secret'])
    else
      @access_token = authorize_app
      # Save access token for future use
      access_token_data = { 'token' => @access_token.token, 'secret' => @access_token.secret }
      File.write(@access_token_file, access_token_data.to_yaml)
    end
  end

  def get_expenses(since_date = nil)
    uri = URI.parse('https://secure.splitwise.com/api/v3.0/get_expenses')
    uri.query = "updated_since=#{since_date.to_i}" if since_date
    request = Net::HTTP::Get.new(uri.request_uri)
    @access_token.sign!(request)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    expenses = JSON.parse(response.body)['expenses']
    File.write('espenses_data.yml', expenses.to_yaml)
    expenses.map! do |expense|
      ruben = expense["users"].find { |u| u["user_id"] == 29031855 }
      other_users = expense["users"].reject { |u| u["user_id"] == 29031855 }
      payee_name =
        if other_users.size == 1
          other_user = other_users.first
          "#{other_user['user']['first_name']} #{other_user['user']['last_name']}"
        else
          "Group Expense"
        end
      OpenStruct.new(
        id: expense['id'],
        date: Date.parse(expense['date']),
        description: expense['description'],
        total: expense['cost'],
        amount: ruben['net_balance'],
        payee_name: payee_name
      )
    end
    expenses
  rescue StandardError => e
    puts "Error getting Splitwise expenses: #{e.message}"
    []
  end

  private

  def authorize_app
    request_token = @consumer.get_request_token
    auth_url = request_token.authorize_url

    puts "Please visit #{auth_url} to authorize the app and retrieve an access token."

    verifier = nil
    while verifier.nil?
      puts "Enter the verifier code from the authorization page:"
      verifier = gets.chomp
      begin
        access_token = request_token.get_access_token(oauth_verifier: verifier)
      rescue OAuth::Unauthorized
        puts "Invalid verifier code, please try again."
        verifier = nil
      end
    end
    access_token
  end
end
