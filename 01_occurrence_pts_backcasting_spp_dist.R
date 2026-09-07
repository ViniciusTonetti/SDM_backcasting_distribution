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

sp <- nome_spp


# Folders ----------------------------------------------------------------------


input <- "C:/Users/vt316/OneDrive - University of Cambridge/Desktop/Vinicius/suzano/01_data/05_Occurrence points/01_Birds/GBIF run 2026.09.d07/"

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


# ==============================================================================
# 4.1) OBTER taxonKey DO GBIF PARA TODAS AS ESPÉCIES
# ==============================================================================

taxon_keys_file <- file.path(output, "gbif_taxon_keys.xlsx")
taxon_keys_rds  <- file.path(output, "gbif_taxon_keys.rds")

if (file.exists(taxon_keys_rds)) {
  
  cat("\nLendo taxonKeys já salvos em:\n")
  cat(taxon_keys_rds, "\n")
  
  taxon_keys <- readRDS(taxon_keys_rds)
  
} else {
  
  taxon_keys <- purrr::map_dfr(
    sp,
    function(spp) {
      
      cat("Buscando taxonKey para:", spp, "\n")
      
      bb <- tryCatch(
        rgbif::name_backbone(name = spp),
        error = function(e) NULL
      )
      
      if (is.null(bb) || is.null(bb$usageKey)) {
        return(tibble::tibble(
          name_original = spp,
          taxonKey = NA_integer_,
          gbif_name = NA_character_,
          matchType = NA_character_,
          status = NA_character_
        ))
      }
      
      tibble::tibble(
        name_original = spp,
        taxonKey = suppressWarnings(as.integer(bb$usageKey)),
        gbif_name = bb$scientificName,
        matchType = bb$matchType,
        status = bb$status
      )
    }
  )
  
  saveRDS(taxon_keys, taxon_keys_rds)
  
  writexl::write_xlsx(
    taxon_keys,
    taxon_keys_file
  )
}

taxon_keys_valid <- taxon_keys %>%
  dplyr::filter(!is.na(taxonKey)) %>%
  dplyr::distinct(taxonKey, .keep_all = TRUE)

cat("\nEspécies com taxonKey válido:", nrow(taxon_keys_valid), "de", length(sp), "\n")

print(head(taxon_keys_valid))


# ==============================================================================
# 5) SOLICITAR DOWNLOAD EM MASSA DO GBIF USANDO taxonKey
# ==============================================================================

# Se você já tiver uma chave de download boa, coloque aqui.
# Caso contrário, deixe NA para solicitar um novo download.

gbif_key_manual <- 0005848-260903145123482

if (!is.na(gbif_key_manual)) {
  
  gbif_key <- gbif_key_manual
  
} else {
  
  gbif_download <- rgbif::occ_download(
    rgbif::pred_in("taxonKey", taxon_keys_valid$taxonKey),
    rgbif::pred("hasCoordinate", TRUE),
    rgbif::pred("hasGeospatialIssue", FALSE),
    rgbif::pred_gte("year", 2025),
    rgbif::pred_lte("year", 2026),            # 7 September 2026
    rgbif::pred_gte("decimalLongitude", -59),
    rgbif::pred_lte("decimalLongitude", -34),
    rgbif::pred_gte("decimalLatitude", -34),
    rgbif::pred_lte("decimalLatitude", -2),
    format = "SIMPLE_CSV",
    user = gbif_user,
    pwd = gbif_pwd,
    email = gbif_email
  )
  
  gbif_key <- as.character(gbif_download)
  
  cat("\nChave do novo download GBIF:\n")
  print(gbif_key)
  
  writeLines(gbif_key, file.path(gbif_dir, "gbif_download_key.txt"))
}








