import pandas as pd
import sqlite3

import time
import math 

from grabber import get_wykop_upvoters,get_wykop_downvoters


# otwieramy bazę danych
db_conn = sqlite3.connect("wykop_hits_%04d_%02d.sqlite" % (time.localtime().tm_year, time.localtime().tm_mon))
c = db_conn.cursor()

# pobiermy całą tabelę z listą znalezisk
df = pd.read_sql_query('SELECT id FROM wykop_hits;', db_conn)

# upvoters - usuwamy tabelę jeśli istniała
c.execute("DROP TABLE IF EXISTS upvoters")
# tworzymy tabelę na dane
c.execute('CREATE TABLE upvoters (id INTEGER, upvoter TEXT, date TEXT)')

# downvoters - usuwamy tabelę jeśli istniała
c.execute("DROP TABLE IF EXISTS downvoters")
# tworzymy tabelę na dane
c.execute('CREATE TABLE downvoters (id INTEGER, upvoter TEXT, date TEXT, reason INTEGER)')


# tabelka pandasowa na dane
upvoters_full = pd.DataFrame()
downvoters_full = pd.DataFrame()

# jedziemy każdy ID po kolei
for r in range(len(df)):
    # progress bar :)
    print(f"{r} of {len(df)}")
    
    # pobieramy listę upvoters dla konkternego ID znaleziska
    upvoters = get_wykop_upvoters(df.iloc[r]['id'])
    upvoters = pd.DataFrame(upvoters)
    # wyciągamy login wykopującego
    upvoters['upvoter'] = upvoters['author'].apply(lambda x: x['login'])    
    upvoters['id'] = df.iloc[r]['id']
    upvoters = upvoters[['id', 'upvoter', 'date']]
    # do pełnej tabeli pandasowej dodajemy listę dla danego ID
    upvoters_full = upvoters_full.append(upvoters)
    
    # to samo dla downvoters
    downvoters = get_wykop_downvoters(df.iloc[r]['id'])
    downvoters = pd.DataFrame(downvoters)
    downvoters['upvoter'] = downvoters['author'].apply(lambda x: x['login'])
    downvoters['id'] = df.iloc[r]['id']
    downvoters = downvoters[['id', 'upvoter', 'date', 'reason']]
    downvoters_full = downvoters_full.append(downvoters)
    
    # zamiast dodawać do _full może lepiej zapisać do SQLa?
    upvoters.to_sql("upvoters", db_conn, if_exists="append", index=False)
    downvoters.to_sql("downvoters", db_conn, if_exists="append", index=False)
    
    # czekamy chwilę, żeby nie przekroczyć limitu 500 zapytań na godzinę
    # wyżej są dwa zapytania -> 250 wywołań pętli na 3600 sekund -> 3600/250 sekund czekania
    time.sleep(math.ceil(3600/250))

# teraz można zamknąć bazę
db_conn.close()

