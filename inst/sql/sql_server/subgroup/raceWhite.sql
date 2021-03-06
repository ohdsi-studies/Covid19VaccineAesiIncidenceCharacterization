DELETE FROM @target_database_schema.@target_cohort_table where cohort_definition_id = @target_cohort_id;

/*Black*/
INSERT INTO @target_database_schema.@target_ref_table (subgroup_cohort_definition_id, subgroup_name)
VALUES(@target_cohort_id, 'Persons with race = White');

INSERT INTO @target_database_schema.@target_cohort_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT @target_cohort_id AS cohort_definition_id,
  op1.person_id AS subject_id,
  op1.observation_period_start_date AS cohort_start_date,
  op1.observation_period_end_date AS cohort_end_date
FROM @cdm_database_schema.observation_period op1
  INNER JOIN @cdm_database_schema.person p1
  ON op1.person_id = p1.person_id
WHERE p1.race_concept_id in (8527,38003614,38003615,38003616)
;


