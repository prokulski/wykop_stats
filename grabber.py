# Funkcje pomocnicze do czytania API

# TODO: dodać funkcje biorące info o użytkowniku

# Dokumentacja API: https://www.wykop.pl/dla-programistow/apiv2docs/

import pandas as pd
import urllib.request
import urllib.error
import json
import time
import logging

# klucz do api:
# TODO: może lepiej użyć zmiennych systemowych?
from api_keys import *


# W pliku api_keys.py powinny znaleźć się:
# wykop_api_key = "xxx"
# wykop_secret_key = "yyy"


def print_pretty_dict(d, indent=4):
    """
    Funkcja printuje JSONa w czytelny sposób
    :param indent: ile spacji wcięcia?
    :param d: JSON
    :return:
    """
    print(json.dumps(d, indent=indent))


def get_json(url, wait=60):
    """
    Funkcja pobiera JSONa z podanego URLa.
    Sprawdza błędy i w printuje je, czeka 30 minu
    :param url: URL do pliku JSON
    :param wait: licza minut oczekiwania w razie niepowodzenia, domyślnie 30 minut
    :return: pobrany JSON
    """

    while True:
        error = False

        try:
            response = urllib.request.urlopen(url)
        except urllib.error.HTTPError as e:
            # Return code error (e.g. 404, 501, ...)
            logging.warning('== API Error - HTTPError: {}'.format(e.code))
            error = True
        except urllib.error.URLError as e:
            # Not an HTTP-specific error (e.g. connection refused)
            logging.warning('== API Error - URLError: {}'.format(e.reason))
            error = True

        if not error:
            data = json.loads(response.read().decode())
            if 'error' in data:
                logging.warning('== API Error: ' + data['error']['message_pl'])
                error = True
            else:
                break

        if error:
            logging.warning('Czekam teraz przez ' + str(wait) + ' minut.')
            time.sleep(60 * wait)
            logging.warning('Skończyłem czekać.')

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
