import pandas as pd
import sqlite3

import time
import math

# wykorzystujemy metody z pakietu
from grabber import get_wykop_upvoters,get_wykop_downvoters


# TODO:
# trzeba zrobić weryfikację czy API dobrze odpowiedziało - jeśli nie - to czekamy np. 15 minut i sprawdzamy ponownie
# zamiast usuwać tabele na początku lepiej sprawdzić co zostało pobrane i dociągać resztę

# bieżący miesiąc i rok
cur_year = time.localtime().tm_year
cur_month = time.localtime().tm_mon
# czy mamy początek miesiąca? jeśli tak - to pobieramy pełny poprzedni miesiąc!
if time.localtime().tm_mday < 10:
    cur_month = cur_month - 1
    # dopowiednie dostosowanie roku
    if cur_month == 1:
        cur_month = 12
        cur_year = cur_year - 1

# otwieramy bazę danych
db_conn = sqlite3.connect("wykop_hits_%04d_%02d.sqlite" % (cur_year, cur_month))
c = db_conn.cursor()

# pobiermy całą tabelę z listą znalezisk
df = pd.read_sql_query('SELECT id FROM wykop_hits;', db_conn)


# TODO
# tworzenie tabel przerzucić do main, tutaj tylko je zapisywać

# upvoters - usuwamy tabelę jeśli istniała
c.execute("DROP TABLE IF EXISTS upvoters")
# tworzymy tabelę na dane
c.execute('CREATE TABLE upvoters (id INTEGER, upvoter TEXT, date TEXT)')

# downvoters - usuwamy tabelę jeśli istniała
c.execute("DROP TABLE IF EXISTS downvoters")
# tworzymy tabelę na dane
c.execute('CREATE TABLE downvoters (id INTEGER, downvoter TEXT, date TEXT, reason INTEGER)')


# tabelka pandasowa na dane
# upvoters_full = pd.DataFrame()
# downvoters_full = pd.DataFrame()

# jedziemy każdy ID po kolei
for r in range(len(df)):
    # pobieramy listę upvoters dla konkternego ID znaleziska
    print(f"upvoters: {r} of {len(df)} @ {time.ctime()}")

    upvoters = get_wykop_upvoters(df.iloc[r]['id'])
    upvoters = pd.DataFrame(upvoters)
    # wyciągamy login wykopującego
    upvoters['upvoter'] = upvoters['author'].apply(lambda x: x['login'])
    upvoters['id'] = df.iloc[r]['id']
    upvoters = upvoters[['id', 'upvoter', 'date']]
    # do pełnej tabeli pandasowej dodajemy listę dla danego ID
    # upvoters_full = upvoters_full.append(upvoters)


    # to samo dla downvoters
    print(f"downvoters: {r} of {len(df)} @ {time.ctime()}")

    downvoters = get_wykop_downvoters(df.iloc[r]['id'])
    downvoters = pd.DataFrame(downvoters)
    downvoters['downvoter'] = downvoters['author'].apply(lambda x: x['login'])
    downvoters['id'] = df.iloc[r]['id']
    downvoters = downvoters[['id', 'downvoter', 'date', 'reason']]
    # downvoters_full = downvoters_full.append(downvoters)

    # zamiast dodawać do _full może lepiej zapisać do SQLa?
    upvoters.to_sql("upvoters", db_conn, if_exists="append", index=False)
    downvoters.to_sql("downvoters", db_conn, if_exists="append", index=False)


# teraz można zamknąć bazę
db_conn.close()

