# TODO dodać logowanie zamiast printów
# TODO: sprawdzić co zostało pobrane i dociągać resztę

import time

import pandas as pd
import sqlite3

import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s :: %(levelname)s :: %(filename)s :: %(message)s')

# wykorzystujemy metody z pakietu
from grabber import get_wykop_upvoters,get_wykop_downvoters

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

logging.info("Opróżniam tabele w bazie danych.")

# upvoters - usuwamy tabelę jeśli istniała
c.execute("DELETE FROM upvoters")
# downvoters - usuwamy dane z tabeli
c.execute("DELETE FROM downvoters")

logging.info("Pobieram wykopy i zakopy...")

# jedziemy każdy ID po kolei
df_len = len(df)
for r in range(df_len):
    print(f"{r} of {df_len}")

    logging.info("Pobieram upvoters dla {a} wiersza z {b} (znalezisko ID={c})".format(a=r, b=df_len, c=df.iloc[r]['id']))
    # pobieramy listę upvoters dla konkternego ID znaleziska
    upvoters_org = get_wykop_upvoters(df.iloc[r]['id'])
    # formalnie powinniśmy sprawdzić czy są wykopywacze,
    # ale bez nich Wykop.pl nie miałby sensu
    # zatem olewamy :)
    upvoters = pd.DataFrame(upvoters_org)
    # wyciągamy login wykopującego
    upvoters['upvoter'] = upvoters['author'].apply(lambda x: x['login'])
    upvoters['id'] = df.iloc[r]['id']
    upvoters = upvoters[['id', 'upvoter', 'date']]
    logging.info("Zapisuję do bazy info o upvoters")
    upvoters.to_sql("upvoters", db_conn, if_exists="append", index=False)

    # to samo dla downvoters
    logging.info("Pobieram downvoters dla {a} wiersza z {b} (znalezisko ID={c})".format(a=r, b=df_len, c=df.iloc[r]['id']))
    downvoters_org = get_wykop_downvoters(df.iloc[r]['id'])
    # sprawdzamy czy byli jacyś zakopywacze
    if len(downvoters_org) > 0:
        downvoters = pd.DataFrame(downvoters_org)
        downvoters['downvoter'] = downvoters['author'].apply(lambda x: x['login'])
        downvoters['id'] = df.iloc[r]['id']
        downvoters = downvoters[['id', 'downvoter', 'date', 'reason']]
        logging.info("Zapisuję do bazy info o downvoters")
        downvoters.to_sql("downvoters", db_conn, if_exists="append", index=False)

# teraz można zamknąć bazę
db_conn.close()

logging.info("Skończyłem.")
