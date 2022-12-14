if (!require("ggplot2")) install.packages("ggplot2")
if (!require("stringr")) install.packages("stringr")
if (!require("dplyr")) install.packages("dplyr")
if (!require("tidyverse")) install.packages("tidyverse")


library(tidyverse)
library(dplyr)
library(forcats)
library(MASS)

api_token <- yaml::read_yaml("secrets.yaml")[[API_TOKEN]]

# fonction de stat agregee
fonction_de_stat_agregee <- function(a, b = "moyenne", ...) {
  checkvalue <- FALSE
  for (x in c("moyenne", "variance", "ecart-type", "sd")) {
    checkvalue <- (checkvalue | b == x)
  }
  if (checkvalue == FALSE) stop("statistique non supportée")
  
  if (b == "moyenne") {
    x <- mean(a, na.rm = TRUE, ...)
  } else if (b == "ecart-type" || b == "sd") {
    x <- sd(a, na.rm = TRUE, ...)
  } else if (b == "variance") {
    x <- var(a, na.rm = TRUE, ...)
  }
  return(x)
}


# Import des donnees --------------------------------------

# j'importe les données avec read_csv2 parce que c'est un csv avec des ;
# et que read_csv attend comme separateur des ,
df <- arrow::read_parquet(
  "data/raw/individu_reg.parquet",
  col_select = c(
    "region", "aemm", "aged", "anai", "catl", "cs1", "cs2", "cs3",
    "couple", "na38", "naf08", "pnai12", "sexe", "surf", "tp",
    "trans", "ur"
  )
)

## TITRE NIVEAU 2 ==========


# combien de professions
print("Nombre de professions :")
print(summarise(df, length(unique(unlist(cs3[!is.na(cs1)])))))
print("Nombre de professions :''")
print(summarise(df, length(unique(unlist(cs3[!is.na(cs2)])))))
print("Nombre de professions :")
print(summarise(df, length(unique(unlist(cs3[!is.na(cs3)])))))

print_data_frame <- summarise(group_by(df, aged), n())
print(print_data_frame)

decennie_a_partir_annee <- function(annee) {
  return(annee - annee %% 10)
}


df %>%
  dyplr::select(aged) %>%
  ggplot(.) +
  geom_histogram(aes(x = 5 * floor(as.numeric(aged) / 5)), stat = "count")

ggplot(df[as.numeric(df$aged) > 50, c(3, 4)], aes(
  x = as.numeric(aged),
  y = ..density.., fill = factor(decennie_a_partir_annee(as.numeric(aemm)))
), alpha = 0.2) +
  geom_histogram() # position = "dodge") + scale_fill_viridis_d()


# Stat descriptives --------------------------------------


# part d'homme dans chaque cohort
ggplot(df %>%
         group_by(aged, sexe) %>%
         summarise(SH_sexe = n()) %>%
         group_by(aged) %>%
         mutate(SH_sexe = SH_sexe / sum(SH_sexe)) %>%
         filter(sexe == 1)) +
  geom_bar(aes(x = as.numeric(aged), y = SH_sexe), stat = "identity") +
  geom_point(aes(x = as.numeric(aged), y = SH_sexe),
             stat = "identity",
             color = "red"
  ) +
  coord_cartesian(c(0, 100))

# stats surf par statut
df3 <- tibble(df %>%
                group_by(couple, surf) %>%
                summarise(x = n()) %>%
                group_by(couple) %>%
                mutate(y = 100 * x / sum(x)))
ggplot(df3) +
  geom_bar(aes(x = surf, y = y, color = couple),
           stat = "identity",
           position = "dodge"
  )

# stats trans par statut
df3 <- tibble(df %>%
                group_by(couple, trans) %>%
                summarise(x = n()) %>%
                group_by(couple) %>%
                mutate(y = 100 * x / sum(x)))
p <- ggplot(df3) +
  geom_bar(aes(x = trans, y = y, color = couple),
           stat = "identity",
           position = "dodge"
  )

ggsave("p.png", p)

df[df$na38 == "ZZ", "na38"] <- NA
df[df$trans == "Z", "trans"] <- NA
df[df$tp == "Z", "tp"] <- NA
df[endsWith(df$naf08, "Z"), "naf08"] <- NA


df$sexe <- df$sexe %>%
  fct_recode(Homme = "1", Femme = "2")


fonction_de_stat_agregee(rnorm(10))
fonction_de_stat_agregee(rnorm(10), "ecart-type")
fonction_de_stat_agregee(rnorm(10), "variance")


fonction_de_stat_agregee(df %>%
                           filter(sexe == "Homme") %>%
                           mutate(aged = as.numeric(aged)) %>%
                           pull(aged))
fonction_de_stat_agregee(df %>%
                           filter(sexe == "Femme") %>%
                           mutate(aged = as.numeric(aged)) %>%
                           pull(aged))
fonction_de_stat_agregee(df %>%
                           filter(sexe == "Homme" & couple == "2") %>%
                           mutate(aged = as.numeric(aged)) %>%
                           pull(aged))
fonction_de_stat_agregee(df %>%
                           filter(sexe == "Femme" & couple == "2") %>%
                           mutate(aged = as.numeric(aged)) %>%
                           pull(aged))


# modelisation

df3 <- df %>%
  dplyr::select(surf, cs1, ur, couple, aged) %>%
  filter(surf != "Z")
df3[, 1] <- factor(df3$surf, ordered = TRUE)
df3[, "cs1"] <- factor(df3$cs1)
df3 %>%
  filter(couple == "2" & aged > 40 & aged < 60)
polr(surf ~ cs1 + factor(ur), df3)
