
# Skrypt główny - zbiera dane z aktualnego miesiąca z Wykopu poprzez API i pakuje je do SQLite

# TODO:
# utworzenie tabelek na początek - razem z tabelami dla up- i down-voters

import pandas as pd
import time
import sqlite3

from grabber import *

if __name__ == "__main__":
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

    # pobranie hitów z miesiąca
    miesiac = get_wykop_month(cur_year, cur_month)
    # TODO: sprawdzić czy się udało, ewentualnie poczekać 15 minut i znowu sprawdzić

    # login autora wyciągamy z zagnieżdżonego pola
    miesiac['login'] = miesiac['author'].apply(lambda x: x['login'])

    # tworzymy bazę danych
    db_conn = sqlite3.connect("wykop_hits_%04d_%02d.sqlite" % (cur_year, cur_month))
    c = db_conn.cursor()

    # usuwamy tabelę jeśli istniała
    c.execute("DROP TABLE IF EXISTS wykop_hits")
    # tworzymy tabelę na dane
    c.execute('''CREATE TABLE wykop_hits
                 (
                    id INTEGER,
                    date TEXT,
                    title TEXT,
                    author TEXT,
                    desc TEXT,
                    comments_count INTEGER,
                    vote_count INTEGER,
                    bury_count INTEGER,
                    tags TEXT,
                    url TEXT,
                    status TEXT,
                    plus18 INTEGER,
                    is_hot INTEGER
                 )
                 ''')

    # dla kolejnych wierszy:
    for r in range(len(miesiac)):
        # weź jeden wiersz
        row = miesiac.iloc[r]

        # włóż wiersz do tabeli
        c.execute(
            "INSERT INTO wykop_hits (id, date, title, author, desc, comments_count, vote_count, bury_count, tags, url, status, plus18, is_hot) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (int(row['id']),
             row['date'],
             row['title'],
             row['login'],
             row['description'],
             int(row['comments_count']),
             int(row['vote_count']),
             int(row['bury_count']),
             row['tags'],
             row['source_url'],
             row['status'],
             int(row['plus18']),
             int(row['is_hot'])
             ))
        # wykonaj query
        db_conn.commit()

    # teraz można zamknąć bazę
    db_conn.close()
