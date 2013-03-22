DROP TABLE IF EXISTS "SECFilings";
CREATE TABLE SECFilings(
  cik     INTEGER NOT NULL,
  form    VARCHAR(12) NOT NULL,
  doclink VARCHAR(256) NOT NULL,
  comlink VARCHAR(256) NOT NULL,
  date    DATE NOT NULL);
INSERT INTO "SECFilings" VALUES(1547625,'N-Q','http://www.sec.gov/Archives/edgar/data/1547625/000092242313000108/kl03045.htm','http://www.sec.govbrowse-edgar?action=getcompany&CIK=1547625','2013-03-21');
INSERT INTO "SECFilings" VALUES(1283381,'N-Q','http://www.sec.gov/Archives/edgar/data/1283381/000111183013000248/fp0006809_nq.htm','http://www.sec.govbrowse-edgar?action=getcompany&CIK=1283381','2013-03-21');
