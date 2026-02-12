# frozen_string_literal: true

# FetcheableOnApi configuration
#
# This initializer configures the FetcheableOnApi gem settings for your application.
# These settings affect the behavior of filtering, sorting, and pagination across
# all controllers that use the FetcheableOnApi module.

FetcheableOnApi.configure do |config|
  # Default number of records per page when no page[size] parameter is provided.
  # This affects the Pageable module when clients don't specify a page size.
  #
  # Examples:
  #   - With default (25): GET /users?page[number]=2 returns 25 records
  #   - With custom (50): GET /users?page[number]=2 returns 50 records
  #
  # Default: 25
  config.pagination_default_size = 25
end
