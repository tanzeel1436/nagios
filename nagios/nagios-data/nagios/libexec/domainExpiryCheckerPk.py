# Created by Nasir Ahmad - DevOps Engineer at Finja Pvt Ltd
# Email: nasir.ahmad@finja.pk


import requests
from bs4 import BeautifulSoup
import sys
from datetime import date
from time import strptime


DOMAIN = sys.argv[1]
T1 = sys.argv[2]  # warning
T2 = sys.argv[3]  # critical

url = "https://pk6.pknic.net.pk/pk5/lookup.PK"


def check_domain(domain):
    data = {
        "name": domain
          }
    response = requests.post(url=url, data=data)
    parsed_html = BeautifulSoup(response.text)
    trs = parsed_html.body.find('div', attrs={'class': 'fboxed formbox'}).find_all('tr')
    close_loop = False
    days_to_expire = 0
    result = ""
    expiry_date = ""
    for tr in trs:
        if close_loop is True:
            break
        else:
            tds = tr.find_all('td')
            for i, td in enumerate(tds):
                if len(td.text.strip()) != 0:
                    if "Expire" in td.text:
                        days_to_expire = date_diff(tds[i+2].text)
                        expiry_date = tds[i+2].text
                        close_loop = True
                        break
    if days_to_expire > 0:
        if int(T2) > days_to_expire:
            result = "Critical: " + DOMAIN + " Will Expire in " + str(days_to_expire) + " days. " + str(expiry_date)
            print(result)
            sys.exit(2)
        elif int(T1) > days_to_expire:
            result = "Warning: " + DOMAIN + " Will Expire in " + str(days_to_expire) + " days. " + str(expiry_date)
            print(result)
            sys.exit(1)
        else:
            result = "Ok: " + DOMAIN + " Will Expire in " + str(days_to_expire) + " days. " + str(expiry_date)
            print(result)
            sys.exit(0)

    return result


def date_diff(obj):
    chunks = obj.strip().split(' ')
    mon = chunks[0].replace(',', "")
    day = chunks[1].replace(',', "")
    year = chunks[2].replace(',', "")
    expiry_date = date(int(year), strptime(mon,'%b').tm_mon, int(day))
    today_date = date.today()
    diff = expiry_date - today_date
    return diff.days


if __name__ == "__main__":
    print(check_domain(DOMAIN))

