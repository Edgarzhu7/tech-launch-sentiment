/* ===========================================================
   PROJECT: Smartphone Launches, Sentiment, and Stock Reactions
   AUTHOR: Edgar Zhu
   PATHS
   =========================================================== */
%let dir = L:\FIN342\Project;
libname proj "L:\FIN342\Project";

/* ===========================================================
   1) DATA IMPORTS
   - CRSP daily for AAPL & GOOGL (CSV)
   - Fama–French daily factors (CSV)
   - RavenPack launch events (CSV export called launch_raw.csv)
   - Compustat fundamentals (CSV)
   =========================================================== */
proc import datafile="&dir\appl.csv"  out=proj.appl  dbms=csv replace; guessingrows=max; getnames=yes; run;
proc import datafile="&dir\googl.csv" out=proj.googl dbms=csv replace; guessingrows=max; getnames=yes; run;
proc import datafile="&dir\ff_daily.csv" out=proj.ff   dbms=csv replace; guessingrows=max; getnames=yes; run;
proc import datafile="&dir\launch_raw.csv" out=proj.events dbms=csv replace; guessingrows=max; getnames=yes; run;
proc import datafile="&dir\compustat.csv" out=proj.comp dbms=csv replace; guessingrows=max; getnames=yes; run;

/* ===========================================================
   1A) EVENT TABLE CLEANING (dates ? SAS date; names ? ticker)
   - Handles character/numeric/Excel-serial/Unix-epoch timestamps
   =========================================================== */
data proj.events_clean;
  set proj.events;
  length firm $6;
  /* event_date from rpa_date_utc robustly */
  if vtype(rpa_date_utc)='C' then event_date = input(strip(rpa_date_utc), anydtdte.);
  else do;
    if 30000 <= rpa_date_utc <= 60000 then event_date = '30DEC1899'd + rpa_date_utc;         /* Excel serial */
    else if rpa_date_utc > 1e9 then event_date = datepart('01JAN1970:00:00:00'dt + rpa_date_utc); /* Unix sec */
    else event_date = rpa_date_utc;
  end;
  format event_date yymmdd10.;

  /* map entity_name to CRSP ticker universe */
  select (strip(upcase(entity_name)));
    when ('APPLE INC.')   firm='AAPL';
    when ('ALPHABET I')   firm='GOOGL';
    otherwise firm='';
  end;

  /* sentiment variable name unification */
  sentiment = event_sentiment_score;

  keep firm event_date sentiment entity_name headline src;
run;

/* ===========================================================
   2) CRSP & FACTORS: type harmonization, panel construction
   =========================================================== */

/* Normalize AAPL */
data work.appl_nrm;
  set proj.appl;
  length firm $6; firm='AAPL';
  if vtype(date)='C' then date_num=input(strip(date), anydtdte.); else date_num=date;
  format date_num yymmdd10.;
  if vtype(ret)='C' then do;
    if strip(ret) in ('', '.', 'C', 'B') then ret_num=.;
    else ret_num=input(strip(ret), best32.);
  end; else ret_num=ret;
  keep firm date_num ret_num prc shrout;
  rename date_num=date ret_num=ret;
run;

/* Normalize GOOGL */
data work.googl_nrm;
  set proj.googl;
  length firm $6; firm='GOOGL';
  if vtype(date)='C' then date_num=input(strip(date), anydtdte.); else date_num=date;
  format date_num yymmdd10.;
  if vtype(ret)='C' then do;
    if strip(ret) in ('', '.', 'C', 'B') then ret_num=.;
    else ret_num=input(strip(ret), best32.);
  end; else ret_num=ret;
  keep firm date_num ret_num prc shrout;
  rename date_num=date ret_num=ret;
run;

/* Stack to daily panel base */
data proj.crsp_all;
  set work.appl_nrm work.googl_nrm;
run;

/* Factors: convert percent to decimal and build mkt = MKT-RF + RF */
data proj.ff_clean;
  set proj.ff;
  if vtype(date)='C' then date=input(strip(date), anydtdte.);
  format date yymmdd10.;
  mktrf = mktrf/100; rf = rf/100;
  mkt   = mktrf + rf;
  keep date mktrf rf mkt;
run;

/* Merge into daily panel with excess return and abnormal return (ß=1 simplification) */
proc sql;
  create table proj.daily as
  select a.firm, a.date, a.ret, a.prc, a.shrout,
         b.mktrf, b.rf, b.mkt,
         (a.ret - b.rf)           as excess_ret,
         (a.ret - b.rf - b.mktrf) as abn_ret
  from proj.crsp_all as a
  left join proj.ff_clean as b
    on a.date=b.date
  ;
quit;

/* ===========================================================
   3) EVENT WINDOWS AND CAR/AR
   - Macro to build [-L,+R] windows; join to daily; aggregate
   =========================================================== */
%macro make_car(L=-3, R=3, tag=car_m3_p3);
  /* expand each event into a window of relative days */
  data proj.win_&tag.;
    set proj.events_clean;
    do rel_day=&L to &R;
      date = intnx('day', event_date, rel_day, 's');
      output;
    end;
    format date yymmdd10.;
  run;

  /* join to daily to fetch AR/Excess returns */
  proc sql;
    create table proj.evret_&tag. as
    select w.firm, w.event_date, w.rel_day, w.date,
           d.abn_ret, d.excess_ret, w.sentiment
    from proj.win_&tag. as w
    left join proj.daily d
      on w.firm=d.firm and w.date=d.date;
  quit;

  /* aggregate to event-level metrics */
  proc sql;
    create table proj.&tag. as
    select firm, event_date, max(sentiment) as sentiment,
           sum(abn_ret) as &tag.,                    /* CAR */
           mean(abn_ret) as ar_mean,                 /* average AR over window */
           sum(case when rel_day=0 then abn_ret else 0 end) as ar_0,
           n(abn_ret) as n_obs
    from proj.evret_&tag.
    group by firm, event_date;
  quit;
%mend;

%make_car(L=-3,  R=3,  tag=car_m3_p3);
%make_car(L=-5,  R=5,  tag=car_m5_p5);
%make_car(L=-10, R=10, tag=car_m10_p10);

/* Combine the three windows into one event-level table */
proc sql;
  create table proj.car_all as
  select coalesce(c1.firm, c2.firm, c3.firm) as firm length=6,
         coalesce(c1.event_date, c2.event_date, c3.event_date) as event_date format=yymmdd10.,
         coalesce(c1.sentiment, c2.sentiment, c3.sentiment) as sentiment,
         c1.car_m3_p3,  c2.car_m5_p5,  c3.car_m10_p10,
         c1.ar_mean as ar_mean_m3p3, c2.ar_mean as ar_mean_m5p5, c3.ar_mean as ar_mean_m10p10,
         c1.ar_0    as ar0_m3p3,     c2.ar_0    as ar0_m5p5,     c3.ar_0    as ar0_m10p10
  from proj.car_m3_p3  as c1
  full join proj.car_m5_p5  as c2 on c1.firm=c2.firm and c1.event_date=c2.event_date
  full join proj.car_m10_p10 as c3 on coalesce(c1.firm,c2.firm)=c3.firm
                                   and coalesce(c1.event_date,c2.event_date)=c3.event_date;
quit;

/* ===========================================================
   4) SIZE CONTROLS (Compustat first; CRSP fallback)
   - Compute market equity (ME) and log size
   - Align each event with the most recent Compustat date = event
   - If missing, fallback to CRSP price*shares on last trading day = event
   =========================================================== */
data proj.comp_clean;
  length firm $6 datadate_sas 8;
  set proj.comp;
  firm = upcase(strip(coalesce(tic, ticker)));
  if vtype(datadate)='C' then datadate_sas = input(strip(datadate), anydtdte.); else datadate_sas = datadate;
  format datadate_sas yymmdd10.;
  me = .;
  if nmiss(prccq, cshoq)=0 then me = abs(prccq)*cshoq;
  else if nmiss(prccm, csho)=0 then me = abs(prccm)*csho;
  else if nmiss(prc  , shrout)=0 then me = abs(prc  )*shrout;
  lme = ifn(me>0, log(me), .);
  keep firm datadate_sas me lme prccq cshoq prccm csho prc shrout;
run;

proc sql;
  create table proj.comp_for_event as
  select e.firm, e.event_date, e.sentiment,
         c.me, c.lme, c.datadate_sas as datadate format=yymmdd10.
  from proj.events_clean e
  left join proj.comp_clean c
    on e.firm=c.firm
   and c.datadate_sas = (select max(datadate_sas) from proj.comp_clean
                         where firm=e.firm and datadate_sas<=e.event_date);
quit;

/* Fallback: closest trading day = event from CRSP */
proc sql;
  create table proj.size_fallback as
  select e.firm, e.event_date, max(d.date) as size_date format=yymmdd10.
  from proj.events_clean e
  left join proj.daily d
    on e.firm=d.firm and d.date<=e.event_date
  group by e.firm, e.event_date;
quit;

proc sql;
  create table proj.size_from_crsp as
  select f.firm, f.event_date, abs(d.prc)*d.shrout as me_crsp
  from proj.size_fallback f
  left join proj.crsp_all d
    on f.firm=d.firm and f.size_date=d.date;
quit;

proc sort data=proj.comp_for_event out=proj.comp_for_event_s; by firm event_date; run;
proc sort data=proj.size_from_crsp out=proj.size_from_crsp_s; by firm event_date; run;

data proj.comp_final;
  merge proj.comp_for_event_s(in=a) proj.size_from_crsp_s(in=b);
  by firm event_date;
  lme_final = coalesce(lme, (me_crsp>0)*log(me_crsp));
run;

/* ===========================================================
   5) ANALYSIS & OUTPUT (PDF + tables)
   Turn on ODS PDF to capture tables/graphs in a report.
   =========================================================== */
ods pdf file="&dir\results_report.pdf" style=journal;
ods graphics on;

/* >>> NEW #1: Sentiment score summary statistics & histogram */
title "Sentiment Score Summary (Overall)";
proc means data=proj.events_clean n mean std min p25 median p75 max maxdec=4;
  var sentiment;
run;

title "Sentiment Score Summary by Firm";
proc means data=proj.events_clean n mean std min p25 median p75 max maxdec=4;
  class firm;
  var sentiment;
run;

title "Sentiment Distribution (Histogram)";
proc sgplot data=proj.events_clean;
  histogram sentiment;
  density sentiment / type=normal;
  xaxis label="Sentiment score";
  yaxis label="Frequency";
run;

/* t-test of mean CAR = 0 across events */
title "Are Mean CARs Zero? (t-tests)";
proc ttest data=proj.car_all h0=0;
  var car_m3_p3 car_m5_p5 car_m10_p10;
run;

/* Build regression-ready table: join size to CARs */
proc sql;
  create table proj.car_final as
  select a.*, b.lme_final
  from proj.car_all a
  left join proj.comp_final b
    on a.firm=b.firm and a.event_date=b.event_date;
quit;

/* >>> NEW #2: Firm-specific regressions plus pooled model */
title "Regression: CAR on Sentiment & Size — AAPL only";
proc reg data=proj.car_final(where=(firm='AAPL'));
  model car_m3_p3   = sentiment lme_final;
  model car_m5_p5   = sentiment lme_final;
  model car_m10_p10 = sentiment lme_final;
run; quit;

title "Regression: CAR on Sentiment & Size — GOOGL only";
proc reg data=proj.car_final(where=(firm='GOOGL'));
  model car_m3_p3   = sentiment lme_final;
  model car_m5_p5   = sentiment lme_final;
  model car_m10_p10 = sentiment lme_final;
run; quit;

title "Regression: CAR on Sentiment & Size — Pooled (AAPL + GOOGL)";
proc reg data=proj.car_final;
  model car_m3_p3   = sentiment lme_final;
  model car_m5_p5   = sentiment lme_final;
  model car_m10_p10 = sentiment lme_final;
run; quit;

/* Optional immediate-reaction check using Day-0 AR */
title "Day-0 AR Regressions — Pooled";
proc reg data=proj.car_final;
  model ar0_m3p3  = sentiment lme_final;
  model ar0_m5_p5 = sentiment lme_final;
  model ar0_m10_p10 = sentiment lme_final;
run; quit;

/* >>> NEW #3: Launch-day returns table with 3s outlier flags */
proc sql;
  create table proj.launch_day_returns as
  select e.firm, e.event_date, e.sentiment,
         d.ret        as ret_day0,
         d.excess_ret as excess_day0,
         d.abn_ret    as abn_day0
  from proj.events_clean e
  left join proj.daily d
    on e.firm=d.firm and e.event_date=d.date
  order by firm, event_date;
quit;

proc means data=proj.launch_day_returns noprint;
  var abn_day0;
  output out=_abn_stats_ mean=mu std=sd;
run;

data proj.launch_day_returns_flag;
  if _n_=1 then set _abn_stats_;
  set proj.launch_day_returns;
  length outlier_flag $12;
  if sd>0 and abs(abn_day0-mu) > 3*sd then outlier_flag='|>3 SD|';
  else outlier_flag='';
  drop mu sd;
run;

title "Stock Returns on Launch Dates (Event Day = 0)";
proc print data=proj.launch_day_returns_flag label noobs;
  var firm event_date sentiment ret_day0 excess_day0 abn_day0 outlier_flag;
  label ret_day0     = "Raw Return (Day 0)"
        excess_day0  = "Excess Return (Day 0)"
        abn_day0     = "Abnormal Return (Day 0)"
        outlier_flag = "Outlier?";
run;

ods graphics off;
ods pdf close;

/* ===========================================================
   6) EXPORTS FOR APPENDIX/TABLES
   =========================================================== */
proc export data=proj.car_final
  outfile="&dir\event_car_results.xlsx" dbms=xlsx replace; sheet='CAR';
run;

proc export data=proj.daily
  outfile="&dir\daily_panel_with_factors.csv" dbms=csv replace;
run;

proc export data=proj.launch_day_returns_flag
  outfile="&dir\launch_day_returns.csv" dbms=csv replace;
run;

title; footnote;
