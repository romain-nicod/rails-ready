# rails-ready

A Rails 8 application template that starts where a project actually starts —
not where `rails new` leaves you.

It is the base taught at Le Wagon's "AI Software Development" bootcamp
(Sprockets, Bootstrap, Font Awesome, Simple Form, the component stylesheet
layout), plus the dozen things a project reaches for in week two and has to
install by hand every single time: background jobs that actually run
asynchronously, a jobs dashboard, live reload, debugging tools, and a `.env`
that Git does not swallow.

Nothing is imposed. Accounts, permissions, search, file uploads and language
models ship **commented out**, each with its exact setup steps — a project
without accounts should not carry Devise.

## How it works

1. **Generate.** One command, at creation time. The template is a generator,
   not a skeleton frozen in this repository, so it does not rot between
   framework releases.
2. **It sets up the base**: Sprockets over Propshaft, the stylesheet
   architecture, Bootstrap wired through the importmap, Simple Form, a
   `pages#home` root.
3. **It adds what the base leaves out**: Solid Queue configured to actually
   run, the Puma plugin so `rails s` is the only command you need, Mission
   Control, live reload, `dotenv`, Pry, `httplog`, Faker.
4. **It leaves the rest commented**, with pointers to
   [`docs/CONFIGURATION.md`](docs/CONFIGURATION.md).
5. **You read that document before deploying.** One step is deliberately not
   scripted — see "Structural decisions".

## Stack

Ruby 3.3 · Rails 8.1 · PostgreSQL · Sprockets + SCSS · Bootstrap 5.3 ·
Importmap (no Node) · Turbo + Stimulus · Solid Queue / Cache / Cable.

## Structural decisions

Things you would not guess from the code, and would break by accident.

**Sprockets, not Propshaft.** Rails 8 ships Propshaft; the `bootstrap` gem
needs Sprockets. The two do not coexist — reverting means removing
`sprockets-rails` **and** `sassc-rails` **and** restoring `propshaft`. Half
the change leaves an application that does not boot.

**Solid Queue over Sidekiq.** Sidekiq is a fine library, but it needs Redis:
one more service to run locally, deploy, monitor and pay for. The database is
already there.

**The single-database setup is documented, not scripted.** Each `solid_*`
install copies a schema file into a migration, and that schema changes between
patch releases. Generating it blind would produce a migration that silently
does not match the gem. It takes three minutes by hand and it is the difference
between one billed database and four.

**Active Storage stays.** The bootcamp generates with `--skip-active-storage`
and reinstalls it two lectures later. A template cannot contradict itself, so
it stays in.

**Four deliberate departures from Le Wagon's `minimal.rb`**, each marked
`DEPARTURE` in [`template.rb`](template.rb):

| # | What | Why |
|---|---|---|
| 1 | A `group :development` with `httplog` | Without it, an outgoing API call — a language-model call in particular — is debugged blind |
| 2 | Stylesheets are downloaded **before** the old ones are deleted | A dropped connection at the wrong moment otherwise leaves the app with no CSS at all |
| 3 | `.env*` is *prepended* to `.gitignore`, above `!.env.example` | Git keeps the **last** matching rule; appending it swallows the negation |
| 4 | `.rubocop.yml` is not overwritten, and the CI workflow is not deleted | `minimal.rb` does both silently: documented rules stop being the rules that run, and pull requests lose their checks |

## Run it

```bash
rails new -d postgresql \
  -m https://raw.githubusercontent.com/OWNER/rails-ready/main/template.rb \
  my_app

cd my_app
bin/rails db:migrate
bin/dev
```

Requires Ruby 3.3+, Rails 8.1+, and a running PostgreSQL.

Using it inside an already-cloned repository (a project scaffold, for example)
needs `--skip`, so that what is already there wins:

```bash
rails new -d postgresql -m …/template.rb --skip .
```

## Environment variables

| Variable | Required | Used for |
|---|---|---|
| `DATABASE_URL` | in production | PostgreSQL connection |
| `RAILS_ENV` | no | `development` unless set; gates the Puma job plugin |
| `OPENAI_API_KEY` | only with `ruby_llm` | language-model calls |
| `CLOUDINARY_URL` | only with `cloudinary` | image hosting |

Real values live in `.env`, which is gitignored. `.env.example` is committed
and lists the names only.

## Quality

```bash
bundle exec rubocop
bundle exec brakeman
bundle exec bundler-audit check --update
```

## Documentation

| Document | What it carries |
|---|---|
| [`docs/CONFIGURATION.md`](docs/CONFIGURATION.md) | Every setting, with what it prevents. The single-database setup, and how to switch each optional gem on |
| [`template.rb`](template.rb) | The generator itself, commented |
| [`Gemfile`](Gemfile) | Three tiers — active, optional, deliberately not picked |

## Licence

All rights reserved.
