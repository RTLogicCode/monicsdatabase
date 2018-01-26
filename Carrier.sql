
/* *********************************************************************************** */
/* This is the SQL script for establishing carrier structure(s) data from Monics.      */
/* *********************************************************************************** */

/* *********************************************************************************** */
/* Table tbl_carrier                                                                   */
/*    The master table for all carrier measurements. Partition tables will             */
/*    inherit from this table. It is essentially a template for a table.               */
/*                                                                                     */
/*    Partition tables will need to reference the table 'tbl_keys', and create the     */
/*    appropriate indexes.                                                             */
/* *********************************************************************************** */
DROP TABLE IF EXISTS tbl_carrier CASCADE;
CREATE TABLE IF NOT EXISTS tbl_carrier (
  rec_id BIGSERIAL,
  rec_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  rec_utimestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  par_rec_id BIGINT NOT NULL,
  RecIndex BIGINT NOT NULL,
  Time TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  Data JSONB NOT NULL
);


/* *********************************************************************************** */
/* Table tbl_carrier_other                                                             */
/*    A holding table for all carrier measurements outside of current of the           */
/*    current collection policy time period. This is really only used when partition   */
/*    tables are undergoing maintenance, or during processing of erroneous data.       */
/*                                                                                     */
/*    This table will be periodically examined and/or truncated.                       */
/* *********************************************************************************** */
DROP TABLE IF EXISTS tbl_carrier_other CASCADE;
CREATE TABLE IF NOT EXISTS tbl_carrier_other (
  CONSTRAINT pk_tbl_carrier_other PRIMARY KEY ( rec_id )
) INHERITS ( tbl_carrier );
-- Remove inheritance so table won't be scanned during queries
ALTER TABLE IF EXISTS ONLY tbl_carrier_other NO INHERIT tbl_carrier;


/* *********************************************************************************** */
/* The 'BEFORE INSERT' trigger on the table 'tbl_carrier'                              */
/* *********************************************************************************** */
DROP TRIGGER IF EXISTS tbl_carrier_bins_trig ON tbl_carrier CASCADE;
DROP FUNCTION IF EXISTS tbl_carrier_bins_func() CASCADE;
CREATE OR REPLACE FUNCTION tbl_carrier_bins_func() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO tbl_carrier_other VALUES ( NEW.* );
  RETURN NULL;
END;
$$ LANGUAGE 'plpgsql';
CREATE TRIGGER tbl_carrier_bins_trig BEFORE INSERT ON tbl_carrier FOR EACH ROW EXECUTE PROCEDURE tbl_carrier_bins_func();


