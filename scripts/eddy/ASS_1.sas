libname eddy "/home/u64020665";

proc contents data=eddy.alz_wide; run;

data eddy.bprs_long;
    set eddy.alz_wide;
    array bprs_arr[7] BPRS0-BPRS6;
    do time = 0 to 6;
        BPRS = bprs_arr[time+1];

        /* Keep relevant baseline covariates */
        keep TRIAL PATID SEX AGE EDU BMI INKOMEN JOB ADL WZC
             CDRSB0 ABPET0 TAUPET0 TIME BPRS;

        output;
    end;
run;

proc contents data=eddy.bprs_long; run;
proc print data=eddy.bprs_long(obs=10); run;

/* MISSINGNESS */
proc means data=eddy.alz_wide n nmiss;
    var SEX AGE EDU BMI INKOMEN JOB ADL WZC CDRSB0 ABPET0 TAUPET0;
    title "Missing and Non-Missing Counts for Baseline Covariates";
run;

/* EXPLORATION */
proc means data=eddy.bprs_long n mean stddev;
    class time;
    var bprs;
run;

proc means data=eddy.bprs_long noprint;
    class time;
    var bprs;
    output out=eddy.mean_by_time mean=mean stddev=sd n=n;
run;

data eddy.mean_by_time;
    set eddy.mean_by_time(where=(_type_>0));
    se  = sd / sqrt(n);
    lcl = mean - 1.96*se;
    ucl = mean + 1.96*se;
run;

proc sgplot data=eddy.mean_by_time;
    band x=time lower=lcl upper=ucl / transparency=0.7;
    series x=time y=mean / markers;
    xaxis label="Year since diagnosis";
    yaxis label="BPRS (mean ± 95% CI)";
    title "Mean BPRS over Time";
run;

/*Continuous variables*/
proc means data=eddy.alz_wide n mean std min max;
    var AGE BMI INKOMEN ADL BPRS0 CDRSB0 ABPET0 TAUPET0;
    title "Baseline summary – Continuous variables";
run;

/*Categorical variables*/
proc freq data=eddy.alz_wide;
    tables SEX EDU JOB WZC / missing;
    title "Baseline summary – Categorical variables";
run;

/* Baseline comparison by residence (WZC)*/
proc ttest data=eddy.alz_wide;
    class WZC;
    var BPRS0 CDRSB0 ABPET0 TAUPET0;
    title "Baseline cognitive and biomarker differences by residence (WZC)";
run;

/*Mean and SD over time */
proc means data=eddy.bprs_long n mean stddev;
    class TIME;
    var BPRS;
    title "BPRS mean and SD per time point";
run;

/*Graphical trends of both mean and SD*/
proc means data=eddy.bprs_long noprint;
    class TIME;
    var BPRS;
    output out=eddy.bprs_stats mean=mean stddev=sd;
run;

proc sgplot data=eddy.bprs_stats;
    series x=TIME y=mean / markers lineattrs=(thickness=2);
    series x=TIME y=sd / y2axis markers lineattrs=(pattern=shortdash);
    xaxis label="Year since diagnosis";
    yaxis label="Mean BPRS";
    y2axis label="SD of BPRS";
    title "BPRS Mean and Variability over Time";
run;

/*Dropout and Missingness Patters*/
proc sql;
    create table eddy.bprs_response as
    select TIME,
           mean(case when BPRS is not null then 1 else 0 end) as response_rate
    from eddy.bprs_long
    group by TIME;
quit;

proc sgplot data=eddy.bprs_response;
    series x=TIME y=response_rate / markers;
    format response_rate percent8.0;
    yaxis label="Response Rate (%)";
    xaxis label="Year";
    title "Dropout / Response Rate over Time";
run;

/*Droptout by baseline cognitive function*/
proc sql;
    create table eddy.dropout as
    select PATID,
           max(time) as last_time,
           CDRSB0,
           /* BPRS at time 0 = baseline BPRS0 */
           max(case when time = 0 then BPRS end) as BPRS0,
           WZC
    from eddy.bprs_long
    group by PATID;
quit;

proc means data=eddy.dropout mean std;
    class WZC;
    var last_time;
    title "Average follow-up length (by residence)";
run;


/* BPRS mean evolution by residence*/
proc means data=eddy.bprs_long noprint;
    class WZC TIME;
    var BPRS;
    output out=eddy.bprs_wzc mean=mean stddev=sd n=n;
run;

data eddy.bprs_wzc;
    set eddy.bprs_wzc(where=(_type_>0));
    se  = sd / sqrt(n);
    lcl = mean - 1.96*se;
    ucl = mean + 1.96*se;
run;

proc sgplot data=eddy.bprs_wzc;
    band x=TIME lower=lcl upper=ucl / group=WZC transparency=0.8;
    series x=TIME y=mean / group=WZC markers;
    xaxis label="Year";
    yaxis label="BPRS";
    keylegend / title="Residence (WZC)";
    title "BPRS evolution by residence type";
run;

/* BPRS mean evolution by sex*/
proc means data=eddy.bprs_long noprint;
    class SEX TIME;
    var BPRS;
    output out=eddy.bprs_sex mean=mean stddev=sd n=n;
run;

data eddy.bprs_sex;
    set eddy.bprs_sex(where=(_type_>0));
    se  = sd / sqrt(n);
    lcl = mean - 1.96*se;
    ucl = mean + 1.96*se;
run;

proc sgplot data=eddy.bprs_sex;
    band x=TIME lower=lcl upper=ucl / group=SEX transparency=0.8;
    series x=TIME y=mean / group=SEX markers;
    xaxis label="Year";
    yaxis label="BPRS";
    keylegend / title="Sex";
    title "BPRS evolution by sex";
run;

/*Correlation structure over time*/
proc corr data=eddy.alz_wide nosimple;
    var BPRS0-BPRS6;
    title "Pairwise correlations of BPRS over time (wide format)";
run;

/* Individual trajectories*/
proc surveyselect data=eddy.alz_wide out=eddy.sample_ids method=srs n=20 seed=42;
    id PATID;
run;

proc sql;
    create table eddy.sample_long as
    select L.* from eddy.bprs_long as L
    inner join eddy.sample_ids as S
    on L.PATID = S.PATID
    order by PATID, TIME;
quit;

proc sgplot data=eddy.sample_long;
    series x=TIME y=BPRS / group=PATID transparency=0.4;
    xaxis label="Year";
    yaxis label="BPRS";
    title "Individual BPRS trajectories (random 20 subjects)";
run;

/*Compare trajectories between high vs low baseline cognition*/

data eddy.bprs_long;
    set eddy.alz_wide;
    array bprs_arr[7] BPRS0-BPRS6;

    do time = 0 to 6;
        BPRS = bprs_arr[time+1];
        output;
    end;

    keep TRIAL PATID SEX AGE EDU BMI INKOMEN JOB ADL WZC
         CDRSB0 ABPET0 TAUPET0 BPRS0 time BPRS;
run;

proc sql noprint;
    select median(BPRS0)
    into :bprs_med
    from eddy.alz_wide;
quit;

%put &=bprs_med;

data eddy.bprs_long2;
    set eddy.bprs_long;

    length group $25;

    if BPRS0 >= &bprs_med then group = "High baseline BPRS";
    else                       group = "Low baseline BPRS";
run;

proc means data=eddy.bprs_long2 noprint;
    class group time;
    var BPRS;
    output out=eddy.bprs_groups mean=mean stddev=sd n=n;
run;

/* Add standard errors and 95% confidence intervals */
data eddy.bprs_groups;
    set eddy.bprs_groups;
    if _type_ > 0;
    se  = sd / sqrt(n);
    lcl = mean - 1.96 * se;
    ucl = mean + 1.96 * se;
run;

proc sgplot data=eddy.bprs_groups;
    band   x=time lower=lcl upper=ucl / group=group transparency=0.8;
    series x=time y=mean              / group=group markers;
    xaxis label="Year";
    yaxis label="BPRS";
    keylegend / title="Baseline group";
    title "BPRS evolution by baseline cognitive level";
run;


/*baseline summary with custom decimals*/
proc means data=eddy.alz_wide n mean std min max maxdec=2;
    var AGE BMI INKOMEN ADL BPRS0 CDRSB0 ABPET0 TAUPET0;
    format 
        AGE 8.0
        BMI 8.0
        INKOMEN 8.0
        ADL 8.2
        BPRS0 8.2
        CDRSB0 8.2
        ABPET0 8.2
        TAUPET0 8.2;
    title "Baseline summary – Continuous variables (Custom Decimals)";
run;



