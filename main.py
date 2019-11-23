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
                    id long,
                    date text,
                    title text,
                    author text,
                    desc text,
                    comments_count int,
                    vote_count int,
                    bury_count int,
                    tags text
                 )''')

    # dla kolejnych wierszy:
    for r in range(len(miesiac)):
        # weź jeden wiersz
        row = miesiac.iloc[r]

        # włóż wiersz do tabeli
        c.execute(
            "INSERT INTO wykop_hits (id, date, title, author, desc, comments_count, vote_count, bury_count, tags) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (row['id'],
             row['date'],
             row['title'],
             row['login'],
             row['description'],
             row['comments_count'],
             row['vote_count'],
             row['bury_count'],
             row['tags']
             ))
        # wykonaj query
        db_conn.commit()

    # teraz można zamknąć bazę
    db_conn.close()
