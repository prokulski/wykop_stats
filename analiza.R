library(tidyverse)
library(lubridate)
library(tidytext)
library(wordcloud)

theme_set(theme_minimal())

# polskie stop_words
pl_stop_words <- read_lines("polish_stopwords.txt")

# nazwa pliku z bazą danych
db_filename <- sprintf("wykop_hits_%04d_%02d.sqlite", year(today()), month(today()))

# pobranie danych z tabeli
wykop_hits <- src_sqlite(db_filename) %>%
  tbl("wykop_hits") %>%
  collect()

# uporządkowanie formatów danych
wykop_hits <- wykop_hits %>%
  mutate(date = ymd_hms(date)) %>%
  filter(as_date(date) != today()) %>%
  mutate(m = month(date),
         d = day(date),
         wd = wday(date, week_start = 1, label = TRUE),
         h = hour(date)) %>%
  mutate(title = str_replace_all(title, "&quot;", "\""),
         desc = str_replace_all(desc, "&quot;", "\""))


# Zakres dat
timeframe <- paste0("Znaleziska opublikowane pomiędzy ",
                    format(min(wykop_hits$date), "%H:%M @ %d-%m-%Y"), " a ",
                    format(max(wykop_hits$date), "%H:%M @ %d-%m-%Y"))

# najpopularniejsi autorzy
top_authors <- wykop_hits %>%
  count(author) %>%
  top_n(30, n)

top_authors %>%
  mutate(author = fct_reorder(author, n)) %>%
  ggplot() +
  geom_col(aes(author, n, fill = n), color = "gray80") +
  coord_flip() +
  scale_fill_distiller(palette = "YlOrRd", direction = 1) +
  labs(title = "Autorzy dodający najwięcej wykopalisk",
       subtitle = timeframe,
       x = "", y = "Liczba dodanch wykopalisk")



# liczba znalezisk dodawana dzień po dniu
wykop_hits %>%
  count(d) %>%
  ggplot() +
  geom_col(aes(d, n, fill = n), color = "gray", show.legend = FALSE) +
  geom_text(aes(d, n, label = n), vjust = -1) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1) +
  labs(title = "Liczba wykopalisk dodawanych w kolejnych dniach miesiąca",
       subtitle = timeframe,
       x = "dzień miesiąca", y = "Liczba dodanch wykopalisk")


# liczba znalezisk dodawana godzina po godzinie
wykop_hits %>%
  count(h) %>%
  ggplot() +
  geom_col(aes(h, n, fill = n), color = "gray", show.legend = FALSE) +
  geom_text(aes(h, n, label = n), vjust = -1) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1) +
  labs(title = "Liczba wykopalisk dodawanych o danej godzinie",
       subtitle = timeframe,
       x = "godzina", y = "Liczba dodanch wykopalisk\n(łącznie w całym miesiącu)")




# czas dodania znaleziska
wykop_hits %>%
  count(wd, h) %>%
  ggplot() +
  geom_tile(aes(wd, h, fill = n), color = "gray80", size = 0.5) +
  scale_y_reverse() +
  scale_fill_distiller(palette = "YlOrRd", direction = 1) +
  theme(legend.position = "bottom") +
  labs(title = "Liczba wykopalisk dodawanych według pory dnia i tygodnia",
       subtitle = timeframe,
       x = "", y = "", 
       fill = "Łączna liczba dodanych znalezisk dodanych\no danej godzinie w danym dniu tygodnie")




# liczba wykopów a liczba komentarzy
wykop_hits %>%
  ggplot() +
  geom_point(aes(vote_count, comments_count),
             size = 2, alpha = 0.5) +
  geom_smooth(aes(vote_count, comments_count),
              method = 'loess',
              color = "red", size = 1, se = FALSE) +
  scale_x_log10() + scale_y_log10() +
  labs(title = "Liczba wykopów i komentarzy",
       subtitle = timeframe,
       x = "Liczba wykopów (log)", y = "Liczba komentarzy (log)")


# na jeden komentarz przypada wykopów:
coef(lm(comments_count ~ vote_count, data = wykop_hits))[1]


# liczba wykopów a liczba zakopów
wykop_hits %>%
  filter(bury_count > 0) %>%
  ggplot() +
  geom_point(aes(vote_count, bury_count),
             size = 2, alpha = 0.5) +
  geom_smooth(aes(vote_count, bury_count),
              method = 'loess',
              color = "red", size = 1, se = FALSE) +
  scale_x_log10() + scale_y_log10() +
  labs(title = "Liczba wykopów i zakopów",
       subtitle = timeframe,
       x = "Liczba wykopów (log)", y = "Liczba zakopów (log)")



# na jeden zakop przypada wykopów:
coef(lm(bury_count ~ vote_count,
        data = wykop_hits %>% filter(bury_count > 0)))[1]



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
  gather("k", "v", -tag) %>%
  arrange(desc(tag)) %>%
  mutate(tag = fct_inorder(tag)) %>%
  ggplot() +
  geom_point(aes(tag, v, color = k), size = 3) +
  scale_color_manual(values = c(m_vote_count = "blue",
                                m_comments_count = "green",
                                m_bury_count = "red"),
                     labels = c(m_vote_count = "wykop",
                                m_comments_count = "komentarz",
                                m_bury_count = "zakop")) +
  coord_flip()  +
  theme(legend.position = "bottom") +
  labs(title = "Średnia liczba wykopów, zakopów i komentarzy w zależności od tagu",
       subtitle = timeframe,
       x = "", y = "Liczba wykopów / zakopów / komentarzy (log)", color = "")




# średnie liczby wykopów, zakopów i komentarzy na autroa
wykop_tag_data %>%
  group_by(author) %>%
  summarise(m_vote_count = mean(vote_count),
            m_comments_count = mean(comments_count),
            m_bury_count = mean(bury_count)) %>%
  ungroup() %>%
  filter(author %in% top_authors$author) %>%
  gather("k", "v", -author) %>%
  arrange(desc(author)) %>%
  mutate(author = fct_inorder(author)) %>%
  ggplot() +
  geom_point(aes(author, v, color = k), size = 3) +
  scale_color_manual(values = c(m_vote_count = "blue",
                                m_comments_count = "green",
                                m_bury_count = "red"),
                     labels = c(m_vote_count = "wykop",
                                m_comments_count = "komentarz",
                                m_bury_count = "zakop")) +
  coord_flip()  +
  theme(legend.position = "bottom") +
  labs(title = "Średnia liczba wykopów, zakopów i komentarzy w zależności od autora",
       subtitle = timeframe,
       x = "", y = "Liczba wykopów / zakopów / komentarzy (log)", color = "")





# kto postuje na jakim tagu?
wykop_tag_data %>%
  filter(author %in% top_authors$author) %>%
  filter(tag %in% top_tags$tag) %>%
  count(author, tag) %>%
  mutate(tag = fct_rev(tag)) %>%
  ggplot() +
  geom_tile(aes(author, tag, fill = n), color = "gray80", size = 0.5) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0),
        legend.position = "bottom") +
  labs(title = "Na jakim tagu postuje autor?",
       subtitle = timeframe,
       x = "", y = "", fill = "Liczba opublikowanych znalezisk w miesiącu")





# poluparność słów w tytułach i opisach
top_words <- wykop_hits %>%
  mutate(title = paste(title, desc)) %>%
  select(title) %>%
  unnest_tokens(word, title) %>%
  count(word, sort = TRUE) %>%
  filter(nchar(word) >= 4) %>%
  filter(!word %in% pl_stop_words) %>%
  filter(is.na(as.numeric(word)))

wordcloud(top_words$word, top_words$n,
          max.words = 150, min.freq = 5,
          scale = c(1.2, 0.5), 
          colors = RColorBrewer::brewer.pal(9, "YlOrRd")[5:9])

text(x = 0.5, y = 0.9,
     "Najpopularniejsze słowa w tytułach i opisach znalezisk",
     cex = 1.5, adj = 0.5, 
     col = "black")

text(x = 0.9, y = 0.15, timeframe, col = "gray20", cex = 0.7, adj = 1)



# słowa (tytuł + opis) per tag
tag_word <- wykop_hits %>%
  mutate(title = paste(title, desc)) %>%
  mutate(tag_list = str_split(tags, " ")) %>%
  select(title, tag_list) %>%
  pivot_longer(tag_list, values_to = "tag") %>%
  unnest_longer(tag) %>%
  select(-name) %>%
  unnest_tokens(word, title) %>%
  filter(nchar(word) >= 4) %>%
  filter(!word %in% pl_stop_words) %>%
  filter(is.na(as.numeric(word))) %>%
  count(tag, word)

# najpopularniejsze słowa
top_words_list <- tag_word %>%
  group_by(word) %>%
  summarise(n = sum(n)) %>%
  ungroup() %>%
  top_n(30, n) %>%
  pull(word)

# wystąpowanie słów w tagach
tag_word %>%
  filter(tag %in% top_tags$tag) %>%
  group_by(tag) %>%
  top_n(30, n) %>%
  ungroup() %>%
  filter(word %in% top_words_list) %>%
  mutate(word = fct_rev(word)) %>%
  ggplot() +
  geom_tile(aes(tag, word, fill = n), color = "gray80", size = 0.5) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0),
        legend.position = "bottom") +
  labs(title = "Najpopularniejsze słowa w tytule i opisie według tagu",
       subtitle = timeframe,
       x = "", y = "", fill = "Liczba słów w ramach tagu (w miesiącu)")





# rozkład w miesiacu wg tagów
tags_day_hour <- wykop_hits %>%
  mutate(tag_list = str_split(tags, " ")) %>%
  select(id, d, h, tag_list) %>%
  pivot_longer(tag_list, values_to = "tag") %>%
  unnest_longer(tag)

tags_day_hour %>%
  count(tag, d) %>%
  group_by(tag) %>%
  mutate(m_n = mean(n)) %>%
  ungroup() %>%
  filter(m_n > 5) %>%
  filter(tag %in% top_tags$tag) %>%
  ggplot() +
  geom_line(aes(d, n, color = tag)) +
  labs(title = "Najpopularniejsze tagi według dnia publikacji",
       subtitle = timeframe,
       x = "dzień publikacji", y = "średnia liczba znalezisk opublikowanych danego dnia",
       color = "")



# rozkład w dniu wg tagów
tags_day_hour %>%
  count(tag, h) %>%
  group_by(tag) %>%
  mutate(m_n = mean(n)) %>%
  ungroup() %>%
  filter(m_n > 5) %>%
  filter(tag %in% top_tags$tag) %>%
  ggplot() +
  geom_line(aes(h, n, color = tag)) +
  labs(title = "Najpopularniejsze tagi według godziny publikacji (uśrednione)",
       subtitle = timeframe,
       x = "godzina publikacji", y = "średnia liczba znalezisk opublikowanych o danej godzinie",
       color = "")

