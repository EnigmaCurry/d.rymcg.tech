-- see aiosql operators manual:
-- https://nackjicholson.github.io/aiosql/defining-sql-queries.html#operators
--
--
-- name: ddl_lock#
-- Call this to ensure that only one client can perform DDL at a time:
select
  pg_advisory_xact_lock(1);

-- name: create_enum_job_status#
do $$
begin
  create type job_status as ENUM (
    'uploaded',
    'processing',
    'complete'
);
exception
  when duplicate_object then
    null;
end
$$;

-- name: create_table_upload#
create table if not exists upload (
  id bigserial not null primary key,
  uploader varchar not null,
  original_filename varchar not null,
  upload_date timestamp,
  upload_path varchar not null,
  status job_status
);

-- name: get_user_uploads
select
  (id,
    uploader,
    original_filename,
    upload_date,
    upload_path,
    status)
from
  upload
where
  uploader = :user;

-- name: register_upload!
insert into upload (uploader, original_filename, upload_date, upload_path, status)
  values (:uploader, :original_filename, :upload_date, :upload_path, :status);

