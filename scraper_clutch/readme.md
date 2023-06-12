# Used Car Scraper

This Python script scrapes used car data from [Clutch.ca](https://www.clutch.ca/cars) based on the filters specified in the `config.json` file. It then sends an email with the details of the newly added cars.

## Requirements

- Python 3.6+
- BeautifulSoup4
- Selenium
- Chrome WebDriver

## Installation

1. Install BeautifulSoup4:

```bash
pip install beautifulsoup4
```

2. Install Selenium:

```bash
pip install selenium
```

3. Download the appropriate version of Chrome WebDriver for your system from [here](https://sites.google.com/a/chromium.org/chromedriver/downloads) and extract the executable.

## Configuration

1. Update the `config.json` file with your desired filters and email settings:

```json
{
    "makes": ["honda", "toyota"],
    "max_price": 20000,
    "max_mileage": 100000,
    "min_year": 2015,
    "sender_email": "your_email@example.com",
    "receiver_emails": ["recipient1@example.com", "recipient2@example.com"],
    "password": "your_email_password"
}
```

2. Replace `/path/to/chromedriver` in the `fetch_page` function with the path to the Chrome WebDriver executable you downloaded earlier:

```python
service = Service(executable_path='/path/to/chromedriver')
```

## Usage

Run the script:

```bash
python used_car_scraper.py
```

The script will scrape the used car data based on the filters specified in the `config.json` file and send an email with the details of the newly added cars. The script also stores the car data in a `cars.json` file for future reference.