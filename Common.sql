
/* *********************************************************************************** */
/* This script contains common tables, views, functions, etc. for the DB.              */
/*                                                                                     */
/* It should be executed first in the series when creating the DB.                     */
/* *********************************************************************************** */

/* *********************************************************************************** */
/* Function update_rec_utimestamp                                                      */
/*     Used as a trigger function, this will set the column 'rec_utimestamp' to the    */
/*     current time.                                                                   */
/* *********************************************************************************** */
DROP FUNCTION IF EXISTS update_rec_utimestamp() CASCADE;
CREATE OR REPLACE FUNCTION update_rec_utimestamp() RETURNS TRIGGER AS $$
BEGIN
  NEW.rec_utimestamp = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';


/* *********************************************************************************** */
/* Function inherits_from                                                              */
/*     To be used in boolean expressions to determine if a given table inherits from   */
/*     some parent table. This will prevent partition tables from being used during    */
/*     partition maintenance.                                                          */
/* *********************************************************************************** */
DROP FUNCTION IF EXISTS inherits_from(IN aParent VARCHAR(255), IN aChild VARCHAR(255)) CASCADE;
CREATE OR REPLACE FUNCTION inherits_from(IN aParent VARCHAR(255), IN aChild VARCHAR(255)) RETURNS BOOLEAN AS $$
DECLARE tmp_bool BOOLEAN DEFAULT FALSE;
BEGIN
  SELECT EXISTS (SELECT 1
                   FROM pg_class AS c1
                   INNER JOIN pg_inherits AS pi ON c1.oid = pi.inhparent
                   INNER JOIN pg_class AS c2 ON pi.inhrelid = c2.oid
                   WHERE c1.relname = aParent
                     AND c2.relname = aChild)
           INTO tmp_bool;
  RETURN tmp_bool;
END;
$$ LANGUAGE 'plpgsql';


/* *********************************************************************************** */
/* Table tbl_keys                                                                      */
/*    Holds all the 'key values' for collections. Partition tables will have a foreign */
/*    key references to this table.                                                    */
/*                                                                                     */
/*    The 'hash' value needs to be comupted in the application. It should be some      */
/*    CRC or something, and must be computed the same way everytime.                   */
/* *********************************************************************************** */
DROP TABLE IF EXISTS tbl_keys CASCADE;
CREATE TABLE IF NOT EXISTS tbl_keys (
  rec_id BIGSERIAL,
  rec_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  rec_utimestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  hash VARCHAR(255) NOT NULL DEFAULT 'UNKNOWN',
  source_system VARCHAR(255) NOT NULL DEFAULT 'UNKNOWN',
  Site VARCHAR(50) NULL DEFAULT NULL,
  MonPlan VARCHAR(50) NULL DEFAULT NULL,
  Antenna VARCHAR(50) NULL DEFAULT NULL,
  Satellite VARCHAR(50) NULL DEFAULT NULL,
  Transponder VARCHAR(50) NULL DEFAULT NULL,
  Carrier VARCHAR(50) NULL DEFAULT NULL,
  Beacon VARCHAR(50) NULL DEFAULT NULL,
  CONSTRAINT pk_tbl_keys PRIMARY KEY ( rec_id )
);
CREATE INDEX idx_tbl_keys_source_system ON tbl_keys ( source_system ASC );
CREATE INDEX idx_tbl_keys_site ON tbl_keys ( Site ASC );
CREATE INDEX idx_tbl_keys_monplan ON tbl_keys ( MonPlan ASC );
CREATE INDEX idx_tbl_keys_antenna ON tbl_keys ( Antenna ASC );
CREATE INDEX idx_tbl_keys_satellite ON tbl_keys ( Satellite ASC );
CREATE INDEX idx_tbl_keys_transponder ON tbl_keys ( Transponder ASC );
CREATE INDEX idx_tbl_keys_carrier ON tbl_keys ( Carrier ASC );
CREATE INDEX idx_tbl_keys_beacon ON tbl_keys ( Beacon ASC );
CREATE INDEX idx_tbl_keys_all ON tbl_keys ( Site ASC, MonPlan ASC, Antenna ASC, Satellite ASC, Transponder ASC, Carrier ASC, Beacon ASC );
CREATE UNIQUE INDEX uidx_tbl_keys_hash ON tbl_keys ( hash ASC );
ALTER TABLE tbl_keys ADD CONSTRAINT uk_tbl_keys UNIQUE USING INDEX uidx_tbl_keys_hash;


/* *********************************************************************************** */
/* Trigger tbl_keys_uts_trig                                                           */
/*     A trigger to update the modified timestamp on 'tbl_keys' using the function     */
/*     'update_rec_utimestamp*.                                                        */
/* *********************************************************************************** */
DROP TRIGGER IF EXISTS tbl_keys_uts_trig ON tbl_keys CASCADE;
CREATE TRIGGER tbl_keys_uts_trig BEFORE UPDATE ON tbl_keys FOR EACH ROW EXECUTE PROCEDURE update_rec_utimestamp();


/* *********************************************************************************** */
/* Function get_key                                                                    */
/*     Returns the 'rec_id' of the corresponding 'key values', and inserts the values  */
/*     if necessary.                                                                   */
/* *********************************************************************************** */
DROP FUNCTION IF EXISTS get_key(IN aHash VARCHAR(255), IN aSource VARCHAR(255), IN aSite VARCHAR(50), IN aMonPlan VARCHAR(50), IN aAntenna VARCHAR(50), IN aSatellite VARCHAR(50), IN aTransponder VARCHAR(50), IN aCarrier VARCHAR(50), IN aBeacon VARCHAR(50)) CASCADE;
CREATE OR REPLACE FUNCTION get_key(IN aHash VARCHAR(255), IN aSource VARCHAR(255), IN aSite VARCHAR(50), IN aMonPlan VARCHAR(50), IN aAntenna VARCHAR(50), IN aSatellite VARCHAR(50), IN aTransponder VARCHAR(50), IN aCarrier VARCHAR(50), IN aBeacon VARCHAR(50))
RETURNS BIGINT AS $$
DECLARE tmp_id BIGINT DEFAULT NULL;
BEGIN
  INSERT INTO tbl_keys (hash, source_system, Site, MonPlan, Antenna, Satellite, Transponder, Carrier, Beacon)
    VALUES (aHash, aSource, aSite, aMonPlan, aAntenna, aSatellite, aTransponder, aCarrier, aBeacon)
    ON CONFLICT ON CONSTRAINT uidx_tbl_keys_hash DO UPDATE SET rec_utimestamp = CURRENT_TIMESTAMP;

  SELECT rec_id INTO tmp_id
    FROM tbl_keys
   WHERE hash = aHash
   LIMIT 1;

  RETURN tmp_id;
END;
$$ LANGUAGE 'plpgsql';


