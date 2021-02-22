
#' @export
runStudy <- function(connectionDetails = NULL,
                     connection = NULL,
                     cdmDatabaseSchema,
                     oracleTempSchema = NULL,
                     cohortDatabaseSchema,
                     cohortTablePrefix = "AESI",
                     targetCohortTable = paste0(cohortTablePrefix, "_target"),
                     targetRefTable = paste0(cohortTablePrefix, "_target_ref"),
                     subgroupCohortTable = paste0(cohortTablePrefix, "_subgroup"),
                     subgroupRefTable = paste0(cohortTablePrefix, "_subgroup_ref"),
                     outcomeCohortTable = paste0(cohortTablePrefix, "_outcome"),
                     outcomeRefTable = paste0(cohortTablePrefix, "_outcome_ref"),
                     timeAtRiskTable = paste0(cohortTablePrefix, "_time_at_risk"),
                     summaryTable = paste0(cohortTablePrefix, "_ir_summary"),
                     exportFolder,
                     databaseId,
                     databaseName = databaseId,
                     databaseDescription = "",
                     minCellCount = 5,
                     incremental = TRUE,
                     incrementalFolder = file.path(exportFolder, "RecordKeeping")) {

  start <- Sys.time()

  if (!file.exists(exportFolder)) {
    dir.create(exportFolder, recursive = TRUE)
  }

  ParallelLogger::clearLoggers()  # Ensure that any/all previous logging activities are cleared
  ParallelLogger::addDefaultFileLogger(file.path(exportFolder,
                                                 paste0(getThisPackageName(), ".txt")))
  ParallelLogger::addDefaultErrorReportLogger(file.path(exportFolder, paste0(getThisPackageName(),
                                                                             "ErrorReportR.txt")))
  ParallelLogger::addDefaultConsoleLogger()
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_FILE_LOGGER", silent = TRUE))
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_ERRORREPORT_LOGGER", silent = TRUE), add = TRUE)
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_CONSOLE_LOGGER", silent = TRUE), add = TRUE)

  # Write out the system information
  ParallelLogger::logInfo(.systemInfo())

  if (incremental) {
    if (is.null(incrementalFolder)) {
      stop("Must specify incrementalFolder when incremental = TRUE")
    }
    if (!file.exists(incrementalFolder)) {
      dir.create(incrementalFolder, recursive = TRUE)
    }
  }

  if (!is.null(getOption("andromedaTempFolder")) && !file.exists(getOption("andromedaTempFolder"))) {
    warning("andromedaTempFolder '",
            getOption("andromedaTempFolder"),
            "' not found. Attempting to create folder")
    dir.create(getOption("andromedaTempFolder"), recursive = TRUE)
  }

  if (is.null(connection)) {
    connection <- DatabaseConnector::connect(connectionDetails)
    on.exit(DatabaseConnector::disconnect(connection))
  }

  # Create the reference tables  -----------------------------------------------------------------------
  ParallelLogger::logInfo("**********************************************************")
  ParallelLogger::logInfo("  ---- Creating reference tables  ---- ")
  ParallelLogger::logInfo("**********************************************************")
  createRefTablesSql <- SqlRender::loadRenderTranslateSql("CreateRefTables.sql",
                                    packageName = getThisPackageName(),
                                    dbms = connection@dbms,
                                    oracleTempSchema = oracleTempSchema,
                                    warnOnMissingParameters = TRUE,
                                    cohort_database_schema = cohortDatabaseSchema,
                                    summary_table = summaryTable,
                                    target_ref_table = targetRefTable,
                                    subgroup_ref_table = subgroupRefTable,
                                    outcome_ref_table = outcomeRefTable,
                                    time_at_risk_table = timeAtRiskTable
                                    )
  DatabaseConnector::executeSql(connection = connection,
                                sql = createRefTablesSql,
                                progressBar = TRUE,
                                reportOverallTime = TRUE)


  # Instantiate cohorts -----------------------------------------------------------------------
  targetCohorts <- readCsv("settings/targetRef.csv")
  subgroupCohorts <- readCsv("settings/subgroupRef.csv")
  outcomeCohorts <- readCsv("settings/outcomeRef.csv")
  timeAtRisk <- readCsv("settings/timeAtRisk.csv")

  instantiatedTargetCohortIds <- c()
  if (nrow(targetCohorts) > 0) {
    ParallelLogger::logInfo("**********************************************************")
    ParallelLogger::logInfo("  ---- Creating target cohorts ---- ")
    ParallelLogger::logInfo("**********************************************************")
    instantiatedTargetCohortIds <- instantiateCohortSet(connectionDetails = connectionDetails,
                                                        connection = connection,
                                                        cdmDatabaseSchema = cdmDatabaseSchema,
                                                        oracleTempSchema = oracleTempSchema,
                                                        cohortDatabaseSchema = cohortDatabaseSchema,
                                                        cohortTable = targetCohortTable,
                                                        cohorts = targetCohorts,
                                                        cohortSqlFolder = "target",
                                                        createCohortTable = TRUE,
                                                        incremental = incremental,
                                                        incrementalFolder = incrementalFolder)

    # Create the ref table
    ParallelLogger::logInfo("Insert target reference")
    for (i in 1:nrow(targetCohorts)) {
      insertRefEntries(connection = connection,
                       sqlFile = "InsertTargetRef.sql",
                       cohortDatabaseSchema = cohortDatabaseSchema,
                       tableName = targetRefTable,
                       target_cohort_definition_id = targetCohorts$cohortId[i],
                       target_name = targetCohorts$cohortName[i])
    }
  }

  if (nrow(subgroupCohorts) > 0) {
    # In the case that the package is running in incremental mode,
    # the vector instantiatedTargetCohortIds will contain a list
    # of cohorts that were generated in this run. If any of the
    # target cohorts are re-generated, the subgroups must be
    # regenerated.
    doIncremental <- ifelse(length(instantiatedTargetCohortIds) == 0, yes = TRUE, no = FALSE)
    ParallelLogger::logInfo("**********************************************************")
    ParallelLogger::logInfo("  ---- Creating subgroup cohorts ---- ")
    ParallelLogger::logInfo("**********************************************************")
    instantiateCohortSet(connectionDetails = connectionDetails,
                         connection = connection,
                         cdmDatabaseSchema = cdmDatabaseSchema,
                         oracleTempSchema = oracleTempSchema,
                         cohortDatabaseSchema = cohortDatabaseSchema,
                         cohortTable = subgroupCohortTable,
                         cohorts = subgroupCohorts,
                         cohortSqlFolder = "subgroup",
                         createCohortTable = TRUE,
                         incremental = doIncremental,
                         incrementalFolder = incrementalFolder,
                         target_ref_table = subgroupRefTable) # NOTE: Extra param target_ref_table
  }

  if (nrow(outcomeCohorts) > 0) {
    # The outcome ref file is a little different from the others
    # so this step aims to normalize it to the other format of
    # cohortId, cohortName, fileName
    outcomeCohortsToCreate <- outcomeCohorts[,c("outcomeId", "outcomeName", "fileName")]
    names(outcomeCohortsToCreate) <- c("cohortId", "cohortName", "fileName")

    ParallelLogger::logInfo("**********************************************************")
    ParallelLogger::logInfo("  ---- Creating outcome cohorts ---- ")
    ParallelLogger::logInfo("**********************************************************")
    instantiateCohortSet(connectionDetails = connectionDetails,
                         connection = connection,
                         cdmDatabaseSchema = cdmDatabaseSchema,
                         oracleTempSchema = oracleTempSchema,
                         cohortDatabaseSchema = cohortDatabaseSchema,
                         cohortTable = outcomeCohortTable,
                         cohorts = outcomeCohortsToCreate,
                         cohortSqlFolder = "outcome",
                         createCohortTable = TRUE,
                         incremental = incremental,
                         incrementalFolder = incrementalFolder)

    # Populate ref table
    ParallelLogger::logInfo("Insert outcome reference")
    for (i in 1:nrow(outcomeCohorts)) {
      insertRefEntries(connection = connection,
                       sqlFile = "InsertOutcomeRef.sql",
                       cohortDatabaseSchema = cohortDatabaseSchema,
                       tableName = outcomeRefTable,
                       outcome_id = outcomeCohorts$outcomeId[i],
                       outcome_cohort_definition_id = outcomeCohorts$outcomeCohortDefinitionId[i],
                       outcome_name = outcomeCohorts$outcomeName[i],
                       clean_window = outcomeCohorts$cleanWindow[i],
                       primary_time_at_risk_start_offset = outcomeCohorts$primaryTimeAtRiskStartOffset[i],
                       primary_time_at_risk_start_index = outcomeCohorts$primaryTimeAtRiskStartIndex[i],
                       primary_time_at_risk_end_offset = outcomeCohorts$primaryTimeAtRiskEndOffset[i],
                       primary_time_at_risk_end_index = outcomeCohorts$primaryTimeAtRiskEndIndex[i],
                       excluded_cohort_definition_id = outcomeCohorts$excludedCohortDefinitionId[i])
    }
  }

  if (nrow(timeAtRisk) > 0) {
    ParallelLogger::logInfo("Insert time at risk reference")
    for (i in 1:nrow(timeAtRisk)) {
      insertRefEntries(connection = connection,
                       sqlFile = "InsertTimeAtRiskRef.sql",
                       cohortDatabaseSchema = cohortDatabaseSchema,
                       tableName = timeAtRiskTable,
                       time_at_risk_id = timeAtRisk$time_at_risk_id[i],
                       time_at_risk_start_offset = timeAtRisk$time_at_risk_start_offset[i],
                       time_at_risk_start_index = timeAtRisk$time_at_risk_start_index[i],
                       time_at_risk_end_offset = timeAtRisk$time_at_risk_end_offset[i],
                       time_at_risk_end_index = timeAtRisk$time_at_risk_end_index[i])
    }
  }
  
  # Run the IR analysis ------------------------------------------------------------
  ParallelLogger::logInfo("**********************************************************")
  ParallelLogger::logInfo("  ---- Computing & Export Incidence Analysis ---- ")
  ParallelLogger::logInfo("**********************************************************")
  computeAndExportIncidenceAnalysis(connection,
                                    exportFolder,
                                    oracleTempSchema, 
                                    cdmDatabaseSchema, 
                                    cohortDatabaseSchema,
                                    targetCohortTable,
                                    targetRefTable,
                                    subgroupCohortTable,
                                    subgroupRefTable,
                                    outcomeCohortTable,
                                    outcomeRefTable,
                                    timeAtRiskTable,
                                    databaseName,
                                    summaryTable,
                                    minCellCount)

  
  # Save database metadata ---------------------------------------------------------------
  ParallelLogger::logInfo("Saving database metadata")
  op <- getObservationPeriodDateRange(connection,
                                      cdmDatabaseSchema = cdmDatabaseSchema,
                                      oracleTempSchema = oracleTempSchema)
  database <- data.frame(databaseId = databaseId,
                         databaseName = databaseName,
                         description = databaseDescription,
                         vocabularyVersion = getVocabularyInfo(connection = connection,
                                                               cdmDatabaseSchema = cdmDatabaseSchema,
                                                               oracleTempSchema = oracleTempSchema),
                         minObsPeriodDate = op$minObsPeriodDate,
                         maxObsPeriodDate = op$maxObsPeriodDate,
                         isMetaAnalysis = 0)
  writeToCsv(database, file.path(exportFolder, "database.csv"))
  
  # Save package metadata ---------------------------------------------------------------
  ParallelLogger::logInfo("Saving package metadata")
  packageVersionNumber <- packageVersion(getThisPackageName())
  packageMetadata <- data.frame(packageId = getThisPackageName(),
                                packageVersion = packageVersionNumber,
                                executionDate = start,
                                params = as.character(jsonlite::toJSON(list(targetCohortTable = targetCohortTable,
                                                                            targetRefTable = targetRefTable,
                                                                            subgroupCohortTable = subgroupCohortTable,
                                                                            subgroupRefTable = subgroupRefTable,
                                                                            outcomeCohortTable = outcomeCohortTable,
                                                                            outcomeRefTable = outcomeRefTable,
                                                                            timeAtRiskTable = timeAtRiskTable,
                                                                            summaryTable = summaryTable,
                                                                            exportFolder = exportFolder,
                                                                            databaseId = databaseId,
                                                                            databaseName = databaseName,
                                                                            databaseDescription = databaseDescription,
                                                                            minCellCount = minCellCount,
                                                                            incremental = incremental,
                                                                            incrementalFolder = incrementalFolder))))
  writeToCsv(packageMetadata, file.path(exportFolder, "package.csv"))
  
  
  # Export to zip file -------------------------------------------------------------------------------
  zipName <- zipResults(exportFolder, databaseId)
  ParallelLogger::logInfo("Results are ready for sharing at:", zipName)
  
  delta <- Sys.time() - start
  ParallelLogger::logInfo(paste("Running study took",
                                round(delta, 2),
                                attr(delta, "units")))
}

computeAndExportIncidenceAnalysis <- function(connection, 
                                              exportFolder,
                                              oracleTempSchema, 
                                              cdmDatabaseSchema, 
                                              cohortDatabaseSchema,
                                              targetCohortTable,
                                              targetRefTable,
                                              subgroupCohortTable,
                                              subgroupRefTable,
                                              outcomeCohortTable,
                                              outcomeRefTable,
                                              timeAtRiskTable,
                                              databaseName,
                                              summaryTable,
                                              minCellCount) {
  # Run the analysis
  
  #1: impact of population characteristics
  targetIds <- c(104, 105, 106, 107)
  subgroupIds <- c(1, 2, 21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92)
  timeAtRiskIds <- c(5)
  outcomeIds <- c(312, 303, 323, 307, 332, 321, 301, 302, 308, 304, 324, 326, 314, 319, 310, 316, 318)
  
  
  runIncidenceAnalysisSql <- SqlRender::loadRenderTranslateSql("runIncidenceAnalysis.sql",
                                                               packageName = getThisPackageName(),
                                                               dbms = connection@dbms,
                                                               oracleTempSchema = oracleTempSchema,
                                                               warnOnMissingParameters = TRUE,
                                                               cdm_database_schema = cdmDatabaseSchema,
                                                               cohort_database_schema = cohortDatabaseSchema,
                                                               target_cohort_table = targetCohortTable,
                                                               target_ref_table = targetRefTable,
                                                               target_ids = targetIds,
                                                               subgroup_cohort_table = subgroupCohortTable,
                                                               subgroup_ref_table = subgroupRefTable,
                                                               subgroup_ids = subgroupIds,
                                                               outcome_cohort_table = outcomeCohortTable,
                                                               outcome_ref_table = outcomeRefTable,
                                                               outcome_ids = outcomeIds,
                                                               time_at_risk_table = timeAtRiskTable,
                                                               time_at_risk_ids = timeAtRiskIds,
                                                               database_name = databaseName,
                                                               summary_table = summaryTable)
  DatabaseConnector::executeSql(connection = connection,
                                sql = runIncidenceAnalysisSql,
                                progressBar = TRUE,
                                reportOverallTime = TRUE)
  
  
  
  
  #2: Impact of anchoring (and future severity of illness)
  targetIds <- c(108, 109, 110, 111, 112, 113, 114)
  subgroupIds <- c(21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92)
  timeAtRiskIds <- c(1, 2, 3, 4, 5)
  outcomeIds <- c(312, 303, 323, 307, 332, 321, 301, 302, 308, 304, 324, 326, 314, 319, 310, 316, 318)
  
  
  runIncidenceAnalysisSql <- SqlRender::loadRenderTranslateSql("runIncidenceAnalysis.sql",
                                                               packageName = getThisPackageName(),
                                                               dbms = connection@dbms,
                                                               oracleTempSchema = oracleTempSchema,
                                                               warnOnMissingParameters = TRUE,
                                                               cdm_database_schema = cdmDatabaseSchema,
                                                               cohort_database_schema = cohortDatabaseSchema,
                                                               target_cohort_table = targetCohortTable,
                                                               target_ref_table = targetRefTable,
                                                               target_ids = targetIds,
                                                               subgroup_cohort_table = subgroupCohortTable,
                                                               subgroup_ref_table = subgroupRefTable,
                                                               subgroup_ids = subgroupIds,
                                                               outcome_cohort_table = outcomeCohortTable,
                                                               outcome_ref_table = outcomeRefTable,
                                                               outcome_ids = outcomeIds,
                                                               time_at_risk_table = timeAtRiskTable,
                                                               time_at_risk_ids = timeAtRiskIds,
                                                               database_name = databaseName,
                                                               summary_table = summaryTable)
  DatabaseConnector::executeSql(connection = connection,
                                sql = runIncidenceAnalysisSql,
                                progressBar = TRUE,
                                reportOverallTime = TRUE)
  
  
  
  
  #3: Impact of seasonal trends and COVID
  targetIds <- c(104, 115, 116, 117, 118, 119, 120, 121)
  subgroupIds <- c(21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92)
  timeAtRiskIds <- c(4)
  outcomeIds <- c(312, 303, 323, 307, 332, 321, 301, 302, 308, 304, 324, 326, 314, 319, 310, 316, 318)
  
  runIncidenceAnalysisSql <- SqlRender::loadRenderTranslateSql("runIncidenceAnalysis.sql",
                                                               packageName = getThisPackageName(),
                                                               dbms = connection@dbms,
                                                               oracleTempSchema = oracleTempSchema,
                                                               warnOnMissingParameters = TRUE,
                                                               cdm_database_schema = cdmDatabaseSchema,
                                                               cohort_database_schema = cohortDatabaseSchema,
                                                               target_cohort_table = targetCohortTable,
                                                               target_ref_table = targetRefTable,
                                                               target_ids = targetIds,
                                                               subgroup_cohort_table = subgroupCohortTable,
                                                               subgroup_ref_table = subgroupRefTable,
                                                               subgroup_ids = subgroupIds,
                                                               outcome_cohort_table = outcomeCohortTable,
                                                               outcome_ref_table = outcomeRefTable,
                                                               outcome_ids = outcomeIds,
                                                               time_at_risk_table = timeAtRiskTable,
                                                               time_at_risk_ids = timeAtRiskIds,
                                                               database_name = databaseName,
                                                               summary_table = summaryTable)
  DatabaseConnector::executeSql(connection = connection,
                                sql = runIncidenceAnalysisSql,
                                progressBar = TRUE,
                                reportOverallTime = TRUE)
  
  
  
  
  #4: Impact of secular trends
  targetIds <- c(122, 123, 124)
  subgroupIds <- c(21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92)
  timeAtRiskIds <- c(5)
  outcomeIds <- c(312, 303, 323, 307, 332, 321, 301, 302, 308, 304, 324, 326, 314, 319, 310, 316, 318)
  
  runIncidenceAnalysisSql <- SqlRender::loadRenderTranslateSql("runIncidenceAnalysis.sql",
                                                               packageName = getThisPackageName(),
                                                               dbms = connection@dbms,
                                                               oracleTempSchema = oracleTempSchema,
                                                               warnOnMissingParameters = TRUE,
                                                               cdm_database_schema = cdmDatabaseSchema,
                                                               cohort_database_schema = cohortDatabaseSchema,
                                                               target_cohort_table = targetCohortTable,
                                                               target_ref_table = targetRefTable,
                                                               target_ids = targetIds,
                                                               subgroup_cohort_table = subgroupCohortTable,
                                                               subgroup_ref_table = subgroupRefTable,
                                                               subgroup_ids = subgroupIds,
                                                               outcome_cohort_table = outcomeCohortTable,
                                                               outcome_ref_table = outcomeRefTable,
                                                               outcome_ids = outcomeIds,
                                                               time_at_risk_table = timeAtRiskTable,
                                                               time_at_risk_ids = timeAtRiskIds,
                                                               database_name = databaseName,
                                                               summary_table = summaryTable)
  DatabaseConnector::executeSql(connection = connection,
                                sql = runIncidenceAnalysisSql,
                                progressBar = TRUE,
                                reportOverallTime = TRUE)
  
  
  
  #5: Impact of prior observation period
  targetIds <- c(125)
  subgroupIds <- c(21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92)
  timeAtRiskIds <- c(5)
  outcomeIds <- c(312, 303, 323, 307, 332, 321, 301, 302, 308, 304, 324, 326, 314, 319, 310, 316, 318)
  
  runIncidenceAnalysisSql <- SqlRender::loadRenderTranslateSql("runIncidenceAnalysis.sql",
                                                               packageName = getThisPackageName(),
                                                               dbms = connection@dbms,
                                                               oracleTempSchema = oracleTempSchema,
                                                               warnOnMissingParameters = TRUE,
                                                               cdm_database_schema = cdmDatabaseSchema,
                                                               cohort_database_schema = cohortDatabaseSchema,
                                                               target_cohort_table = targetCohortTable,
                                                               target_ref_table = targetRefTable,
                                                               target_ids = targetIds,
                                                               subgroup_cohort_table = subgroupCohortTable,
                                                               subgroup_ref_table = subgroupRefTable,
                                                               subgroup_ids = subgroupIds,
                                                               outcome_cohort_table = outcomeCohortTable,
                                                               outcome_ref_table = outcomeRefTable,
                                                               outcome_ids = outcomeIds,
                                                               time_at_risk_table = timeAtRiskTable,
                                                               time_at_risk_ids = timeAtRiskIds,
                                                               database_name = databaseName,
                                                               summary_table = summaryTable)
  DatabaseConnector::executeSql(connection = connection,
                                sql = runIncidenceAnalysisSql,
                                progressBar = TRUE,
                                reportOverallTime = TRUE)
  
  
  
  #6: Impact of phenotype definition and outcome clean window
  targetIds <- c(104)
  subgroupIds <- c(21, 22, 31, 32, 41, 42, 51, 52, 61, 62, 71, 72, 81, 82, 91, 92)
  timeAtRiskIds <- c(5)
  outcomeIds <- c(313, 327, 345, 328, 346, 322, 329, 347, 330, 348, 315, 331, 333, 349, 320, 334, 350, 351, 352, 335, 337, 353, 309, 338, 354, 305, 306, 355, 325, 339, 356, 340, 357, 341, 358, 359, 311, 342, 360, 343, 344, 361, 317, 362)
  
  runIncidenceAnalysisSql <- SqlRender::loadRenderTranslateSql("runIncidenceAnalysis.sql",
                                                               packageName = getThisPackageName(),
                                                               dbms = connection@dbms,
                                                               oracleTempSchema = oracleTempSchema,
                                                               warnOnMissingParameters = TRUE,
                                                               cdm_database_schema = cdmDatabaseSchema,
                                                               cohort_database_schema = cohortDatabaseSchema,
                                                               target_cohort_table = targetCohortTable,
                                                               target_ref_table = targetRefTable,
                                                               target_ids = targetIds,
                                                               subgroup_cohort_table = subgroupCohortTable,
                                                               subgroup_ref_table = subgroupRefTable,
                                                               subgroup_ids = subgroupIds,
                                                               outcome_cohort_table = outcomeCohortTable,
                                                               outcome_ref_table = outcomeRefTable,
                                                               outcome_ids = outcomeIds,
                                                               time_at_risk_table = timeAtRiskTable,
                                                               time_at_risk_ids = timeAtRiskIds,
                                                               database_name = databaseName,
                                                               summary_table = summaryTable)
  DatabaseConnector::executeSql(connection = connection,
                                sql = runIncidenceAnalysisSql,
                                progressBar = TRUE,
                                reportOverallTime = TRUE)
  
  
  
  
  # Export & Censor results
  ParallelLogger::logInfo("Exporting analysis results")
  getIncidenceAnalysisSql <- SqlRender::loadRenderTranslateSql("GetIncidenceAnalysisResults.sql",
                                                               packageName = getThisPackageName(),
                                                               dbms = connection@dbms,
                                                               oracleTempSchema = oracleTempSchema,
                                                               warnOnMissingParameters = TRUE,
                                                               cohort_database_schema = cohortDatabaseSchema,
                                                               summary_table = summaryTable)
  
  results <- DatabaseConnector::querySql(connection = connection,
                                         sql = getIncidenceAnalysisSql,
                                         snakeCaseToCamelCase = TRUE)
  
  # Censor the results
  ParallelLogger::logInfo("Censoring results")
  fieldsToCensor <- c("numPersonsWOutcomePreExclude",
                      "numPersonsWOutcome",
                      "numOutcomesPreExclude",
                      "numOutcomes")
  for (i in 1:length(fieldsToCensor)) {
    results <- enforceMinCellValue(results, fieldsToCensor[i], minCellCount)
  }
  
  writeToCsv(results, file.path(exportFolder, "incidence_analysis.csv"))
}

insertRefEntries <- function(connection, sqlFile, cohortDatabaseSchema, tableName, oracleTempSchema, ...) {
  sql <- SqlRender::loadRenderTranslateSql(sqlFile,
                                           packageName = getThisPackageName(),
                                           dbms = connection@dbms,
                                           oracleTempSchema = oracleTempSchema,
                                           warnOnMissingParameters = TRUE,
                                           cohort_database_schema = cohortDatabaseSchema,
                                           ref_table = tableName,
                                           ...)
  DatabaseConnector::executeSql(connection = connection,
                                sql = sql,
                                progressBar = FALSE,
                                reportOverallTime = FALSE)
}

zipResults <- function(exportFolder, databaseId) {
  zipName <- file.path(exportFolder, paste0("Results_", databaseId, ".zip"))
  files <- list.files(exportFolder, pattern = ".*\\.csv$")
  oldWd <- setwd(exportFolder)
  on.exit(setwd(oldWd), add = TRUE)
  DatabaseConnector::createZipFile(zipFile = zipName, files = files)
  return(zipName)
}

getVocabularyInfo <- function(connection, cdmDatabaseSchema, oracleTempSchema) {
  sql <- "SELECT vocabulary_version FROM @cdm_database_schema.vocabulary WHERE vocabulary_id = 'None';"
  sql <- SqlRender::render(sql, cdm_database_schema = cdmDatabaseSchema)
  sql <- SqlRender::translate(sql,
                              targetDialect = attr(connection, "dbms"),
                              oracleTempSchema = oracleTempSchema)
  vocabInfo <- DatabaseConnector::querySql(connection, sql)
  return(vocabInfo[[1]])
}

getObservationPeriodDateRange <- function(connection, cdmDatabaseSchema, oracleTempSchema) {
  sql <- "SELECT MIN(observation_period_start_date) min_obs_period_date, MAX(observation_period_end_date) max_obs_period_date FROM @cdm_database_schema.observation_period;"
  sql <- SqlRender::render(sql, cdm_database_schema = cdmDatabaseSchema)
  sql <- SqlRender::translate(sql,
                              targetDialect = attr(connection, "dbms"),
                              oracleTempSchema = oracleTempSchema)
  op <- DatabaseConnector::querySql(connection, sql)
  names(op) <- SqlRender::snakeCaseToCamelCase(names(op))
  return(op)
}

writeToCsv <- function(data, fileName, incremental = FALSE, ...) {
  colnames(data) <- SqlRender::camelCaseToSnakeCase(colnames(data))
  if (incremental) {
    params <- list(...)
    names(params) <- SqlRender::camelCaseToSnakeCase(names(params))
    params$data <- data
    params$fileName <- fileName
    do.call(saveIncremental, params)
  } else {
    readr::write_csv(data, fileName)
  }
}

enforceMinCellValue <- function(data, fieldName, minValues, silent = FALSE) {
  toCensor <- !is.na(data[, fieldName]) & data[, fieldName] < minValues & data[, fieldName] != 0
  if (!silent) {
    percent <- round(100 * sum(toCensor)/nrow(data), 1)
    ParallelLogger::logInfo("   censoring ",
                            sum(toCensor),
                            " values (",
                            percent,
                            "%) from ",
                            fieldName,
                            " because value below minimum")
  }
  if (length(minValues) == 1) {
    data[toCensor, fieldName] <- -minValues
  } else {
    data[toCensor, fieldName] <- -minValues[toCensor]
  }
  return(data)
}
