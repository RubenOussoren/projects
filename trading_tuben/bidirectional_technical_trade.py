import os
import time
import numpy as np
import talib
import pandas as pd
import smtplib
import logging
import tenacity
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from alpha_vantage.timeseries import TimeSeries
from sklearn.preprocessing import MinMaxScaler
from keras.models import Sequential, load_model
from keras.layers import Dense, LSTM, Dropout, Bidirectional
from keras.regularizers import L1L2
from keras.callbacks import EarlyStopping
from prettytable import PrettyTable
from tenacity import before_sleep_log, after_log


# Set your Alpha Vantage API key
api_key = 'YG0UB6KP63MT95A6'

# List of stock tickers
tickers = ['HXU.TO', 'HXD.TO', 'BNS.TO', 'ENB.TO', 'XGD.TO']

# Set the rate limit for the fetch_stock_data function
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Set the rate limit for the fetch_stock_data function
@tenacity.retry(wait=tenacity.wait_fixed(60 / 5),  # 60 seconds divided by 5 calls
                stop=tenacity.stop_after_attempt(5),
                before_sleep=before_sleep_log(logger, logging.INFO),
                after=after_log(logger, logging.INFO))

def fetch_stock_data(ticker):
    try:
        ts = TimeSeries(key=api_key, output_format='pandas')
        data, _ = ts.get_daily_adjusted(symbol=ticker, outputsize='full')
        data = data.sort_index(ascending=True)
        return data
    except Exception as e:
        print(f"Error fetching stock data for {ticker}: {e}")
        exit
        raise

def preprocess_data(data):
    data = data['5. adjusted close'].values
    data = data.reshape(-1, 1)
    scaler = MinMaxScaler(feature_range=(0, 1))
    data_scaled = scaler.fit_transform(data)
    return data_scaled, scaler

def create_dataset(data, window_size):
    X, y = [], []
    for i in range(window_size, len(data)):
        X.append(data[i-window_size:i, 0])
        y.append(data[i, 0])
    return np.array(X), np.array(y)

def build_lstm_model(input_shape):
    model = Sequential()
    
    # Add L1 and L2 regularization
    reg = L1L2(l1=0.00001, l2=0.00001)
    
    # Add the regularizer to the LSTM layers and include dropout layers
    model.add(Bidirectional(LSTM(units=73, return_sequences=True, kernel_regularizer=reg), input_shape=input_shape))
    model.add(Dropout(0.3))
    model.add(Bidirectional(LSTM(units=65, return_sequences=True, kernel_regularizer=reg)))
    model.add(Dropout(0.3))
    model.add(Bidirectional(LSTM(units=58, kernel_regularizer=reg)))
    model.add(Dropout(0.3))
    model.add(Dense(units=1))
    model.compile(optimizer='adam', loss='mean_squared_error')
    return model

def calculate_technical_indicators(data):
    # Calculate Bollinger Bands
    upper, middle, lower = talib.BBANDS(data['5. adjusted close'], timeperiod=20)

    # Calculate Stochastic Oscillator
    slowk, slowd = talib.STOCH(data['2. high'], data['3. low'], data['5. adjusted close'], fastk_period=5, slowk_period=3, slowk_matype=0, slowd_period=3, slowd_matype=0)

    # Calculate moving averages
    sma_short = talib.SMA(data['5. adjusted close'], timeperiod=5)
    sma_long = talib.SMA(data['5. adjusted close'], timeperiod=20)

    # Calculate RSI
    rsi = talib.RSI(data['5. adjusted close'], timeperiod=14)

    # Calculate ADX
    adx = talib.ADX(data['2. high'], data['3. low'], data['5. adjusted close'], timeperiod=14)

    # Calculate OBV
    obv = talib.OBV(data['5. adjusted close'], data['6. volume'])

    # Calculate MACD
    macd, macd_signal, macd_hist = talib.MACD(data['5. adjusted close'], fastperiod=12, slowperiod=26, signalperiod=9)

    return upper, middle, lower, slowk, slowd, sma_short, sma_long, rsi, adx, obv, macd, macd_signal, macd_hist

def fibonacci_retracement_levels(data):
    high = max(data['2. high'])
    low = min(data['3. low'])
    diff = high - low
    levels = [high, high - 0.236 * diff, high - 0.382 * diff, high - 0.5 * diff, high - 0.618 * diff, low]
    return levels

def generate_recommendation(predictions, data, upper, middle, lower, slowk, slowd, sma_short, sma_long, rsi, adx, obv, macd, macd_signal, macd_hist, fib_levels):
    last_prediction = predictions[-1][0]
    last_actual_price = data['5. adjusted close'].values[-1]

    # Bollinger Bands
    bb_buy = last_actual_price < lower[-1]
    bb_sell = last_actual_price > upper[-1]

    # Stochastic Oscillator
    so_buy = (slowk[-1] < 20) & (slowd[-1] < 20) & (slowk[-1] > slowd[-1])
    so_sell = (slowk[-1] > 80) & (slowd[-1] > 80) & (slowk[-1] < slowd[-1])

    # Moving Averages
    ma_buy = sma_short[-1] > sma_long[-1]
    ma_sell = sma_short[-1] < sma_long[-1]

    # RSI
    rsi_buy = rsi[-1] < 30
    rsi_sell = rsi[-1] > 70

    # ADX
    adx_trend = adx[-1] > 25

    # OBV
    obv_buy = obv[-1] > obv[-2]
    obv_sell = obv[-1] < obv[-2]

    # MACD
    macd_buy = macd_hist[-1] > 0
    macd_sell = macd_hist[-1] < 0

    # Fibonacci Retracement Levels
    fib_buy = any(last_actual_price < level for level in fib_levels)
    fib_sell = any(last_actual_price > level for level in fib_levels)

    # LSTM prediction
    lstm_buy = last_prediction > last_actual_price
    lstm_sell = last_prediction < last_actual_price

    # Combine signals
    buy_signals = [bb_buy, so_buy, ma_buy, rsi_buy, adx_trend & obv_buy, macd_buy, fib_buy, lstm_buy]
    sell_signals = [bb_sell, so_sell, ma_sell, rsi_sell, adx_trend & obv_sell, macd_sell, fib_sell, lstm_sell]

    buy_votes = sum(buy_signals)
    sell_votes = sum(sell_signals)

    if buy_votes > sell_votes:
        recommendation = "Buy"
    elif sell_votes > buy_votes:
        recommendation = "Sell"
    else:
        recommendation = "Hold"

    return buy_votes, sell_votes, recommendation, bb_buy, bb_sell, so_buy, so_sell, ma_buy, ma_sell, rsi_buy, rsi_sell, adx_trend, obv_buy, obv_sell, macd_buy, macd_sell, fib_buy, fib_sell, lstm_buy, lstm_sell
    
def calculate_investment_performance(ticker):
    investments = pd.read_csv("investments.csv")
    ticker_investments = investments[investments['ticker'] == ticker]

    if ticker_investments.empty:
        return None, None, None

    total_investment = 0
    total_value = 0

    for index, row in ticker_investments.iterrows():
        buy_price = float(row['buy_price'])
        shares = float(row['shares'])
        sell_price = float(row['sell_price']) if not pd.isna(row['sell_price']) and row['sell_price'].strip() != '' else None

        # Fetch the latest stock data
        stock_data = fetch_stock_data(ticker)
        current_price = stock_data['5. adjusted close'].values[-1]

        investment = buy_price * shares
        value = (sell_price if sell_price else current_price) * shares

        total_investment += investment
        total_value += value

    performance = (total_value - total_investment) / total_investment * 100
    return total_investment, total_value, performance

def get_available_funds():
    with open("available_funds.txt", "r") as f:
        available_funds = float(f.read().strip())
    return available_funds

def calculate_shares_to_buy(ticker, recommendation, total_available_funds, num_tickers):
    if recommendation != "Buy":
        return 0

    # Fetch the latest stock data
    stock_data = fetch_stock_data(ticker)
    current_price = stock_data['5. adjusted close'].values[-1]

    # Calculate the number of shares to buy based on available funds per ticker
    available_funds_per_ticker = total_available_funds / num_tickers
    shares_to_buy = int(available_funds_per_ticker / current_price)

    return shares_to_buy

def send_email(subject, body):
    # Set your email credentials
    sender_email = "clutchsearch@gmail.com"
    sender_password = "spmapuzfsloyrkwd"
    receiver_email = "benoussoren@gmail.com"

    # Create the email message
    message = MIMEMultipart()
    message["From"] = sender_email
    message["To"] = receiver_email
    message["Subject"] = subject
    message.attach(MIMEText(body, "html"))

    # Send the email
    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, receiver_email, message.as_string())
        print(f"Email sent to {receiver_email}")
    except Exception as e:
        print(f"Error sending email: {e}")

def display_results(ticker, last_prediction, last_actual_price, recommendation, buy_votes, sell_votes, upper, middle, lower, slowk, slowd, sma_short, sma_long, rsi, adx, obv, macd, macd_signal, macd_hist, fib_levels, bb_buy, bb_sell, so_buy, so_sell, ma_buy, ma_sell, rsi_buy, rsi_sell, adx_trend, obv_buy, obv_sell, macd_buy, macd_sell, fib_buy, fib_sell, lstm_buy, lstm_sell):
    # Calculate the number of shares to buy
    total_available_funds = get_available_funds()
    num_tickers = len(tickers)
    shares_to_buy = calculate_shares_to_buy(ticker, recommendation, total_available_funds, num_tickers)

    # Create the Overall Recommendation table
    print("\nOverall Recommendation:")
    table = PrettyTable()
    table.field_names = ["Ticker", "Last Prediction", "Last Actual Price", "Recommendation", "Buy Votes", "Sell Votes", "Shares to Buy"]
    table.add_row([ticker, f"{last_prediction:.2f}", f"{last_actual_price:.2f}", recommendation, buy_votes, sell_votes, shares_to_buy])
    print(table)

    # Create the Technical Indicators table
    print("\nTechnical Indicators:")
    indicators_table = PrettyTable()
    indicators_table.field_names = ["Indicator", "Value", "Signal", "Explanation"]
    indicators_table.add_row(["Bollinger Bands", f"U: {upper[-1]:.2f}, M: {middle[-1]:.2f}, L: {lower[-1]:.2f}", "Buy" if bb_buy else "Sell" if bb_sell else "Hold", "Buy when price is below lower band, sell when price is above upper band"])
    indicators_table.add_row(["Stochastic Oscillator", f"K: {slowk[-1]:.2f}, D: {slowd[-1]:.2f}", "Buy" if so_buy else "Sell" if so_sell else "Hold", "Buy when K and D are below 20 and K > D, sell when K and D are above 80 and K < D"])
    indicators_table.add_row(["Moving Averages", f"Short: {sma_short[-1]:.2f}, Long: {sma_long[-1]:.2f}", "Buy" if ma_buy else "Sell" if ma_sell else "Hold", "Buy when short MA is above long MA, sell when short MA is below long MA"])
    indicators_table.add_row(["RSI", f"{rsi[-1]:.2f}", "Buy" if rsi_buy else "Sell" if rsi_sell else "Hold", "Buy when RSI is below 30, sell when RSI is above 70"])
    indicators_table.add_row(["ADX", f"{adx[-1]:.2f}", "Trending" if adx_trend else "Non-trending", "Trending when ADX is above 25, non-trending when ADX is below 25"])
    indicators_table.add_row(["OBV", f"{obv[-1]:.2f}", "Buy" if obv_buy else "Sell" if obv_sell else "Hold", "Buy when OBV is increasing, sell when OBV is decreasing"])
    indicators_table.add_row(["MACD", f"MACD: {macd[-1]:.2f}, Signal: {macd_signal[-1]:.2f}, Hist: {macd_hist[-1]:.2f}", "Buy" if macd_buy else "Sell" if macd_sell else "Hold", "Buy when MACD histogram is positive, sell when MACD histogram is negative"])
    indicators_table.add_row(["Fibonacci Retracement", f"Levels: {', '.join([f'{level:.2f}' for level in fib_levels])}", "Buy" if fib_buy else "Sell" if fib_sell else "Hold", "Buy when price is below a retracement level, sell when price is above a retracement level"])
    indicators_table.add_row(["LSTM Prediction", f"{last_prediction:.2f}", "Buy" if lstm_buy else "Sell" if lstm_sell else "Hold", "Buy when predicted price is above actual price, sell when predicted price is below actual price"])
    print(indicators_table)

    # Calculate investment performance
    total_investment, total_value, performance = calculate_investment_performance(ticker)

    if total_investment is not None and total_value is not None and performance is not None:
        # Add performance information to the output
        print("\nInvestment Performance:")
        performance_table = PrettyTable()
        performance_table.field_names = ["Total Investment", "Total Value", "Performance"]
        performance_table.add_row([f"{total_investment:.2f}", f"{total_value:.2f}", f"{performance:.2f}%"])
        print(performance_table)

        # Create the 'results' subfolder if it doesn't exist
    if not os.path.exists("results"):
        os.makedirs("results")

    # Save results to the results file
    with open(f"results/{ticker}.txt", "a+") as f:
        f.write("-" * 80 + "\n")  # Add a separator line
        f.write(f"{time.strftime('%Y-%m-%d')}\n")
        f.write("Overall Recommendation\n")
        f.write(str(table) + "\n\n")
        f.write("Technical Indicators\n")
        f.write(str(indicators_table) + "\n\n")

    if total_investment is not None and total_value is not None and performance is not None:
        f.write("Investment Performance\n")
        f.write(str(performance_table) + "\n\n")

    # Save the results as an HTML string
    results = f"<h2>{time.strftime('%Y-%m-%d')}</h2>"
    results += "<h3>Overall Recommendation</h3>"
    overall_recommendation_df = pd.DataFrame([[ticker, f"{last_prediction:.2f}", f"{last_actual_price:.2f}", recommendation, buy_votes, sell_votes, shares_to_buy]], columns=["Ticker", "Last Prediction", "Last Actual Price", "Recommendation", "Buy Votes", "Sell Votes", "Shares to Buy"])
    results += overall_recommendation_df.to_html(index=False)

    results += "<br><h3>Technical Indicators</h3>"
    technical_indicators_df = pd.DataFrame([["Bollinger Bands", f"U: {upper[-1]:.2f}, M: {middle[-1]:.2f}, L: {lower[-1]:.2f}", "Buy" if bb_buy else "Sell" if bb_sell else "Hold", "Buy when price is below lower band, sell when price is above upper band"],
                                            ["Stochastic Oscillator", f"K: {slowk[-1]:.2f}, D: {slowd[-1]:.2f}", "Buy" if so_buy else "Sell" if so_sell else "Hold", "Buy when K and D are below 20 and K > D, sell when K and D are above 80 and K < D"],
                                            ["Moving Averages", f"Short: {sma_short[-1]:.2f}, Long: {sma_long[-1]:.2f}", "Buy" if ma_buy else "Sell" if ma_sell else "Hold", "Buy when short MA is above long MA, sell when short MA is below long MA"],
                                            ["RSI", f"{rsi[-1]:.2f}", "Buy" if rsi_buy else "Sell" if rsi_sell else "Hold", "Buy when RSI is below 30, sell when RSI is above 70"],
                                            ["ADX", f"{adx[-1]:.2f}", "Trending" if adx_trend else "Non-trending", "Trending when ADX is above 25, non-trending when ADX is below 25"],
                                            ["OBV", f"{obv[-1]:.2f}", "Buy" if obv_buy else "Sell" if obv_sell else "Hold", "Buy when OBV is increasing, sell when OBV is decreasing"],
                                            ["MACD", f"MACD: {macd[-1]:.2f}, Signal: {macd_signal[-1]:.2f}, Hist: {macd_hist[-1]:.2f}", "Buy" if macd_buy else "Sell" if macd_sell else "Hold", "Buy when MACD histogram is positive, sell when MACD histogram is negative"],
                                            ["Fibonacci Retracement", f"Levels: {', '.join([f'{level:.2f}' for level in fib_levels])}", "Buy" if fib_buy else "Sell" if fib_sell else "Hold", "Buy when price is below a retracement level, sell when price is above a retracement level"],
                                            ["LSTM Prediction", f"{last_prediction:.2f}", "Buy" if lstm_buy else "Sell" if lstm_sell else "Hold", "Buy when predicted price is above actual price, sell when predicted price is below actual price"]],
                                          columns=["Indicator", "Value", "Signal", "Explanation"])
    results += technical_indicators_df.to_html(index=False)
                                                   
    if total_investment is not None and total_value is not None and performance is not None:
        results += "<br><h3>Investment Performance</h3>"
        investment_performance_df = pd.DataFrame([[f"{total_investment:.2f}", f"{total_value:.2f}", f"{performance:.2f}%"]], columns=["Total Investment", "Total Value", "Performance"])
        results += investment_performance_df.to_html(index=False)

    return results

def train_and_predict(ticker):
    # Fetch stock data
    data = fetch_stock_data(ticker)

    # Preprocess data
    data_scaled, scaler = preprocess_data(data)

    # Create training and testing datasets
    train_size = int(len(data_scaled) * 0.8)
    train_data = data_scaled[:train_size]
    test_data = data_scaled[train_size:]

    window_size = 60
    X_train, y_train = create_dataset(train_data, window_size)
    X_test, y_test = create_dataset(test_data, window_size)

    # Reshape data for LSTM input
    X_train = np.reshape(X_train, (X_train.shape[0], X_train.shape[1], 1))
    X_test = np.reshape(X_test, (X_test.shape[0], X_test.shape[1], 1))

    # Check if the model file exists
    if os.path.isfile(f"{ticker}_model.keras"):
        # Load the saved model
        model = load_model(f"{ticker}_model.keras")
    else:
        # Build a new LSTM model if no saved model exists
        model = build_lstm_model((X_train.shape[1], 1))

    # Train model with EarlyStopping callback
    early_stopping = EarlyStopping(monitor='val_loss', patience=3)
    try:
        model.fit(X_train, y_train, epochs=100, batch_size=32, validation_split=0.2, callbacks=[early_stopping])
    except Exception as e:
        print(f"Error training model for {ticker}: {e}")
        return

    # Save model
    model.save(f"models/{ticker}.keras")
    
    # Make predictions
    predictions = model.predict(X_test)
    predictions = scaler.inverse_transform(predictions)
 
    # Calculate technical indicators
    upper, middle, lower, slowk, slowd, sma_short, sma_long, rsi, adx, obv, macd, macd_signal, macd_hist = calculate_technical_indicators(data)

    # Generate recommendation
    fib_levels = fibonacci_retracement_levels(data)
    buy_votes, sell_votes, recommendation, bb_buy, bb_sell, so_buy, so_sell, ma_buy, ma_sell, rsi_buy, rsi_sell, adx_trend, obv_buy, obv_sell, macd_buy, macd_sell, fib_buy, fib_sell, lstm_buy, lstm_sell = generate_recommendation(predictions, data, upper, middle, lower, slowk, slowd, sma_short, sma_long, rsi, adx, obv, macd, macd_signal, macd_hist, fib_levels)

    # Extract last prediction and last actual price
    last_prediction = predictions[-1][0]
    last_actual_price = data['5. adjusted close'].values[-1]

   # Display and save results
    results = display_results(ticker, last_prediction, last_actual_price, recommendation, buy_votes, sell_votes, upper, middle, lower, slowk, slowd, sma_short, sma_long, rsi, adx, obv, macd, macd_signal, macd_hist, fib_levels, bb_buy, bb_sell, so_buy, so_sell, ma_buy, ma_sell, rsi_buy, rsi_sell, adx_trend, obv_buy, obv_sell, macd_buy, macd_sell, fib_buy, fib_sell, lstm_buy, lstm_sell)

    return results

def train_and_predict_wrapper(ticker):
    all_results = ""
    for ticker in tickers:
        results = train_and_predict(ticker)
        all_results += results
        all_results += "\n" + "=" * 80 + "\n"  # Add a separator between tickers

    # Send results via email
    subject = f"Trading Recommendations - {time.strftime('%Y-%m-%d')}"
    send_email(subject, all_results)

if __name__ == '__main__':
    train_and_predict_wrapper(tickers)