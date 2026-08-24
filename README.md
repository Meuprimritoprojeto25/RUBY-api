# Dashboardia Ruby API

Dashboardia is a small, executable project-and-task service built with Ruby,
Sinatra, Active Record, SQLite, and Puma. It provides a live visual overview
at `/` and a versioned JSON API at `/api/v1`. The application is intentionally
usable with a brand-new database: its startup process creates the SQLite
directory, applies pending migrations, and only loads sample records when demo
mode is explicitly enabled.

## Requirements

- Ruby 3.1 or newer
- Bundler

## Start locally

```sh
bundle install
DASHBOARDIA_DEMO_MODE=true bundle exec puma -C config/puma.rb config.ru
```

Open <http://localhost:9292/> for the visual dashboard. The initial page is
also useful without demo mode; it displays a clean empty-state onboarding
instead of failing when no records exist.

`DASHBOARDIA_DEMO_MODE=true` creates two projects and three tasks during
startup. The seed is idempotent, so restarts do not duplicate records. Demo
mode does not create credentials because this service has no authentication
layer.

Useful environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `9292` | Puma listen port |
| `BIND` | `0.0.0.0` | Puma bind address |
| `DATABASE_PATH` | `db/dashboardia.sqlite3` | SQLite database file |
| `DATABASE_URL` | unset | SQLite URL, for example `sqlite3:/tmp/dashboardia.sqlite3` |
| `DASHBOARDIA_DEMO_MODE` | unset | Set exactly to `true` to load demo data |
| `DB_LOG` | unset | Set to `true` to write SQL logs to stdout |

The convenience launcher is also available after dependencies are installed:

```sh
ruby bin/server
```

## API

All API responses are JSON. Validation failures return `422` with a
field-by-field error object; missing resources return `404`.

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Liveness and database connectivity |
| `GET` | `/api/v1/dashboard` | Aggregate project/task metrics |
| `GET`, `POST` | `/api/v1/projects` | List or create projects |
| `GET`, `PATCH`, `DELETE` | `/api/v1/projects/:id` | Read, edit, or remove a project |
| `GET`, `POST` | `/api/v1/projects/:project_id/tasks` | List or create a project's tasks |
| `GET`, `PATCH`, `DELETE` | `/api/v1/tasks/:id` | Read, edit, or remove a task |

Example:

```sh
curl -X POST http://localhost:9292/api/v1/projects \
  -H 'Content-Type: application/json' \
  -d '{"name":"Website refresh","code":"website-refresh","description":"Improve the public site","status":"active"}'

curl -X POST http://localhost:9292/api/v1/projects/1/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"Create content inventory","state":"todo","priority":"high","due_on":"2030-01-15"}'
```

Project statuses are `active`, `paused`, and `completed`. Task states are
`todo`, `in_progress`, and `done`; priorities are `low`, `medium`, and
`high`.

## Database operations

Migrations live in `db/migrate` and use normal Active Record migration
metadata, so they are safe to rerun:

```sh
bundle exec rake db:migrate
bundle exec rake db:seed
```

Audit fields (`created_at` and `updated_at`) are database-required and also
assigned centrally by `ApplicationRecord` lifecycle callbacks. Model
validations, foreign keys, unique indexes, and non-null schema constraints
protect records created by the API, seed data, or future Ruby entry points.