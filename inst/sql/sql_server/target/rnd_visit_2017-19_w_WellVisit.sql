CREATE TABLE #well_visit_procs (
  concept_id bigint NOT NULL
)
;

INSERT INTO #well_visit_procs (concept_id)
select c.concept_id
  from @cdm_database_schema.CONCEPT c
  where concept_id in (441482,764211,2213220,2213221,2213222,2213225,2213226,2213227,2213228,2213229,2213231,2213235,2213236,2213237,2213238,2213243,2213244,2514516,2514517,2514518,2514519,2514520,2514521,2514522,2514523,2514524,2514525,2514526,2514527,2514528,2514529,2514556,2617225,2617226,2617236,2617237,2617238,2617239,2617240,2617241,2617420,2720510,2720511,2720580,2721063,2721064,2721067,2721068,4029705,4063398,4076661,4077490,4088016,4145334,4233655,4312230,40664424,40664425)
;


DELETE FROM @target_database_schema.@target_cohort_table where cohort_definition_id = @target_cohort_id;

insert into @target_database_schema.@target_cohort_table (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
select @target_cohort_id as cohort_definition_id, subject_id, cohort_start_date, cohort_end_date
from
	(
  select t0.subject_id, t2.visit_start_date as cohort_start_date, t2.visit_start_date as cohort_end_date 
  from
  (
    select op1.person_id as subject_id, datefromparts(2017,1,1) as cohort_start_date, datefromparts(2017,1,1) as cohort_end_date
    from @cdm_database_schema.observation_period op1
    where dateadd(dd,365,op1.observation_period_start_date) <= datefromparts(2017,1,1)
    and op1.observation_period_end_date >= datefromparts(2017,1,1)
  ) t0
  inner join
  (
  	   select distinct po1.person_id
  		  from @cdm_database_schema.procedure_occurrence po1
  		  inner join #well_visit_procs wp1
  		  on po1.procedure_concept_id = wp1.concept_id 
  		  where procedure_date >= DATEFROMPARTS(2017, 1, 1)
  		  and procedure_date < DATEFROMPARTS(2018, 1, 1)
  ) t1
  on t0.subject_id = t1.person_id
  inner join
  (
  select person_id, visit_start_date
	from
	(
	select person_id, row_number() over (partition by person_id order by newid()) as rn1, visit_start_date
		  from @cdm_database_schema.visit_occurrence
		  where visit_start_date >= DATEFROMPARTS(2017, 1, 1)
		  and visit_start_date < DATEFROMPARTS(2018, 1, 1)
	) t
	where rn1 = 1
  ) t2
  on t0.subject_id = t2.person_id
  
	union all


  select t0.subject_id, t2.visit_start_date as cohort_start_date, t2.visit_start_date as cohort_end_date 
  from
  (
    select op1.person_id as subject_id, datefromparts(2018,1,1) as cohort_start_date, datefromparts(2018,1,1) as cohort_end_date
    from @cdm_database_schema.observation_period op1
    where dateadd(dd,365,op1.observation_period_start_date) <= datefromparts(2018,1,1)
    and op1.observation_period_end_date >= datefromparts(2018,1,1)
  ) t0
  inner join
  (
  	   select distinct po1.person_id
  		  from @cdm_database_schema.procedure_occurrence po1
  		  inner join #well_visit_procs wp1
  		  on po1.procedure_concept_id = wp1.concept_id 
  		  where procedure_date >= DATEFROMPARTS(2018, 1, 1)
  		  and procedure_date < DATEFROMPARTS(2019, 1, 1)
  ) t1
  on t0.subject_id = t1.person_id
  inner join
  (
  select person_id, visit_start_date
	from
	(
	select person_id, row_number() over (partition by person_id order by newid()) as rn1, visit_start_date
		  from @cdm_database_schema.visit_occurrence
		  where visit_start_date >= DATEFROMPARTS(2018, 1, 1)
		  and visit_start_date < DATEFROMPARTS(2019, 1, 1)
	) t
	where rn1 = 1
  ) t2
  on t0.subject_id = t2.person_id 


	 union all


  select t0.subject_id, t2.visit_start_date as cohort_start_date, t2.visit_start_date as cohort_end_date 
  from
  (
    select op1.person_id as subject_id, datefromparts(2019,1,1) as cohort_start_date, datefromparts(2019,1,1) as cohort_end_date
    from @cdm_database_schema.observation_period op1
    where dateadd(dd,365,op1.observation_period_start_date) <= datefromparts(2019,1,1)
    and op1.observation_period_end_date >= datefromparts(2019,1,1)
  ) t0
  inner join
  (
  	   select distinct po1.person_id
  		  from @cdm_database_schema.procedure_occurrence po1
  		  inner join #well_visit_procs wp1
  		  on po1.procedure_concept_id = wp1.concept_id 
  		  where procedure_date >= DATEFROMPARTS(2019, 1, 1)
  		  and procedure_date < DATEFROMPARTS(2020, 1, 1)
  ) t1
  on t0.subject_id = t1.person_id
  inner join
  (
  select person_id, visit_start_date
	from
	(
	select person_id, row_number() over (partition by person_id order by newid()) as rn1, visit_start_date
		  from @cdm_database_schema.visit_occurrence
		  where visit_start_date >= DATEFROMPARTS(2019, 1, 1)
		  and visit_start_date < DATEFROMPARTS(2020, 1, 1)
	) t
	where rn1 = 1
  ) t2
  on t0.subject_id = t2.person_id  
) t3
;



TRUNCATE TABLE #well_visit_procs;
DROP TABLE #well_visit_procs;
