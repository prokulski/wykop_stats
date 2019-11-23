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
  mutate(m = month(date),
         d = day(date),
         wd = wday(date, week_start = 1, label = TRUE),
         h = hour(date)) %>%
  mutate(title = str_replace_all(title, "&quot;", "\""),
         desc = str_replace_all(desc, "&quot;", "\""))


# najpopularniejsi autorzy
top_authors <- wykop_hits %>%
  count(author) %>%
  top_n(30, n)

top_authors %>%
  mutate(author = fct_reorder(author, n)) %>%
  ggplot() +
  geom_col(aes(author, n, fill = n)) +
  coord_flip() +
  scale_fill_distiller(palette = "YlOrRd", direction = 1)


# liczba znalezisk dodawana dzień po dniu
wykop_hits %>%
  count(d) %>%
  ggplot() +
  geom_col(aes(d, n, fill = n)) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1)

# liczba znalezisk dodawana godzina po godzinie
wykop_hits %>%
  count(h) %>%
  ggplot() +
  geom_col(aes(h, n, fill = n)) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1)


# czas dodania znaleziska
wykop_hits %>%
  count(wd, h) %>%
  ggplot() +
  geom_tile(aes(wd, h, fill = n), color = "gray80", size = 0.5) +
  scale_y_reverse() +
  scale_fill_distiller(palette = "YlOrRd", direction = 1)


# liczba wykopów a liczba komentarzy
wykop_hits %>%
  ggplot() +
  geom_point(aes(vote_count, comments_count),
             size = 2, alpha = 0.5) +
  geom_smooth(aes(vote_count, comments_count),
              method = 'loess',
              color = "red", size = 1, se = FALSE) +
  scale_x_log10() + scale_y_log10()

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
  scale_x_log10() + scale_y_log10()

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
  coord_flip()


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
          colors = RColorBrewer::brewer.pal(9, "YlOrRd"))



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
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0))




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
  geom_line(aes(d, n, color = tag))


# rozkład w dniu wg tagów
tags_day_hour %>%
  count(tag, h) %>%
  group_by(tag) %>%
  mutate(m_n = mean(n)) %>%
  ungroup() %>%
  filter(m_n > 5) %>%
  filter(tag %in% top_tags$tag) %>%
  ggplot() +
  geom_line(aes(h, n, color = tag))
