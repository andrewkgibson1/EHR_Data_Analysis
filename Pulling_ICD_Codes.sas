*testing;
libname lla '/data/dart/2020/ord_zakhary_202010038d/Data';

/* inclusion criterion, PVD + DM */

data metaicd9;
set DIM_RB02.ICD9(KEEP=ICD9Code ICD9SID);
length cmrb $32.;

	* PVD;
		if icd9code in: ('440.2','440.9','443.9')
		then cmrb = "PVD";

	*Diabetes;
		IF ICD9Code IN: ('250') 
		THEN cmrb = "DM";

IF cmrb="" then delete;
RUN;

data metaicd10;
set DIM_RB02.ICD10(KEEP=ICD10Code ICD10SID);
length cmrb $32.;

	* PVD;
		if icd10code in: ('I70.2','I73.8','I73.9')
		then cmrb = "PVD";

	*Diabetes;
		IF ICD10Code IN: ('E08','E09','E10','E11','E13') 
		THEN cmrb = "DM";

IF cmrb="" then delete;
RUN;

data sid;
set metaicd9 metaicd10;
run;

proc freq data=sid;
table cmrb;
run;

**************************;

* Inpatient diagnosis;
DATA Inpat_ICD / VIEW=inpat_ICD;
SET ZAK38SRC.Inpat_InpatientDiagnosis(KEEP=patientsid DischargeDateTime icd9sid icd10sid );
	WHERE DHMS(MDY(01, 01, 2012), 00, 00, 00) <= DischargeDateTime < DHMS(MDY(01, 01, 2018), 00, 00, 00) ;
	RENAME DischargeDateTime=Vdiagnosisdatetime;
RUN; *n=875,770; 

PROC SQL;
CREATE TABLE Inpat_ICD9 AS
SELECT a.*, b.ICD9Code, b.cmrb 
from Inpat_ICD AS a
inner join sid AS b
on a.icd9sid=b.icd9sid;
QUIT; *n=22,662 ;

PROC SQL;
CREATE TABLE Inpat_ICD10 AS
SELECT a.*, b.ICD10Code, b.cmrb 
from Inpat_ICD AS a
inner join sid AS b
on a.icd10sid=b.icd10sid;
QUIT; *n=16,894 ;

data Inpat_ICD_2;
set Inpat_ICD9 Inpat_ICD10;
run; *n=39,556;

* Outpatient Diagnosis;
DATA Outpat_ICD / view=outpat_ICD;
SET ZAK38SRC.Outpat_VDiagnosis(KEEP=patientsid Vdiagnosisdatetime icd9sid icd10sid);
	WHERE DHMS(MDY(01, 01, 2012), 00, 00, 00) <= Vdiagnosisdatetime < DHMS(MDY(01, 01, 2018), 00, 00, 00);
RUN; *n=21,474,658;

PROC SQL;
CREATE TABLE Outpat_ICD9 AS
SELECT a.*, b.ICD9Code, b.cmrb 
from Outpat_ICD AS a
inner join sid AS b
on a.icd9sid=b.icd9sid;
QUIT; *n=711,677;

PROC SQL;
CREATE TABLE Outpat_ICD10 AS
SELECT a.*, b.ICD10Code, b.cmrb 
from Outpat_ICD AS a
inner join sid AS b
on a.icd10sid=b.icd10sid;
QUIT; *n=410,700;

data Outpat_ICD_2;
set Outpat_ICD9 Outpat_ICD10;
run; *n=1,122,377;

* Combine data sets;
DATA combine1;
SET Inpat_ICD_2 Outpat_ICD_2;
	DiagnosisDate = datepart(Vdiagnosisdatetime);
	FORMAT DiagnosisDate MMDDYY10.;
RUN; *n=1,161,933;

PROC SQL;
CREATE TABLE test AS
SELECT R.PatientICN, L.DiagnosisDate, L.CMRB 
	FROM combine1 L
LEFT JOIN ZAK38SRC.SPatient_SPatient(KEEP=PatientSID PatientICN) R
	ON L.PatientSID=R.PatientSID;
QUIT;

data a;
set test;
if cmrb = "DM";
run; *1,070,547;

data b;
set test;
if cmrb="PVD";
run; *91,386;

* Must have both PVD and DM on same day;
proc sql;
create table test2 as
select L.*, R.PatientICN as PatientICN2, R.DiagnosisDate as DiagnosisDate2, R.cmrb as cmrb2
from a L
inner join b R
on L.PatientICN=R.PatientICN
and R.DiagnosisDate = L.DiagnosisDate ;
quit;

proc sort data=test2; by PatientICN DiagnosisDate;run; 

data test3;
set test2;
by PatientICN;
if first.PatientICN;
run;

%squeeze (test3, lla.cohort);
*n=5005;
