/* rparser/rparser--1.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION rparser" to load this file. \quit

do $$
	begin
		ASSERT (select pg_encoding_to_char(encoding) from pg_database WHERE datname = current_database()) = 'UTF8', 'Database encoding must be UTF8';
	end;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rparser_start(internal, int4)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION rparser_nexttoken(internal, internal, internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION rparser_end(internal)
RETURNS void
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION rparser_lextype(internal)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION rparser_headline(internal, internal, tsquery)
RETURNS internal
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE TEXT SEARCH PARSER rparser (
	START    = rparser_start,
	GETTOKEN = rparser_nexttoken,
	END      = rparser_end,
	HEADLINE = rparser_headline,
	LEXTYPES = rparser_lextype
);

COMMENT ON TEXT SEARCH PARSER rparser IS 'Text search parser for Runestone';