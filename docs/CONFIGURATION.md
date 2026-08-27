# Configuration

What the template sets up, what it deliberately leaves to you, and how to
switch on each optional gem.

> This document is **operational**: the steps to run, and what each one
> prevents. The reasoning — which lecture said what, which alternatives were
> weighed — lives in the vault, at
> `ObsiClaud/le-wagon/bootcamp-ai-software-engineer/`. Two angles, one source
> each. Do not copy either into the other.

---

## 1. The one step the template does not take

### Single database for Solid Queue, Cache and Cable

Rails 8 ships `solid_queue`, `solid_cache` and `solid_cable`. **Each defaults
to its own database.** On a paid host that is four databases billed where one
would do.

This is not scripted, on purpose: every install copies a schema file into a
migration, and that schema changes between Rails patch releases. A generated
migration would silently drift from the gem. Three minutes by hand:

```bash
rails g migration InstallSolidQueue
rails g migration InstallSolidCache
rails g migration InstallSolidCable
```

For each one, open the matching schema file and copy everything between
`ActiveRecord::Schema[...] do` and its `end` into the migration's `change`
method:

| Migration | Schema file |
|---|---|
| `InstallSolidQueue` | `db/queue_schema.rb` |
| `InstallSolidCache` | `db/cache_schema.rb` |
| `InstallSolidCable` | `db/cable_schema.rb` |

> ⚠️ Course material in circulation names `db/queue_schema.rb` for Solid
> **Cable**. It is `db/cable_schema.rb`. Each gem has its own file.

```bash
rails db:migrate
rm db/queue_schema.rb db/cache_schema.rb db/cable_schema.rb
```

Then point all four entries at the same database:

```yaml
# config/database.yml
production:
  primary: { <<: *default, url: <%= ENV["DATABASE_URL"] %> }
  cache:   { <<: *default, url: <%= ENV["DATABASE_URL"] %> }
  queue:   { <<: *default, url: <%= ENV["DATABASE_URL"] %> }
  cable:   { <<: *default, url: <%= ENV["DATABASE_URL"] %> }
```

> 🔴 **Last step, the one everyone forgets:** remove
> `config.solid_queue.connects_to` from `config/environments/production.rb`.
> Leave it in and production still looks for a second database.

And make the Action Cable logs readable:

```yaml
# config/cable.yml
development:
  adapter: solid_cable
test:
  adapter: test
production:
  adapter: solid_cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

---

## 2. What the template already did

### Jobs run asynchronously

```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue
```

> ⚠️ Without this line, jobs run **synchronously without warning**. Everything
> appears to work and nothing is asynchronous.

### One terminal in development, a worker in production

```ruby
# config/puma.rb
if ENV.fetch("RAILS_ENV", "development") == "development"
  plugin :solid_queue
end
```

`rails s` is the only command you need locally. In production the worker gets
its own process, which is what the generated `Procfile` declares:

```
web: bundle exec puma -C config/puma.rb
worker: bin/jobs
```

```bash
heroku ps:scale worker=1
heroku ps
```

### Secrets

`.env` is created and gitignored; `.env.example` is committed and lists names
only. The ignore rule is **prepended**, above `!.env.example`, because Git
keeps the last matching rule.

> 🔴 Check `git status` before committing. That is what separates a protected
> key from a published one — and a key that was committed and then removed is
> still leaked: revoke it and rotate it at the source.

### Live reload

The layout's `data-turbo-track` is empty outside production, which is what
lets `hotwire-livereload` refresh the browser on save.

```bash
rails livereload:disable   # temporarily
rails livereload:enable
```

---

## 3. Switching on an optional gem

Uncomment it in the `Gemfile`, `bundle install`, then follow its section.

### Devise — accounts

```bash
rails generate devise:install
rails generate devise User
rails db:migrate
rails generate devise:views   # to customise them
```

The generator prints three manual steps. **Nothing works until all three are
done:**

```ruby
# 1. config/environments/development.rb
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

# 2. config/routes.rb -- a root route must exist
root to: "pages#home"
```

```erb
<%# 3. the layout must render flash messages %>
<p class="notice"><%= notice %></p>
<p class="alert"><%= alert %></p>
```

> ⚠️ Without the third, Devise redirects **without ever saying why**: the
> message is produced, nothing displays it.

Protect by allow-list, never the other way round:

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
end

class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: :home
end
```

Adding a field to sign-up takes **three** moves: a migration, the field in the
Devise views, **and** permitting the parameter:

```ruby
before_action :configure_permitted_parameters, if: :devise_controller?

def configure_permitted_parameters
  devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name])
  devise_parameter_sanitizer.permit(:account_update, keys: [:first_name])
end
```

> ⚠️ Devise does not use ordinary strong parameters. Skip this and the field
> shows up but never saves.

### Pundit — permissions

```bash
rails generate pundit:install
rails generate pundit:policy <model>
```

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  include Pundit::Authorization

  after_action :verify_authorized, except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

  private

  def skip_pundit?
    devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
  end
end
```

> 🔴 **The two `after_action` callbacks are the whole mechanism.** They make
> any action that forgot its `authorize` or `policy_scope` fail. Without them
> an omission goes unnoticed — which is the exact hole you were closing.

```ruby
# config/environments/development.rb
config.action_controller.raise_on_missing_callback_actions = false
```

> ⚠️ Replace the line if it already exists set to `true`. Rails 8 otherwise
> raises on callbacks declared for actions the controller does not define,
> which is what the Pundit setup above does on purpose.

> 🔴 `:user_id` never belongs in strong parameters. The owner comes from
> `current_user`; otherwise a visitor can create records in someone else's name.

### Mission Control — the jobs dashboard

Already in the `Gemfile`, but **not mounted**. Mounting it without an
authorisation check would expose the job queue publicly — and therefore the
contents of every job argument.

```ruby
# config/application.rb
config.mission_control.jobs.http_basic_auth_enabled = false
```

```js
// app/assets/config/manifest.js
//= link mission_control/jobs/application.js
```

> ⚠️ That manifest line is required. Without it the dashboard renders but its
> JavaScript never loads.

```bash
rails g migration AddAdminToUsers admin:boolean
```

```ruby
def change
  add_column :users, :admin, :boolean, null: false, default: false
end
```

```ruby
# config/routes.rb
authenticate :user, ->(user) { user.admin? } do
  mount MissionControl::Jobs::Engine, at: "/jobs"
end
```

### pg_search — full-text search

```ruby
class Movie < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :global_search,
    against: [:title, :synopsis],
    associated_against: { director: [:first_name, :last_name] },
    using: { tsearch: { prefix: true } }
end
```

> 💎 `prefix: true` is the setting that matters: without it a partial word
> matches nothing.

Across several models:

```bash
rails g pg_search:migration:multisearch
rails db:migrate
```

```ruby
multisearchable against: [:title, :synopsis]
```

> ⚠️ The index must be rebuilt (`PgSearch::Multisearch.rebuild(Movie)`) — it
> does not backfill existing records. Results are polymorphic: the real object
> is behind `result.searchable`.

### ruby_llm — language models

```bash
touch config/initializers/ruby_llm.rb
```

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
end
```

> 🔴 **Three protections before this reaches production:** the key out of the
> repository, a spending cap, and authentication in front of every action that
> calls a model. A deployed page is usable by anyone, and every call costs.

A message cap is the cheapest guard rail:

```ruby
# app/models/message.rb
MAX_USER_MESSAGES = 10

validate :user_message_limit, if: -> { role == "user" }
```

> 💎 Every message sends the **whole** history back to the model: the cost of a
> conversation grows quadratically, not linearly.

Tools, if the application grows into an agent:

```ruby
class CreateTicketTool < RubyLLM::Tool
  description "..."          # this is the interface -- it is all the model reads
  param :challenge_id, desc: "...", type: :integer

  def initialize(user:)      # injected, NEVER declared as a param
    @user = user
  end

  def execute(challenge_id:)
    # ...
  rescue ActiveRecord::RecordNotFound
    { error: "Not found" }   # return the error, do not raise it
  end
end
```

> 🔴 **Anything touching identity or permissions is injected through the
> constructor.** The model must never choose which user it acts as.

> ⚠️ A background job has no `current_user`: pass `@chat.user` instead.

### neighbor — vector search for RAG

```bash
psql -c "CREATE EXTENSION vector;"
rails generate neighbor:vector
rails generate migration AddEmbeddingToProducts embedding:vector{1536}
rails db:migrate
```

> 🔴 `{1536}` is the dimension of the embedding model in use. Change models and
> the column must follow, or nothing saves.

```ruby
class Product < ApplicationRecord
  has_neighbors :embedding
  after_create :set_embedding
end
```

> ⚠️ `after_create` only: a record whose text changes keeps its stale vector.
> In production, recompute on update too.

### cloudinary — file uploads

A host's filesystem is usually ephemeral: anything a user uploads disappears on
restart.

```bash
rails active_storage:install
rails db:migrate
```

```yaml
# config/storage.yml
cloudinary:
  service: Cloudinary
  folder: <%= Rails.env %>
```

```ruby
# config/environments/development.rb AND production.rb
config.active_storage.service = :cloudinary
```

```bash
heroku config:set CLOUDINARY_URL=cloudinary://...
```

> ⚠️ Restart the server after any configuration change.

Strong parameters differ between one file and many:

```ruby
params.require(:article).permit(:title, :photo)      # has_one_attached
params.require(:article).permit(:title, photos: [])  # has_many_attached
```

---

## 4. Verifying the template itself

```bash
cd $(mktemp -d)
rails new -d postgresql -m /path/to/rails-ready/template.rb --skip-ci probe
cd probe && bin/rails db:migrate && bin/rails runner 'puts "boot ok"'
```

> 🔴 **`ruby -c` is not a test.** Thor loads the template with `instance_eval`
> without declaring UTF-8, so a single non-ASCII character in a comment breaks
> heredoc parsing — and the reported error points somewhere else entirely.
> `ruby -c` reads the file as UTF-8 and sees nothing wrong. The template must
> stay **ASCII only**, and it is only tested by being run.
