import requests
import json
import os
from datetime import datetime
from urllib.parse import quote

def fetch_all_region_data():
    base_url = "http://apis.data.go.kr/1741000/StanReginCd/getStanReginCdList"
    service_key = quote("SoZiaHO8v1qTinVIqVYU4BsqAFBARb2BK1wxqm/DP1ib26lJHVEWxd5wV9OBJptjLdMe30UVhVBxsRSrYHKMRw==")
    num_of_rows = 1000
    page_no = 1
    all_items = []

    print("API 요청 시작...")
    print(f"URL: {base_url}")
    print(f"서비스 키: {service_key}")
    
    while True:
        params = {
            "serviceKey": service_key,
            "type": "json",
            "pageNo": str(page_no),
            "numOfRows": str(num_of_rows),
            "flag": "Y"
        }
        response = requests.get(base_url, params=params)
        response.raise_for_status()
        data = response.json()
        items = data['response']['body']['items']
        if not items:
            break
        all_items.extend(items)
        total_count = int(data['response']['body']['totalCount'])
        print(f"페이지 {page_no} 수집, 누적 {len(all_items)}/{total_count}")
        if len(all_items) >= total_count:
            break
        page_no += 1

    os.makedirs("assets/data", exist_ok=True)
    current_date = datetime.now().strftime("%Y%m%d")
    output_file = f"assets/data/region_{current_date}.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(all_items, f, ensure_ascii=False, indent=2)
    print(f"전국 데이터 저장 완료: {output_file}")

if __name__ == "__main__":
    fetch_all_region_data() 