# Architecture

This document describes the high-level architecture of FetcheableOnApi.
If you want to familiarize yourself with the codebase, you are in the
right place.

## Bird's Eye View

FetcheableOnApi is a Rails controller concern that translates JSONAPI
query parameters into ActiveRecord scopes. Controllers declare which
attributes are filterable and sortable at class level. At request time,
a single method, `apply_fetcheable`, reads the query string and
applies filtering, sorting, and pagination to any ActiveRecord relation,
in that order.

```
  HTTP request
  ┌────────────────────────────────────────────────────┐
  │ ?filter[name]=john&sort=-created_at&page[number]=2 │
  └────────────────────┬───────────────────────────────┘
                       │
              apply_fetcheable(collection)
                       │
           ┌───────────┼───────────┐
           v           v           v
       Filterable   Sortable    Pageable
       (Arel WHERE) (Arel ORDER) (LIMIT/OFFSET + headers)
           │           │           │
           └───────────┼───────────┘
                       v
              ActiveRecord::Relation
```

The gem auto-includes itself into all ActionController classes via
`ActiveSupport.on_load :action_controller`, so controllers get
`filter_by`, `sort_by`, and `apply_fetcheable` without manual includes.

## Code Map

### `lib/fetcheable_on_api.rb`

The main entry point. Defines the `FetcheableOnApi` module, which
includes the three concern modules (`Filterable`, `Sortable`, `Pageable`)
into any class that includes it. Provides:

- `apply_fetcheable(collection)`, the single public-facing method
  controllers call. Chains `apply_filters` → `apply_sort` →
  `apply_pagination`.
- `foa_valid_parameters!`, shared parameter type validation used by all
  three concerns.
- `foa_string_to_datetime`, overridable hook for date format conversion.
- Custom exception classes: `FetcheableOnApi::ArgumentError`,
  `FetcheableOnApi::NotImplementedError`.

Key files: `lib/fetcheable_on_api.rb`.

**Architecture Invariant:** `apply_fetcheable` always applies operations
in the order filter → sort → paginate. Pagination must come last because
it depends on the filtered count for header accuracy.

### `lib/fetcheable_on_api/filterable.rb`

Handles `filter[attribute]=value` query parameters. The `filter_by`
class method stores per-attribute configuration (predicate, class name,
column alias, format) in a `filters_configuration` class attribute.
At request time, `apply_filters` reads `params[:filter]`, iterates
configured attributes, and builds Arel predicates combined with AND
logic. Multiple values for the same field use OR logic.

Key types/constants: `Filterable::ClassMethods` (provides `filter_by`),
`PREDICATES_WITH_ARRAY` (list of predicates expecting array values).

Key methods: `apply_filters`, `predicates` (the large case statement
that maps predicate symbols to Arel nodes), `apply_format_conversion`.

**Architecture Invariant:** only attributes explicitly declared via
`filter_by` are filterable. Undeclared filter params are silently
ignored by Rails strong parameters (`permit`).

### `lib/fetcheable_on_api/sortable.rb`

Handles `sort=field1,-field2` query parameters. The `sort_by` class
method stores configuration in `sorts_configuration`. At request time,
`apply_sort` parses the comma-separated sort string, maps `+`/`-`
prefixes to `:asc`/`:desc`, and builds Arel ordering expressions.

Key types/constants: `Sortable::ClassMethods` (provides `sort_by`),
`SORT_ORDER` (maps `+`/`-` to `:asc`/`:desc`).

Key methods: `apply_sort`, `format_params` (parses the sort string),
`arel_sort` (builds per-field Arel order nodes).

**Architecture Invariant:** `arel_sort` returns nil for unconfigured or
non-existent attributes, and `apply_sort` compacts nils. This means
unknown sort fields are silently dropped, not errored.

### `lib/fetcheable_on_api/pageable.rb`

Handles `page[number]` and `page[size]` query parameters. Unlike the
other two modules, Pageable has no class-level configuration, it is
always active. It applies `LIMIT`/`OFFSET` to the collection and writes
four pagination headers to the response.

Key methods: `apply_pagination`, `extract_pagination_informations`,
`define_header_pagination`.

**Architecture Invariant:** if `params[:page]` is absent, no pagination
is applied and no headers are set. The collection passes through
untouched.

### `lib/fetcheable_on_api/configuration.rb`

Singleton configuration object accessed via
`FetcheableOnApi.configuration`. Currently holds one setting:
`pagination_default_size` (default: 25). Set via a `configure` block
in a Rails initializer.

### `lib/generators/`

Rails generator for `rails generate fetcheable_on_api:install`. Creates
the initializer file at `config/initializers/fetcheable_on_api.rb`.

Key files: `generators/fetcheable_on_api/install_generator.rb`,
`generators/templates/fetcheable_on_api_initializer.rb`.

## Invariants

- **Dependency direction:** the three concern modules (`Filterable`,
  `Sortable`, `Pageable`) never depend on each other. They share only
  the parent module's protected helpers (`foa_valid_parameters!`,
  `foa_string_to_datetime`).

- **Configuration isolation:** each concern uses `class_attribute` with
  `instance_writer: false` and duplicates the hash on every `filter_by`
  / `sort_by` call. This prevents child controllers from mutating a
  parent's configuration.

- **Parameter whitelisting:** user-supplied filter/sort/page params are
  validated and permitted before use. `Filterable` uses
  `params.require(:filter).permit(...)` with keys derived solely from
  `filters_configuration`. `Sortable` validates the sort param is a
  `String`. `Pageable` validates the page param is a `Hash`.

- **No runtime monkey-patching:** the gem adds behavior through module
  inclusion only, never reopens ActiveRecord or Arel classes.

## Cross-Cutting Concerns

**Parameter validation.** All three concerns delegate to
`foa_valid_parameters!` in the parent module, which checks param types
against a permitted list and raises `FetcheableOnApi::ArgumentError` on
mismatch. `Filterable` overrides `foa_default_permitted_types` to also
allow `Array`.

**Association handling.** Both `Filterable` and `Sortable` support the
`class_name:` and `association:` options to operate on joined tables.
The controller is responsible for calling `.joins(...)` on the
collection before passing it to `apply_fetcheable`.

**Testing.** Tests live in `spec/` and use RSpec. The test suite mocks
ActionController with helper classes defined in
`spec/support/test_helpers.rb`. Multi-Rails-version testing is supported
via gemfiles in `gemfiles/`.

## A Typical Change

**Adding a new filter predicate** (e.g., `:starts_with`):

1. Add the Arel mapping in the `predicates` case statement in
   `lib/fetcheable_on_api/filterable.rb`.
2. If the predicate expects array values, add its symbol to
   `PREDICATES_WITH_ARRAY`.
3. Add a test case in `spec/filterable_spec.rb`.

**Adding a new configuration option** (e.g., `default_sort_direction`):

1. Add the `attr_accessor` and default in
   `lib/fetcheable_on_api/configuration.rb`.
2. Reference it in the relevant concern module.
3. Update the generator template in
   `lib/generators/templates/fetcheable_on_api_initializer.rb`.
4. Add a test in `spec/configuration_spec.rb`.
