let dir = L:\FIN342\Project;
libname proj "L:\FIN342\Project";
/* 1.1 Read CRSP:AAPL & GOOGL(CSV) */
proc import datafile="&dir\appl.csv"  out=proj.appl  dbms=csv replace; guessingrows=max; getnames=yes; run;
proc import datafile="&dir\googl.csv" out=proj.googl dbms=csv replace; guessingrows=max; getnames=yes; run;

/* combine two stocks into one file */
data proj.crsp_all;
  set proj.appl(in=a) proj.googl(in=b);
  length firm $6;
  /* --- standardize SAS date --- */
  if vtype(date)='C' then date=input(strip(date), anydtdte.);
  format date yymmdd10.;
  /* --- unify ret)--- */
  if missing(ret) and not missing(retx) then ret=retx;         /* ???? retx */
  /* --- mark stocks --- */
  if a then firm='AAPL';
  if b then firm='GOOGL';
  keep firm date ret ticker tic permno prc vol shrout;
run;

/* 1.2 Read Fama-French Daily Factor(CSV) */
proc import datafile="&dir\ff_daily.csv" out=proj.ff dbms=csv replace; guessingrows=max; run;

data proj.ff;
  set proj.ff;
  if vtype(date)='C' then date=input(strip(date), anydtdte.);
  format date yymmdd10.;

  if abs(mktrf)>0.5 then do; mktrf=mktrf/100; rf=rf/100; end;
  mkt = mktrf + rf;          /* Compute mkt */
run;

/* 1.3 Read Ravenpack sentiment(Excel)*/
proc import datafile="&dir\launch_raw.csv"
  out=proj.events dbms=csv replace; guessingrows=max; getnames=yes;
run;

/* 1.4 Read Compustat */
proc import datafile="&dir\compustat.csv" out=proj.comp dbms=csv replace; guessingrows=max; run;

data proj.comp;
  set proj.comp;
  firm = upcase(strip(tic));                 /* ????? firm ??:AAPL/GOOGL */
  if vtype(datadate)='C' then datadate=input(strip(datadate), anydtdte.);
  format datadate yymmdd10.;
  me = .;   /* ??? prccq/cshoq, ?: me = prccq * cshoq; */
  lme = log(me);
run;
/*proc contents data=proj.crsp_all; run;*/
/*proc contents data=proj.ff; run;*/
/*proc contents data=proj.events; run;*/
/*proc contents data=proj.comp; run;*/
proc contents data=proj.appl;run;
proc contents data=proj.googl;run;

/**********************************************
* 1) ?????:???SAS ??;???Ticker
**********************************************/
data proj.events_clean;
  set proj.events;
  length firm $6;

  /* ????:?? rpa_date_utc;???????? */
  if vtype(rpa_date_utc)='C' then do event_date = input(strip(rpa_date_utc), anydtdte.);
  end;
  else do;
	if 30000 <= rpa_date_utc <= 60000 then
		event_date = '30DEC1899'd + rpa_date_utc;
	else if rpa_date_utc > 1e9 then
		event_date = datepart('01JAN1970:00:00:00'dt +rpa_date_utc);
	else
		event_date = rpa_date_utc;
  end;
  format event_date yymmdd10.;

  /* RavenPack ??????? CRSP Ticker(??????) */
  select (strip(upcase(entity_name)));
    when ('APPLE INC.')       firm='AAPL';
    when ('ALPHABET I')    firm='GOOGL';   /* ?? CRSP ? GOOGL */
    otherwise firm='';
  end;

  /* ????:????(???? event_sentiment_score) */
  sentiment = event_sentiment_score;

  /* ????? */
  keep firm event_date sentiment entity_name headline src;
run;
/*proc contents data=proj.events_clean; run;*/
proc print data=proj.events_clean (obs=10);run;
/**********************************************
* 2) CRSP & FF:???????,???????
**********************************************/
* 2.1 CRSP ?????? + ?? RET;
data proj.crsp_all_raw;
  set proj.appl (in=a) proj.googl (in=g);
  length firm $6;
  if a then firm='AAPL';
  if g then firm='GOOGL';

  /* ???????? date(??????) */
  /* ??? CSV ??????,????? input/rename */
  /* ?? RET:CRSP ??????,? “C”, “B”, “.” ?,????? */
  if vtype(ret)='C' then do;
    if strip(ret) in ('', '.', 'C', 'B') then ret_num=.;
    else ret_num = input(strip(ret), best32.);
  end;
  else ret_num = ret;

  /* ???? */
  keep firm date ret_num /* ?? prc/shrout ????????? */ prc shrout;
run;

data proj.crsp_all;
  set proj.crsp_all_raw;
  ret = ret_num;
  drop ret_num;
run;


/* ---------- 1) ?? appl ????? ---------- */
data work.appl_nrm;
  set proj.appl;

  length firm $6;
  firm = 'AAPL';

  /* date -> ??? SAS ?? */
  if vtype(date)='C' then date_num = input(strip(date), anydtdte.);
  else                    date_num = date;
  format date_num yymmdd10.;

  /* ret -> ??? */
  if vtype(ret)='C' then do;
    if strip(ret) in ('', '.', 'C', 'B') then ret_num=.;
    else ret_num = input(strip(ret), best32.);
  end;
  else ret_num = ret;

  /* ??????? */
  keep firm date_num ret_num prc shrout;
  rename date_num = date
         ret_num  = ret;
run;

/* ---------- 2) ?? googl ????? ---------- */
data work.googl_nrm;
  set proj.googl;

  length firm $6;
  firm = 'GOOGL';

  if vtype(date)='C' then date_num = input(strip(date), anydtdte.);
  else                    date_num = date;
  format date_num yymmdd10.;

  if vtype(ret)='C' then do;
    if strip(ret) in ('', '.', 'C', 'B') then ret_num=.;
    else ret_num = input(strip(ret), best32.);
  end;
  else ret_num = ret;

  keep firm date_num ret_num prc shrout;
  rename date_num = date
         ret_num  = ret;
run;

/* ---------- 3) ?????(?????,????/??) ---------- */
data proj.crsp_all_raw;
  set work.appl_nrm work.googl_nrm;
run;

data proj.crsp_all;
  set proj.crsp_all_raw;
run;

proc contents data=proj.crsp_all; run;
proc print data=proj.crsp_all(obs=10); run;

* 2.2 FF ??:??????;?? mkt = MKT-RF + RF(???);
data proj.ff_clean;
  set proj.ff;
  /* FF ???????????:????? */
  mktrf = mktrf/100;
  rf    = rf/100;
  /* ??:?????(???) */
  mkt   = mktrf + rf;
  format date yymmdd10.;
  keep date mktrf rf mkt;
run;

* 2.3 ????????:???? & (??)????;
proc sql;
  create table proj.daily as
  select a.firm, a.date, a.ret,
         b.mktrf, b.rf, b.mkt,
         (a.ret - b.rf)           as excess_ret,
         /* ??:?? ß=1 ? “????????” */
         (a.ret - b.rf - b.mktrf) as abn_ret
  from proj.crsp_all as a
  left join proj.ff_clean as b
    on a.date=b.date
  ;
quit;

/****************************************************
* 3) ????? + ????? ? ?? AR / CAR
****************************************************/
%macro make_car(L=-3, R=3, tag=car_m3_p3);

  /* 3.1 ?????????? -L…R */
  data proj.win_&tag.;
    set proj.events_clean;
    do rel_day=&L to &R;
      date = intnx('day', event_date, rel_day, 's');
      output;
    end;
    format date yymmdd10.;
  run;

  /* 3.2 ??????,? AR/???? */
  proc sql;
    create table proj.evret_&tag. as
    select w.firm, w.event_date, w.rel_day, w.date,
           d.abn_ret, d.excess_ret, w.sentiment
    from proj.win_&tag. as w
    left join proj.daily   as d
      on w.firm=d.firm and w.date=d.date
    ;
  quit;

  /* 3.3 ???????:CAR???AR?Day0 AR???? */
  proc sql;
    create table proj.&tag. as
    select firm, event_date, max(sentiment) as sentiment,   /* ?????? */
           sum(abn_ret)                         as &tag.,    /* CAR */
           mean(abn_ret)                        as ar_mean,  /* ??AR */
           sum(case when rel_day=0 then abn_ret else 0 end) as ar_0,
           n(abn_ret)                           as n_obs
    from proj.evret_&tag.
    group by firm, event_date
    ;
  quit;

%mend;

%make_car(L=-3,  R=3,  tag=car_m3_p3);
%make_car(L=-5,  R=5,  tag=car_m5_p5);
%make_car(L=-10, R=10, tag=car_m10_p10);

proc sql;
  create table proj.car_all as
  select coalesce(c1.firm, c2.firm, c3.firm)                 as firm length=6,
         coalesce(c1.event_date, c2.event_date, c3.event_date) as event_date format=yymmdd10.,
         coalesce(c1.sentiment, c2.sentiment, c3.sentiment)  as sentiment,
         c1.car_m3_p3,  c2.car_m5_p5,  c3.car_m10_p10,
         c1.ar_mean as ar_mean_m3p3, c2.ar_mean as ar_mean_m5p5, c3.ar_mean as ar_mean_m10p10,
         c1.ar_0    as ar0_m3p3,     c2.ar_0    as ar0_m5p5,     c3.ar_0    as ar0_m10p10
  from proj.car_m3_p3  as c1
  full join proj.car_m5_p5  as c2 on c1.firm=c2.firm and c1.event_date=c2.event_date
  full join proj.car_m10_p10 as c3 on coalesce(c1.firm,c2.firm)=c3.firm
                                   and coalesce(c1.event_date,c2.event_date)=c3.event_date
  ;
quit;

/****************************************************
* 4) ???????(??):?? Compustat,?? CRSP ??
****************************************************/
data proj.comp_clean;
  length firm $6 datadate_sas 8;   /* ?????/?? */
  set proj.comp;

  /* ?????? */
  firm = upcase(strip(coalesce(tic, ticker)));

  /* ? Compustat ???? SAS ????,??? datadate_sas */
  if vtype(datadate)='C' then datadate_sas = input(strip(datadate), anydtdte.);
  else                         datadate_sas = datadate;
  format datadate_sas yymmdd10.;

  /* ????:?? prccq*cshoq,?? prccm*csho,?? prc*shrout ?? */
  me = .;
  if nmiss(prccq, cshoq)=0 then me = abs(prccq)*cshoq;
  else if nmiss(prccm, csho)=0 then me = abs(prccm)*csho;
  else if nmiss(prc  , shrout)=0 then me = abs(prc  )*shrout;

  /* lme:?? me>0 ???? */
  lme = ifn(me>0, log(me), .);

  keep firm datadate_sas me lme prccq cshoq prccm csho prc shrout;
run;

/* ???(<= ???)? Compustat ???? */
proc sql;
  create table proj.comp_for_event as
  select e.firm, e.event_date, e.sentiment,
         c.me, c.lme, c.datadate_sas as datadate format=yymmdd10.
  from proj.events_clean as e
  left join proj.comp_clean as c
    on e.firm=c.firm
   and c.datadate_sas = (select max(datadate_sas) from proj.comp_clean
                     where firm=e.firm and datadate_sas<=e.event_date)
  ;
quit;

/* ? lme ??,? CRSP(??? prc/shrout)??????????? */
proc sql;
  create table proj.size_fallback as
  select e.firm, e.event_date,
         /* ???????????????? */
         max(d.date) as size_date format=yymmdd10.
  from proj.events_clean e
  left join proj.daily d
    on e.firm=d.firm and d.date<=e.event_date
  group by e.firm, e.event_date
  ;
quit;

proc sql;
  create table proj.size_from_crsp as
  select f.firm, f.event_date,
         abs(d.prc)*d.shrout as me_crsp
  from proj.size_fallback f
  left join proj.crsp_all d
    on f.firm=d.firm and f.size_date=d.date
  ;
quit;
proc sort data=proj.comp_for_event out=proj.comp_for_event_s;
	by firm event_date;
run;
proc sort data=proj.size_from_crsp out=proj.size_from_crsp_s;
	by firm event_date;
run;
data proj.comp_final;
  merge proj.comp_for_event_s (in=a)
        proj.size_from_crsp_s (in=b);
  by firm event_date;
  lme_final = coalesce(lme, (me_crsp>0)*log(me_crsp));
run;

/********************************************
* 5) ??:t-test & ??(??????)
********************************************/
ods pdf file="&dir\results_report.pdf" style=journal;
ods graphics on;
* 5.1 ? CAR ?????=0 ? t ??(??????);
proc ttest data=proj.car_all h0=0;
  var car_m3_p3 car_m5_p5 car_m10_p10;
run;

* 5.2 ??:CAR ~ Sentiment + Size;
proc sql;
  create table proj.car_final as
  select a.*, b.lme_final
  from proj.car_all as a
  left join proj.comp_final as b
    on a.firm=b.firm and a.event_date=b.event_date
  ;
quit;

proc reg data=proj.car_final;
  model car_m3_p3   = sentiment lme_final;
  model car_m5_p5   = sentiment lme_final;
  model car_m10_p10 = sentiment lme_final;
run; quit;

* 5.3(??)??? AR(0) ??????;
proc reg data=proj.car_final;
  model ar0_m3p3  = sentiment lme_final;
  model ar0_m5p5  = sentiment lme_final;
  model ar0_m10p10= sentiment lme_final;
run; quit;
ods graphics off;
ods pdf close;

/*****************
* 6) ????
*****************/
proc export data=proj.car_final
  outfile="&dir\event_car_results.xlsx" dbms=xlsx replace; sheet='CAR';
run;

proc export data=proj.daily
  outfile="&dir\daily_panel_with_factors.csv" dbms=csv replace;
run;

