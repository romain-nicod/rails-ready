# =============================================================================
#  rails-ready -- a Rails 8 application template
# =============================================================================
#  Run it at creation time:
#
#    rails new -d postgresql \
#      -m https://raw.githubusercontent.com/romain-nicod/rails-ready/main/template.rb \
#      my_app
#
#  It is a GENERATOR, not a skeleton frozen in a repository -- which is why it
#  does not rot between framework releases.
#
#  What it is: the base taught at Le Wagon's bootcamp (Sprockets, Bootstrap,
#  Font Awesome, Simple Form, the component stylesheet layout), plus what a
#  project reaches for in week two and has to install by hand every time.
#
#  Four deliberate departures from that base are marked DEPARTURE below. Each
#  one is a bug we paid for, not a preference.
# =============================================================================

# /!\ ASCII ONLY in this file. Thor loads a template with instance_eval
#     without declaring UTF-8, so a single em dash in a comment breaks the
#     heredoc delimiters and the parser reports errors far from the cause.
#     `ruby -c` does NOT catch this -- it reads the file as UTF-8.
RUBY_READY_VERSION = "0.1.0"

say "\n  rails-ready #{RUBY_READY_VERSION}", :green

# -----------------------------------------------------------------------------
#  Gemfile
# -----------------------------------------------------------------------------
inject_into_file "Gemfile", before: "group :development, :test do" do
  <<~RUBY
    # --- Asset pipeline: Sprockets, not Propshaft --------------------------
    # The bootstrap gem needs Sprockets. The two do NOT coexist: going back to
    # Propshaft means removing both gems below AND restoring propshaft.
    gem "sprockets-rails"
    gem "sassc-rails"

    # --- Front-end ---------------------------------------------------------
    gem "bootstrap", "~> 5.3"
    gem "autoprefixer-rails"
    gem "font-awesome-sass", "~> 6.1"
    gem "simple_form"

    # --- Jobs dashboard ----------------------------------------------------
    # Mount it behind an authorisation check -- see docs/CONFIGURATION.md.
    gem "mission_control-jobs"

    # --- Optional, uncomment when the project needs it ---------------------
    # Each one carries its setup steps in docs/CONFIGURATION.md.
    #
    # gem "devise"                  # accounts and sessions
    # gem "pundit"                  # who may do what
    # gem "pg_search"               # full-text search, no external service
    # gem "ruby_llm", "~> 1.2"      # talk to a language model
    # gem "neighbor"                # vector search for RAG (needs pgvector)
    # gem "cloudinary"              # image hosting and transformation

  RUBY
end

inject_into_file "Gemfile", after: "group :development, :test do" do
  <<~RUBY

    gem "dotenv-rails"
    gem "pry-byebug"
    gem "pry-rails"
    gem "faker"
  RUBY
end

# DEPARTURE 1 -- a development group the Wagon template does not create.
# httplog is what makes an outgoing API call inspectable; without it you debug
# a language-model call blind.
append_file "Gemfile", <<~RUBY

  group :development do
    gem "hotwire-livereload"
    gem "httplog"
  end
RUBY

gsub_file("Gemfile", /^gem "propshaft".*\n/, "")

# -----------------------------------------------------------------------------
#  Stylesheets
# -----------------------------------------------------------------------------
# DEPARTURE 2 -- download FIRST, delete second.
# The Wagon template removes app/assets/stylesheets before fetching the new
# ones. A dropped connection at that moment leaves the application with no
# stylesheets at all. Here a failed download leaves Rails' own CSS in place.
say "  Fetching stylesheets...", :green
run "curl -fsSL https://github.com/lewagon/rails-stylesheets/archive/rails-8.zip > /tmp/stylesheets.zip"

if File.exist?("/tmp/stylesheets.zip") && File.size("/tmp/stylesheets.zip") > 1024
  run "rm -rf app/assets/stylesheets vendor"
  run "unzip -q /tmp/stylesheets.zip -d app/assets"
  run "rm -f /tmp/stylesheets.zip app/assets/rails-stylesheets-rails-8/README.md"
  run "mv app/assets/rails-stylesheets-rails-8 app/assets/stylesheets"
else
  say "  ! Stylesheet download failed -- keeping Rails' default CSS.", :red
  say "    Fetch them later from github.com/lewagon/rails-stylesheets", :red
end

# Sprockets manifest -- Rails 8 does not create one, and sprockets-rails
# REFUSES TO BOOT without it. It must exist before bundle, otherwise every
# `rails` command the template runs afterwards aborts. Measured on a real run.
run "mkdir -p app/assets/config"
file "app/assets/config/manifest.js", <<~JS
  //= link_tree ../images
  //= link_directory ../stylesheets .css
  //= link popper.js
  //= link bootstrap.min.js
JS

# -----------------------------------------------------------------------------
#  Layout
# -----------------------------------------------------------------------------
gsub_file(
  "app/views/layouts/application.html.erb",
  '<meta name="viewport" content="width=device-width,initial-scale=1">',
  '<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">'
)

# Rails 8.1 generates `stylesheet_link_tag :app`; earlier versions use
# "application". Handle both rather than guessing.
gsub_file("app/views/layouts/application.html.erb", "stylesheet_link_tag :app", 'stylesheet_link_tag "application"')

# -----------------------------------------------------------------------------
#  Generators
# -----------------------------------------------------------------------------
environment <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end

RUBY

# Background jobs run through Solid Queue. Without this line they execute
# SYNCHRONOUSLY without warning.
environment 'config.active_job.queue_adapter = :solid_queue'

# -----------------------------------------------------------------------------
#  Puma -- one terminal, not two
# -----------------------------------------------------------------------------
# Rails 8.1 already writes a Solid Queue line into config/puma.rb, gated on
# SOLID_QUEUE_IN_PUMA. We REPLACE it rather than append our own: two
# `plugin :solid_queue` lines in one config is confusing at best.
#
# Why not just set SOLID_QUEUE_IN_PUMA in .env? Because Puma reads this file
# before Rails boots, so dotenv has not loaded yet -- the variable would be
# empty exactly when it is read.
gsub_file "config/puma.rb",
  /^# Run the Solid Queue supervisor.*\nplugin :solid_queue if ENV\["SOLID_QUEUE_IN_PUMA"\]$/,
  <<~RUBY.strip
    # Run the job worker inside the web process in development, so `rails s` is
    # the only command you need. In production the worker gets its own process --
    # see the Procfile. Set SOLID_QUEUE_IN_PUMA to force it on elsewhere.
    if ENV.fetch("RAILS_ENV", "development") == "development" || ENV["SOLID_QUEUE_IN_PUMA"]
      plugin :solid_queue
    end
  RUBY

# -----------------------------------------------------------------------------
#  Procfile -- the production counterpart of the puma plugin above
# -----------------------------------------------------------------------------
file "Procfile", <<~TXT
  web: bundle exec puma -C config/puma.rb
  worker: bin/jobs
TXT

########################################
after_bundle do
  rails_command "db:drop db:create db:migrate"
  generate("simple_form:install", "--bootstrap")
  generate(:controller, "pages", "home", "--skip-routes", "--no-test-framework")
  route 'root to: "pages#home"'

  # ---------------------------------------------------------------------------
  #  Assets
  # ---------------------------------------------------------------------------
  run "rm -f app/assets/stylesheets/application.css app/assets/stylesheets/app.css"
  file "app/assets/stylesheets/application.scss", <<~SCSS unless File.exist?("app/assets/stylesheets/application.scss")
    @import "bootstrap";
    @import "font-awesome";
  SCSS

  # sprockets-rails appends its own link_tree lines during install, which can
  # duplicate ours. Collapse the file to unique lines, order preserved.
  manifest = "app/assets/config/manifest.js"
  if File.exist?(manifest)
    lines = File.readlines(manifest).map(&:rstrip).reject(&:empty?).uniq
    File.write(manifest, lines.join("\n") + "\n")
  end

  append_file "config/importmap.rb", <<~RUBY
    pin "bootstrap", to: "bootstrap.min.js", preload: true
    pin "@popperjs/core", to: "popper.js", preload: true
  RUBY

  append_file "config/initializers/assets.rb", <<~RUBY
    Rails.application.config.assets.precompile += %w(bootstrap.min.js popper.js)
  RUBY

  append_file "app/javascript/application.js", <<~JS
    import "@popperjs/core"
    import "bootstrap"
  JS

  # ---------------------------------------------------------------------------
  #  Live reload
  # ---------------------------------------------------------------------------
  gsub_file(
    "app/views/layouts/application.html.erb",
    'stylesheet_link_tag "application", "data-turbo-track": "reload"',
    'stylesheet_link_tag "application", "data-turbo-track": Rails.env.production? ? "reload" : ""'
  )

  # ---------------------------------------------------------------------------
  #  Secrets
  # ---------------------------------------------------------------------------
  # DEPARTURE 3 -- the negation goes AFTER every .env rule, at the very end.
  # Git keeps the LAST matching rule. Rails 8.1 already writes `/.env*` partway
  # down its own .gitignore, so a `!.env.example` placed above it is dead: the
  # later rule wins and the example file is never tracked. Measured, not
  # assumed -- the first version of this template put it on top and .env.example
  # silently stayed untracked.
  run "touch .env"
  file ".env.example", <<~TXT
    # Copy to .env and fill in. .env is gitignored; .env.example is not.
    # Never commit real values -- a key that was committed and then removed is
    # still leaked: revoke it and rotate it at the source.
  TXT

  append_file ".gitignore", <<~TXT

    # macOS / editors
    .DS_Store
    *.swp

    # Credentials: .env stays local, .env.example is committed.
    # This negation MUST stay last -- see DEPARTURE 3 above.
    .env*
    !.env.example
  TXT

  # ---------------------------------------------------------------------------
  #  Solid Queue, Cache and Cable -- one database, not four
  # ---------------------------------------------------------------------------
  # Not scripted: each install copies a schema file into a migration, and the
  # schema differs between Rails patch releases. Doing it blind here would
  # produce a migration that silently does not match the gem. The exact steps
  # are in docs/CONFIGURATION.md, and they take about three minutes.
  say "\n  ! Single-database setup for solid_queue / solid_cache / solid_cable", :yellow
  say "    is NOT done automatically. See docs/CONFIGURATION.md before deploying --", :yellow
  say "    without it a paid host bills four databases where one would do.", :yellow

  # ---------------------------------------------------------------------------
  #  Heroku
  # ---------------------------------------------------------------------------
  run "bundle lock --add-platform x86_64-linux"

  # ---------------------------------------------------------------------------
  #  Quality
  # ---------------------------------------------------------------------------
  # DEPARTURE 4 -- do NOT overwrite .rubocop.yml, and do NOT delete the CI
  # workflow. The Wagon template does both, silently: the rules the project
  # documents stop being the rules that run, and pull requests lose their
  # checks. You find out at the first review.
  unless File.exist?(".rubocop.yml")
    file ".rubocop.yml", <<~YAML
      inherit_gem:
        rubocop-rails-omakase: rubocop.yml
    YAML
  end

  # ---------------------------------------------------------------------------
  #  Git
  # ---------------------------------------------------------------------------
  git :init
  git add: "."
  git commit: %(-m "Initial commit from rails-ready #{RUBY_READY_VERSION}")

  say "\n  Done. Next:", :green
  say "    bin/rails db:migrate"
  say "    bin/dev            # or `rails s` -- jobs run in the same process"
  say "\n  Read docs/CONFIGURATION.md before deploying.\n", :green
end
