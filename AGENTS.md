# Chatwoot Development Guidelines

## Build / Test / Lint

- **Setup**: `bundle install && pnpm install`
- **Run Dev**: `pnpm dev` or `overmind start -f ./Procfile.dev`
- **Seed Local Test Data**: `bundle exec rails db:seed` (quickly populates minimal data for standard feature verification)
- **Seed Search Test Data**: `bundle exec rails search:setup_test_data` (bulk fixture generation for search/performance/manual load scenarios)
- **Seed Account Sample Data (richer test data)**: `Seeders::AccountSeeder` is available as an internal utility and is exposed through Super Admin `Accounts#seed`, but can be used directly in dev workflows too:
  - UI path: Super Admin → Accounts → Seed (enqueues `Internal::SeedAccountJob`).
  - CLI path: `bundle exec rails runner "Internal::SeedAccountJob.perform_now(Account.find(<id>))"` (or call `Seeders::AccountSeeder.new(account: Account.find(<id>)).perform!` directly).
- **Lint JS/Vue**: `pnpm eslint` / `pnpm eslint:fix`
- **Lint Ruby**: `bundle exec rubocop -a`
- **Test JS**: `pnpm test` or `pnpm test:watch`
- **Test Ruby**: `bundle exec rspec spec/path/to/file_spec.rb`
- **Single Test**: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- **Run Project**: `overmind start -f Procfile.dev`
- **Ruby Version**: Manage Ruby via `rbenv` and install the version listed in `.ruby-version` (e.g., `rbenv install $(cat .ruby-version)`)
- **rbenv setup**: Before running any `bundle` or `rspec` commands, init rbenv in your shell (`eval "$(rbenv init -)"`) so the correct Ruby/Bundler versions are used
- Always prefer `bundle exec` for Ruby CLI tasks (rspec, rake, rubocop, etc.)

## Code Style

- **Ruby**: Follow RuboCop rules (150 character max line length)
- **Vue/JS**: Use ESLint (Airbnb base + Vue 3 recommended)
- **Vue Components**: Use PascalCase
- **Events**: Use camelCase
- **I18n**: No bare strings in templates; use i18n
- **Error Handling**: Use custom exceptions (`lib/custom_exceptions/`)
- **Models**: Validate presence/uniqueness, add proper indexes
- **Type Safety**: Use PropTypes in Vue, strong params in Rails
- **Naming**: Use clear, descriptive names with consistent casing
- **Vue API**: Always use Composition API with `<script setup>` at the top

## Styling

- **Tailwind Only**:
  - Do not write custom CSS
  - Do not use scoped CSS
  - Do not use inline styles
  - Always use Tailwind utility classes
- **Colors**: Refer to `tailwind.config.js` for color definitions

## General Guidelines

- MVP focus: Least code change, happy-path only
- No unnecessary defensive programming
- Ship the happy path first: limit guards/fallbacks to what production has proven necessary, then iterate
- Prefer minimal, readable code over elaborate abstractions; clarity beats cleverness
- Break down complex tasks into small, testable units
- Iterate after confirmation
- Avoid writing specs unless explicitly asked
- Remove dead/unreachable/unused code
- Don’t write multiple versions or backups for the same logic — pick the best approach and implement it
- Prefer `with_modified_env` (from spec helpers) over stubbing `ENV` directly in specs
- Specs in parallel/reloading environments: prefer comparing `error.class.name` over constant class equality when asserting raised errors

## Codex Worktree Workflow

- Use a separate git worktree + branch per task to keep changes isolated.
- Keep Codex-specific local setup under `.codex/` and use `Procfile.worktree` for worktree process orchestration.
- The setup workflow in `.codex/environments/environment.toml` should dynamically generate per-worktree DB/port values (Rails, Vite, Redis DB index) to avoid collisions.
- Start each worktree with its own Overmind socket/title so multiple instances can run at the same time.

## Commit Messages

- Prefer Conventional Commits: `type(scope): subject` (scope optional)
- Example: `feat(auth): add user authentication`
- Don't reference Claude in commit messages

## PR Description Format

- Start with a short, user-facing paragraph describing the product change.
- Add a `Closes` section with relevant issue links (GitHub, Linear, etc.).
- For feature PRs, add `How to test` from a product/UX standpoint.
- For bugfix PRs, use `How to reproduce` when helpful.
- Optionally add a `What changed` section for implementation highlights.
- Do not add a `How this was tested` section listing specs/commands.

## Project-Specific

- **Translations**:
  - Only update `en.yml` and `en.json`
  - Other languages are handled by the community
  - Backend i18n → `config/locales/en.yml` (plus `enterprise/config/locales/en.yml` when applicable)
  - Frontend i18n → English JSON files under `app/javascript/dashboard/i18n/locale/en/` (split into many `*.json` files), with parallel trees for `widget/`, `portal/`, `survey/`
- **Frontend apps** (separate Vue entry points under `app/javascript/`):
  - `dashboard/` – agent SPA (most work happens here)
  - `widget/` – embeddable chat widget; `sdk/` – loader script for the widget
  - `portal/` – help-center; `survey/`, `v3/`, `superadmin_pages/`
  - Shared code in `app/javascript/shared/`; design tokens in `app/javascript/design-system/`
  - Use `app/javascript/dashboard/components-next/` for message bubbles (the rest is being deprecated)
- **Frontend state**: dual stack. Legacy Vuex modules in `app/javascript/dashboard/store/modules/` (built via `storeFactory.js`); new Pinia stores in `app/javascript/dashboard/stores/` (e.g. `calls.js`, `companies.js`) and `store/captain/`. Prefer Pinia for new modules.
- **Frontend routes** live in `app/javascript/dashboard/routes/` (`index.js` + `dashboard/`), not `config/routes.rb`.
- **API surfaces** (place new endpoints in the correct tree under `app/controllers/`):
  - `api/v1/` – primary authenticated agent API
  - `api/v2/` – next-gen endpoints
  - `public/api/v1/` – unauthenticated portal/widget APIs
  - `platform/api/v1/` – server-to-server platform API (platform-app token auth)
  - `webhooks/`, `widget/`, and channel-specific controllers (`twilio/`, `instagram/`, `microsoft/`, …)
  - Swagger source lives in `swagger/` and must be updated alongside API changes.

## Ruby Best Practices

- Use compact `module/class` definitions; avoid nested styles
- **Backend layering** — keep controllers thin and route work to:
  - **Builders** (`app/builders/`) – orchestrate creation of complex aggregates (e.g. `ConversationBuilder`, `Messages::MessageBuilder`)
  - **Finders** (`app/finders/`) – query/filter logic
  - **Services** (`app/services/`) – stateless business operations; instantiated then `.perform`/`.perform!`
  - **Listeners** (`app/listeners/`) extend `BaseListener` and subscribe via the Wisper-style **Dispatchers** in `app/dispatchers/` (`sync_dispatcher`, `async_dispatcher`, invoked through `EventDispatcherJob`)
  - **Drops** (`app/drops/`) – Liquid presenters for templating; **Presenters** (`app/presenters/`) – view-model wrappers
- **Pundit policies**: every API resource needs a matching `*_policy.rb` in `app/policies/`; controllers call `authorize` via `Api::V1::Accounts::BaseController`.
- **Sidekiq jobs**: domain-grouped under `app/jobs/` (`conversations/`, `webhooks/`, `notification/`, …). Internal/maintenance/cron jobs live under `app/jobs/internal/` and are scheduled in `config/schedule.yml`. Use `MutexApplicationJob` for distributed locking. Queue names defined in `config/sidekiq.yml`.
- **ActionCable**: single `RoomChannel` (`app/channels/room_channel.rb`); broadcasts go through `ActionCableListener` + `ActionCableBroadcastJob`. Don't add new channels — emit events through the dispatcher instead.
- **Migrations** in `db/migrate/`: for indexes on large tables use `disable_ddl_transaction!` + `algorithm: :concurrently` (existing precedent). Schema is committed at `db/schema.rb`.

## Enterprise Edition Notes

- Chatwoot has an Enterprise overlay under `enterprise/` that extends/overrides OSS code.
- When you add or modify core functionality, always check for corresponding files in `enterprise/` and keep behavior compatible.
- Follow the Enterprise development practices documented here:
  - https://chatwoot.help/hc/handbook/articles/developing-enterprise-edition-features-38

Practical checklist for any change impacting core logic or public APIs
- Search for related files in both trees before editing (e.g., `rg -n "FooService|ControllerName|ModelName" app enterprise`).
- If adding new endpoints, services, or models, consider whether Enterprise needs:
  - An override (e.g., `enterprise/app/...`), or
  - An extension point (e.g., `prepend_mod_with`, hooks, configuration) to avoid hard forks.
- Avoid hardcoding instance- or plan-specific behavior in OSS; prefer configuration, feature flags, or extension points consumed by Enterprise.
- Keep request/response contracts stable across OSS and Enterprise; update both sets of routes/controllers when introducing new APIs.
- When renaming/moving shared code, mirror the change in `enterprise/` to prevent drift.
- Tests: Add Enterprise-specific specs under `spec/enterprise`, mirroring OSS spec layout where applicable.
- When modifying existing OSS features for Enterprise-only behavior, add an Enterprise module (via `prepend_mod_with`/`include_mod_with`) instead of editing OSS files directly—especially for policies, controllers, and services. For Enterprise-exclusive features, place code directly under `enterprise/`.
- The Enterprise overlay is an autoload path (not a fork): `enterprise/app/` mirrors `app/`, and modules are wired in by `prepend_mod_with('ClassName')` calls placed at the **bottom** of the OSS file (see examples in `app/builders/*`, `app/services/*`, `app/controllers/api/v1/accounts_controller.rb`). When adding a new class that may need EE behavior, end the file with this hook.

## Branding / White-labeling note

- For user-facing strings that currently contain "Chatwoot" but should adapt to branded/self-hosted installs, prefer applying `replaceInstallationName` from `shared/composables/useBranding` in the UI layer (for example tooltip and suggestion labels) instead of adding hardcoded brand-specific copy.
