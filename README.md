Calculating the background rates of adverse events of special interest (AESI) for the COVID vaccines
=============

<img src="https://img.shields.io/badge/Study%20Status-Started-blue.svg" alt="Study Status: Started">

- Analytics use case(s): Characterization
- Study type: Clinical Application
- Tags: COVID-19
- Study lead: George Hripcsak, Patrick Ryan, Marc Suchard
- Study lead forums tag: **[Patrick_Ryan](https://forums.ohdsi.org/u/[Patrick_Ryan])**
- Study start date: **-**
- Study end date: **-**
- Protocol: [C19-Vaccine-Safety-AESI-Background-Rate-Protocol-2020.pdf](https://www.bestinitiative.org/wp-content/uploads/2021/01/C19-Vaccine-Safety-AESI-Background-Rate-Protocol-2020.pdf)
- Publications: **-**
- Results explorer: **-**


Calculating the background rates of adverse events of special interest (AESI) for the COVID vaccines.

## Package Requirements
- A database in [Common Data Model version 5](https://github.com/OHDSI/CommonDataModel) in one of these platforms: SQL Server, Oracle, PostgreSQL, IBM Netezza, Apache Impala, Amazon RedShift, or Microsoft APS.
- R version 4.0 or newer
- On Windows: [RTools](http://cran.r-project.org/bin/windows/Rtools/)
- [Java](http://java.com)
- Suggested: 25 GB of free disk space

See [this video](https://youtu.be/DjVgbBGK4jM) for instructions on how to set up the R environment on Windows.

## Package Usage

The following will guide you through the package setup and execution process:

- [Study package setup](STUDY-PACKAGE-SETUP.md): Guides you through the steps to install the study package.
- [Study execution](STUDY-EXECUTION.md): Guides you through the steps to execute the study package.

### FAQ
#### *I'm a data owner. How do I know if this study is right for my data?*
The study is designed to run on any OMOP CDM V5 that has populated the [PERSON](https://ohdsi.github.io/CommonDataModel/cdm531.html#person), [OBSERVATION_PERIOD](https://ohdsi.github.io/CommonDataModel/cdm531.html#observation_period), [VISIT_OCCURRENCE](https://ohdsi.github.io/CommonDataModel/cdm531.html#visit_occurrence), [CONDITION_OCCURRENCE](https://ohdsi.github.io/CommonDataModel/cdm531.html#condition_occurrence), [DRUG_EXPOSURE](https://ohdsi.github.io/CommonDataModel/cdm531.html#drug_exposure), [PROCEDURE_OCCURRENCE](https://ohdsi.github.io/CommonDataModel/cdm531.html#procedure_occurrence), [MEASUREMENT](https://ohdsi.github.io/CommonDataModel/cdm531.html#measurement), [OBSERVATION](https://ohdsi.github.io/CommonDataModel/cdm531.html#observation), [DRUG_ERA](https://ohdsi.github.io/CommonDataModel/cdm531.html#drug_era), [CONDITION_ERA](https://ohdsi.github.io/CommonDataModel/cdm531.html#condition_era), and [DEATH](https://ohdsi.github.io/CommonDataModel/cdm531.html#death) tables. If you have data in OMOP CDM V6, please reach out to the study leads and we can advise how you can adjust this to fit your database.

##### *I don't have an OBSERVATION_PERIOD Table. Why do I need to populate this?*
Sites often ask if the OBSERVATION_PERIOD table is required. The OBSERVATION_PERIOD is a table that is required for downstream analytics. It establishes, as best as we are able, a valid period of time that someone is observed in a database. Since each data asset/data partner usually has different understandings of how their patients move in and out of their system we don't have a good "rule of thumb" for how to define an observation period en mass. Essentially, it should be the time period where you are reasonably confident that any interaction with the health care system would be captured in the data. It is essential that this is populated in your CDM so we can construct person-time for the study.

##### *I've never used the ERA Tables. Why do I need to populate these?*
The OMOP CDM stores verbatim data from the source across various clinical domains, such as records for conditions, drugs, procedures, and measurements. In addition, to assist the analyst, the CDM also provides some derived tables, based on commonly used analytic procedures. For example, the [Condition_era](https://github.com/OHDSI/CommonDataModel/wiki/CONDITION_ERA) table is derived from the [Condition_occurrence](https://github.com/OHDSI/CommonDataModel/wiki/CONDITION_OCCURRENCE) table and both the [Drug_era](https://github.com/OHDSI/CommonDataModel/wiki/DRUG_ERA) and [Dose_era](https://github.com/OHDSI/CommonDataModel/wiki/DOSE_ERA) tables are derived from the [Drug_exposure](https://github.com/OHDSI/CommonDataModel/wiki/DRUG_EXPOSURE) table. An era is defined as a span of time when a patient is assumed to have a given condition or exposure to a particular active ingredient. For network research, it is essential to populate ERA tables so that downstream analytical methods/tools can utilize this information (e.g. ERA tables are required for using [FeatureExtraction](https://github.com/OHDSI/FeatureExtraction) which is the backbone to this package). It is suggested to run ERA scripts at the time of your latest ETL. If processing time is limited, you may choose to omit the Dose_era tables as these are not commonly used in network research. There are [scripts available from the OHDSI community](https://github.com/OHDSI/CommonDataModel/tree/master/CodeExcerpts/DerivedTables).

#### *Do I have to get IRB approval to run this study?*
Generally, yes. We encourage sites to file the protocol/study results with their local governance committee (e.g. Institutional Review Boards, Publication Review Committees, etc). It is at your discretion whether you choose to file a master protocol for all COVID-19 related work or if you wish to file individual protocols for each subsequent OHDSI network study. In the [Documents](https://github.com/ohdsi-studies/ScyllaCharacterization/tree/master/documents) folder, we will keep an up to date copy of the Protocol (inclusive of any iterative revisions that may arise as we test and validate the overall study package). Please use the documents in this folder in your IRB submissions. If you need additional input, please reach out to the study leads.
