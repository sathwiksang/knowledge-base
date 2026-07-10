# Test Suite Documentation

Comprehensive guide to the Knowledge Base API test suite — how it's organized,
how to run it, how to read coverage reports, and how to add new tests.

---

## 1. Overview

### Testing Philosophy

This project follows a **layered testing strategy**:

- **Unit tests** verify individual classes in isolation (models, services, error
  classes, blueprints).
- **Request specs** test the full HTTP stack — routing, authentication,
  authorization, parameter handling, serialization, and error responses — without
  a browser.
- **Integration / contract specs** validate end-to-end workflows and ensure API
  responses match their documented schemas (via RSwag).
- **Edge-case specs** explicitly cover boundary conditions, encoding quirks, and
  malicious input (SQL injection, XSS payloads, null bytes).
- **Performance specs** enforce response-time budgets so regressions are caught
  before deploy.
- **Security specs** verify the application stores dangerous payloads as literal
  strings, never executing them.

The guiding principle: **every layer tests what it owns**. Models test
validations and scopes, services test business logic and external-call handling,
and request specs test the HTTP contract.

### Test Types

| Type | Location | What it exercises |
|------|----------|-------------------|
| Model | `spec/models/` | Validations, associations, scopes, instance methods |
| Service | `spec/services/` | Business logic, external service integration |
| Request | `spec/requests/` | Full HTTP cycle (routing, auth, params, responses) |
| Controller | `spec/controllers/` | Concerns and controller-specific logic |
| Job | `spec/jobs/` | Background job execution, retries, error handling |
| Blueprint | `spec/blueprints/` | JSON serialization output for each view |
| Integration | `spec/integration/` | End-to-end workflows via RSwag |
| Edge case | `spec/edge_cases/` | Boundary conditions, encoding, large payloads |
| Security | `spec/security/` | Injection attack prevention |
| Performance | `spec/performance/` | Response-time and memory benchmarks |
| Contract | `spec/contract/` | API response schema validation |
| Middleware | `spec/middleware/` | Rack middleware behavior |
| Error | `spec/errors/` | Custom error classes and serialization |
| Client | `spec/lib/clients/` | External HTTP client (Ollama) |
| Mailer | `spec/mailers/` | Mailer configuration |

### How to Run Tests

```bash
# Run everything
bundle exec rspec

# Run with documentation output
bundle exec rspec --format documentation

# Run a single file
bundle exec rspec spec/models/user_spec.rb

# Run a single test by line number
bundle exec rspec spec/models/user_spec.rb:15

# Run a folder
bundle exec rspec spec/services/

# Run in parallel (uses all CPU cores)
bundle exec parallel_test spec/
```

---

## 2. Coverage

### Current Coverage

| Metric | Value |
|--------|-------|
| **Overall line coverage** | **93.57%** (1222 / 1306 lines) |
| **Total examples** | **771** |
| **Failures** | **0** |
| **Minimum overall threshold** | 85% (enforced by SimpleCov) |
| **Minimum per-file threshold** | 70% (enforced by SimpleCov) |

### Coverage by Folder

| Group | Coverage | Lines |
|-------|----------|-------|
| Models | 100.0% | 56 / 56 |
| Errors | 100.0% | 103 / 103 |
| Mailers | 100.0% | 3 / 3 |
| Blueprints | 98.2% | 55 / 56 |
| Middleware | 97.0% | 32 / 33 |
| Jobs | 96.8% | 92 / 95 |
| Services | 93.4% | 494 / 529 |
| Controllers | 91.2% | 332 / 364 |
| Clients | 82.1% | 55 / 67 |

### How to View the Coverage Report

SimpleCov generates an HTML report after every test run:

```bash
# Run tests (report is generated automatically)
bundle exec rspec

# Open the HTML report
open coverage/index.html
```

The report shows:

- **Per-file coverage** — click any file to see line-by-line hit counts.
- **Group breakdown** — files are organized by the groups defined in
  `rails_helper.rb` (Controllers, Models, Services, Jobs, Blueprints, Errors,
  Clients, Middleware).
- **Uncovered lines** highlighted in red — these are the exact lines that no
  test exercises.

### SimpleCov Configuration

Defined at the top of `spec/rails_helper.rb`:

```ruby
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'

  add_group 'Controllers', 'app/controllers'
  add_group 'Models',      'app/models'
  add_group 'Services',    'app/services'
  add_group 'Jobs',        'app/jobs'
  add_group 'Blueprints',  'app/blueprints'
  add_group 'Errors',      'app/errors'
  add_group 'Clients',     'lib/clients'
  add_group 'Middleware',   'lib/middleware'

  minimum_coverage 85
  minimum_coverage_by_file 70
end
```

If coverage drops below these thresholds, `rspec` exits with a non-zero status
and prints which files are below the minimum.

---

## 3. Spec Folders in Detail

### `spec/models/` — Model Specs

**What it tests:** ActiveRecord validations, associations, scopes, default
values, and instance methods.

**Key files:**

| File | Tests | Purpose |
|------|-------|---------|
| `user_spec.rb` | 9 | Email validation/normalization, `has_secure_password`, `has_many :knowledge_bases` |
| `knowledge_base_spec.rb` | 10 | Name uniqueness scoped to user, stat methods (`total_documents`, `indexed_documents`, `total_chunks`) |
| `document_spec.rb` | 18 | Status lifecycle (`pending` / `processing` / `indexed` / `failed`), scopes, transition methods (`mark_processing!`, `mark_indexed!`, `mark_failed!`) |
| `chunk_spec.rb` | 8 | Embedding dimension validation (768), `for_knowledge_base` scope, `search_similar` class method |

**Mocking:** Minimal — model specs hit the real database through transactional
fixtures.

**Factories used:** `:user`, `:knowledge_base`, `:document` (with `:processing`,
`:indexed`, `:failed` traits), `:chunk`.

**Matchers:** Shoulda Matchers for one-liner validation and association checks:

```ruby
it { should validate_presence_of(:email) }
it { should have_many(:knowledge_bases).dependent(:destroy) }
```

---

### `spec/services/` — Service Specs

**What it tests:** Business logic, external service integration, error handling,
and return value structures.

**Key files:**

| File | Tests | Purpose |
|------|-------|---------|
| `jwt_service_spec.rb` | 8 | Token encode/decode, expiration, invalid/tampered tokens |
| `embedding_service_spec.rb` | 18 | Vector generation, batch processing, dimension validation, cosine similarity |
| `text_chunker_service_spec.rb` | 25 | Text splitting, chunk size bounds, overlap, paragraph boundaries, Unicode |
| `document_processor_service_spec.rb` | 26 | Full indexing pipeline: chunk &#8594; embed &#8594; persist, status transitions, error recovery |
| `search_service_spec.rb` | 31 | pgvector similarity search, result ranking, limit/threshold params, `SearchResponse` struct |
| `rag_service_spec.rb` | 30 | RAG pipeline: search &#8594; context assembly &#8594; LLM generation, source citations, conversation history |
| `llm_service_spec.rb` | 15 | `answer_question`, `chat`, `summarize`, `extract_keywords`, availability checks |

**Mocking:** Services that call external APIs (Ollama) use **WebMock** stubs.
Service-to-service dependencies are injected via constructor or mocked with
`instance_double`:

```ruby
let(:mock_search) { instance_double(SearchService) }
allow(mock_search).to receive(:search).and_return(results)
```

**Factories used:** `:knowledge_base`, `:document` (`:indexed` trait), `:chunk`.

---

### `spec/requests/` — Request Specs

**What it tests:** The full HTTP stack — routing, authentication,
authorization, parameter parsing, controller logic, serialization, and error
responses.

**Key files:**

| File | Tests | Purpose |
|------|-------|---------|
| `api/v1/auth_spec.rb` | 15 | `POST /register`, `POST /login` — valid/invalid params, token return, email normalization |
| `api/v1/knowledge_bases_spec.rb` | 20 | CRUD, owner isolation, stats inclusion, pagination |
| `api/v1/documents_spec.rb` | 40 | CRUD, status tracking, batch reprocess, job enqueuing |
| `api/v1/search_spec.rb` | 29 | `POST /search`, `POST /ask` — query validation, result structure, error cases |

**Mocking:** External services (Ollama) are stubbed via WebMock. The
`auth_headers` helper (from `spec/support/request_helpers.rb`) generates valid
JWT tokens:

```ruby
let(:user) { create(:user) }
let(:headers) { auth_headers(user) }

get '/api/v1/knowledge_bases', headers: headers
expect(response).to have_http_status(:ok)
```

**Factories used:** All factories. Documents often use the `:indexed` trait for
search/ask tests.

---

### `spec/jobs/` — Job Specs

**What it tests:** Background job execution, retry behavior, error handling,
and status transitions.

**Key files:**

| File | Tests | Purpose |
|------|-------|---------|
| `process_document_job_spec.rb` | 17 | Single-document processing, status updates (`pending` &#8594; `processing` &#8594; `indexed`), retry on failure, priority levels |
| `batch_process_documents_job_spec.rb` | 17 | Fan-out to individual jobs, status filtering, partial failure handling, `BatchResult` struct |

**Mocking:** `DocumentProcessorService` is typically stubbed to avoid calling
Ollama. ActiveJob test adapter is configured in `rails_helper.rb`:

```ruby
config.before(:each) do
  ActiveJob::Base.queue_adapter = :test
end
```

This allows assertions like:

```ruby
expect { described_class.perform_later(document.id) }
  .to have_enqueued_job(ProcessDocumentJob)
```

**Factories used:** `:document` with various status traits.

---

### `spec/blueprints/` — Blueprint Specs

**What it tests:** Blueprinter serialization output — which fields appear in
each view, correct nesting, and field value computation.

**Key files:**

| File | Tests | Purpose |
|------|-------|---------|
| `user_blueprint_spec.rb` | 6 | Default view (id, email, created_at), `:with_stats` view |
| `knowledge_base_blueprint_spec.rb` | 13 | Default, `:with_stats`, `:with_documents` views |
| `document_blueprint_spec.rb` | 17 | Default, `:minimal`, `:detailed`, `:with_chunks` views |
| `chunk_blueprint_spec.rb` | 10 | Default view, `:with_similarity` view with score injection |
| `search_result_blueprint_spec.rb` | 11 | Struct serialization, nested document via OpenStruct, `:detailed` view |

**Mocking:** None — blueprints are tested against real ActiveRecord objects
(or Structs for `SearchResultBlueprint`).

**Factories used:** All factories. Tests create records and pass them to
`Blueprint.render_as_hash(record)`.

---

### `spec/controllers/` — Controller and Concern Specs

**What it tests:** Shared concerns (`ErrorHandler`, `ApiResponse`) and
controller-specific logic (`HealthController`).

**Key files:**

| File | Tests | Purpose |
|------|-------|---------|
| `concerns/error_handler_spec.rb` | 28 | All `rescue_from` handlers — tests each error type is caught and returns the correct HTTP status and JSON body |
| `concerns/api_response_spec.rb` | 31 | All render helpers (`render_success`, `render_created`, `render_no_content`, `render_accepted`, `render_unprocessable`, `render_not_found`, `render_unauthorized`, `render_forbidden`, `render_bad_request`, `render_service_unavailable`) |
| `api/v1/health_controller_spec.rb` | 11 | Health/liveness/readiness probes, Ollama status |

**Mocking:** `error_handler_spec.rb` uses `allow_any_instance_of` to force
specific exceptions from controller actions, exercising each `rescue_from`
handler. `api_response_spec.rb` uses a temporary test controller with dedicated
routes to exercise each helper method in isolation.

---

### `spec/edge_cases/` — Edge Case Specs

**What it tests:** Boundary conditions that could cause crashes, data
corruption, or security issues.

| File | Tests | Focus |
|------|-------|-------|
| `authentication_edge_cases_spec.rb` | 29 | Token tampering, null bytes, bcrypt 72-byte limit, Unicode emails |
| `document_edge_cases_spec.rb` | 24 | Empty content, 500KB+ documents, binary data, encoding edge cases |
| `knowledge_base_edge_cases_spec.rb` | 24 | Special characters in names, Unicode, rapid create/delete, tenant isolation |
| `search_rag_edge_cases_spec.rb` | 38 | Empty/long queries, special characters, no results, context assembly limits |

---

### `spec/security/` — Security Specs

**What it tests:** Injection attack prevention.

| File | Tests | Focus |
|------|-------|-------|
| `injection_attacks_spec.rb` | 15 | SQL injection, XSS, path traversal, header injection — verifies payloads are stored as literal strings |

---

### `spec/performance/` — Performance Specs

**What it tests:** Response time budgets using `rspec-benchmark`.

| File | Tests | Thresholds |
|------|-------|------------|
| `benchmark_spec.rb` | 14 | Auth < 500ms, List < 200ms, Search < 500ms, Create doc < 300ms, Memory < 50MB growth |

---

### `spec/integration/` — Integration Specs

**What it tests:** Full API workflows with RSwag schema validation.

| File | Purpose |
|------|---------|
| `auth_spec.rb` | Register &#8594; Login &#8594; Profile workflow |
| `health_spec.rb` | Health/liveness/readiness response schemas |
| `documents_spec.rb` | Document CRUD response schemas |
| `knowledge_bases_spec.rb` | Knowledge base CRUD response schemas |

---

### `spec/contract/` — Contract Specs

| File | Tests | Purpose |
|------|-------|---------|
| `api_contracts_spec.rb` | 42 | Validates all endpoints return the documented JSON structure |

---

### `spec/errors/` — Error Class Specs

| File | Tests | Purpose |
|------|-------|---------|
| `api_errors_spec.rb` | 47 | Every `ApiErrors::*` subclass: default messages, status codes, `to_h` serialization |

---

### `spec/middleware/` — Middleware Specs

| File | Tests | Purpose |
|------|-------|---------|
| `json_error_middleware_spec.rb` | 10 | Catches `ParseError` and `BadRequest` before Rails, returns JSON |
| `rate_limiting_spec.rb` | 7 | Rack::Attack throttle/blocklist configuration verification |

---

### `spec/lib/clients/` — External Client Specs

| File | Tests | Purpose |
|------|-------|---------|
| `ollama_client_spec.rb` | 17 | `embed`, `generate`, `chat`, `health_check` — all HTTP calls stubbed with WebMock |

---

### `spec/mailers/` — Mailer Specs

| File | Tests | Purpose |
|------|-------|---------|
| `application_mailer_spec.rb` | 2 | Base class config (default `from` address) |

---

## 4. Testing Commands Reference

### Run All Tests

```bash
bundle exec rspec
```

### Run with Documentation Output

```bash
bundle exec rspec --format documentation
```

### Run a Specific File

```bash
bundle exec rspec spec/models/user_spec.rb
```

### Run a Specific Test (by Line Number)

```bash
bundle exec rspec spec/models/user_spec.rb:15
```

### Run a Specific Folder

```bash
bundle exec rspec spec/services/
```

### Run with Coverage Report

Coverage is generated on every run by default. To view:

```bash
bundle exec rspec
open coverage/index.html
```

### Run Only Fast Tests (Exclude Performance)

```bash
bundle exec rspec --exclude-pattern "spec/performance/**/*_spec.rb"
```

### Run Only Slow / Performance Tests

```bash
bundle exec rspec spec/performance/
```

### Run Only Model Tests

```bash
bundle exec rspec spec/models/
```

### Run Only Request Tests

```bash
bundle exec rspec spec/requests/
```

### Run Tests in Parallel

```bash
bundle exec parallel_test spec/
```

### Run Tests Matching a Keyword

```bash
bundle exec rspec -e "authentication"
```

### Run with Fail-Fast (Stop on First Failure)

```bash
bundle exec rspec --fail-fast
```

### Profile Slowest Tests

```bash
bundle exec rspec --profile 10
```

---

## 5. Adding New Tests

### Adding a Model Spec

Create `spec/models/<model_name>_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyModel, type: :model do
  # -- Associations --
  it { should belong_to(:user) }
  it { should have_many(:items).dependent(:destroy) }

  # -- Validations --
  it { should validate_presence_of(:name) }
  it { should validate_uniqueness_of(:name).scoped_to(:user_id) }

  # -- Scopes --
  describe '.active' do
    it 'returns only active records' do
      active = create(:my_model, active: true)
      create(:my_model, active: false)

      expect(described_class.active).to eq([active])
    end
  end

  # -- Instance Methods --
  describe '#full_name' do
    it 'concatenates first and last name' do
      record = build(:my_model, first: 'Jane', last: 'Doe')
      expect(record.full_name).to eq('Jane Doe')
    end
  end
end
```

**Checklist:**
- Test all validations with Shoulda Matchers
- Test all associations (including `dependent` behavior)
- Test every scope with at least one positive and one negative case
- Test instance methods with representative inputs
- Add a factory in `spec/factories/` if one doesn't exist

### Adding a Service Spec

Create `spec/services/<service_name>_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyService do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user: user) }

  describe '#perform' do
    context 'with valid input' do
      it 'returns a successful result' do
        # Stub external calls
        allow(Clients::OllamaClient).to receive(:new).and_return(
          instance_double(Clients::OllamaClient, generate: 'response')
        )

        result = service.perform('input text')

        expect(result).to be_success
        expect(result.data).to be_present
      end
    end

    context 'with blank input' do
      it 'returns an error result' do
        result = service.perform('')
        expect(result).not_to be_success
        expect(result.error).to include('blank')
      end
    end

    context 'when external service fails' do
      it 'raises a service-specific error' do
        allow(Clients::OllamaClient).to receive(:new).and_raise(
          Clients::OllamaClient::ConnectionError.new('refused')
        )

        expect { service.perform('text') }
          .to raise_error(MyService::MyError)
      end
    end
  end
end
```

**Checklist:**
- Test the happy path with expected return values
- Test every error/edge case branch
- Stub all external HTTP calls (Ollama, etc.) with WebMock or instance doubles
- Verify return value structures (Structs, hashes)
- Test with nil, blank, and boundary inputs

### Adding a Request Spec

Create `spec/requests/api/v1/<resource>_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Items', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe 'GET /api/v1/items' do
    it 'returns a list of items' do
      create_list(:item, 3, user: user)

      get '/api/v1/items', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['items'].size).to eq(3)
    end

    it 'requires authentication' do
      get '/api/v1/items'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not return other users items' do
      other = create(:user)
      create(:item, user: other)

      get '/api/v1/items', headers: headers

      expect(json_response['items']).to be_empty
    end
  end

  describe 'POST /api/v1/items' do
    let(:valid_params) { { title: 'New Item', content: 'Body text' } }

    it 'creates the item' do
      expect {
        post '/api/v1/items', params: valid_params, headers: headers
      }.to change(Item, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it 'returns 422 for invalid params' do
      post '/api/v1/items', params: { title: '' }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
```

**Checklist:**
- Test every endpoint (GET, POST, PATCH, DELETE)
- Test authentication (missing token, invalid token, expired token)
- Test authorization (user can't access other user's resources)
- Test valid params (happy path)
- Test invalid params (missing required fields, bad values)
- Use `auth_headers(user)` helper for authenticated requests
- Use `json_response` helper to parse response body
- Verify response status codes and JSON structure

### Best Practices

1. **One assertion per test when practical.** Each `it` block should verify one
   behavior. This makes failures easy to diagnose.

2. **Use `let` and `let!` for setup.** `let` is lazy (created on first use),
   `let!` is eager (created before each test). Use `let!` when the record must
   exist before the test runs (e.g., for index endpoints).

3. **Use factory traits** instead of overriding attributes inline:
   ```ruby
   # Good
   create(:document, :indexed)
   # Avoid
   create(:document, status: 'indexed')
   ```

4. **Stub external services** — never make real HTTP calls in tests. WebMock
   is configured to block all external requests.

5. **Avoid `allow_any_instance_of`** when possible — prefer dependency
   injection or targeted `allow(object).to receive(...)`.

6. **Test the public interface**, not implementation details. Don't test
   private methods directly.

7. **Keep factories minimal** — only set attributes that are required by
   validations. Let tests override what they need.

8. **Use `described_class`** instead of hardcoding the class name. This keeps
   specs resilient to renames.

9. **Run the full suite before pushing.** A single `bundle exec rspec` catches
   cross-test interference.

---

## 6. CI/CD

### Current CI Pipeline (`.github/workflows/ci.yml`)

The project currently runs two CI jobs on every push to `main` and on pull
requests:

| Job | What it does |
|-----|-------------|
| `scan_ruby` | Brakeman (static security analysis) + bundler-audit (gem vulnerability scan) |
| `lint` | RuboCop with caching |

### Recommended Test Job for CI

To add test execution to the CI pipeline, add this job to
`.github/workflows/ci.yml`:

```yaml
test:
  runs-on: ubuntu-latest

  services:
    postgres:
      image: pgvector/pgvector:pg17
      env:
        POSTGRES_USER: postgres
        POSTGRES_PASSWORD: postgres
        POSTGRES_DB: knowledge_base_api_test
      ports:
        - 5432:5432
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5

  env:
    RAILS_ENV: test
    DATABASE_URL: postgres://postgres:postgres@localhost:5432/knowledge_base_api_test
    JWT_SECRET_KEY: test-secret-key-for-ci
    OLLAMA_BASE_URL: http://localhost:11434

  steps:
    - name: Checkout code
      uses: actions/checkout@v6

    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        bundler-cache: true

    - name: Set up database
      run: bin/rails db:schema:load

    - name: Run tests
      run: bundle exec rspec --format documentation

    - name: Upload coverage report
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: coverage-report
        path: coverage/
```

### Required Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `DATABASE_URL` | PostgreSQL connection (must have pgvector extension) | `postgres://user:pass@localhost:5432/kb_test` |
| `RAILS_ENV` | Must be `test` | `test` |
| `JWT_SECRET_KEY` | Secret for signing JWT tokens | Any random string |
| `OLLAMA_BASE_URL` | Ollama API endpoint (stubbed in tests, but config needs a value) | `http://localhost:11434` |

### Pre-Commit Hook Suggestion

Add a Git pre-commit hook to catch issues before they reach CI. Create
`.git/hooks/pre-commit`:

```bash
#!/usr/bin/env bash
set -e

echo "Running RuboCop..."
bundle exec rubocop --format simple

echo "Running fast tests (excluding performance)..."
bundle exec rspec --exclude-pattern "spec/performance/**/*_spec.rb" --fail-fast

echo "All checks passed."
```

Make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

Or use a tool like [overcommit](https://github.com/sds/overcommit) or
[lefthook](https://github.com/evilmartians/lefthook) for a more maintainable
hook configuration:

```yaml
# .lefthook.yml
pre-commit:
  commands:
    rubocop:
      run: bundle exec rubocop --format simple {staged_files}
      glob: "*.rb"

pre-push:
  commands:
    rspec:
      run: bundle exec rspec --fail-fast
```

---

## Appendix: Support Files

| File | Purpose |
|------|---------|
| `spec/support/request_helpers.rb` | `auth_headers(user)` and `json_response` helpers, auto-included in request specs |
| `spec/support/webmock.rb` | Blocks all external HTTP requests in tests |
| `spec/support/shoulda_matchers.rb` | Configures Shoulda Matchers for RSpec + Rails |
| `spec/factories/users.rb` | User factory (email via Faker, default password) |
| `spec/factories/knowledge_bases.rb` | Knowledge base factory (associated user, Faker name) |
| `spec/factories/documents.rb` | Document factory with `:processing`, `:indexed`, `:failed` traits |
| `spec/factories/chunks.rb` | Chunk factory (random 768-dim embedding vector) |

---

## Appendix: Gem Dependencies for Testing

| Gem | Version | Purpose |
|-----|---------|---------|
| `rspec-rails` | ~> 7.0 | RSpec integration for Rails |
| `factory_bot_rails` | ~> 6.4 | Test data factories |
| `faker` | ~> 3.4 | Realistic fake data generation |
| `simplecov` | latest | Code coverage measurement |
| `shoulda-matchers` | ~> 6.0 | One-liner validation/association matchers |
| `database_cleaner-active_record` | latest | Database cleanup between tests |
| `webmock` | ~> 3.23 | HTTP request stubbing |
| `rspec-benchmark` | ~> 0.6 | Performance assertions |
| `json_matchers` | ~> 0.11 | JSON structure validation |
| `parallel_tests` | ~> 4.7 | Multi-core test execution |
| `test-prof` | ~> 1.4 | Test profiling and optimization |
| `rswag-specs` | ~> 2.16 | API documentation from integration tests |
