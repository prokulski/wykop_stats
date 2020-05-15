#!/bin/bash

# akutalny rok i poprzedni numer miesiąca
# TODO: trzeba dodać wiodące zero dla miesiąca
YEAR=$(date +%Y)
MONTH=$(($(date +%m)-1))

# sprzątamy to co ewentualnie już było dla tego miesiąca
rm -rf /var/www/html/wykop/wykop_$YEAR$MONTH

# pobranie znalezisk z głównej
python main.py

# pobranie zakopujących i wykopujących
python get_voters.py

# renderowanie raportu
R -e "rmarkdown::render('raport.Rmd')"

# folder na WWW na raport
mkdir -p "/var/www/html/wykop/wykop_$YEAR$MONTH"
# skopiowanie raportu na produkcję
cp -fR raport.html /var/www/html/wykop/wykop_$YEAR$MONTH/
cp -fR raport_files /var/www/html/wykop/wykop_$YEAR$MONTH/
