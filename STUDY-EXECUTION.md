Executing the study package
===========================================================================================

**NOTE**: This guide assumes you have performed the steps in the [study package setup guide](STUDY-PACKAGE-SETUP.md). 

This guide will take you through the process of running the study to produce cohort diagnostics and the characterization results. 

## How to Run the Study
1. In `R`, you will build an `.Renviron` file. An `.Renviron` is an R environment file that sets variables you will be using in your code. It is encouraged to store these inside your environment so that you can protect sensitive information. Below are brief instructions on how to do this:

````
# The code below makes use of R environment variables (denoted by "Sys.getenv(<setting>)") to 
# allow for protection of sensitive information. If you'd like to use R environment variables stored
# in an external file, this can be done by creating an .Renviron file in the root of the folder
# where you have cloned this code. For more information on setting environment variables please refer to: 
# https://stat.ethz.ch/R-manual/R-devel/library/base/html/readRenviron.html
#
# Below is an example .Renviron file's contents: (please remove)
# the "#" below as these too are interprted as comments in the .Renviron file:
#
#    DBMS = "postgresql"
#    DB_SERVER = "database.server.com"
#    DB_PORT = 5432
#    DB_USER = "database_user_name_goes_here"
#    DB_PASSWORD = "your_secret_password"
#    DB_EXTRA_SETTINGS = "extra settings such as SSL connection"
#    ANDROMEDA_TEMP_FOLDER = "E:/andromeda"
#
# The following describes the settings
#    DBMS, DB_SERVER, DB_PORT, DB_USER, DB_PASSWORD, DB_EXTRA_SETTINGS := These are the details used to connect
#    to your database server. For more information on how these are set, please refer to:
#    http://ohdsi.github.io/DatabaseConnector/
#
#    ANDROMEDA_TEMP_FOLDER = A directory where temporary files used by the Andromeda package are stored while running.
#
# Once you have established an .Renviron file, you must restart your R session for R to pick up these new
# variables. 
````

2. Now you have set-up your environment, you can use the following `R` script to load in your library and configure your environment connection details:

```
library(Covid19VaccineAesiIncidenceCharacterization)

# Optional: specify where the temporary files (used by the Andromeda package) will be created:
andromedaTempFolder <- if (Sys.getenv("ANDROMEDA_TEMP_FOLDER") == "") "~/andromedaTemp" else Sys.getenv("ANDROMEDA_TEMP_FOLDER")
options(andromedaTempFolder = andromedaTempFolder)

# Details for connecting to the server:
dbms = Sys.getenv("DBMS")
user <- if (Sys.getenv("DB_USER") == "") NULL else Sys.getenv("DB_USER")
password <- if (Sys.getenv("DB_PASSWORD") == "") NULL else Sys.getenv("DB_PASSWORD")
connectionString <- if (Sys.getenv("DB_CONNECTION_STRING") == "") NULL else Sys.getenv("DB_CONNECTION_STRING")
server = Sys.getenv("DB_SERVER")
port = Sys.getenv("DB_PORT")
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
                                                                  port = port)
  
}

````

3. Next you will need to specify the database ID, name and description for your CDM as shown below. This information is used in the Shiny results viewer to identify your database. In addition, you will need to specify the database schema that holds your CDM information and a schema that can be used to write results. The user account set in the step above will need read-only access to the `cdmDatabaseSchema` and the ability to create tables & insert data into the `cohortDatabaseSchema`.

Additionally, the `minCellCount` variable below is used to censor any statics that are below the value specified which by default is 5.

````
# Details specific to the database:
databaseId <- "SIDIAP"
databaseName <- "Information System for Research in Primary Care (SIDIAP)"
databaseDescription <- "The Information System for Research in Primary Care (SIDIAP; www.sidiap.org) is a primary care records database that covers approximately 7 million people, equivalent to an 80% of the population of Catalonia, North-East Spain. Healthcare is universal and tax-payer funded in the region, and primary care physicians are gatekeepers for all care and responsible for repeat prescriptions."

# Details for connecting to the CDM and storing the results
cdmDatabaseSchema <- "cdm_schema"
cohortDatabaseSchema <- "scratch_writable_schema"
cohortTablePrefix <- "AESI_"
minCellCount <- 5

````

4. Set the file location where you will hold the study results. Please note that the `projectRootFolder` must match the location specified used in the [study package setup guide](STUDY-PACKAGE-SETUP.md). The additional variables below the `setwd(outputFolder)` should be left.

````
# Set the folder for holding the study output
projectRootFolder <- "E:/Covid19VaccineAesiIncidenceCharacterization"
outputFolder <- file.path(projectRootFolder, databaseId)
if (!dir.exists(outputFolder)) {
  dir.create(outputFolder)
}
setwd(outputFolder)
````

5. You can now run the package. This step is designed to take advantage of incremental building. This means if the job fails, the R package will start back up where it left off. Package runtime will vary based on your infrastructure.

In your `R` script, you will use the following code:
````
# Use this to run the study. The results will be stored in a zip file called
# 'Results_<databaseId>.zip in the outputFolder.
runStudy(connectionDetails = connectionDetails,
         cdmDatabaseSchema = cdmDatabaseSchema,
         cohortDatabaseSchema = cohortDatabaseSchema,
         cohortTablePrefix = cohortTablePrefix,
         tempEmulationSchema = tempEmulationSchema,
         exportFolder = outputFolder,
         databaseId = databaseId,
         databaseName = databaseName,
         databaseDescription = databaseDescription,
         incremental = TRUE,
         minCellCount = minCellCount)
````

6. If the study code runs to completion, your `outputFolder` will have the following contents:
- RecordKeeping = a folder designed to store incremental information such that if the study code dies, it will restart where it left off
- database.csv: Contains metadata information that you supplied as part of running the package to identify the database across the OHDSI network. Additionally, the vocabulary version and min/max observation_period_start/end dates used in your CDM are included.
- _**incidence_analysis.csv**_: Contains the running the full study. The fields `num_persons_w_outcome_pre_exclude`, `numPersonsWOutcome`, `numOutcomesPreExclude`, and `numOutcomes` contain the number of people amongst the target/subgroup population that experience the outcome in either the time-at-risk or prior to entering the target cohort.
- package.csv: Contains metadata information that you supplied as part of running the package. Specifically it records the package name & version used during the execution, the date & time the package started and a list of the parameters used when executing the package (without any of the database connection details).

Those files noted in **_bold italics_** above should be reviewed for sensitive information for your site. The package will censor values based on the `minCellCount` parameter specified when calling the `runStudy` function. Censored values will be represented with a negative to show it has been censored. 

As a data owner, you will want to inspect these files for adherence to the `minCellCount` you input. You may find that only some files are generated. If this happens, please reach out to the study leads to debug. 

7. To utilize the `OhdsiSharing` library to connect and upload results to the OHDSI STFP server, you will need a site key. You may reach out to the study leads to get a key file. You will store this key file in a place that is retrievable by your `R`/`RStudio` environment (e.g. on your desktop if local `R` or uploaded to a folder in the cloud for `RServer`)

Once you have checked results, you can use the following code to send:
````
# For uploading the results. You should have received the key file from the study coordinator:
keyFileName <- "E:/Covid19VaccineAesiIncidenceCharacterization/study-data-site-covid19.dat"
userName <- "study-data-site-covid19"

# When finished with reviewing the diagnostics, use the next command
# to upload the diagnostic results
uploadDiagnosticsResults(outputFolder, keyFileName, userName)


# When finished with reviewing the results, use the next command
# upload study results to OHDSI SFTP server:
uploadStudyResults(outputFolder, keyFileName, userName)
````

Please send an email to [Anthony Sena](mailto:asena5@its.jnj.com) to notify you have dropped results in the folder.
