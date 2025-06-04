import requests
import json

# --- CONFIGURATION ---
API_KEY = "65d6d135-a94c-4f7f-ae63-68392c5bca1d"
TENANT = "nzc"
ORG_ID = "a2aeb720-88f2-4887-94ee-9de630679dc3"  # Replace with your actual org ID if needed

BASE_URL = "https://api.playhq.com/v1"
OUTPUT_FILE = "cricket_fixtures.json"

HEADERS = {
    "x-api-key": API_KEY,
    "x-phq-tenant": TENANT,
    "Accept": "application/json"
}

def fetch_seasons_for_organisation(org_id):
    url = f"{BASE_URL}/organisations/{org_id}/seasons"
    seasons = []
    cursor = None
    while True:
        params = {}
        if cursor:
            params["cursor"] = cursor
        response = requests.get(url, headers=HEADERS, params=params)
        response.raise_for_status()
        data = response.json()
        seasons.extend(data.get("data", []))
        meta = data.get("metadata", {})
        if meta.get("hasMore"):
            cursor = meta.get("nextCursor")
        else:
            break
    return seasons

def fetch_teams_for_season(season_id):
    url = f"{BASE_URL}/seasons/{season_id}/teams"
    teams = []
    cursor = None
    while True:
        params = {}
        if cursor:
            params["cursor"] = cursor
        response = requests.get(url, headers=HEADERS, params=params)
        response.raise_for_status()
        data = response.json()
        teams.extend(data.get("data", []))
        meta = data.get("metadata", {})
        if meta.get("hasMore"):
            cursor = meta.get("nextCursor")
        else:
            break
    return teams

def fetch_fixture_for_team(team_id):
    url = f"{BASE_URL}/teams/{team_id}/fixture"
    fixtures = []
    cursor = None
    while True:
        params = {}
        if cursor:
            params["cursor"] = cursor
        response = requests.get(url, headers=HEADERS, params=params)
        response.raise_for_status()
        data = response.json()
        fixtures.extend(data.get("data", []))
        meta = data.get("metadata", {})
        if meta.get("hasMore"):
            cursor = meta.get("nextCursor")
        else:
            break
    return fixtures

def get_opponent_name(competitors, sacred_heart_name):
    for comp in competitors:
        if sacred_heart_name.lower() not in comp.get('name', '').lower():
            return comp.get('name')
    return "Unknown"

def get_result(competitors):
    # Try to build a result string like "159 vs 144" if both scores are present
    if len(competitors) == 2:
        score1 = competitors[0].get('scoreTotal')
        score2 = competitors[1].get('scoreTotal')
        if score1 is not None and score2 is not None:
            return f"{score1} vs {score2}"
    return None

def build_fixture_info(fixture, sacred_heart_name):
    game_id = fixture.get('id')
    grade_id = fixture.get('grade', {}).get('id')
    competitors = fixture.get('competitors', [])
    result = get_result(competitors)
    venue_obj = fixture.get('venue', {})
    venue_name = venue_obj.get('name', '')
    surface_name = venue_obj.get('surfaceAbbreviation', '') or venue_obj.get('surfaceName', '')
    venue = f"{venue_name} - {surface_name}" if venue_name and surface_name else venue_name or surface_name
    schedule = fixture.get('schedule', {})
    date = schedule.get('date')
    time = schedule.get('time')
    opponent = get_opponent_name(competitors, sacred_heart_name)
    url = fixture.get('url')
    status = fixture.get('status')
    round_info = fixture.get('round', {}).get('name')
    return {
        "result": result,
        "game_id": game_id,
        "grade_id": grade_id,
        "date": date,
        "time": time,
        "venue": venue,
        "opponent": opponent,
        "game_url": url,
        "status": status,
        "round": round_info
    }

def save_fixtures_to_json(data, filename):
    # Always overwrite the file
    with open(filename, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print(f"Fixtures saved to {filename}")

if __name__ == "__main__":
    output = {
        "organisation_id": ORG_ID,
        "sacred_heart_teams": []
    }
    seasons = fetch_seasons_for_organisation(ORG_ID)
    if not seasons:
        print("No seasons found for this organisation.")
    else:
        for season in seasons:
            season_id = season.get("id")
            season_name = season.get("name")
            teams = fetch_teams_for_season(season_id)
            sacred_heart_teams = [team for team in teams if "sacred heart" in team.get('name', '').lower()]
            for team in sacred_heart_teams:
                team_name = team.get('name')
                team_id = team.get('id')
                fixtures = fetch_fixture_for_team(team_id)
                fixtures_info = [build_fixture_info(fix, team_name) for fix in fixtures]
                output["sacred_heart_teams"].append({
                    "season_id": season_id,
                    "season_name": season_name,
                    "team_id": team_id,
                    "team_name": team_name,
                    "fixtures": fixtures_info
                })
        save_fixtures_to_json(output, OUTPUT_FILE)