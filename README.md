# FetcheableOnApi

JSONAPI-compliant filtering, sorting, and pagination for Rails API controllers, declared in two lines, zero boilerplate.

---

<p align="center">
  <a href="https://badge.fury.io/rb/fetcheable_on_api"><img src="https://badge.fury.io/rb/fetcheable_on_api.svg" alt="Gem Version"></a>
  <a href="https://rubydoc.info/gems/fetcheable_on_api"><img src="https://img.shields.io/badge/docs-yard-blue.svg" alt="Documentation"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
</p>


## Quick Start

Add the gem:

```ruby
gem 'fetcheable_on_api'
```

```bash
bundle install
rails generate fetcheable_on_api:install
```

Declare what's allowed, then apply:

```ruby
class UsersController < ApplicationController
  filter_by :name, :email, :status
  sort_by :name, :created_at

  def index
    render json: apply_fetcheable(User.all)
  end
end
```

Your API now supports:

```bash
GET /users?filter[name]=john&filter[status]=active
GET /users?sort=name,-created_at
GET /users?page[number]=2&page[size]=25
GET /users?filter[status]=active&sort=-created_at&page[number]=1&page[size]=10
```

<!-- LAYER 3: DETAILS -->

## Features

- **30+ filter predicates**, `eq`, `ilike`, `between`, `in`, `gt`, `lt`, and [many more](https://github.com/fabienpiette/fetcheable_on_api/wiki/Predicates), plus custom lambdas
- **Multi-field sorting**, comma-separated fields, `+`/`-` prefix for direction, case-insensitive option
- **Automatic pagination**, page-based with response headers (`Pagination-Current-Page`, `Pagination-Per`, `Pagination-Total-Pages`, `Pagination-Total-Count`)
- **Association support**, filter and sort through ActiveRecord associations
- **Whitelisted by design**, only explicitly declared attributes are queryable

## Install

**Prerequisites:** Ruby >= 2.7, Rails >= 5.2 (ActiveSupport >= 5.2, < 9)

### Compatibility

| Ruby  | Rails 5.2 | Rails 7.0 | Rails 7.1 | Rails 7.2 | Rails 8.0 |
|-------|-----------|-----------|-----------|-----------|-----------|
| 2.7   | ✓         | ✓         | ✓         |           |           |
| 3.0   | ✓         | ✓         | ✓         |           |           |
| 3.1   |           | ✓         | ✓         | ✓         |           |
| 3.2   |           | ✓         | ✓         | ✓         | ✓         |
| 3.3   |           |           | ✓         | ✓         | ✓         |
| 3.4   |           |           |           |           | ✓         |

### Bundler (recommended)

```ruby
# Gemfile
gem 'fetcheable_on_api'
```

```bash
bundle install
rails generate fetcheable_on_api:install
```

### Manual

```bash
gem install fetcheable_on_api
```

## Usage

### Filtering

```ruby
filter_by :name                          # default: ilike (partial, case-insensitive)
filter_by :email, with: :eq              # exact match
filter_by :age, with: :gteq             # numeric comparison
filter_by :created_at, with: :between, format: :datetime  # date range
```

Filter through associations:

```ruby
filter_by :author, class_name: User, as: 'name'
```

Custom lambda predicates:

```ruby
filter_by :full_name, with: ->(collection, value) {
  collection.arel_table[:first_name].matches("%#{value}%").or(
    collection.arel_table[:last_name].matches("%#{value}%")
  )
}
```

```bash
GET /users?filter[name]=john              # partial match
GET /users?filter[status]=active,pending  # multiple values (OR)
GET /users?filter[age]=21                 # numeric
GET /users?filter[author]=jane            # through association
```

### Sorting

```ruby
sort_by :name, :created_at
sort_by :display_name, lower: true                          # case-insensitive
sort_by :author, class_name: User, as: 'name'              # through association
```

```bash
GET /users?sort=name                # ascending
GET /users?sort=-created_at         # descending
GET /users?sort=status,-created_at  # multiple fields
```

### Pagination

Pagination works automatically. Configure the default page size:

```ruby
# config/initializers/fetcheable_on_api.rb
FetcheableOnApi.configure do |config|
  config.pagination_default_size = 50  # default: 25
end
```

```bash
GET /users?page[number]=2&page[size]=25
```

Response headers:

```
Pagination-Current-Page: 2
Pagination-Per: 25
Pagination-Total-Pages: 8
Pagination-Total-Count: 200
```

### Combining Everything

```ruby
class PostsController < ApplicationController
  filter_by :title, :published
  filter_by :author, class_name: User, as: 'name'
  sort_by :title, :created_at
  sort_by :author, class_name: User, as: 'name'

  def index
    render json: apply_fetcheable(Post.joins(:author).includes(:author))
  end
end
```

```bash
GET /posts?filter[author]=john&filter[published]=true&sort=-created_at&page[number]=1&page[size]=10
```

## Documentation

- [Full predicate reference](https://github.com/fabienpiette/fetcheable_on_api/wiki/Predicates), all 33 supported Arel predicates
- [API docs (YARD)](https://rubydoc.info/gems/fetcheable_on_api)
- [JSONAPI specification](https://jsonapi.org/)

## Contributing

Contributions welcome. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community guidelines.

```bash
bin/setup          # install dependencies
rake spec          # run tests
bin/console        # interactive console
```

## Acknowledgments

Thanks to all [contributors](https://github.com/FabienPiette/fetcheable_on_api/graphs/contributors).

Built on top of [Arel](https://github.com/rails/arel) and the [JSONAPI specification](https://jsonapi.org/).

## License

[MIT](LICENSE)
