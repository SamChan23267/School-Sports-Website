import json
import time
from datetime import datetime, timedelta
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

def get_date_range():
    today = datetime.today()
    start_date = today - timedelta(days=30)
    end_date = today + timedelta(days=60)
    return start_date, end_date

def wait_and_click(driver, by, value, timeout=10):
    elem = WebDriverWait(driver, timeout).until(
        EC.element_to_be_clickable((by, value))
    )
    elem.click()
    return elem

def wait_and_send_keys(driver, by, value, keys, timeout=10):
    elem = WebDriverWait(driver, timeout).until(
        EC.visibility_of_element_located((by, value))
    )
    elem.clear()
    elem.send_keys(keys)
    return elem

def select_date(driver, input_xpath, calendar_id, target_date):
    # Click the date input to open the calendar
    wait_and_click(driver, By.XPATH, input_xpath)
    time.sleep(0.5)
    # Wait for calendar to appear
    calendar = WebDriverWait(driver, 10).until(
        EC.visibility_of_element_located((By.ID, calendar_id))
    )
    # Find the month/year button
    while True:
        header = calendar.find_element(By.CSS_SELECTOR, ".mat-calendar-period-button")
        month_year = header.text.strip()
        current_month_year = datetime.strptime(month_year, "%B %Y")
        if current_month_year.year == target_date.year and current_month_year.month == target_date.month:
            break
        elif (current_month_year.year, current_month_year.month) < (target_date.year, target_date.month):
            # Click next month
            next_btn = calendar.find_element(By.CSS_SELECTOR, ".mat-calendar-next-button")
            next_btn.click()
        else:
            # Click previous month
            prev_btn = calendar.find_element(By.CSS_SELECTOR, ".mat-calendar-previous-button")
            prev_btn.click()
        time.sleep(0.3)
    # Click the day
    day_cells = calendar.find_elements(By.CSS_SELECTOR, ".mat-calendar-body-cell")
    for cell in day_cells:
        aria_label = cell.get_attribute("aria-label")
        if aria_label:
            try:
                cell_date = datetime.strptime(aria_label, "%d %B %Y")
                if cell_date.date() == target_date.date():
                    cell.click()
                    return
            except Exception:
                continue

def scrape_fixtures(driver):
    # Wait for fixtures to load
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.CSS_SELECTOR, "mat-card.desktop-fixture"))
    )
    cards = driver.find_elements(By.CSS_SELECTOR, "mat-card.desktop-fixture")
    fixtures = []
    for card in cards:
        # Walk up the DOM to find sport, competition, section headers
        sport = competition = section = ""
        parent = card
        for _ in range(10):  # Walk up max 10 levels
            try:
                parent = parent.find_element(By.XPATH, "..")
                siblings = parent.find_elements(By.XPATH, "./*")
                for sib in siblings:
                    try:
                        cls = sib.get_attribute("class") or ""
                        if "sport-header" in cls:
                            sport = sib.text.strip()
                        elif "comp-header" in cls:
                            competition = sib.text.strip()
                        elif "section-header" in cls:
                            section = sib.text.strip()
                    except Exception:
                        continue
                if sport and competition and section:
                    break
            except Exception:
                break

        try:
            date_elem = card.find_element(By.CSS_SELECTOR, ".fixture-tab-date")
            date_text = date_elem.text.strip()
        except Exception:
            date_text = ""
        try:
            venue_elems = card.find_elements(By.CSS_SELECTOR, ".venue")
            venue = " ".join([v.text.strip() for v in venue_elems])
        except Exception:
            venue = ""
        try:
            home_team = card.find_element(By.CSS_SELECTOR, ".home-team").text.strip()
        except Exception:
            home_team = ""
        try:
            home_org = card.find_element(By.CSS_SELECTOR, ".home-org").text.strip()
        except Exception:
            home_org = ""
        try:
            away_team = card.find_element(By.CSS_SELECTOR, ".away-team").text.strip()
        except Exception:
            away_team = ""
        try:
            away_org = card.find_element(By.CSS_SELECTOR, ".away-org").text.strip()
        except Exception:
            away_org = ""
        try:
            vs_label = card.find_element(By.CSS_SELECTOR, ".vs-label").text.strip()
        except Exception:
            vs_label = ""
        fixture = {
            "sport": sport,
            "competition": competition,
            "section": section,
            "date_time": date_text,
            "venue": venue,
            "home_team_name": home_team,
            "home_org": home_org,
            "away_team_name": away_team,
            "away_org": away_org,
            "result": vs_label
        }
        fixtures.append(fixture)
    return fixtures

def main():
    # Setup Chrome options
    chrome_options = Options()
    chrome_options.add_argument("--start-maximized")
    # Uncomment below to run headless
    # chrome_options.add_argument("--headless")
    driver = webdriver.Chrome(options=chrome_options)

    try:
        driver.get("https://www.collegesport.co.nz/draws-results")
        wait = WebDriverWait(driver, 20)

        # Wait for the page to load the organisation filter by ID
        wait.until(EC.presence_of_element_located((By.ID, "mat-select-1")))
        time.sleep(1)

        # 1. Open Organisation filter using ID
        wait_and_click(driver, By.ID, "mat-select-1")
        time.sleep(0.5)

        # 2. Deselect All (updated selector)
        try:
            deselect_btn = wait.until(
                EC.element_to_be_clickable((By.XPATH, "//button[.//span[contains(text(),'Deselect All')]]"))
            )
            deselect_btn.click()
            time.sleep(0.5)
        except Exception as e:
            print("Could not click Deselect All button:", e)

        # 3. Type Sacred Heart College in search
        wait_and_send_keys(driver, By.XPATH, "//input[@placeholder='Type to filter options']", "Sacred Heart College")
        time.sleep(1)

        # 4. Select Sacred Heart College (Auckland)
        sacred_btn = wait.until(
            EC.element_to_be_clickable((By.XPATH, "//button[.//span[contains(text(),'Sacred Heart College (Auckland)')]]"))
        )
        sacred_btn.click()
        time.sleep(0.5)

        # 5. Close the dropdown (click outside)
        driver.find_element(By.TAG_NAME, "body").click()
        time.sleep(0.5)

        # 6. Set date range
        start_date, end_date = get_date_range()

        # Print page source for debugging date input selection
        # print(driver.page_source)
        time.sleep(2)

        # Use a more general selector for date inputs (should match both start and end)
        date_inputs = driver.find_elements(By.XPATH, "//input[@aria-haspopup='dialog']")
        if len(date_inputs) < 2:
            raise Exception("Could not find both start and end date inputs. Found: {}".format(len(date_inputs)))
        # Start date input
        select_date(driver,
            "(//input[@aria-haspopup='dialog'])[1]",
            "mat-datepicker-0",
            start_date
        )
        time.sleep(0.5)
        # End date input
        select_date(driver,
            "(//input[@aria-haspopup='dialog'])[2]",
            "mat-datepicker-1",
            end_date
        )
        time.sleep(1)

        # 7. Wait for fixtures to reload with a more robust approach
        time.sleep(1)
        try:
            wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "mat-card.desktop-fixture")))
            time.sleep(1)
        except Exception as e:
            print("Warning: Timeout waiting for fixtures to load:", e)
            print("Continuing anyway...")

        # 8. Scrape fixtures
        fixtures = scrape_fixtures(driver)

        # 9. Output to JSON
        with open("sacred_heart_fixtures.json", "w", encoding="utf-8") as f:
            json.dump(fixtures, f, ensure_ascii=False, indent=2)
        print(f"Extracted {len(fixtures)} fixtures. Saved to sacred_heart_fixtures.json.")
        
        # Print sample of first fixture for verification
        if fixtures:
            print("\nSample fixture:")
            print(json.dumps(fixtures[0], indent=2))

    finally:
        driver.quit()

if __name__ == "__main__":
    main()
