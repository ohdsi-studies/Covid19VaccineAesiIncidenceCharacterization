# Please see code in extras/ProjectSetup.R to ensure
# you have installed and initialized "renv" for this
# project.
library(Covid19VaccineAesiIncidenceCharacterization)

# Specify where the temporary files (used by the Andromeda package) will be created:
andromedaTempFolder <- if (Sys.getenv("ANDROMEDA_TEMP_FOLDER") == "") "~/andromedaTemp" else Sys.getenv("ANDROMEDA_TEMP_FOLDER")
options(andromedaTempFolder = andromedaTempFolder)

# Details for connecting to the server:
dbms <- Sys.getenv("DBMS")
user <- if (Sys.getenv("DB_USER") == "") NULL else Sys.getenv("DB_USER")
password <- if (Sys.getenv("DB_PASSWORD") == "") NULL else Sys.getenv("DB_PASSWORD")
connectionString <- if (Sys.getenv("DB_CONNECTION_STRING") == "") NULL else Sys.getenv("DB_CONNECTION_STRING")
server <- Sys.getenv("DB_SERVER")
port <- Sys.getenv("DB_PORT")
extraSettings <- if (Sys.getenv("DB_EXTRA_SETTINGS") == "") NULL else Sys.getenv("DB_EXTRA_SETTINGS")

# Define a schema that can be used to emulate temp tables:
tempEmulationSchema <- NULL

if (!is.null(connectionString)) {
  connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = dbms,
                                                                  connectionString = connectionString,
                                                                  user = user,
                                                                  password = password)

} else {
  connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = dbms,
                                                                  server = server,
                                                                  user = user,
                                                                  password = password,
                                                                  port = port,
                                                                  extraSettings = extraSettings)

}

# Details specific to the database:
databaseId <- "CDM_IQVIA_GERMANY_DA_V1049"
databaseName <- "CDM_IQVIA_GERMANY_DA_V1049"
databaseDescription <- "CDM_IQVIA_GERMANY_DA_V1049"
# cdmDatabaseSchema <- "cdm"
# cohortDatabaseSchema <- "scratch_asena5_lsc"
# cohortTablePrefix <- "AESI"

# Details for connecting to the CDM and storing the results
cdmDatabaseSchema <- "CDM_IQVIA_GERMANY_DA_V1049.dbo"
cohortDatabaseSchema <- "scratch.dbo"
cohortTablePrefix <- "AS_22FEB2021_AESI_"

#  databaseId <- "CDM_OPTUM_EXTENDED_SES_v1522"
#  databaseName <- "OPTUM_EXTENDED_SES_v1522"
#  databaseDescription <- "OPTUM_EXTENDED_SES_v1522"
# 
# # Details for connecting to the CDM and storing the results
#  cdmDatabaseSchema <- "CDM_OPTUM_EXTENDED_SES_v1522.dbo"
#  cohortDatabaseSchema <- "scratch.dbo"
#  cohortTablePrefix <- "PBR_21FEB2021_AESI_OptumSES"


minCellCount <- 5

# Set the folder for holding the study output
projectRootFolder <- "D:/Covid19VaccineAesiIncidenceCharacterization/Runs"
outputFolder <- file.path(projectRootFolder, databaseId)
if (!dir.exists(outputFolder)) {
  dir.create(outputFolder, recursive = TRUE)
}
setwd(outputFolder)

# Use this to run the study. The results will be stored in a zip file called
# 'Results_<databaseId>.zip in the outputFolder.
runStudy(connectionDetails = connectionDetails,
         cdmDatabaseSchema = cdmDatabaseSchema,
         cohortDatabaseSchema = cohortDatabaseSchema,
         cohortTablePrefix = cohortTablePrefix,
         tempEmulationSchema = cohortDatabaseSchema,
         exportFolder = outputFolder,
         databaseId = databaseId,
         databaseName = databaseName,
         databaseDescription = databaseDescription,
         incremental = TRUE,
         minCellCount = minCellCount)


# For uploading the results. You should have received the key file from the study coordinator:
keyFileName <- "E:/Covid19VaccineAesiIncidenceCharacterization/study-data-site-covid19.dat"
userName <- "study-data-site-covid19"

# When finished with reviewing the diagnostics, use the next command to upload the diagnostic results
# uploadDiagnosticsResults(outputFolder, keyFileName, userName)


# When finished with reviewing the results, use the next command upload study results to OHDSI SFTP
# server: uploadStudyResults(outputFolder, keyFileName, userName)
