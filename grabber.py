# Funkcje pomocnicze do czytania API

# Dokumentacja API: https://www.wykop.pl/dla-programistow/apiv2docs/

import pandas as pd
import urllib.request
import json
import time

# TODOs -------------------------------------------
# TODO: dodać fukkcje biorące info o użytkowniku
# TODO: przerobić na klasę - jedno znalezisko to obiekt:
#  Konstruktor: ID jako argument + wez_info,
#  metody: wez_komcie, wez_upvoters, wez_downvoters
# -------------------------------------------------
# TODO: dodać obsługę błędów w przypadku wyczerpania limitu

# klucz do api:
from api_keys import *


# W pliku api_keys.py powinny znaleźć się:
# wykop_api_key = "xxx"
# wykop_secret_key = "yyy"


def print_pretty_dict(d):
    """
    Funkcja printuje JSONa w czytelny sposób
    :param d: JSON
    :return:
    """
    print(json.dumps(d, indent=4))


def get_json(url):
    """
    Funkcja pobiera JSONa z podanego URLa.
    Zakłada się udało, nie sprawdza błędów itp.
    :param url: URL do pliku JSON
    :return: pobrany JSON
    """

    while True:
        error = False

        try:
            response = urllib.request.urlopen(url)
        except urllib.error.HTTPError as e:
            # Return code error (e.g. 404, 501, ...)
            print('== API Error - HTTPError: {}'.format(e.code))
            error = True
        except urllib.error.URLError as e:
            # Not an HTTP-specific error (e.g. connection refused)
            print('== API Error - URLError: {}'.format(e.reason))
            error = True

        data = json.loads(response.read().decode())

        if 'error' in data:
            print(data)
            print('== API Error: ' + data['error']['message_pl'])
            error = True
        else:
            break

        if error:
            print(f'\tCzekam teraz przez 10 minut ({time.ctime()})')
            time.sleep(60 * 10)
            print(f'\tSkończyłem czekać ({time.ctime()})')

    return data


def get_wykop_json(api_method):
    """
    Funkcja wywołuje konkretną metodę z API Wykopu.
    W zmiennej globalnej wykop_api_key musi być klucz do API
    :param api_method: Metoda wg dokumnetacji
    :return: JSON z wynikiem zapytania
    """
    url_page = "https://a2.wykop.pl/" + api_method + "/appkey/" + wykop_api_key
    data = get_json(url_page)
    return data


def get_wykop_link_info(id):
    """
    Pobranie informacji o konkretnym znalezisku poprzez API Wykopu.
    TODO: przerobić zwracany typ na DataFrame

    :param id: ID znaleziska
    :return: dict z wynikiem
    """
    data = get_wykop_json("Links/Link/" + str(id))
    return data['data']


def get_wykop_link_comments(id):
    """
    Funkcja pobiera komentarze do podanego znaleziska.
    TODO: sprawdzić czy w odpowiedzi są wszystkie czy jest stronicowanie.
    TODO: przerobić zwracany typ na DataFrame

    :param id: ID znaleziska
    :return: dict z wynikiem
    """
    data = get_wykop_json("Links/Link/" + str(id) + "/withcomments")
    return data['data']['comments']


def get_wykop_upvoters(id):
    """
    Funkcja pobiera listę wykopujących znalezisko.
    TODO: przerobić zwracany typ na DataFrame

    :param id: ID znaleziska
    :return: Dict z listą.
    """
    data = get_wykop_json("Links/Upvoters/" + str(id))
    return data['data']


def get_wykop_downvoters(id):
    """
    Funkcja pobiera listę zakopujących.
    TODO: przerobić zwracany typ na DataFrame

    :param id: ID znaleziska
    :return: Dict z wynikiem
    """
    data = get_wykop_json("Links/Downvoters/" + str(id))
    return data['data']


def get_wykop_month(year, month):
    """
    Funkcja pobiera listę znalezisk z danego miesiąca (hity miesiąca)

    :param year: rok
    :param month: miesiąc
    :return: pandasowy data frame z listą znalezisk
    """
    data = get_wykop_json("Hits/Month/" + str(year) + "/" + str(month))
    df = pd.DataFrame(data['data'])
    while (len(data['data']) > 0):
        data = get_json(data['pagination']['next'])
        df = df.append(pd.DataFrame(data['data']), sort=False)
    return df
