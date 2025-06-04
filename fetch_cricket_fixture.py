import requests

# --- CONFIGURATION ---
API_KEY = "65d6d135-a94c-4f7f-ae63-68392c5bca1d"
TENANT = "nzc"
ORG_ID = "a2aeb720-88f2-4887-94ee-9de630679dc3"  # Replace with your actual org ID if needed

BASE_URL = "https://api.playhq.com/v1"
SEASONS_ENDPOINT = f"/organisations/{ORG_ID}/seasons"

HEADERS = {
    "x-api-key": API_KEY,
    "x-phq-tenant": TENANT,
    "Accept": "application/json"
}

def fetch_seasons_for_organisation(org_id, cursor=None):
    url = f"{BASE_URL}/organisations/{org_id}/seasons"
    params = {}
    if cursor:
        params["cursor"] = cursor
    try:
        response = requests.get(url, headers=HEADERS, params=params)
        print(f"GET {response.url}")
        print(f"Status: {response.status_code}")
        response.raise_for_status()
        data = response.json()
        print("Seasons for Organisation:")
        for season in data.get("data", []):
            print(f"- {season.get('name')} (ID: {season.get('id')})")
        # Handle pagination if needed
        if data.get("metadata", {}).get("hasMore"):
            print("More results available. Use cursor:", data["metadata"].get("nextCursor"))
        return data
    except requests.RequestException as e:
        print("Error fetching seasons:", e)
        if hasattr(e, 'response') and e.response is not None:
            print("Response content:", e.response.text)
        return None

if __name__ == "__main__":
    fetch_seasons_for_organisation(ORG_ID)