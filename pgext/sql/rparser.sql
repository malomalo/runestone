CREATE EXTENSION rparser;


SELECT * FROM ts_token_type('rparser');

SELECT DISTINCT a.token, j.alias
FROM ts_parse('rparser', 'v & J ~ ` ! @ # $ % ^ & * ( ) - _ = + ? / > . < , : ; '' " [ { ] } \ | V & J') AS a
INNER JOIN ts_token_type('rparser') AS j ON j.tokid = a.tokid;

SELECT a.token, j.alias
FROM ts_parse('rparser', 'V&J a!n') AS a
INNER JOIN ts_token_type('rparser') AS j ON j.tokid = a.tokid;

SELECT * FROM ts_parse('rparser', 'V&J.992600');
SELECT * FROM ts_parse('rparser', 'V_J&25.34');
SELECT * FROM ts_parse('rparser', 'V&J.H25');

SELECT j.alias AS type, a.token AS token
FROM ts_parse('rparser', '345 12_abc qwe@efd.r '' http://www.com/ http://aew.werc.ewr/?ad=qwe&dw 1aew.werc.ewr/?ad=qwe&dw 2aew.werc.ewr http://3aew.werc.ewr/?ad=qwe&dw http://4aew.werc.ewr http://5aew.werc.ewr:8100/?  ad=qwe&dw 6aew.werc.ewr:8100/?ad=qwe&dw 7aew.werc.ewr:8100/?ad=qwe&dw=%20%32 +4.0e-10 qwe qwe qwqwe 234.435 455 5.005 teodor@stack.net teodor@123-stack.net 123_teodor@stack.net 123-teodor@stack.net qwe-wer asdf <fr>qwer jf sdjk<we hjwer <werrwe> ewr1> ewri2 <a href="qwe<qwe>">
/usr/local/fff /awdf/dwqe/4325 rewt/ewr wefjn /wqe-324/ewr gist.h gist.h.c gist.c. readline 4.2 4.2. 4.2, readline-4.2 readline-4.2. 234
<i <b> wow  < jqw <> qwerty') AS a
INNER JOIN ts_token_type('rparser') AS j ON j.tokid = a.tokid;

-- Test text search configuration with parser
CREATE TEXT SEARCH CONFIGURATION runestone (
    PARSER = rparser
);

ALTER TEXT SEARCH CONFIGURATION runestone
ALTER MAPPING FOR
	asciiword, word, numword, asciihword, hword, numhword, hword_asciipart,
	hword_part, hword_numpart, email, protocol, url, host, url_path, file, sfloat,
	float, int, uint, version, tag, entity, blank, symbol
WITH simple;

SELECT to_tsvector('runestone', 'pg_trgm');
SELECT to_tsvector('runestone', '12_abc');
SELECT to_tsvector('runestone', '12-abc');
SELECT to_tsvector('runestone', 'test.com');
SELECT to_tsvector('runestone', 'test2.com');

SELECT * FROM to_tsquery('runestone', '(shepherd | sheppard) & (and | ''&'') & wedderburn:*');


-- Test non-ASCII symbols
-- must have a UTF8 database
SELECT getdatabaseencoding();
SET client_encoding TO 'UTF8';

SELECT a.token, j.alias
FROM ts_parse('rparser', 'аб_вгд 12_абв 12-абв абв.рф абв2.рф') AS a
INNER JOIN ts_token_type('rparser') AS j ON j.tokid = a.tokid;

-- ts_debug
SELECT * from ts_debug('runestone', '<myns:foo-bar_baz.blurfl>abc&nm1;def&#xa9;ghi&#245;jkl</myns:foo-bar_baz.blurfl>');

-- check parsing of URLs
SELECT * from ts_debug('runestone', 'http://www.harewoodsolutions.co.uk/press.aspx</span>');
SELECT * from ts_debug('runestone', 'http://aew.wer0c.ewr/id?ad=qwe&dw<span>');
SELECT * from ts_debug('runestone', 'http://5aew.werc.ewr:8100/?');
SELECT * from ts_debug('runestone', '5aew.werc.ewr:8100/?xx');





SELECT j.alias AS type, a.token AS token
FROM ts_parse('rparser', '12_abc') AS a
INNER JOIN ts_token_type('rparser') AS j ON j.tokid = a.tokid;