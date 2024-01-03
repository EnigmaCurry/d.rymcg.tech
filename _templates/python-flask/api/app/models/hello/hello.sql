-- PostgreSQL version
--
-- name: ddl_lock#
-- Call this to ensure that only one client can perform DDL at a time:
select
  pg_advisory_xact_lock(1);

-- name: create_table_visitor#
create table if not exists visitor (
  encounter bigserial not null primary key,
  name varchar not null,
  salutation varchar not null,
  ip_address varchar not null
);

-- name: create_index_visitor_name#
create index if not exists visitor_name_idx on visitor ("name");

-- name: log_user_encounter!
-- Log an encounter with a user
insert into visitor (name, salutation, ip_address)
  values (:username, :salutation, :ip_address);

-- name: count_user_encounters$
-- Read how many times a user has been greeted
select
  count(*)
from
  visitor
where
  name = :username;

-- name: get_users
-- Get all the usernames who have been greeted
select distinct
  name
from
  greeting;

