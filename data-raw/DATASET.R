## code to prepare `DATASET` dataset goes here
if(!"tidyverse" %in% row.names(installed.packages())){
  install.packages("tidyverse")
}
if(!"googleway" %in% row.names(installed.packages())){
  install.packages("googleway")
}
library(tidyverse)
library(googleway)




# unidades agrícolas ------------------------------------------------------
temp <- tempfile()
download.file("https://ftp.ibge.gov.br/Censo_Agropecuario/Censo_Agropecuario_2017/Cadastro_Nacional_de_Enderecos_Fins_Estatisticos/33_RIO_DE_JANEIRO.zip",
              destfile = temp)

ua <- unz(temp, file = "33_RIO_DE_JANEIRO/3301009_CAMPOS_DOS_GOYTACAZES.csv") %>%
  read.csv2() %>%
  select("lat" = LATITUDE,
         "lng" = LONGITUDE) %>%
  mutate("nome" = NA,
         "endereco" = NA,
         "tipo" = "unidade agrícola",
         "lat" = as.numeric(lat),
         "lng" = as.numeric(lng))

# escolas -----------------------------------------------------------------


esc <- read_csv2("data-raw/escolas.csv")  %>%
  select("nome" = Escola,
         "endereco" = Endereço) %>%
  mutate("tipo" = "escola") %>%
  mutate_geocode(endereco, output = "latlona")


# mercados ----------------------------------------------------------------
set_key(Sys.getenv("GGMAP_GOOGLE_API_KEY"), api = "places")

res <- google_places("supermercados em Campos dos Goytacazes, RJ, Brasil",
                     place_type = "supermarket",
                     language = "pt-BR")
mercados <- tibble(
  "nome" = res$results$name,
  "endereco" = res$results$formatted_address,
  "lat" = res$results$geometry$location$lat,
  "lng" = res$results$geometry$location$lng)


page_token <- res$next_page_token
res <- google_places("supermercados em Campos dos Goytacazes, RJ, Brasil",
                          place_type = "supermarket",
                          language = "pt-BR", page_token = page_token)
mercados2 <- tibble(
  "nome" = res$results$name,
  "endereco" = res$results$formatted_address,
  "lat" = res$results$geometry$location$lat,
  "lng" = res$results$geometry$location$lng)
mercados <- bind_rows(mercados, mercados2) %>%
  mutate(tipo = "mercado")
rm(mercados2, res, page_token)


# feiras ------------------------------------------------------------------

feiras <- read.csv2("data-raw/feiras.CSV") %>%
  separate(lat_lng, into = c("lat","lng"), sep = ",") %>%
  mutate(lat = str_trim(lat) %>% as.numeric(),
         lng = str_trim(lng) %>% as.numeric()) %>%
  mutate(tipo = "feira livre")


# juntando tudo -----------------------------------------------------------
esc <- esc %>%
  filter(between(lon, -41.7, -41)) %>%
  rename("lng" = lon)
bd <- bind_rows(ua, esc, mercados, feiras) %>% select(-endereco, -address) %>%
  filter(!is.na(lng))
Encoding(bd$nome) <- "latin1"
Encoding(bd$tipo) <- "latin1"
bd$nome <- iconv(bd$nome, "latin1", "UTF-8")
bd$tipo <- iconv(bd$tipo, "latin1", "UTF-8")
use_data(bd, overwrite = T)
