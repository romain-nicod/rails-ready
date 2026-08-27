# AGENTS.md — rails-ready

**Project notes live in the vault**, not here:
`~/Documents/Claude/ObsiClaud/le-wagon/bootcamp-ai-software-engineer/`
— the decision log is `CLAUDE.md` there, the request register is
`Bootcamp AI SWE - Registre des demandes.md`.

This file carries the rules for working in this repository.

## What this repository is

A single Rails application template (`template.rb`) plus the documentation that
explains it. There is no application here — the template generates one.

## 🔴 Rules

**English only.** Code, comments, commits, documentation, issues. No exception.

**`template.rb` is the source of truth for what gets installed.** The `Gemfile`
in this repository is a *reference copy* for readers: the file that actually
runs is the one the template injects. Change one, change the other, in the
same commit.

**Every gem carries a one-line reason.** A gem whose reason cannot be stated is
a gem that should not be added.

**The three tiers are the decision**, and they are load-bearing:

| Tier | Meaning |
|---|---|
| active | uncommented. Every project wants it |
| optional | commented, with its setup steps. Nothing is imposed |
| not picked | named, with the reason, so nobody re-opens the question |

**The four `DEPARTURE` markers in `template.rb` are not preferences.** Each one
is a defect in Le Wagon's `minimal.rb` that costs time on every project. Do not
"simplify" them away — read the reason in the comment first.

## ⚠️ Traps

**Never overwrite `.rubocop.yml` or delete `.github/workflows/`.** That is
departure 4, and it is the reason this template exists rather than a fork.

**`.gitignore` order matters.** `.env*` must sit *above* `!.env.example`: Git
keeps the last matching rule.

**Do not script the single-database setup for the `solid_*` gems.** The schema
files change between Rails patch releases; a generated migration would
silently drift from the gem. It is documented in `docs/CONFIGURATION.md` on
purpose.

## Verifying a change

The template cannot be unit-tested. It is verified by running it:

```bash
cd $(mktemp -d)
rails new -d postgresql -m /path/to/rails-ready/template.rb --skip-ci probe
cd probe && bin/rails db:migrate && bin/rails runner 'puts "boot ok"'
```

🔴 **A template that has been edited but not run has not been tested.** Syntax
checking with `ruby -c` proves the file parses, nothing more.
