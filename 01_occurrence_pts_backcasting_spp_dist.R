# Pontos de ocorrência
# Vinicius Tonetti - vrtonetti@gmail.com


# Cleaning environment ---------------------------------------------------------

rm(list = ls())


# packages ---------------------------------------------------------------------

library(sf)
library(spocc)
library(tidyverse)
library(CoordinateCleaner)
library(lubridate)
library(rnaturalearth)
library(rnaturalearthdata)
library(taxize)
library(spatialEco)
library(writexl)
library(rgbif)
# remotes::install_github("sjevelazco/flexsdm") # make sure Rtools is updated
#library(flexsdm)
#remotes::install_github("ropensci/taxize")

# Names of species that are being considered -----------------------------------

folder_pts <- "C:/Users/vt316/OneDrive - University of Cambridge/Desktop/Vinicius/suzano/01_data/05_Occurrence points/01_Birds/Biota Sintese/final_clean-20260727T132748Z-1-001/final_clean/"

nome_spp <- list.files(folder_pts, pattern = "\\.xlsx$")

nome_spp  <- gsub("_", " ", gsub("_final_clean.xlsx", "", nome_spp))


# Folders ----------------------------------------------------------------------


input <- "C:/Users/vt316/OneDrive - University of Cambridge/Desktop/Vinicius/suzano/01_data/05_Occurrence points/01_Birds/"

shape_af <- "C:/Users/vt316/OneDrive - University of Cambridge/Desktop/Vinicius/maps/Atlantic Forest/Muylaert et al/limites_integradores_wgs84_v1_2_0/limites_integradores_wgs84_v1_2_0/ma_limite_integrador_muylaert_et_al_2018_wgs84_geodesic_v1_2_0.shp"

# Como input já é a pasta final das aves, output deve ser igual a input

output <- input

dir.create(output, recursive = TRUE, showWarnings = FALSE)

dir.create(file.path(output, "raw"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output, "raw_year"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output, "flagged"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output, "final_clean"), recursive = TRUE, showWarnings = FALSE)

gbif_dir <- file.path(output, "GBIF_download")
dir.create(gbif_dir, recursive = TRUE, showWarnings = FALSE)


# GBIF -------------------------------------------------------------------------


gbif_user  <- "eduardorigacci"
gbif_pwd   <- "Rigacci1993"
gbif_email <- "eduardorigacci@gmail.com"

Sys.setenv(
  GBIF_USER  = gbif_user,
  GBIF_PWD   = gbif_pwd,
  GBIF_EMAIL = gbif_email
)

# Conferir usuário e e-mail salvos na sessão
Sys.getenv("GBIF_USER")
Sys.getenv("GBIF_EMAIL")

# Shapefile Mata Atlantica -----------------------------------------------------


af <- sf::st_read(shape_af)

sf::st_crs(af) <- "EPSG:4326"

sf::sf_use_s2(FALSE)






