from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time

def setup_driver():
    options = webdriver.ChromeOptions()
    options.add_argument("--start-maximized")
    driver = webdriver.Chrome(options=options)
    return driver

def wait_and_click(driver, by, value):
    try:
        element = WebDriverWait(driver, 20).until(
            EC.element_to_be_clickable((by, value))
        )
        element.click()
        print(f"Clicked element: {value}")
    except Exception as e:
        print(f"Error clicking element: {e}")

def select_dropdown_option_by_text(driver, text):
    try:
        element = WebDriverWait(driver, 20).until(
            EC.element_to_be_clickable((By.XPATH, f"//mat-panel-title[contains(text(), '{text}')]"))
        )
        element.click()
        print(f"Selected option: {text}")
    except Exception as e:
        print(f"Error selecting option: {e}")

def scrape_standings(driver):
    try:
        # Wait for the standings to be present
        WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.CLASS_NAME, "standing"))
        )
        standings_cards = driver.find_elements(By.CLASS_NAME, "standing")
        standings_data = []
        for card in standings_cards:
            rows = card.find_elements(By.TAG_NAME, "tr")
            for row in rows:
                cols = row.find_elements(By.TAG_NAME, "td")
                standings_data.append([col.text for col in cols])
        return standings_data
    except Exception as e:
        print(f"Error scraping standings: {e}")
        return []

def main():
    driver = setup_driver()
    driver.get("https://www.collegesport.co.nz/draws-results")

    # Click the 'Standings' button
    wait_and_click(driver, By.XPATH, "//span[contains(text(), 'Standings')]")

    # Select the sport, competition, and section by text
    select_dropdown_option_by_text(driver, "Football (School Sport)")
    select_dropdown_option_by_text(driver, "Football Boys Season")
    select_dropdown_option_by_text(driver, "Premier League")

    # Scrape the standings data
    standings_data = scrape_standings(driver)
    print("Standings Data:", standings_data)

    driver.quit()

if __name__ == "__main__":
    main()