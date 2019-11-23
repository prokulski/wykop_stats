# Dokumentacja API: https://www.wykop.pl/dla-programistow/apiv2docs/
import pandas as pd
import urllib.request
import json

from api_keys import *


# wykop_api_key = "xxx"
# wykop_secret_key = "yyy"

def print_pretty_dict(d):
    print(json.dumps(d, indent=4))


def get_json(url):
    response = urllib.request.urlopen(url)
    data = json.loads(response.read().decode())
    return data


def get_wykop_json(api_method):
    url_page = "https://a2.wykop.pl/" + api_method + "/appkey/" + wykop_api_key
    data = get_json(url_page)
    return data


def get_wykop_link_info(id):
    data = get_wykop_json("Links/Link/" + str(id))
    return data['data']


def get_wykop_link_comments(id):
    data = get_wykop_json("Links/Link/" + str(id) + "/withcomments")
    return data['data']['comments']


def get_wykop_upvoters(id):
    data = get_wykop_json("Links/Upvoters/" + str(id))
    return data['data']


def get_wykop_downvoters(id):
    data = get_wykop_json("Links/Downvoters/" + str(id))
    return data['data']


def get_wykop_month(year, month):
    data = get_wykop_json("Hits/Month/" + str(year) + "/" + str(month))
    df = pd.DataFrame(data['data'])
    while (len(data['data']) > 0):
        data = get_json(data['pagination']['next'])
        df = df.append(pd.DataFrame(data['data']))
    return df
