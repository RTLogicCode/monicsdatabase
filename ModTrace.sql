
/* *********************************************************************************** */
/* This is the SQL script for establishing MOD Trace structure(s) data from Monics.    */
/*                                                                                     */
/* Structures for MOD Trace follow a similar but different pattern for partitions.     */
/* They also parition on the 'ChannelType' of a record. This further segemnts records  */
/* out to improve scan times. Additionally, trace data and measurement data are        */
/* maintained in different tables. Traces will be queried more often than measurements */
/* and those indexes should be more memory resident compared to other indexes.         */
/*                                                                                     */
/* The 'id' column is also include, but is not part of partitioning. It is relevant    */
/* correlating demodulation and analysis.                                              */
/* *********************************************************************************** */

/* *********************************************************************************** */
/* Table tbl_modtrace_measure                                                          */
/*    The master table for all MOD Trace measurements. Partition tables will           */
/*    inherit from this table. It is essentially a template for a table.               */
/*                                                                                     */
/*    Partition tables will need to reference the table 'tbl_keys', and create the     */
/*    appropriate indexes.                                                             */
/* *********************************************************************************** */
DROP TABLE IF EXISTS tbl_modtrace_measure CASCADE;
CREATE TABLE IF NOT EXISTS tbl_modtrace_measure (
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
/* Table tbl_modtrace_measure_other                                                    */
/*    A holding table for all MOD Trace measurements outside of current of the         */
/*    current collection policy time period. This is really only used when partition   */
/*    tables are undergoing maintenance, or during processing of erroneous data.       */
/*                                                                                     */
/*    This table will be periodically examined and/or truncated.                       */
/* *********************************************************************************** */
DROP TABLE IF EXISTS tbl_modtrace_measure_other CASCADE;
CREATE TABLE IF NOT EXISTS tbl_modtrace_measure_other (
  CONSTRAINT pk_tbl_modtrace_measure_other PRIMARY KEY ( rec_id )
) INHERITS ( tbl_modtrace_measure );
-- Remove inheritance so table won't be scanned during queries
ALTER TABLE IF EXISTS ONLY tbl_modtrace_measure_other NO INHERIT tbl_modtrace_measure;


/* *********************************************************************************** */
/* The 'BEFORE INSERT' trigger on the table 'tbl_modtrace_measure'                     */
/* *********************************************************************************** */
DROP TRIGGER IF EXISTS tbl_modtrace_measure_bins_trig ON tbl_modtrace_measure CASCADE;
DROP FUNCTION IF EXISTS tbl_modtrace_measure_bins_func() CASCADE;
CREATE OR REPLACE FUNCTION tbl_modtrace_measure_bins_func() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO tbl_modtrace_measure_other VALUES ( NEW.* );
  RETURN NULL;
END;
$$ LANGUAGE 'plpgsql';
CREATE TRIGGER tbl_modtrace_measure_bins_trig BEFORE INSERT ON tbl_modtrace_measure FOR EACH ROW EXECUTE PROCEDURE tbl_modtrace_measure_bins_func();


/* *********************************************************************************** */
/* Table tbl_modtrace_trace                                                            */
/*    The master table for all MOD Trace trace data. Partition tables will             */
/*    inherit from this table. It is essentially a template for a table.               */
/*                                                                                     */
/*    Partition tables will need to reference the table 'tbl_keys', and create the     */
/*    appropriate indexes.                                                             */
/*                                                                                     */
/*    This table is storing the actual data in columns by choice. It removes abiguity  */
/*    from JSON data as it is structured. That's the only real reason.                 */
/* *********************************************************************************** */
DROP TABLE IF EXISTS tbl_modtrace_trace CASCADE;
CREATE TABLE IF NOT EXISTS tbl_modtrace_trace (
  rec_id BIGSERIAL,
  rec_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  rec_utimestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  par_rec_id BIGINT NOT NULL,
  RecIndex BIGINT NOT NULL,
  Time TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  ChannelType VARCHAR(50) NULL DEFAULT NULL,
  id INTEGER NULL DEFAULT NULL,
  sa_id VARCHAR(50) NULL DEFAULT NULL,
  sa_model VARCHAR(50) NULL DEFAULT NULL,
  start_freq DOUBLE PRECISION NULL DEFAULT NULL,
  stop_freq DOUBLE PRECISION NULL DEFAULT NULL,
  center_freq DOUBLE PRECISION NULL DEFAULT NULL,
  span_freq DOUBLE PRECISION NULL DEFAULT NULL,
  res_bw DOUBLE PRECISION NULL DEFAULT NULL,
  vid_bw DOUBLE PRECISION NULL DEFAULT NULL,
  ref_level DOUBLE PRECISION NULL DEFAULT NULL,
  scale DOUBLE PRECISION NULL DEFAULT NULL,
  atten INTEGER NULL DEFAULT NULL,
  units INTEGER NULL DEFAULT NULL,
  det_type INTEGER NULL DEFAULT NULL,
  sweep DOUBLE PRECISION NULL DEFAULT NULL,
  uncal INTEGER NULL DEFAULT NULL,
  maxval SMALLINT NULL DEFAULT NULL,
  minval SMALLINT NULL DEFAULT NULL,
  num_Points INTEGER NULL DEFAULT NULL,
  Trace BYTEA NULL DEFAULT NULL
);


/* *********************************************************************************** */
/* Table tbl_modtrace_trace_other                                                      */
/*    A holding table for all MOD Trace traces outside of current of the               */
/*    current collection policy time period. This is really only used when partition   */
/*    tables are undergoing maintenance, or during processing of erroneous data.       */
/*                                                                                     */
/*    This table will be periodically examined and/or truncated.                       */
/* *********************************************************************************** */
DROP TABLE IF EXISTS tbl_modtrace_trace_other CASCADE;
CREATE TABLE IF NOT EXISTS tbl_modtrace_trace_other (
  CONSTRAINT tbl_modtrace_trace_other PRIMARY KEY ( rec_id )
) INHERITS ( tbl_modtrace_trace );
-- Remove inheritance so table won't be scanned during queries
ALTER TABLE IF EXISTS ONLY tbl_modtrace_trace_other NO INHERIT tbl_modtrace_trace;


/* *********************************************************************************** */
/* The 'BEFORE INSERT' trigger on the table 'tbl_modtrace_trace'                       */
/* *********************************************************************************** */
DROP TRIGGER IF EXISTS tbl_modtrace_trace_bins_trig ON tbl_modtrace_trace CASCADE;
DROP FUNCTION IF EXISTS tbl_modtrace_trace_bins_func() CASCADE;
CREATE OR REPLACE FUNCTION tbl_modtrace_trace_bins_func() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO tbl_modtrace_trace_other VALUES ( NEW.* );
  RETURN NULL;
END;
$$ LANGUAGE 'plpgsql';
CREATE TRIGGER tbl_modtrace_trace_bins_trig BEFORE INSERT ON tbl_modtrace_trace FOR EACH ROW EXECUTE PROCEDURE tbl_modtrace_trace_bins_func();



