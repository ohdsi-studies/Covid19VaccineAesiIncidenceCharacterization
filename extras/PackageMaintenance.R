# Copyright 2021 Observational Health Data Sciences and Informatics
#
# This file is part of Covid19VaccineAesiIncidenceCharacterization19VaccineAesiIncidenceCharacterization
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Format and check code ---------------------------------------------------
OhdsiRTools::formatRFolder()
OhdsiRTools::updatePackageNameFolder(packageName = "Covid19VaccineAesiIncidenceCharacterization", recursive = T)
OhdsiRTools::checkUsagePackage("Covid19VaccineAesiIncidenceCharacterization")
OhdsiRTools::updateCopyrightYearFolder()
devtools::document()
Sys.setenv(JAVA_HOME = "")
devtools::check()

# Create manual -----------------------------------------------------------
unlink("extras/Covid19VaccineAesiIncidenceCharacterization.pdf")
shell("R CMD Rd2pdf ./ --output=extras/Covid19VaccineAesiIncidenceCharacterization.pdf")

pkgdown::build_site()

# Establish the analysis settings json
#1: impact of population characteristics
analysis1 <- list(name = "impact of population characteristics",
                  targetIds = list(104, 105, 106, 107, 126),
                  subgroupIds = list(1, 2, 21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92),
                  timeAtRiskIds = list(5),
                  outcomeIds = list(312, 303, 323, 307, 332, 321, 301, 302, 308, 305, 324, 326, 314, 319, 310, 316, 318))

#2: "Impact of anchoring (and future severity of illness)"
analysis2 <- list(name = "Impact of anchoring (and future severity of illness)",
                  targetIds = list(108, 109, 110, 111, 112, 113, 114),
                  subgroupIds = list(21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92),
                  timeAtRiskIds = list(1, 2, 3, 4, 5),
                  outcomeIds = list(312, 303, 323, 307, 332, 321, 301, 302, 308, 305, 324, 326, 314, 319, 310, 316, 318))

#3: "Impact of seasonal trends and COVID"
analysis3 <- list(name = "Impact of seasonal trends and COVID",
                  targetIds = list(104, 115, 116, 117, 118, 119, 120, 121),
                  subgroupIds = list(21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92),
                  timeAtRiskIds = list(4),
                  outcomeIds = list(312, 303, 323, 307, 332, 321, 301, 302, 308, 305, 324, 326, 314, 319, 310, 316, 318))

#4: Impact of secular trends
analysis4 <- list(name = "Impact of secular trends",
                  targetIds = list(122, 123, 124),
                  subgroupIds = list(21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92),
                  timeAtRiskIds = list(5),
                  outcomeIds = list(312, 303, 323, 307, 332, 321, 301, 302, 308, 305, 324, 326, 314, 319, 310, 316, 318))

#5: Impact of prior observation period
analysis5 <- list(name = "Impact of prior observation period",
                  targetIds = list(125),
                  subgroupIds = list(21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92),
                  timeAtRiskIds = list(5),
                  outcomeIds = list(312, 303, 323, 307, 332, 321, 301, 302, 308, 305, 324, 326, 314, 319, 310, 316, 318))

#6: Impact of phenotype definition and outcome clean window
analysis6 <- list(name = "Impact of phenotype definition and outcome clean window",
                  targetIds = list(104),
                  subgroupIds = list(21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92),
                  timeAtRiskIds = list(5),
                  outcomeIds = list(313, 327, 345, 328, 346, 363, 322, 329, 347, 330, 348, 315, 331, 333, 349, 320, 334, 350, 351, 352, 335, 337, 353, 309, 338, 354, 304, 306, 355, 325, 339, 356, 340, 357, 341, 358, 359, 311, 364, 342, 360, 343, 344, 361, 317, 362))

analysisList = list(analysisList = list(analysis1, analysis2, analysis3, analysis4, analysis5, analysis6))
analysisListJson <- RJSONIO::toJSON(analysisList, pretty = T)
analysisListFile <- "D:/git/ohdsi-studies/Covid19VaccineAesiIncidenceCharacterization/inst/settings/analysisSettings.json"
write(analysisListJson, file = analysisListFile)

# Verify the analysis settings ---------------
targetRef <- system.file("settings/targetRef.csv", package = "Covid19VaccineAesiIncidenceCharacterization", mustWork = TRUE)
subgroupRef <- system.file("settings/subgroupRef.csv", package = "Covid19VaccineAesiIncidenceCharacterization", mustWork = TRUE)
outcomeRef <- system.file("settings/outcomeRef.csv", package = "Covid19VaccineAesiIncidenceCharacterization", mustWork = TRUE)
tarRef <- system.file("settings/timeAtRisk.csv", package = "Covid19VaccineAesiIncidenceCharacterization", mustWork = TRUE)

targetCohort <- readr::read_csv(targetRef, col_types = readr::cols())
subgroupCohorts <- readr::read_csv(subgroupRef, col_types = readr::cols())
outcomeCohorts <- readr::read_csv(outcomeRef, col_types = readr::cols())
tars <- readr::read_csv(tarRef, col_types = readr::cols())

targetIds <- targetCohort$cohortId
subgroupIds <- subgroupCohorts$cohortId
outcomeIds <- outcomeCohorts$outcomeId
tarIds <- tars$time_at_risk_id

analysisListJsonFromFile <- paste(readLines(analysisListFile),collapse="\n");
analysisListFromFile <- RJSONIO::fromJSON(analysisListJsonFromFile)
compareLists <- function(x, y) {
  xCompareY <- x %in% y
  xInY <- which(xCompareY)
  return(length(x) == length(xInY))
}

for(i in 1:length(analysisListFromFile$analysisList)) {
  print(paste(i, analysisListFromFile$analysisList[[i]]$name))
  if (!(compareLists(analysisListFromFile$analysisList[[i]]$targetIds, targetIds))) {
    warning("Target ID mismatch from targetRef.csv file.")
  }
  # These are generated dynamically by runIncidenceAnalysis.sql so we can't 
  # check these at design time.
  #if (!(compareLists(analysisListFromFile$analysisList[[i]]$subgroupIds, subgroupIds))) {
  #  warning("Subgroup ID mismatch from subgroupRef.csv file.")
  #}
  if (!(compareLists(analysisListFromFile$analysisList[[i]]$outcomeIds, outcomeIds))) {
    warning("Outcome ID mismatch from outcomeRef.csv file.")
  }
  if (!(compareLists(analysisListFromFile$analysisList[[i]]$timeAtRiskIds, tarIds))) {
    warning("Time-at-risk ID mismatch from timeAtRisk.csv file.")
  }
}

# Check the warnings if any are generated to find configuration errors


# Store environment in which the study was executed -----------------------
OhdsiRTools::insertEnvironmentSnapshotInPackage("Covid19VaccineAesiIncidenceCharacterization")
OhdsiRTools::createRenvLockFile(rootPackage = "Covid19VaccineAesiIncidenceCharacterization")

# Check all files for UTF-8 Encoding and ensure there are no non-ASCII characters
OhdsiRTools::findNonAsciiStringsInFolder()

packageFiles <- list.files(path = ".", recursive = TRUE)
if (!all(utf8::utf8_valid(packageFiles))) {
  print("Found invalid UTF-8 encoded files")
}

# Create the Renv lock file
OhdsiRTools::createRenvLockFile("Covid19VaccineAesiIncidenceCharacterization")

# Validate cohort SQL file names ------------
targetCohorts <- Covid19VaccineAesiIncidenceCharacterization::readCsv("settings/targetRef.csv")
targetCohorts$cohortFolder <- "target"
subgroupCohorts <- Covid19VaccineAesiIncidenceCharacterization::readCsv("settings/subgroupRef.csv")
subgroupCohorts$cohortFolder <- "subgroup"
outcomeCohorts <- Covid19VaccineAesiIncidenceCharacterization::readCsv("settings/outcomeRef.csv")
outcomeCohorts$cohortFolder <- "outcome"
# Reformat the outcomeCohorts dataframe to match target/subgroup
outcomeCohortsReformatted <- outcomeCohorts[,c("outcomeId", "outcomeName", "fileName", "cohortFolder")]
names(outcomeCohortsReformatted) <- c("cohortId", "cohortName", "fileName", "cohortFolder") 
allCohorts <- rbind(targetCohorts, subgroupCohorts, outcomeCohortsReformatted)

# Obtain the list of SQL files in the list
packageSqlFiles <- list.files(system.file(file.path("sql/sql_server/"), package="Covid19VaccineAesiIncidenceCharacterization"), recursive = TRUE)

for (i in 1:nrow(allCohorts)) {
  # Verify that the path to the SQL file is correct and matches
  # with case sensitivity
  sqlFileName <- file.path(allCohorts$cohortFolder[i], allCohorts$fileName[i])
  fileFound <- sqlFileName %in% packageSqlFiles
  if (!fileFound) {
    warning(paste(sqlFileName, "not found in package. This is likely due to a difference in case sensitivity."))
  }
}
