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


