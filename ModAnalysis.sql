
/* *********************************************************************************** */
/* This is the SQL script for establishing MOD Analysis structure(s) data from Monics. */
/*                                                                                     */
/* Structures for MOD Analysis follow a similar but different pattern for partitions.  */
/* They also parition on the 'ChannelType' of a record. This further segemnts records  */
/* out to improve scan times.                                                          */
/*                                                                                     */
/* The 'id' column is also include, but is not part of partitioning. It is relevant    */
/* correlating traces and analysis.                                                    */
/* *********************************************************************************** */

/* *********************************************************************************** */
/* Table tbl_modanalysis                                                               */
/*    The master table for all carrier measurements. Partition tables will             */
/*    inherit from this table. It is essentially a template for a table.               */
/*                                                                                     */
/*    Partition tables will need to reference the table 'tbl_keys', and create the     */
/*    appropriate indexes.                                                             */
/* *********************************************************************************** */
DROP TABLE IF EXISTS tbl_modanalysis CASCADE;
CREATE TABLE IF NOT EXISTS tbl_modanalysis (
  rec_id BIGSERIAL,
  rec_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  rec_utimestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  par_rec_id BIGINT NOT NULL,
  RecIndex BIGINT NOT NULL,
  Time TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  ChannelType VARCHAR(50) NULL DEFAULT NULL,
  id INTEGER NULL DEFAULT NULL,
  Data JSONB NOT NULL
);


/* *********************************************************************************** */
/* Table tbl_modanalysis_other                                                         */
/*    A holding table for all MOD analysis measurements outside of current of the      */
/*    current collection policy time period. This is really only used when partition   */
/*    tables are undergoing maintenance, or during processing of erroneous data.       */
/*                                                                                     */
/*    This table will be periodically examined and/or truncated.                       */
/* *********************************************************************************** */
DROP TABLE IF EXISTS tbl_modanalysis_other CASCADE;
CREATE TABLE IF NOT EXISTS tbl_modanalysis_other (
  CONSTRAINT pk_tbl_modanalysis_other PRIMARY KEY ( rec_id )
) INHERITS ( tbl_modanalysis );
-- Remove inheritance so table won't be scanned during queries
ALTER TABLE IF EXISTS ONLY tbl_modanalysis_other NO INHERIT tbl_modanalysis;


/* *********************************************************************************** */
/* The 'BEFORE INSERT' trigger on the table 'tbl_modanalysis'                          */
/* *********************************************************************************** */
DROP TRIGGER IF EXISTS tbl_modanalysis_bins_trig ON tbl_carrier CASCADE;
DROP FUNCTION IF EXISTS tbl_modanalysis_bins_func() CASCADE;
CREATE OR REPLACE FUNCTION tbl_modanalysis_bins_func() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO tbl_modanalysis_other VALUES ( NEW.* );
  RETURN NULL;
END;
$$ LANGUAGE 'plpgsql';
CREATE TRIGGER tbl_modanalysis_bins_trig BEFORE INSERT ON tbl_modanalysis FOR EACH ROW EXECUTE PROCEDURE tbl_modanalysis_bins_func();


