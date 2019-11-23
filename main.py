# Skrypt główny - zbiera dane z aktualnego miesiąca z Wykopu poprzez API i pakuje je do SQLite

import pandas as pd
import time
import sqlite3

from grabber import *

if __name__ == "__main__":
    # bieżący miesiąc i rok
    cur_year = time.localtime().tm_year
    cur_month = time.localtime().tm_mon

    # pobranie hitów z miesiąca
    miesiac = get_wykop_month(cur_year, cur_month)
    miesiac['login'] = miesiac['author'].apply(lambda x: x['login'])

    # tworzymy bazę danych
    db_conn = sqlite3.connect("wykop_hits_%04d_%02d.sqlite" % (time.localtime().tm_year, time.localtime().tm_mon))
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
                    tags TEXT
                 )''')

    # dla kolejnych wierszy:
    for r in range(len(miesiac)):
        # weź jeden wiersz
        row = miesiac.iloc[r]

        # włóż wiersz do tabeli
        c.execute(
            "INSERT INTO wykop_hits (id, date, title, author, desc, comments_count, vote_count, bury_count, tags) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (int(row['id']),
             row['date'],
             row['title'],
             row['login'],
             row['description'],
             int(row['comments_count']),
             int(row['vote_count']),
             int(row['bury_count']),
             row['tags']
             ))
        # wykonaj query
        db_conn.commit()

    # teraz można zamknąć bazę
    db_conn.close()
