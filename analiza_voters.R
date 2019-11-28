library(tidyverse)
library(lubridate)
library(patchwork)
library(urltools)
library(igraph)

theme_set(theme_minimal())

reasons <- tribble(~reason, ~reason_name,
                   1, "duplikat",
                   2, "spam",
                   3, "informacja nieprawdziwa",
                   4, "treść nieodpowiednia",
                   5, "nie nadaje się")


znaleziska <- src_sqlite("wykop_hits_2019_11.sqlite") %>% tbl("wykop_hits") %>% collect()
upvoters <- src_sqlite("wykop_hits_2019_11.sqlite") %>% tbl("upvoters") %>% collect()
downvoters <- src_sqlite("wykop_hits_2019_11.sqlite") %>% tbl("downvoters") %>% collect() %>%
  rename(downvoter = upvoter)


wykop_hits <- znaleziska %>%
  mutate(date = ymd_hms(date)) %>%
  filter(as_date(date) != today()) %>%
  mutate(m = month(date),
         d = day(date),
         wd = wday(date, week_start = 1, label = TRUE),
         h = hour(date)) %>%
  mutate(title = str_replace_all(title, "&quot;", "\""),
         desc = str_replace_all(desc, "&quot;", "\"")) %>%
  mutate(domain = domain(url) %>% str_remove_all("^www.")) %>%
  mutate(domain = if_else(domain == "youtu.be", "youtube.com", domain))


upvoters %>% distinct(id) %>% nrow()
downvoters %>% distinct(id) %>% nrow()


# ROZKŁAD CZASOWY -------------------------------------------------------

# ile dni prezentujemy na wykresie?
N_DNI <- 2

# DOWNVOTERS

votes_density_down_data <- znaleziska %>%
  select(id, author, wykop_date = date) %>%
  inner_join(downvoters %>%
               rename(upvote_date = date),
             by = "id") %>%
  mutate(wykop_date = ymd_hms(wykop_date),
         upvote_date = ymd_hms(upvote_date)) %>%
  mutate(date_diff = as.numeric(upvote_date - wykop_date, "mins")) %>%
  filter(date_diff <= 60*24*N_DNI)  # tylko pierwsze dwa dni

votes_density_down <- votes_density_down_data %>%
  ggplot() +
  geom_density(aes(date_diff, color = as.factor(id)),
               show.legend = FALSE, alpha = 0.01) +
  scale_x_log10() +
  labs(title = "Rozkład czasowy downvoters",
       x = "Minuty od dodania znaleziska")


votes_count_down_data <- znaleziska %>%
  select(id, author, wykop_date = date) %>%
  inner_join(downvoters %>%
               rename(vote_date = date),
             by = "id") %>%
  mutate(wykop_date = ymd_hms(wykop_date),
         vote_date = ymd_hms(vote_date)) %>%
  mutate(date_diff = round(as.numeric(vote_date - wykop_date, "hours"))) %>%
  filter(date_diff <= 24*N_DNI) %>% # tylko pierwsze dwa dni
  count(date_diff)

votes_count_down <- votes_count_down_data %>%
  ggplot() +
  geom_col(aes(date_diff, n, fill = n), color = "gray", size = 0.8, show.legend = FALSE) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1) +
  labs(title = "Rozkład czasowy downvoters",
       x = "Godziny od dodania znaleziska",
       y = "Łączna liczba downvoters\nna wszystkich znaleziskach")



# UPVOTERS

votes_density_up_data <- znaleziska %>%
  select(id, author, wykop_date = date) %>%
  inner_join(upvoters %>%
               rename(vote_date = date),
             by = "id") %>%
  mutate(wykop_date = ymd_hms(wykop_date),
         vote_date = ymd_hms(vote_date)) %>%
  mutate(date_diff = as.numeric(vote_date - wykop_date, "mins")) %>%
  filter(date_diff <= 60*24*N_DNI) # tylko pierwsze dwa dni

votes_density_up <- votes_density_up_data %>%
  ggplot() +
  geom_density(aes(date_diff, color = as.factor(id)),
               show.legend = FALSE, alpha = 0.01) +
  scale_x_log10() +
  labs(title = "Rozkład czasowy upvoters",
       x = "Minuty od dodania znaleziska")


votes_count_up_data <- znaleziska %>%
  select(id, author, wykop_date = date) %>%
  inner_join(upvoters %>%
               rename(vote_date = date),
             by = "id") %>%
  mutate(wykop_date = ymd_hms(wykop_date),
         vote_date = ymd_hms(vote_date)) %>%
  mutate(date_diff = round(as.numeric(vote_date - wykop_date, "hours"))) %>%
  filter(date_diff <= 24*N_DNI) %>% # tylko pierwsze dwa dni
  count(date_diff)

votes_count_up <- votes_count_up_data %>%
  ggplot() +
  geom_col(aes(date_diff, n, fill = n),
           color = "gray", size = 0.8, show.legend = FALSE) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1) +
  labs(title = "Rozkład czasowy upvoters",
       x = "Godziny od dodania znaleziska",
       y = "Łączna liczba upvoters\nna wszystkich znaleziskach")


# wykresy

votes_count_up / votes_count_down


votes_density_up / votes_density_down






# PRZYCZYNY ZAKOPÓW -----------------------------------------------------

downvoters %>%
  count(id, reason) %>%
  group_by(id) %>%
  mutate(p = 100*n/sum(n)) %>%
  ungroup() %>%
  left_join(reasons, by = "reason") %>%
  ggplot() +
  geom_boxplot(aes(reason_name, p, group = reason_name, fill = reason_name),
               show.legend = FALSE) +
  labs(title = "Przyczyny zakopów", x = "", "Procent zakopów")


# top zakopywaczy wg przyczyny
downvoters_reason <- downvoters %>% count(downvoter, reason) %>% left_join(reasons, by = "reason")

downvoters_reason %>%
  group_by(reason_name) %>%
  top_n(10, n) %>%
  ungroup() %>%
  ggplot() +
  geom_col(aes(downvoter, n, fill = reason_name), show.legend = FALSE) +
  facet_wrap(~reason_name, scales = "free", ncol = 5) +
  coord_flip() +
  labs(title = "Zakopujący według przyczyny",
       x = "", y ="Liczba zakopów")



# UPVOTES vs DOWNVOTES --------------------------------------------------

votes_df <- bind_rows(upvoters %>% count(id) %>% mutate(type = "upvote"),
                      downvoters %>% count(id) %>% mutate(type = "downvote")) %>%
  spread(type, n, fill = 0) %>%
  mutate(up_proc = 100*upvote/(upvote + downvote),
         down_proc = 100*downvote/(upvote + downvote))


# jakie domeny wykopują i zakopują?
upvoters_domain <- upvoters %>%
  select(id, upvoter) %>%
  left_join(wykop_hits %>% select(id, domain),
            by = "id") %>%
  count(upvoter, domain, sort = TRUE) %>%
  left_join(upvoters %>%
              count(upvoter) %>%
              set_names(c("upvoter", "n_votes")),
            by = "upvoter") %>%
  mutate(p = 100*n/n_votes)

downvoters_domain <- downvoters %>%
  select(id, downvoter) %>%
  left_join(wykop_hits %>% select(id, domain),
            by = "id") %>%
  count(downvoter, domain, sort = TRUE) %>%
  left_join(downvoters %>%
              count(downvoter) %>%
              set_names(c("downvoter", "n_votes")),
            by = "downvoter") %>%
  mutate(p = 100*n/n_votes)


# najbardziej zakopywane domeny
downvoters_domain %>%
  group_by(domain) %>%
  summarise(n = sum(n)) %>%
  ungroup() %>%
  mutate(p = 100*n/nrow(downvoters)) %>%
  top_n(30, p) %>%
  mutate(domain = fct_reorder(domain, p)) %>%
  ggplot() +
  geom_col(aes(domain, p, fill = p), show.legend = FALSE, color = "gray") +
  coord_flip() +
  scale_fill_distiller(palette = "Reds", direction = 1) +
  labs(title = "Najczęściej zakopywane domeny",
       x = "", y = "Procent wszystkich zakopów")



# najbardziej wykopywane domeny
upvoters_domain %>%
  group_by(domain) %>%
  summarise(n = sum(n)) %>%
  ungroup() %>%
  mutate(p = 100*n/nrow(upvoters)) %>%
  top_n(30, p) %>%
  mutate(domain = fct_reorder(domain, p)) %>%
  ggplot() +
  geom_col(aes(domain, p, fill = p), show.legend = FALSE, color = "gray") +
  coord_flip() +
  scale_fill_distiller(palette = "Greens", direction = 1) +
  labs(title = "Najczęściej wykopywane domeny",
       x = "", y = "Procent wszystkich wykopów")





downvoters_domain %>%
  filter(n_votes > 1) %>%
  filter(p >= 75) %>%
  ggplot() +
  geom_tile(aes(domain, downvoter, fill = p)) +
  scale_fill_distiller(palette = "Reds", direction = 1) +
  labs(title = "Kto zakopuje jakie domeny?",
       x = "", y = "",
       fill = "Procent zakopów użytkownika") +
  theme(legend.position = "bottom")



upvoters_domain %>%
  filter(n_votes > 1) %>%
  filter(p >= 75) %>%
  ggplot() +
  geom_tile(aes(domain, upvoter, fill = p)) +
  scale_fill_distiller(palette = "Greens", direction = 1) +
  labs(title = "Kto wykopuje jakie domeny?",
       x = "", y = "",
       fill = "Procent wykopów użytkownika") +
  theme(legend.position = "bottom")




# KTO KOMU KOPIE? -------------------------------------------------------

wykop_voters <- bind_rows(znaleziska %>%
                            select(id, author) %>%
                            inner_join(upvoters %>% select(id, voter=upvoter),
                                       by = "id") %>%
                            count(author, voter) %>%
                            mutate(type = "up"),
                          znaleziska %>%
                            select(id, author) %>%
                            inner_join(downvoters %>% select(id, voter=downvoter),
                                       by = "id") %>%
                            count(author, voter) %>%
                            mutate(type = "down"))


znaleziska_author <- count(znaleziska, author)

wykop_voters_up <- wykop_voters %>%
  filter(type == "up") %>%
  select(from = author,
         to = voter,
         weigth = n)

wykop_voters_down <- wykop_voters %>%
  filter(type == "down") %>%
  select(from = author,
         to = voter,
         weigth = n)


# kto wykopał komu co najmnie 75% jego znalezisk?
wykop_voters_up %>%
  filter(weigth > 1) %>%
  inner_join(znaleziska_author, by = c("from" = "author")) %>%
  mutate(p = 100*weigth/n) %>%
  filter(p > 75) %>%
  ggplot() +
  geom_point(aes(from, to, color = p), size = 2) +
  scale_color_distiller(palette = "YlOrRd", direction = 1) +
  labs(title = "Kto wykopuje komu?",
       x = "Czyje znalezisko?", y = "Kto wykopał?",
       color = "Ile procent znalezisk zakopane?") +
  theme(legend.position = "bottom")


# kto zakopał komu co najmniej połowę znalezisk?
wykop_voters_down %>%
  filter(weigth > 1) %>%
  inner_join(znaleziska_author, by = c("from" = "author")) %>%
  mutate(p = 100*weigth/n) %>%
  filter(p > 50) %>%
  ggplot() +
  geom_tile(aes(from, to, fill = p), color = "gray", size = 0.8) +
  scale_fill_distiller(palette = "YlOrRd", direction = 1) +
  labs(title = "Kto zakopuje komu?",
       x = "Czyje znalezisko?", y = "Kto zakopał?",
       fill = "Ile procent znalezisk zakopane?") +
  theme(legend.position = "bottom")






# przy jakim najmniejszym N dodstaniemy max 5 tys węzłów?
N_NODES <- 5000

n_nodes_up <- wykop_voters_up %>%
  count(weigth) %>%
  arrange(desc(weigth)) %>%
  mutate(p = cumsum(n)) %>%
  filter(p <= N_NODES) %>%
  filter(weigth == min(weigth)) %>%
  pull(weigth)

n_nodes_down <- wykop_voters_down %>%
  count(weigth) %>%
  arrange(desc(weigth)) %>%
  mutate(p = cumsum(n)) %>%
  filter(p <= N_NODES) %>%
  filter(weigth == min(weigth)) %>%
  pull(weigth)

up_graph <- graph_from_data_frame(wykop_voters_up %>% filter(weigth >= n_nodes_up))

down_graph <- graph_from_data_frame(wykop_voters_down %>% filter(weigth >= n_nodes_down))

up_layout <- layout_nicely(up_graph)
down_layout <- layout_nicely(down_graph)

plot(up_graph,
     layout = up_layout,
     vertex.size = 3,
     vertex.label.color = "gray50",
     vertex.label.cex = 1,
     edge.arrow.size = 0.3)

plot(down_graph,
     layout = down_layout,
     vertex.size = 3,
     vertex.label.color = "gray50",
     vertex.label.cex = 1,
     edge.arrow.size = 0.3)


centr_degree(up_graph, mode = "total")$centralization
centr_clo(up_graph, mode = "total")$centralization
centr_eigen(up_graph, directed = FALSE)$centralization


centr_degree(down_graph, mode = "total")$centralization
centr_clo(down_graph, mode = "total")$centralization
centr_eigen(down_graph, directed = FALSE)$centralization

# stopień węzła

# Stopień Węzła lub stopień koncentracji opisuje, jak bardzo “centralny” jest węzeł sieci, czyli ile ma wchodzących i wychodzących krawędzi, albo inaczej mówiąc – ile innych węzłów jest z nim bezpośrednio połączonych (za pośrednictwem jednej krawędzi)



graph_degree <- function(g, n = 10) {
  degree(g, mode = "total") %>%
    data.frame() %>%
    rownames_to_column() %>%
    set_names(c("node", "degree")) %>%
    as_tibble() %>%
    top_n(n, degree) %>%
    filter(degree != min(degree)) %>%
    arrange(desc(degree))
}

graph_degree(up_graph)

graph_degree(down_graph)

# bliskość węzła

# Bliskość węzła opisuje jego odległość do wszystkich innych węzłów. Węzeł o najwyższej bliskości jest bardziej centralny i może rozprzestrzeniać informacje na wiele innych węzłów.

graph_closeness <- function(g, n = 10) {

  closeness(g, mode = "total") %>%
    data.frame() %>%
    rownames_to_column() %>%
    set_names(c("node", "closeness")) %>%
    as_tibble() %>%
    top_n(n, closeness) %>%
    filter(closeness != min(closeness)) %>%
    arrange(desc(closeness))
}



graph_closeness(up_graph)

graph_closeness(down_graph)

# wykrywanie klik

up_clwt <- cluster_walktrap(up_graph)

plot(up_clwt,
     up_graph,
     layout = up_layout,
     vertex.label = NA,
     vertex.size = 1,
     vertex.frame.color = "gray",
     edge = NA)


down_clwt <- cluster_walktrap(down_graph)

plot(down_clwt,
     down_graph,
     layout = down_layout,
     vertex.size = 3,
     vertex.label.color = "darkgray",
     vertex.label.cex = 1,
     edge = NA)

