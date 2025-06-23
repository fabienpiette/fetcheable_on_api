# Association Sorting Solution

## The Issue

You want to sort books by their author's name using:

```ruby
sort_by :author_name,
        as: :name,
        class_name: User,
        association: :author
```

## Current Status

The current implementation **should already work** with the following setup:

```ruby
class BooksController < ApplicationController
  # This configuration should work
  sort_by :author_name, class_name: User, as: 'name'
  
  def index
    # THE KEY: Make sure to join the association
    books = apply_fetcheable(Book.joins(:author))
    render json: books
  end
end
```

## Why It Should Work

1. `class_name: User` tells Sortable to use the `users` table
2. `as: 'name'` tells it to sort by the `name` column
3. `Book.joins(:author)` ensures the `users` table is available in the query
4. The result is `ORDER BY users.name ASC/DESC`

## The Missing Piece: Association Option Support

To fully implement the `:association` option like in Filterable, we need to:

1. ✅ Add `:association` to valid options in `sort_by` (done)
2. ✅ Update documentation with examples (done)
3. 🔧 **Optional**: Add association validation logic

## Complete Implementation

Here's your controller setup:

```ruby
class BooksController < ApplicationController
  # Basic sorting
  sort_by :title, :created_at
  
  # Association sorting (current working version)
  sort_by :author_name, class_name: User, as: 'name'
  
  # Association sorting (with new association option)
  sort_by :author_name, class_name: User, as: 'name', association: :author
  
  def index
    # IMPORTANT: Join the association
    books = apply_fetcheable(Book.joins(:author))
    render json: books
  end
end
```

## API Usage

```bash
# Sort by book title
GET /books?sort=title

# Sort by author name (ascending)
GET /books?sort=author_name

# Sort by author name (descending)
GET /books?sort=-author_name

# Multiple sorts: author name asc, then created_at desc
GET /books?sort=author_name,-created_at
```

## Testing the Implementation

The implementation should generate SQL like:

```sql
SELECT books.* 
FROM books 
INNER JOIN users ON users.id = books.author_id 
ORDER BY users.name ASC
```

## If It's Still Not Working

Check these common issues:

1. **Missing Join**: Ensure `Book.joins(:author)` is called
2. **Wrong Association Name**: Verify the association name matches your model
3. **Field Name**: Ensure the `as: 'name'` field exists on the User model
4. **Case Sensitivity**: Some databases are case-sensitive

## Debug Steps

```ruby
def index
  puts "Sorts configuration: #{sorts_configuration}"
  
  books = Book.joins(:author)
  puts "Before apply_fetcheable SQL: #{books.to_sql}"
  
  books = apply_fetcheable(books)
  puts "After apply_fetcheable SQL: #{books.to_sql}"
  
  render json: books
end
```