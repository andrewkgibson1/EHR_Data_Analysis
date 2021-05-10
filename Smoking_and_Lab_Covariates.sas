
libname lla '/data/dart/2020/ord_zakhary_202010038d/Data';

*age, gender from Spatient;
proc sql;
create table covar as
select L.*, R.BirthDateTime, R.Gender
from lla.cohort_adi L
inner join ZAK38SRC.SPatient_SPatient R
on L.PatientICN=R.PatientICN;
quit;
*n=;

data covar2;
set covar;
age = intck('year',datepart(BirthDateTime),DiagnosisDate);
drop BirthDateTime;
run;

proc sql;
create table patrace as
select L.Race, R.PatientICN
from ZAK38SRC.PatSub_PatientRace L
inner join ZAK38SRC.SPatient_SPatient R
on L.PatientSID=R.PatientSID
where L.Race ne "";
quit;

proc sort data=patrace; by PatientICN; run;

data patrace;
set patrace;
by PatientICN;
if first.PatientICN;
run;

*race from PatSub_PatientRace;
proc sql;
create table covar3 as
select L.*, R.Race
from covar2 L
inner join patrace R
on L.PatientICN=R.PatientICN;
quit; *n=2,048;

proc freq data=covar3;
table race;
run;
*74.46% white;
*22.85% black;
*02.69% other;

data covar4;
set covar3;
if race = "BLACK OR AFRICAN AMERICAN" then race = "B";
else if race = "WHITE" then race = "W";
else race = "O";
run;

/***********************  SMOKING  ************************************************************/

*current, former, never;

proc sql;
create table smoking_meta as
select a.healthfactortypesid, b.NEW_FACTOR
from DIM_RB02.healthfactortype as a
inner join lla.Smoking_crosswalk as b
on a.HealthFactorType=b.factor;
quit;

***This pulls all the health factor data....
Not sure if the VisitVistaErrorDate is right, the example I looked at had it a LOT;
****THis is a big data pull.....
May have to do this in yearly chunks...;
%macro hf_pull(year1, year2, name);
data &name;
set ZAK38SRC.HF_healthfactor (keep=patientsid healthfactortypesid HealthFactorDateTime VisitVistaErrorDate);
where &year2>=year(datepart(HealthFactorDateTime))>=&year1;
run;
%mend;

%hf_pull(1998, 2001, hf1);
%hf_pull(2002, 2007, hf2);
%hf_pull(2008, 2013, hf3);
%hf_pull(2014, 2015, hf4);
%hf_pull(2016, 2017, hf5);

*50 minutes;

proc sql;
create table smoking1 as
select a.*, b.*
from hf1 as a
inner join smoking_meta as b
on a.healthfactortypesid=b.healthfactortypesid;
quit;

proc sql;
create table smoking2 as
select a.*, b.*
from hf2 as a
inner join smoking_meta as b
on a.healthfactortypesid=b.healthfactortypesid;
quit;

proc sql;
create table smoking3 as
select a.*, b.*
from hf3 as a
inner join smoking_meta as b
on a.healthfactortypesid=b.healthfactortypesid;
quit;

proc sql;
create table smoking4 as
select a.*, b.*
from hf4 as a
inner join smoking_meta as b
on a.healthfactortypesid=b.healthfactortypesid;
quit;

proc sql;
create table smoking5 as
select a.*, b.*
from hf5 as a
inner join smoking_meta as b
on a.healthfactortypesid=b.healthfactortypesid;
quit;

data allsmok;
set smoking1 smoking2 smoking3 smoking4 smoking5;
where VisitVistaErrorDate=" ";
Format date MMDDYY10.;
date=datepart(HealthFactorDateTime);
if NEW_FACTOR="UNKNOWN" then delete;
smoke=NEW_FACTOR;
drop healthfactortypesid VisitVistaErrorDate HealthFactorDateTime NEW_FACTOR; 
run;

proc sql;
create table allsmoking as
select a.date, a.smoke, b.PatientICN
from allsmok as a
inner join ZAK38SRC.SPatient_SPatient as b
on a.patientsid=b.patientsid;
quit;

proc sort data=allsmoking;
by PatientICN date;
run; *706,676;


proc sql;
create table test as
select b.date as smokdate, b.smoke, b.PatientICN
from lla.cohort_adi as a
inner join allsmoking as b
on a.patientICN=b.patientICN
where b.date <= a.DiagnosisDate;
quit; *7,016;

proc sort data=test;
by PatientICN smokdate;
run;

data test1;
set test;
by PatientICN;
if last.PatientICN;
run; *1,441;

proc freq data=test1;
table smoke;
run;

proc sql;
create table covar5 as
select a.*, b.smoke
from covar4 as a
left join test1 as b
on a.patientICN=b.patientICN;
quit; *2,048;

data covar6;
set covar5;
if smoke = '' then smoke = 'UNKNOWN SMOKER';
run;

%squeeze (covar6, lla.cohort_cov);


/*                                                                 */
/*   May need to request DSS or now called MCA for labs for HbA1c  */
/*                                                                 */


/************************************************* Hba1c ****************************************/


data metaicd9;
set DIM_RB02.dss_FY00_Lar(KEEP=ICD9Code ICD9SID);
length cmrb $32.;

	* PVD;
		if icd9code in: ('440.2','440.9','443.9')
		then cmrb = "PVD";

	*Diabetes;
		IF ICD9Code IN: ('250') 
		THEN cmrb = "DM";

IF cmrb="" then delete;
RUN;


PROC SQL;
   CONNECT TO SQLSVR as con1
    (CURSOR_TYPE=FORWARD_ONLY DEFER=YES READBUFF=5000 INSERTBUFF=3000 UTILCONN_TRANSIENT=YES 
    Datasrc=ORD_AlAly_201403107D user='vha15\vhastlxieyan' password='{sas002}4790305746C401AB42CF48C546CA3E2503A34F1F');

   CREATE TABLE Lab00 AS 
   SELECT *
      FROM CONNECTION TO con1 (
      SELECT scrssn, res_date, dsslarno, result 
         FROM src.dss_FY00_Lar 
        where res_date>'1998-09-30' and dsslarno=17);

   DISCONNECT FROM con1;
QUIT;

PROC SQL;
   CONNECT TO SQLSVR as con1
    (CURSOR_TYPE=FORWARD_ONLY DEFER=YES READBUFF=5000 INSERTBUFF=3000 UTILCONN_TRANSIENT=YES 
    Datasrc=ORD_AlAly_201403107D user='vha15\vhastlxieyan' password='{sas002}4790305746C401AB42CF48C546CA3E2503A34F1F');

   CREATE TABLE lab AS 
   SELECT *
      FROM CONNECTION TO con1 (
      SELECT scrssn, res_date, dsslarno, result 
         FROM src.dss_Lar 
        where res_date>'1998-09-30' and dsslarno=17);

DISCONNECT FROM con1;
QUIT;

data combine;
set lab lab00;
where index(result,'0') or index(result,'1') or index(result,'2') or index(result,'3')
or index(result,'4') or index(result,'5') or index(result,'6') or index(result,'7')
or index(result,'8') or index(result,'9');
run;


data dm large small char;
set combine;
z=result+0;
if 3.5<=z<=6.4 then delete;
else if 25>z>6.4 then do; lab_DM=1;output dm; end;
else if z>=25  then output large;
else if z<3.5 and z^=. then output small;
else if z=. then do;
if index(result,'>')  then do;
q=compress(result,'>');
q=compress(q,'=');
if 25>q>6.4 then do; lab_dm=1;output dm;end;
end;
if index(result,'-') then output char;
end;

run;

data dm;
set dm;
drop dsslarno z q;
run;
proc sort data=dm out=kid_lxcl.HbA1C;
by scrssn res_date;
run;






/************ TABLE 1 ***************************************/

data cohort_cov;
set lla.cohort_cov;
run;

%include '/data/dart/2020/ord_zakhary_202010038d/Programs/table1macro.sas';
%let yourdata=cohort_cov; 												/*name of your SAS data set*/
%let output_data=trash; 														/*name of output SAS data set*/
%let formatsfolder=; 														/*location of your SAS formats*/
%let yourfolder=; 															/*location of your SAS data set*/
%let decimal_max=1; 														/*desired number of decimal points*/
%let varlist_cat = gender race smoke ; 		/*list of categorical variables*/
%let varlist_cont = age ; 								/*list of continuous variables*/
%let output_order = age gender race smoke ; 			/*output order of all UNIQUE variables*/
%let group_by=; 			/*name of stratification variable*/
%let group_by_missing=0; 		/*remove observations missing the stratification variable.*/
%Table_summary; 				/*call the macros*/


/*************  chi-square and t-tests  *************************/ 
* if n is small, use two sided fischer exact test p value;
* otherwise look at chi square p value;

proc ttest data=lla.cohort_cov;
class group ;
var age;
run;

proc freq data=lla.cohort_cov;
table group*(sex race smoke Hyperlipidemia_pre COPD_pre HF_pre MI_pre Diabetes_pre HTN_pre PAD_pre CAD_pre CAS_pre Myocarditis_pre DVT_pre PE_pre VTE_pre Cvalve_pre CKD3_pre CKD4_pre CKD5_pre CKD_pre ESRD_pre
			Hyperlipidemia_post COPD_post HF_post MI_post Diabetes_post HTN_post PAD_post CAD_post CAS_post Myocarditis_post DVT_post PE_post VTE_post Cvalve_post CKD3_post CKD4_post CKD5_post CKD_post ESRD_post
			aspirin plavix ticagrelor prasugrel insulin statin) /chisq;
run;