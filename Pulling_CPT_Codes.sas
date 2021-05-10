
* Amputation can be anytime before Dec 2017, but PVD + DM must occur together before this amputation;

/* 1. find earliest instance of PVD + DM among cohort already selected */
/* 2. see if any amputation after this date */

/** CPT  **/


libname lla '/data/dart/2020/ord_zakhary_202010038d/Data';


PROC SQL;
   CREATE TABLE WORK.metacpt AS 
   SELECT t1.cptcode, 
          t1.cptsid
      FROM DIM_RB03.CPT t1;
QUIT;

data metacpt;
set metacpt;
if cptcode in:("27880","27881","27590","27591","27884","27886") then amput=1;
if amput=. then delete;
run; *780;


DATA Outpat_CPT / VIEW=Outpat_CPT;
SET ZAK38SRC.Outpat_VProcedure(KEEP=patientsid vproceduredatetime CPTsid);
	WHERE vproceduredatetime < DHMS(MDY(01, 01, 2018), 00, 00, 00) ;
RUN; *n=875,770; 

PROC SQL;
CREATE TABLE Outpat_CPT1 AS
SELECT a.*, b.amput 
from Outpat_CPT AS a
inner join metacpt AS b
on a.cptsid=b.cptsid;
QUIT; *n=22,662 ;

DATA Inpat_CPT / VIEW=Inpat_CPT;
SET ZAK38SRC.inpat_InpatientCPTprocedure(KEEP=patientsid cptproceduredatetime CPTsid);
	WHERE CPTproceduredatetime < DHMS(MDY(01, 01, 2018), 00, 00, 00) ;
RUN; *n=875,770; 

PROC SQL;
CREATE TABLE Inpat_CPT1 AS
SELECT a.*, b.amput 
from Inpat_CPT AS a
inner join metacpt AS b
on a.cptsid=b.cptsid;
QUIT; *n=22,662 ;

data combine;
set Outpat_CPT1(in=a) Inpat_CPT1(in=b);
if a then do; AmpDate=datepart(vproceduredatetime); inout="O";end;
else do; AmpDate=datepart(CPTproceduredatetime); inout="I";end;
run;

PROC SQL;
CREATE TABLE test AS
SELECT R.PatientICN, L.AmpDate, L.amput 
	FROM combine L
LEFT JOIN ZAK38SRC.SPatient_SPatient(KEEP=PatientSID PatientICN) R
	ON L.PatientSID=R.PatientSID;
QUIT;

proc sql;
create table cohort_outcome as
select a.*, b.AmpDate, b.amput
from lla.cohort_cov as a
left join test as b
on a.patientICN=b.patientICN;
quit; *2,048;

%squeeze (cohort_outcome, lla.cohort_outcome);