library(tidyverse)
library(lubridate)

theme_set(theme_minimal())

# nazwa pliku z bazą danych
db_filename <- sprintf("wykop_hits_%04d_%02d.sqlite", year(today()), month(today()))

# pobranie danych z tabeli
wykop_hits <- src_sqlite(db_filename) %>%
    tbl("wykop_hits") %>%
    collect()

# uporządkowanie formatów danych
wykop_hits <- wykop_hits %>%
    mutate(date = ymd_hms(date)) %>%
    mutate(m = month(date),
    d = day(date),
    wd = wday(date, week_start = 1, label = TRUE),
    h = hour(date))

# TODO: dodać zrobienie listy z tagów


# najpopularniejsi autorzy
top_authors <- wykop_hits %>%
count(author) %>%
top_n(30, n)

top_authors %>%
    mutate(author = fct_reorder(author, n)) %>%
    ggplot() +
    geom_col(aes(author, n)) +
    coord_flip()


# czas dodania znaleziska
wykop_hits %>%
count(wd, h) %>%
ggplot() +
    geom_tile(aes(wd, h, fill = n), color = "gray80", size = 0.5) +
    scale_y_reverse() +
    scale_fill_distiller(palette = "YlOrRd", direction = 1)


# liczba znalezisk dodawana dzień po dniu
wykop_hits %>%
count(d) %>%
ggplot() +
geom_col(aes(d, n))


# liczba wykopów a liczba komentarzy
wykop_hits %>%
ggplot() +
    geom_point(aes(comments_count, vote_count)) +
    scale_y_log10()


# liczba wykopów a liczba zakopów
wykop_hits %>%
ggplot() +
geom_point(aes(vote_count, bury_count))


# rozbicie danych per tag
wykop_tag_data <- wykop_hits %>%
    mutate(tag_list = str_split(tags, " ")) %>%
    select(id, author, vote_count, comments_count, bury_count, tag_list) %>%
    pivot_longer(tag_list, values_to = "tag") %>%
    unnest_longer(tag)

# najpopularniejsze tagi
top_tags <- wykop_tag_data %>%
    count(tag) %>%
    top_n(30, n)


# średnie liczby wykopów, zakopów i komentarzy na tag
wykop_tag_data %>%
    group_by(tag) %>%
    summarise(m_vote_count = mean(vote_count),
    m_comments_count = mean(comments_count),
    m_bury_count = mean(bury_count)) %>%
    ungroup() %>%
    filter(tag %in% top_tags$tag) %>%
    gather("k", "v", - tag) %>%
    arrange(desc(tag)) %>%
    mutate(tag = fct_inorder(tag)) %>%
    ggplot() +
    geom_point(aes(tag, v, color = k)) +
    coord_flip()


# kto postuje na jakim tagu?
wykop_tag_data %>%
    filter(author %in% top_authors$author) %>%
    filter(tag %in% top_tags$tag) %>%
    count(author, tag) %>%
    mutate(tag = fct_rev(tag)) %>%
    ggplot() +
    geom_tile(aes(author, tag, fill = n), color = "gray80", size = 0.5) +
    scale_fill_distiller(palette = "YlOrRd", direction = 1) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0))
