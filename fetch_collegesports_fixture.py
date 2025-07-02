import json
import time
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import re

def get_date_range():
    today = datetime.today()
    start_date = datetime(today.year, 1, 1)
    end_date = datetime(today.year, 12, 31)
    return start_date, end_date

def wait_and_click(driver, by, value, timeout=10):
    try:
        elem = WebDriverWait(driver, timeout).until(
            EC.element_to_be_clickable((by, value))
        )
        elem.click()
        return elem
    except Exception as e:
        print(f"Error clicking element {value}: {e}")

def wait_and_send_keys(driver, by, value, keys, timeout=10):
    try:
        elem = WebDriverWait(driver, timeout).until(
            EC.visibility_of_element_located((by, value))
        )
        elem.clear()
        elem.send_keys(keys)
        return elem
    except Exception as e:
        print(f"Error sending keys to element {value}: {e}")

def select_date(driver, input_xpath, calendar_id, target_date):
    try:
        wait_and_click(driver, By.XPATH, input_xpath)
        time.sleep(0.5)
        calendar = WebDriverWait(driver, 10).until(
            EC.visibility_of_element_located((By.ID, calendar_id))
        )
        while True:
            header = calendar.find_element(By.CSS_SELECTOR, ".mat-calendar-period-button")
            month_year = header.text.strip()
            current_month_year = datetime.strptime(month_year, "%B %Y")
            if current_month_year.year == target_date.year and current_month_year.month == target_date.month:
                break
            elif (current_month_year.year, current_month_year.month) < (target_date.year, target_date.month):
                next_btn = calendar.find_element(By.CSS_SELECTOR, ".mat-calendar-next-button")
                next_btn.click()
            else:
                prev_btn = calendar.find_element(By.CSS_SELECTOR, ".mat-calendar-previous-button")
                prev_btn.click()
            time.sleep(0.3)
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
    except Exception as e:
        print(f"Error selecting date {target_date}: {e}")

def scrape_fixtures(driver):
    try:
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "mat-card.desktop-fixture"))
        )
        elements = driver.find_elements(By.CSS_SELECTOR, ".sport-header, .comp-header, .section-header, mat-card.desktop-fixture")
        fixtures = []

        # Initialize headers
        sport = competition = section = subsection = ""

        for element in elements:
            cls = element.get_attribute("class") or ""
            if "sport-header" in cls:
                sport = element.text.strip()
            elif "comp-header" in cls:
                competition = element.text.strip()
            elif "section-header" in cls:
                section_text = element.text.strip()
                match = re.match(r"(.+?)\s*(\((.+)\))?$", section_text)
                if match:
                    section = match.group(1).strip()
                    if match.group(3):
                        subsection = match.group(3).strip()
            elif "desktop-fixture" in cls:
                try:
                    date_elem = element.find_element(By.CSS_SELECTOR, ".fixture-tab-date")
                    date_text = date_elem.text.strip()
                except Exception:
                    date_text = ""
                try:
                    venue_elems = element.find_elements(By.CSS_SELECTOR, ".venue")
                    venue = " ".join([v.text.strip() for v in venue_elems])
                except Exception:
                    venue = ""
                try:
                    home_team = element.find_element(By.CSS_SELECTOR, ".home-team").text.strip()
                except Exception:
                    home_team = ""
                try:
                    home_org = element.find_element(By.CSS_SELECTOR, ".home-org").text.strip()
                except Exception:
                    home_org = ""
                try:
                    away_team = element.find_element(By.CSS_SELECTOR, ".away-team").text.strip()
                except Exception:
                    away_team = ""
                try:
                    away_org = element.find_element(By.CSS_SELECTOR, ".away-org").text.strip()
                except Exception:
                    away_org = ""
                try:
                    vs_label = element.find_element(By.CSS_SELECTOR, ".vs-label").text.strip()
                except Exception:
                    vs_label = ""
                fixture = {
                    "sport": sport,
                    "competition": competition,
                    "section": section,
                    "subsection": subsection,
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
    except Exception as e:
        print(f"Error scraping fixtures: {e}")
        return []
    
    
def main():
    chrome_options = Options()
    chrome_options.add_argument("--start-maximized")
    driver = webdriver.Chrome(options=chrome_options)

    try:
        driver.get("https://www.collegesport.co.nz/draws-results")
        wait = WebDriverWait(driver, 20)

        wait.until(EC.presence_of_element_located((By.ID, "mat-select-1")))
        time.sleep(1)

        wait_and_click(driver, By.ID, "mat-select-1")
        time.sleep(0.5)

        try:
            deselect_btn = wait.until(
                EC.element_to_be_clickable((By.XPATH, "//button[.//span[contains(text(),'Deselect All')]]"))
            )
            deselect_btn.click()
            time.sleep(0.5)
        except Exception as e:
            print("Could not click Deselect All button:", e)

        wait_and_send_keys(driver, By.XPATH, "//input[@placeholder='Type to filter options']", "Sacred Heart College")
        time.sleep(1)

        sacred_btn = wait.until(
            EC.element_to_be_clickable((By.XPATH, "//button[.//span[contains(text(),'Sacred Heart College (Auckland)')]]"))
        )
        sacred_btn.click()
        time.sleep(0.5)

        driver.find_element(By.TAG_NAME, "body").click()
        time.sleep(0.5)

        start_date, end_date = get_date_range()

        time.sleep(2)

        date_inputs = driver.find_elements(By.XPATH, "//input[@aria-haspopup='dialog']")
        if len(date_inputs) < 2:
            raise Exception("Could not find both start and end date inputs. Found: {}".format(len(date_inputs)))
        
        select_date(driver,
            "(//input[@aria-haspopup='dialog'])[1]",
            "mat-datepicker-0",
            start_date
        )
        time.sleep(0.5)
        
        select_date(driver,
            "(//input[@aria-haspopup='dialog'])[2]",
            "mat-datepicker-1",
            end_date
        )
        time.sleep(1)

        time.sleep(1)
        try:
            wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "mat-card.desktop-fixture")))
            time.sleep(1)
        except Exception as e:
            print("Warning: Timeout waiting for fixtures to load:", e)
            print("Continuing anyway...")

        fixtures = scrape_fixtures(driver)

        with open("sacred_heart_fixtures.json", "w", encoding="utf-8") as f:
            json.dump(fixtures, f, ensure_ascii=False, indent=2)
        print(f"Extracted {len(fixtures)} fixtures. Saved to sacred_heart_fixtures.json.")
        
    finally:
        driver.quit()

if __name__ == "__main__":
    main()