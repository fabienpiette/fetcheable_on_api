# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FetcheableOnApi is a Ruby gem that provides filtering, sorting, and pagination functionality for Rails API controllers following JSONAPI specification. The gem automatically adds query parameter support for `filter`, `sort`, and `page` parameters to controllers.

## Common Development Commands

### Setup
```bash
bin/setup                # Install dependencies and setup project
```

### Testing
```bash
rake spec               # Run all tests (default rake task)
bundle exec rspec       # Run tests with explicit bundler
```

### Console
```bash
bin/console             # Start IRB console with gem loaded
```

### Gem Management
```bash
bundle exec rake install    # Install gem locally
bundle exec rake release    # Release new version (updates version, creates git tag, pushes to rubygems)
```

## Architecture

### Core Module Structure

The gem follows a modular architecture with three main concern modules:

1. **FetcheableOnApi::Filterable** (`lib/fetcheable_on_api/filterable.rb`)
   - Handles `filter[attribute]=value` query parameters
   - Supports 30+ Arel predicates (`:eq`, `:ilike`, `:between`, `:in`, etc.)
   - Supports filtering through associations
   - Supports custom lambda predicates

2. **FetcheableOnApi::Sortable** (`lib/fetcheable_on_api/sortable.rb`)
   - Handles `sort=attribute` query parameters
   - Supports multiple sort fields (comma-separated)
   - Supports ascending/descending with `+`/`-` prefixes
   - Supports sorting through associations

3. **FetcheableOnApi::Pageable** (`lib/fetcheable_on_api/pageable.rb`)
   - Handles `page[number]` and `page[size]` query parameters
   - Adds pagination headers to responses
   - Configurable default page size

### Main Entry Point

The main module (`lib/fetcheable_on_api.rb`) includes all three concerns and provides the `apply_fetcheable(collection)` method that controllers use to apply filtering, sorting, and pagination in sequence.

### Controller Integration

Controllers gain access to the functionality by including the module (automatically done for ActionController::Base):

```ruby
class QuestionsController < ActionController::Base
  # Define allowed filters and sorts
  filter_by :content, :category_id
  sort_by :position, :created_at
  
  def index
    questions = apply_fetcheable(Question.all)
    render json: questions
  end
end
```

### Configuration

Global configuration is handled through `FetcheableOnApi::Configuration`:
- Default pagination size (default: 25)
- Configurable via `FetcheableOnApi.configure` block

### Key Design Patterns

- **Class Attributes**: Each concern uses `class_attribute` to store configuration per controller
- **Parameter Validation**: Built-in parameter type validation with helpful error messages
- **Flexible Predicates**: Support for both built-in Arel predicates and custom lambda predicates
- **Association Support**: Can filter/sort through ActiveRecord associations
- **Header Integration**: Pagination info automatically added to response headers

## Rails Integration

The gem integrates with Rails through `ActiveSupport.on_load :action_controller` hook, automatically including the module in all ActionController classes.

## Testing Approach

Tests are located in `spec/` directory using RSpec. The gem supports testing against multiple Rails versions via gemfiles in `gemfiles/` directory (Rails 4.1 through 5.2 and head).