import json
import smtplib
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.image import MIMEImage
from email.header import Header
import requests

def load_config():
    with open('config.json', 'r') as f:
        return json.load(f)

def load_config():
    with open('config.json', 'r') as f:
        return json.load(f)

def create_filtered_url(config):
    base_url = 'https://www.clutch.ca/cars'
    filters = []

    if 'makes' in config and config['makes']:
        first_make = config['makes'][0]
        base_url = f'{base_url}/{first_make}'
        makes = ','.join(config['makes'])
        filters.append(f'makes={makes}')
    if 'max_price' in config:
        filters.append(f'priceHigh={config["max_price"]}')
    if 'max_mileage' in config:
        filters.append(f'mileageHigh={config["max_mileage"]}')
    if 'min_year' in config:
        filters.append(f'yearLow={config["min_year"]}')

    if filters:
        return f'{base_url}?{"&".join(filters)}'
    else:
        return base_url
    
def fetch_page(url):
    options = Options()
    options.add_argument('--headless')
    service = Service(executable_path='/path/to/chromedriver')
    driver = webdriver.Chrome(service=service, options=options)
    driver.get(url)
    content = driver.page_source
    driver.quit()
    return content

def create_car_html(car):
    html = f"""
    <h3>New car added: {car['title']}</h3>
    <p>Price: {car['price']}</p>
    """
    if 'mileage' in car:
        html += f"<p>Mileage: {car['mileage']}</p>"
    html += f"""
    <p><a href="{car['car_url']}">Link to car</a></p>
    <img src="{car['image_url']}" alt="Car image" /><br><br>
    """
    return html

def send_email(new_cars):
    config = load_config()

    sender_email = config['sender_email']
    receiver_emails =  config['receiver_emails']
    password = config['password']

    subject = f"New Cars Added"

    message = MIMEMultipart("related")
    message["Subject"] = Header(subject, "utf-8")
    message["From"] = sender_email
    message["To"] = ", ".join(receiver_emails)

    html = "<html><body>"
    for car in new_cars:
        html += create_car_html(car)
    html += "</body></html>"

    html_part = MIMEText(html, "html")
    message.attach(html_part)

    try:
        server = smtplib.SMTP_SSL("smtp.gmail.com", 465)
        server.login(sender_email, password)
        server.sendmail(sender_email, receiver_emails, message.as_string())
        server.quit()
        print(f"Email sent for new cars")
    except Exception as e:
        print(f"Error sending email: {e}")

def main():
    config = load_config()

    filtered_url = create_filtered_url(config)
    print(f"Filtered URL: {filtered_url}")

    response = fetch_page(filtered_url)
    soup = BeautifulSoup(response, 'html.parser')

    car_cards = soup.find_all('a', class_='sc-jZRpAH jlYxlU')
    print(f"Number of car cards found: {len(car_cards)}")

    new_cars = []

    for car_card in car_cards:
        car = {}
        
        title = car_card.find('span', class_='sc-dXVzwg cvEYsq')
        if title:
            car['title'] = title.text.strip()
        
        price = car_card.find('span', class_='sc-SjVdP gFtQyY')
        if price:
            car['price'] = price.text.strip()
        
        mileage = car_card.find_all('span', class_='sc-SjVdP gFtQyY')
        if len(mileage) > 1:
            car['mileage'] = mileage[1].text.strip()
        
        img = car_card.find('img')
        if img:
            car['image_url'] = img['src']
        
        car_url = car_card['href']
        if car_url:
            car['car_url'] = f'https://www.clutch.ca{car_url}'
        
        new_cars.append(car)

    print(f"New cars found: {len(new_cars)}")

    try:
        with open('cars.json', 'r') as f:
            existing_cars = json.load(f)
    except FileNotFoundError:
        existing_cars = []

    updated_cars = existing_cars.copy()

    new_cars_to_email = []

    existing_car_urls = [car['car_url'] for car in existing_cars]

    for new_car in new_cars:
        if new_car['car_url'] not in existing_car_urls:
            updated_cars.append(new_car)
            new_cars_to_email.append(new_car)
            existing_car_urls.append(new_car['car_url'])

    if new_cars_to_email:
        send_email(new_cars_to_email)

    with open('cars.json', 'w') as f:
        json.dump(updated_cars, f, indent=4)

if __name__ == "__main__":
    main()