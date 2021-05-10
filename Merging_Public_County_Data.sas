
libname lla '/data/dart/2020/ord_zakhary_202010038d/Data';

*adi data;
proc import datafile='/data/dart/2020/ord_zakhary_202010038d/Data/MO_2018_ADI_9 Digit Zip Code_v3.0.txt' 
out=lla.adi2018 dbms=csv replace;

proc import datafile='/data/dart/2020/ord_zakhary_202010038d/Data/MO_2015_ADI_9 Digit Zip Code_v3.0.txt' 
out=lla.adi2015 dbms=csv replace;

*year and quarter to match zip code;
data cohort;
set lla.cohort;
if 10 <= month(DiagnosisDate) <= 12 then quarter1 = 1;
else if 01 <= month(DiagnosisDate) <= 03 then quarter1 = 2;
else if 04 <= month(DiagnosisDate) <= 06 then quarter1 = 3;
else quarter1 = 4;
if quarter1 = 1 then year1 = year(DiagnosisDate) + 1;
else year1 = year(DiagnosisDate);
run;

data cohort;
set cohort;
quarter2 = put(quarter1, 1.);
year2 = put(year1, 4.);
drop quarter1 year1;
run;

* PSSG to get zips;
data lla.pssg;
set 
ZAK38SRC.PSSG_FY2012 (keep=ScrSSN zip_1 zip_2 year quarter state_1)
ZAK38SRC.PSSG_FY2013 (keep=ScrSSN zip_1 zip_2 year quarter state_1)
ZAK38SRC.PSSG_FY2014 (keep=ScrSSN zip_1 zip_2 year quarter state_1)
ZAK38SRC.PSSG_FY2015 (keep=ScrSSN zip_1 zip_2 year quarter state_1)
ZAK38SRC.PSSG_FY2016 (keep=ScrSSN zip_1 zip_2 year quarter state_1)
ZAK38SRC.PSSG_FY2017 (keep=ScrSSN zip_1 zip_2 year quarter state_1)
ZAK38SRC.PSSG_FY2018 (keep=ScrSSN zip_1 zip_2 year quarter state_1);
where STATE_1 = "MO" 
and Quarter ne "Q4-PH2" 
and ScrSSN ne "";
run;

PROC SQL;
CREATE TABLE test AS
SELECT L.*, R.PatientICN
	FROM lla.pssg L
LEFT JOIN ZAK38SRC.SPatient_SPatient(KEEP=Scrssn PatientICN) R
	ON L.Scrssn=R.Scrssn;
QUIT;

data lla.pssg;
set test;
zip = cats(zip_1,zip_2);
quarter = substr(quarter,2,1);
drop ICN State_1 zip_1 zip_2 ScrSSN;
run;

*match zip to cohort;
proc sql;
create table cohort1 as
select L.*, R.zip
from cohort L
inner join lla.pssg R
on L.PatientICN=R.PatientICN
and L.Year2=R.year 
and L.Quarter2=R.quarter;
quit;
*n=2,326;

data adi2015;
set lla.adi2015;
zip = substr(ZIPID,2,9);
run;

data adi2018;
set lla.adi2018;
zip = substr(ZIPID,2,9);
run;

*split cohort based on years for different adi datasets;
data cohort2015;
set cohort1;
where year2="2012" or year2="2013" or year2="2014" or year2="2015" or (year2="2016" and quarter2="1");
run; *1,750;

data cohort2018;
set cohort1;
where year2="2017" or (year2="2016" and quarter2 ne "1");
run; *513;

*match cohort to adi;
proc sql;
create table cohort2015z as
select L.*, R.ADI_STATERNK as adi
from cohort2015 L
inner join adi2015 R
on L.zip=R.zip;
quit;
*n=1,683;

proc sql;
create table cohort2018z as
select L.*, R.ADI_STATERNK as adi
from cohort2018 L
inner join adi2018 R
on L.zip=R.zip;
quit;
*n=380;

data cohort_adi;
set cohort2015z cohort2018z;
run;
*n=2,063;

%squeeze (cohort_adi, lla.cohort_adi);