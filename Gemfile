# =============================================================================
#  Gemfile — rails-ready
# =============================================================================
#  A Rails 8 starting point that already carries what a project needs on day
#  one, instead of collecting it one gem at a time over six weeks.
#
#  HOW TO READ THIS FILE
#  Three tiers, and the tier is the decision:
#
#    ACTIVE    uncommented. Every project wants it. Removing one is a choice
#              you write down in the README.
#    OPTIONAL  commented, with the exact steps to switch it on. Nothing is
#              imposed — a project without accounts should not ship Devise.
#    NOTED     mentioned but not listed. An alternative we deliberately did
#              not pick, kept so nobody re-opens the question from scratch.
#
#  Anything not in the base `rails new` carries a one-line reason. A gem
#  whose reason you cannot state is a gem you should not add.
# =============================================================================

source "https://rubygems.org"

# -----------------------------------------------------------------------------
#  Framework
# -----------------------------------------------------------------------------
gem "rails", "~> 8.1"
gem "pg", "~> 1.5"                  # PostgreSQL from day one: SQLite does not
                                    # hold up in production, and switching late
                                    # means re-testing every query.
gem "puma", ">= 6.0"

# -----------------------------------------------------------------------------
#  Asset pipeline — Sprockets, NOT Propshaft
# -----------------------------------------------------------------------------
#  Rails 8 ships Propshaft. The `bootstrap` gem needs Sprockets, so we switch.
#
#  /!\ The two do NOT coexist. Going back to Propshaft means removing BOTH
#      gems below AND restoring `gem "propshaft"`. Half the change leaves an
#      application that will not boot.
gem "sprockets-rails"
gem "sassc-rails"                   # compiles SCSS, and minifies CSS in production

# -----------------------------------------------------------------------------
#  Front-end
# -----------------------------------------------------------------------------
#  No Node, no bundler, no build step: JavaScript is declared in
#  config/importmap.rb and served as-is.
#
#  /!\ Add a library with `bin/importmap pin <package>`. NEVER `yarn add` —
#      one package is not worth introducing a Node toolchain to maintain.
gem "importmap-rails"
gem "turbo-rails"                   # navigation and DOM updates without writing JS
gem "stimulus-rails"                # behaviour attached to HTML via data- attributes

gem "bootstrap", "~> 5.3"           # grid, components, utilities
gem "autoprefixer-rails"            # browser prefixes, from the Can I Use database
gem "font-awesome-sass", "~> 6.1"   # icons callable from a view
gem "simple_form"                   # f.input picks the field type from the column,
                                    # renders Bootstrap markup, and displays errors
                                    # with aria-invalid for screen readers

# -----------------------------------------------------------------------------
#  Jobs, cache and real time — the database, not Redis
# -----------------------------------------------------------------------------
#  All three ship with Rails 8 and need no gem line. They need CONFIGURATION.
#
#  /!\ Each one defaults to its OWN database. On a paid host that is four
#      databases billed where one would do. See docs/CONFIGURATION.md,
#      "Single database setup" — and do not skip the last step, removing
#      `config.solid_queue.connects_to` from production.rb.
#
#  /!\ Without `config.active_job.queue_adapter = :solid_queue`, jobs run
#      SYNCHRONOUSLY without warning. Everything appears to work.
#
#  Not picked: Sidekiq. It is a fine library, but it needs Redis — one more
#  service to run locally, deploy, monitor and pay for. The database is
#  already there.
gem "solid_queue"                   # background jobs
gem "solid_cache"                   # application cache
gem "solid_cable"                   # WebSockets for Action Cable

gem "mission_control-jobs"          # web dashboard to watch, retry and purge jobs
                                    # /!\ mount it behind an authorisation check,
                                    #     see docs/CONFIGURATION.md

# -----------------------------------------------------------------------------
#  Deployment
# -----------------------------------------------------------------------------
gem "bootsnap", require: false

# -----------------------------------------------------------------------------
#  OPTIONAL — accounts and permissions
# -----------------------------------------------------------------------------
#  Uncomment together: authorisation without authentication has no subject.
#
#  devise    rails generate devise:install && rails generate devise User
#            /!\ The generator prints three manual steps. Nothing works until
#                all three are done — default_url_options, a root route, and
#                flash messages in the layout.
#
#  pundit    rails generate pundit:install
#            /!\ Rails 8 needs
#                config.action_controller.raise_on_missing_callback_actions = false
#
# gem "devise"
# gem "pundit"

# -----------------------------------------------------------------------------
#  OPTIONAL — full-text search
# -----------------------------------------------------------------------------
#  pg_search needs nothing but PostgreSQL. Use `tsearch: { prefix: true }`,
#  which is what makes partial words match.
#
#  Not picked: Elasticsearch + searchkick, or Algolia. Both are better at
#  typo tolerance, scoring and suggestions — and both cost an external
#  service. Start here; move only when you can name what you are missing.
#
# gem "pg_search"

# -----------------------------------------------------------------------------
#  OPTIONAL — file uploads
# -----------------------------------------------------------------------------
#  Active Storage is built in but NOT installed: run
#  `rails active_storage:install`. A host's filesystem is usually ephemeral,
#  so uploads need an external service.
#
# gem "cloudinary"                  # storage plus transformation: crop, quality,
#                                   # watermark, face-aware thumbnails
# gem "image_processing", "~> 1.2"  # only for local variants

# -----------------------------------------------------------------------------
#  OPTIONAL — talking to a language model
# -----------------------------------------------------------------------------
#  ruby_llm  config/initializers/ruby_llm.rb, key from ENV — never in code.
#            Switching provider is a model string, not a rewrite.
#            /!\ Three protections before this reaches production: key out of
#                the repository, a spending cap, and authentication in front
#                of every action that calls a model.
#
#  neighbor  vector search for RAG. Needs the pgvector extension:
#            `CREATE EXTENSION vector;`
#            /!\ The column dimension must match the embedding model.
#
# gem "ruby_llm", "~> 1.2"
# gem "neighbor"

group :development, :test do
  gem "dotenv-rails"                # keys live in .env, which is gitignored.
                                    # /!\ Check `git status` before committing:
                                    #     that is what separates a protected key
                                    #     from a published one.
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "pry-byebug"                  # binding.pry, and stepping through code
  gem "pry-rails"                   # the Rails console becomes a Pry console
  gem "faker"                       # believable seed data

  gem "rubocop-rails-omakase", require: false
  gem "brakeman", require: false    # static security scan
  gem "bundler-audit", require: false
end

group :development do
  gem "web-console"
  gem "hotwire-livereload"          # the browser reloads itself when CSS or JS
                                    # changes. Pure comfort, and you notice it
                                    # the day it is missing.
  gem "httplog"                     # logs every outgoing HTTP request. Without
                                    # it you debug an API call blind — this is
                                    # what makes LLM calls inspectable.
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
