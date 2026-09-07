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


# ==============================================================================
# 6) VERIFICAR SE O DOWNLOAD ESTÁ PRONTO
# ==============================================================================

# Se o script parar aqui porque o download está RUNNING,
# NÃO rode a seção 5 novamente.
# Na próxima tentativa, coloque a chave salva em gbif_key_manual.


meta <- rgbif::occ_download_meta("0024379-260519110011954")

cat("\nStatus do download GBIF:\n")
print(meta$status)

cat("\nNúmero de registros encontrados pelo GBIF:\n")
print(meta$totalRecords)

if (meta$status != "SUCCEEDED") {
  stop(
    paste0(
      "O download do GBIF ainda não está pronto. ",
      "Status atual: ", meta$status, ". ",
      "Guarde esta chave e use em gbif_key_manual na próxima tentativa: ",
      gbif_key
    )
  )
}

if (is.null(meta$totalRecords) || meta$totalRecords == 0) {
  stop(
    paste0(
      "O download terminou, mas retornou 0 registros. ",
      "Isso indica problema nos filtros da consulta. Chave: ",
      gbif_key
    )
  )
}


# ==============================================================================
# 7) BAIXAR E IMPORTAR O ARQUIVO DO GBIF
# ==============================================================================

# Remover arquivos vazios/incompletos, se houver

arquivos_gbif <- list.files(gbif_dir, full.names = TRUE)

if (length(arquivos_gbif) > 0) {
  
  info_arquivos <- file.info(arquivos_gbif)
  
  arquivos_vazios <- rownames(info_arquivos)[
    !is.na(info_arquivos$size) & info_arquivos$size == 0
  ]
  
  if (length(arquivos_vazios) > 0) {
    message("Removendo arquivos vazios/incompletos do GBIF:")
    print(arquivos_vazios)
    file.remove(arquivos_vazios)
  }
}

gbif_zip <- rgbif::occ_download_get(
  key = "0005848-260903145123482",
  path = gbif_dir,
  overwrite = TRUE
)

cat("\nArquivo baixado:\n")
print(gbif_zip)

cat("\nTamanho do arquivo em bytes:\n")
print(file.info(gbif_zip)$size)

gbif_all <- rgbif::occ_download_import(gbif_zip)

cat("\nDimensão do objeto GBIF importado:\n")
print(dim(gbif_all))

cat("\nColunas do GBIF:\n")
print(colnames(gbif_all))

View(gbif_all)

unique(gbif_all$institutionCode)

# Preparar GBIF usando taxonKey.
# Não filtramos por scientificName porque o GBIF pode retornar nome com autoria,
# sinônimos ou pequenas diferenças em relação à sua planilha.

gbif_occ <- gbif_all %>%
  dplyr::transmute(
    taxonKey  = suppressWarnings(as.integer(taxonKey)),
    gbif_name = stringr::str_squish(scientificName),
    longitude = suppressWarnings(as.numeric(decimalLongitude)),
    latitude  = suppressWarnings(as.numeric(decimalLatitude)),
    year      = suppressWarnings(as.numeric(year)),
    database  = "GBIF_occ_download"
  ) %>%
  dplyr::filter(
    !is.na(taxonKey),
    taxonKey %in% taxon_keys_valid$taxonKey,
    !is.na(longitude),
    !is.na(latitude)
  ) %>%
  dplyr::left_join(
    taxon_keys_valid %>%
      dplyr::select(name_original, taxonKey),
    by = "taxonKey"
  ) %>%
  dplyr::mutate(
    name = name_original
  ) %>%
  dplyr::select(name, longitude, latitude, year, database)

cat("\nNúmero total de registros GBIF importados e filtrados para suas espécies:", nrow(gbif_occ), "\n")


# ==============================================================================
# 7.1) EXCLUIR FONTES INDESEJADAS DO GBIF
# ==============================================================================
#Excluding not vertfing data from Citzenship data
fontes_excluir_gbif <- c(
  "iNaturalist",
  "Mined from GenBank, NCBI", "NABU|naturgucker"
)

# Diagnóstico antes da exclusão
cat("\nRegistros GBIF antes da exclusão:", nrow(gbif_all), "\n")

gbif_excluidos_origem <- gbif_all %>%
  dplyr::mutate(
    institutionCode = stringr::str_squish(as.character(institutionCode))
  ) %>%
  dplyr::filter(institutionCode %in% fontes_excluir_gbif) %>%
  dplyr::count(institutionCode, sort = TRUE, name = "n_excluded")

print(gbif_excluidos_origem)

# Filtrar GBIF
gbif_all_filtrado <- gbif_all %>%
  dplyr::mutate(
    institutionCode = stringr::str_squish(as.character(institutionCode))
  ) %>%
  dplyr::filter(
    !institutionCode %in% fontes_excluir_gbif
  )

cat("\nRegistros GBIF depois da exclusão:", nrow(gbif_all_filtrado), "\n")
cat("\nRegistros removidos:", nrow(gbif_all) - nrow(gbif_all_filtrado), "\n")

gbif_occ <- gbif_all_filtrado %>%
  dplyr::transmute(
    taxonKey  = suppressWarnings(as.integer(taxonKey)),
    gbif_name = stringr::str_squish(scientificName),
    longitude = suppressWarnings(as.numeric(decimalLongitude)),
    latitude  = suppressWarnings(as.numeric(decimalLatitude)),
    year      = suppressWarnings(as.numeric(year)),
    institutionCode = stringr::str_squish(as.character(institutionCode)),
    collectionCode  = stringr::str_squish(as.character(collectionCode)),
    basisOfRecord   = stringr::str_squish(as.character(basisOfRecord)),
    datasetKey      = stringr::str_squish(as.character(datasetKey)),
    database  = "GBIF_occ_download"
  ) %>%
  dplyr::filter(
    !is.na(taxonKey),
    taxonKey %in% taxon_keys_valid$taxonKey,
    !is.na(longitude),
    !is.na(latitude)
  ) %>%
  dplyr::left_join(
    taxon_keys_valid %>%
      dplyr::select(name_original, taxonKey),
    by = "taxonKey"
  ) %>%
  dplyr::mutate(
    name = name_original
  ) %>%
  dplyr::select(
    name,
    longitude,
    latitude,
    year,
    database,
    institutionCode,
    collectionCode,
    basisOfRecord,
    datasetKey
  )



# ==============================================================================
# 8) LOOP DE LIMPEZA POR ESPÉCIE
# ==============================================================================

for (i in seq_along(sp)) {
  
  cat("\n=============================\n")
  cat("Espécie:", sp[i], "\n")
  cat("Progresso:", i, "de", length(sp), "\n")
  cat("=============================\n")
  
  spp_name <- sp[i]
  spp_file <- gsub(" ", "_", spp_name)
  
  # ---------------------------------------------------------------------------
  # Dados do GBIF já filtrados por origem
  # ---------------------------------------------------------------------------
  
  occ_data_gbif <- gbif_occ %>%
    dplyr::filter(name == spp_name) %>%
    dplyr::transmute(
      name = name,
      longitude = suppressWarnings(as.numeric(longitude)),
      latitude  = suppressWarnings(as.numeric(latitude)),
      year      = suppressWarnings(as.numeric(year)),
      database  = as.character(database),
      institutionCode = as.character(institutionCode),
      collectionCode  = as.character(collectionCode),
      basisOfRecord   = as.character(basisOfRecord),
      datasetKey      = as.character(datasetKey)
    )
  
  # ===========================================================================
  # RAW
  # ===========================================================================
  
  occ_data <- occ_data_gbif %>%
    dplyr::mutate(
      name = spp_name,
      longitude = suppressWarnings(as.numeric(longitude)),
      latitude  = suppressWarnings(as.numeric(latitude)),
      year      = suppressWarnings(as.numeric(year)),
      database  = as.character(database),
      institutionCode = as.character(institutionCode),
      collectionCode  = as.character(collectionCode),
      basisOfRecord   = as.character(basisOfRecord),
      datasetKey      = as.character(datasetKey)
    ) %>%
    dplyr::select(
      name,
      longitude,
      latitude,
      year,
      database,
      institutionCode,
      collectionCode,
      basisOfRecord,
      datasetKey
    )
  
  writexl::write_xlsx(
    occ_data,
    file.path(output, "raw", paste0(spp_file, "_raw.xlsx"))
  )
  
  # ===========================================================================
  # RAW_YEAR
  # ===========================================================================
  
  occ_data_tax_date <- occ_data %>%
    dplyr::filter(
      !is.na(year),
      year >= 2025,
      year <= 2026
    ) %>%
    dplyr::arrange(year)
  
  writexl::write_xlsx(
    occ_data_tax_date,
    file.path(output, "raw_year", paste0(spp_file, "_raw_year.xlsx"))
  )
  
  # ===========================================================================
  # REMOVER NA DE COORDENADAS
  # ===========================================================================
  
  occ_data_na <- occ_data_tax_date %>%
    tidyr::drop_na(longitude, latitude) %>%
    dplyr::mutate(name = spp_name)
  
  if (nrow(occ_data_na) == 0) {
    
    message("Sem registros válidos após filtro temporal/coordenadas para ", spp_name)
    
    writexl::write_xlsx(
      tibble::tibble(),
      file.path(output, "flagged", paste0(spp_file, "_flagged.xlsx"))
    )
    
    writexl::write_xlsx(
      tibble::tibble(),
      file.path(output, "final_clean", paste0(spp_file, "_final_clean.xlsx"))
    )
    
    next
  }
  
  # ===========================================================================
  # COORDINATECLEANER
  # ===========================================================================
  
  flags_spatial <- tryCatch({
    
    CoordinateCleaner::clean_coordinates(
      x = occ_data_na,
      species = "name",
      lon = "longitude",
      lat = "latitude",
      value = "spatialvalid",
      tests = c(
        "capitals",
        "centroids",
        "duplicates",
        "equal",
        "gbif",
        "institutions",
        "outliers",
        "seas",
        "validity",
        "zeros"
      ),
      capitals_rad = 1000,
      centroids_rad = 1000,
      centroids_detail = "provinces",
      inst_rad = 500,
      outliers_method = "quantile",
      outliers_mtp = 5
    )
    
  }, error = function(e) {
    
    message("Erro no CoordinateCleaner para ", spp_name, ": ", e$message)
    
    occ_data_na %>%
      dplyr::mutate(.summary = FALSE)
  })
  
  if (!".summary" %in% colnames(flags_spatial)) {
    flags_spatial <- flags_spatial %>%
      dplyr::mutate(.summary = TRUE)
  }
  
  # ===========================================================================
  # FLAGGED
  # ===========================================================================
  
  occ_flagged_i <- flags_spatial %>%
    dplyr::filter(.summary == FALSE)
  
  writexl::write_xlsx(
    occ_flagged_i,
    file.path(output, "flagged", paste0(spp_file, "_flagged.xlsx"))
  )
  
  # ===========================================================================
  # CLEAN APÓS COORDINATECLEANER
  # ===========================================================================
  
  occ_data_tax_date_spa <- flags_spatial %>%
    dplyr::filter(.summary == TRUE) %>%
    dplyr::select(
      name,
      longitude,
      latitude,
      year,
      database,
      institutionCode,
      collectionCode,
      basisOfRecord,
      datasetKey
    )
  
  if (nrow(occ_data_tax_date_spa) == 0) {
    
    message("Sem registros após CoordinateCleaner para ", spp_name)
    
    writexl::write_xlsx(
      tibble::tibble(),
      file.path(output, "final_clean", paste0(spp_file, "_final_clean.xlsx"))
    )
    
    next
  }
  
  # ===========================================================================
  # FILTRO PELO POLÍGONO DA MATA ATLÂNTICA
  # ===========================================================================
  
  occ_sf <- occ_data_tax_date_spa %>%
    dplyr::mutate(
      x = longitude,
      y = latitude
    ) %>%
    sf::st_as_sf(coords = c("x", "y"), crs = 4326, remove = FALSE)
  
  inside_af <- sf::st_intersects(occ_sf, af, sparse = FALSE)
  
  occ_data_tax_date_spa_lim <- occ_sf %>%
    dplyr::mutate(lim = inside_af[, 1]) %>%
    dplyr::filter(lim == TRUE) %>%
    dplyr::select(-lim) %>%
    sf::st_drop_geometry() %>%
    dplyr::select(
      name,
      longitude,
      latitude,
      year,
      database,
      institutionCode,
      collectionCode,
      basisOfRecord,
      datasetKey
    ) %>%
    dplyr::mutate(name = spp_name)
  
  if (nrow(occ_data_tax_date_spa_lim) == 0) {
    
    message("Sem registros dentro do polígono final para ", spp_name)
    
    writexl::write_xlsx(
      tibble::tibble(),
      file.path(output, "final_clean", paste0(spp_file, "_final_clean.xlsx"))
    )
    
    next
  }
  
  writexl::write_xlsx(
    occ_data_tax_date_spa_lim,
    file.path(output, "final_clean", paste0(spp_file, "_final_clean.xlsx"))
  )
}

cat("\nProcessamento finalizado.\n")



