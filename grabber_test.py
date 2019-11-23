# Skrypt sprawdza jak działają funkcje do czytania API

import pandas as pd
from grabber import *

if __name__ == "__main__":
    # info o linku
    print("\n==== INFORMACJE O KONKRETYM WYKOPALISKU =====")
    wykopalisko = get_wykop_link_info(4690931)
    print_pretty_dict(wykopalisko)

    # info o linku i komentarze
    print("\n==== KOMENTARZE =====")
    komentarze = pd.DataFrame(get_wykop_link_comments(4690931))
    print(komentarze.head())

    # wykopujący
    print("\n==== WYKOPUJĄCY  =====")
    wykopujacy = pd.DataFrame(get_wykop_upvoters(4690931))
    print(wykopujacy.head())

    # zakopujący
    print("\n==== ZAKUPUJĄCY =====")
    zakopujacy = pd.DataFrame(get_wykop_downvoters(4690931))
    print(zakopujacy.head())

    # hity miesiąca
    print("\n==== HITY LISTOPADA 2019 =====")
    listopad = get_wykop_month(2019, 11)
    print("\n== podsumowanie")
    print(listopad.describe())
    print("\n== pocztątek tabelki:")
    print(listopad.head())
