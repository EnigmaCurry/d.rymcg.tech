-- SQLite version

-- name: create_table_greeting#
create table if not exists greeting (
  name text not null primary key,
  times_greeted integer default (0)
);

-- name: increment_user_greetings$
-- Increment the number of times a user has been greeted
insert into greeting (name, times_greeted)
  values (:username, 1)
on conflict (name)
  do update set
    times_greeted = COALESCE(times_greeted, 1) + 1
  returning
    times_greeted;

-- name: count_user_greetings$
-- Read how many times a user has been greeted
select
  times_greeted
from
  greeting
where
  name = :username;

-- name: get_users
-- Get all the usernames who have been greeted
select
  name
from
  greeting;
