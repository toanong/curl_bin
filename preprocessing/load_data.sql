-- Create the table for raw data
DROP TABLE IF EXISTS <raw_data>;
CREATE TABLE <raw_data>
(
  id integer,
  first_name character varying(50),
  last_name character varying(50),
  email character varying(100),
  country character varying(50),
  address character varying(200),
  ssn character varying(15),
  gender character varying(1),
  city character varying(50),
  zip character varying(10),
  state character varying(50),
  date_of_birth date
)

-- load data from csv file into <raw_table
COPY <raw_data> FROM '{PATH}/data/SourceA.csv' HEADER DELIMITER ',';

-- CREATE normalized data table
DROP TABLE IF EXISTS tz.normalized_data;
CREATE TABLE tz.normalized_data
(
  id integer,
  n_first_name character varying(50),
  n_last_name character varying(50),
  n_email character varying(100),
  n_country character varying(50),
  n_address1 character varying(200),
  n_ssn character varying(15),
  n_gender character varying(1),
  n_city character varying(50),
  n_zip character varying(10),
  n_state character varying(50),
  n_date_of_birth character varying(8),
  blocking_1 character varying(50),
  blocking_2 character varying(50),
  blocking_3 character varying(50),
  blocking_4 character varying(50),
  blocking_5 character varying(50)
);

-- create normalized ssn function

CREATE OR REPLACE FUNCTION tz.normalize_ssn(p_text text)
  RETURNS text AS
$BODY$

declare
	result text;
begin
	result := p_Text;

	-- Remove hyphens
	
	result := replace(result,'-','');
	
	-- Remove space
	result := replace(result,' ','');

	-- regularize repeating numbers
	if (result ~ '([0-9])\1+\1+\1+\1+') then
		result = 'NULL';
	end if;

	return result;
end

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
  
-- create normalize names function
CREATE OR REPLACE FUNCTION tz.normalize_name(p_text text)
  RETURNS text AS
$BODY$

declare
	result text;
begin
	result := p_Text;
	-- To UPPER case
	result := '@'||trim(upper(result))||'@';

	-- Remove prefix
	
	result := replace(result,'@MR.','');
	result := replace(result,'@MRS.','');
	result := replace(result,'@MS.','');
	result := replace(result,'@DR.','');

	result := replace(result,'@MR ','');
	result := replace(result,'@MRS ','');
	result := replace(result,'@MS ','');
	result := replace(result,'@DR ','');


	-- Remove suffix
	
	result := replace(result,' III@','');
	result := replace(result,' JR@','');

	-- Remove all digits
	result := replace(result,'0','');
	result := replace(result,'1','');
	result := replace(result,'2','');
	result := replace(result,'3','');
	result := replace(result,'4','');
	result := replace(result,'5','');
	result := replace(result,'6','');
	result := replace(result,'7','');
	result := replace(result,'8','');
	result := replace(result,'9','');
	
	-- Remove special characters
	result := replace(result,'.','');
	result := replace(result,'!','');
	result := replace(result,';','');
	result := replace(result,':','');
	result := replace(result,'''','');
	result := replace(result,'\"','');
	result := replace(result,'-','');
	result := replace(result,'_','');
	result := replace(result,'*','');
	result := replace(result,'[','');
	result := replace(result,']','');
	result := replace(result,'{','');
	result := replace(result,'}','');
	result := replace(result,'(','');
	result := replace(result,')','');
	result := replace(result,'#','');
	result := replace(result,'@','');
	result := replace(result,'%','');
	result := replace(result,'^','');
	result := replace(result,'$','');
	result := replace(result,'&','');
	result := replace(result,'>','');
	result := replace(result,'<','');
	result := replace(result,'\\','');
	result := replace(result,'/','');
	result := replace(result,'+','');
	result := replace(result,'=','');

	-- Remove space
	result := replace(result,' ','');

	return result;
end

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;  


-- Populate normalized data
INSERT INTO tz.normalized_data
(
	id integer,
  	n_first_name,
  	n_last_name,
  	n_email,
  	n_country,
  	n_address1,
  	n_ssn,
  	n_gender,
  	n_city,
  	n_zip,
  	n_state,
  	n_date_of_birth
)
SELECT 
  	id											as id,
  	standardize_name(first_name)				as n_first_name,
  	standardize_name(last_name)					as n_last_name,
  	upper(email)								as n_email,
  	upper(country)								as n_country,
  	upper(address1)								as n_address1,	
  	standardize_ssn(ssn)						as n_ssn,
  	upper(gender)								as n_gender,
  	upper(city)									as n_city,
  	left(zip,5)									as n_zip,
  	upper(state)								as n_state,
  	lpad(extract(year from bdate)::text)||
  	lpad(extract(month from bdate)::text,2,'0')||
  	lpad(extract(day from bdate)::text,2,'0')	as n_date_of_birth,
FROM
	tz.<raw_data>;

-- Set blocking values

UPDATE tz.normalized_data
SET
	blocking_1 = left(n_lastname, 4),
	blocking_2 = n_zip,
	blocking_3 = n_gender || n_state;
	
-- Create hash data table
-- naming convention: The <hash_data> table should be named as: <normalized_data>_hash
-- For example if the name your <normalized_data> table is source_a, the name of <hash_data> table is source_a_hash
DROP TABLE IF EXISTS tz.tz.normalized_data_hash
CREATE TABLE tz.tz.normalized_data_hash
(
  id integer,
  h_first_name character varying(2000),
  h_last_name character varying(2000),
  h_email character varying(2000),
  h_address1 character varying(2000),
  h_ssn character varying(2000),
  h_date_of_birth character varying(2000),
  h_blocking_1 character varying(1000),
  h_blocking_2 character varying(1000),
  h_blocking_3 character varying(1000)
);