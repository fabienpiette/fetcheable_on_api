
# FetcheableOnApi

FetcheableOnApi allows you to quickly and easily set up a filter system based on the JSONAPI specification for ActiveRecord objects.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fetcheable_on_api'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fetcheable_on_api

Finally, run the install generator:

    $ rails generate fetcheable_on_api:install

It will create the following initializer `config/initializers/fetcheable_on_api.rb`.
This file contains all the informations about the existing configuration options.

## Usage

Imagine the following models called question and answer:

```ruby
class Question < ApplicationRecord
  #
  # Validations
  #
  validates :content,
            presence: true

  #
  # Associations
  #
  has_one :answer,
          class_name: 'Answer',
          foreign_key: 'question_id',
          dependent: :destroy,
          inverse_of: :question

  belongs_to :category,
             class_name: 'Category',
             inverse_of: :questions,
             optional: true
end

# == Schema Information
#
# Table name: questions
#
#  id          :bigint(8)        not null, primary key
#  content     :text             not null
#  position    :integer
#  category_id :bigint(8)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
```

```ruby
class Answer < ApplicationRecord
  #
  # Validations
  #
  validates :content,
            presence: true

  #
  # Associations
  #
  belongs_to :question,
             class_name: 'Question',
             foreign_key: 'question_id',
             inverse_of: :answer
end

# == Schema Information
#
# Table name: answers
#
#  id          :bigint(8)        not null, primary key
#  content     :text             not null
#  question_id :bigint(8)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
```

```ruby
class Category < ApplicationRecord
  #
  # Validations
  #
  validates :name,
            presence: true

  #
  # Associations
  #
  has_many :questions,
           class_name: 'Question',
           inverse_of: :category
end

# == Schema Information
#
# Table name: categories
#
#  id          :bigint(8)        not null, primary key
#  name        :text             not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
```

And controller:

```ruby
class QuestionsController < ActionController::Base
  # GET /questions
  def index
    questions = Question.joins(:answer).includes(:answer).all
    render json: questions
  end
end
```

### Sorting

You can now define the allowed attribute(s) in the sorting of the collection like this:

```ruby
class QuestionsController < ActionController::Base
  #
  # FetcheableOnApi
  #
  sort_by :position

  # GET /questions
  def index
    questions = apply_fetcheable(Question.joins(:answer).includes(:answer).all)
    render json: questions
  end
end
```
This allows you to pass a new parameter in the query:

```bash
$ curl -X GET \
  'http://localhost:3000/questions?sort=position'

[
    {
        "id": 3,
        "position": 1,
        "category_id": 1,
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
    },
    {
        "id": 4,
        "position": 2,
        "category_id": 2,
        "content": "Is it so simple?",
        "answer": "Yes"
    },
    {
        "id": 5,
        "position": 3,
        "category_id": 2,
        "content": "Is this real life?",
        "answer": "Yes this is real life"
    }
]
```

FetcheableOnApi support multiple sort fields by allowing comma-separated (U+002C COMMA, “,”) sort fields:
```ruby
class QuestionsController < ActionController::Base
  #
  # FetcheableOnApi
  #
  sort_by :position, :id

  # GET /questions
  def index
    questions = apply_fetcheable(Question.joins(:answer).includes(:answer).all)
    render json: questions
  end
end
```

```bash
$ curl -X GET \
  'http://localhost:3000/questions?sort=position,id'

[
    {
        "id": 3,
        "position": 1,
        "category_id": 1,
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
    },
    {
        "id": 4,
        "position": 2,
        "category_id": 2,
        "content": "Is it so simple?",
        "answer": "Yes"
    },
    {
        "id": 5,
        "position": 3,
        "category_id": 2,
        "content": "Is this real life?",
        "answer": "Yes this is real life"
    }
]
```

The default sort order for each sort field is ascending unless it is prefixed with a minus (U+002D HYPHEN-MINUS, “-“), in which case it is descending:

```bash
$ curl -X GET \
  'http://localhost:3000/questions?sort=-position'

[
    {
        "id": 5,
        "position": 3,
        "category_id": 2,
        "content": "Is this real life?",
        "answer": "Yes this is real life"
    },
    {
        "id": 4,
        "position": 2,
        "category_id": 2,
        "content": "Is it so simple?",
        "answer": "Yes"
    },
    {
        "id": 3,
        "position": 1,
        "category_id": 1,
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
    }
]
```

### Pagination

Pagination is automatically set on the controller and allows the use of a new parameter `page`.
The pagination is page-based strategy, it can use query parameters such as `page[number]` and `page[size]`

```bash
$ curl -X GET \
  'http://localhost:3000/questions?page[number]=1&page[size]=2'

[
    {
        "id": 3,
        "position": 1,
        "category_id": 1,
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
    },
    {
        "id": 4,
        "position": 2,
        "category_id": 2,
        "content": "Is it so simple?",
        "answer": "Yes"
    }
]

$ curl -X GET \
  'http://localhost:3000/questions?page[number]=2&page[size]=2'

[
    {
        "id": 5,
        "position": 3,
        "category_id": 2,
        "content": "Is this real life?",
        "answer": "Yes this is real life"
    }
]
```

When you use pagination, additional information is returned in the Header

- `Pagination-Current-Page`: the current page number
- `Pagination-Per`: the number of records per page
- `Pagination-Total-Pages`: the total number of pages
- `Pagination-Total-Count`: the total number of records

### Filtering

The `filter` query parameter is reserved for filtering data and the controller must set the attributes allowed to be filtered.

```ruby
class QuestionsController < ActionController::Base
  #
  # FetcheableOnApi
  #
  sort_by :position, :id
  filter_by :content

  # GET /questions
  def index
    questions = apply_fetcheable(Question.joins(:answer).includes(:answer).all)
    render json: questions
  end
end
```

```bash
$ curl -X GET \
  'http://localhost:3000/questions?filter[content]=gem'

[
    {
        "id": 3,
        "position": 1,
        "category_id": 1,
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
    }
]
```

Multiple filter values can be combined in a comma-separated list.

```bash
$ curl -X GET \
  'http://localhost:3000/questions?filter[content]=real,simple'

[
    {
        "id": 4,
        "position": 2,
        "category_id": 2,
        "content": "Is it so simple?",
        "answer": "Yes"
    },
    {
        "id": 5,
        "position": 3,
        "category_id": 2,
        "content": "Is this real life?",
        "answer": "Yes this is real life"
    }
]
```

You can also define a filter through an association like this:

```ruby
class QuestionsController < ActionController::Base
  #
  # FetcheableOnApi
  #
  sort_by :position, :id
  filter_by :content
  filter_by :answer,
            class_name: Answer,
            as: 'content'

  # GET /questions
  def index
    questions = apply_fetcheable(Question.joins(:answer).includes(:answer).all)
    render json: questions
  end
end
```

```bash
$ curl -X GET \
  'http://localhost:3000/questions?filter[answer]=apply_fetcheable'

[
    {
        "id": 3,
        "position": 1,
        "category_id": 1,
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
    }
]
```

Furthermore you can specify one of the supported `Arel` predicate.

```ruby
class QuestionsController < ActionController::Base
  #
  # FetcheableOnApi
  #
  filter_by :category_id, with: :eq

  # GET /questions
  def index
    questions = apply_fetcheable(Question.includes(:answer).all)
    render json: questions
  end
end
```

```bash
$ curl -X GET \
  'http://localhost:3000/questions?filter[category_id]=1'

[
    {
        "id": 3,
        "position": 1,
        "category_id": 1,
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
    }
]
```

Currently 33 predicates are supported ([more details here](https://github.com/fabienpiette/fetcheable_on_api/wiki/Predicates)):

+ `:between`
+ `:does_not_match`
+ `:does_not_match_all`
+ `:does_not_match_any`
+ `:eq` which matches the parameter with the SQL fragment `= 'foo'`.
+ `:eq_all`
+ `:eq_any`
+ `:gt`
+ `:gt_all`
+ `:gt_any`
+ `:gteq`
+ `:gteq_all`
+ `:gteq_any`
+ `:ilike` which is the default behaviour and will match the parameter with the SQL fragment `ILIKE '%foo%'`.
+ `:in`
+ `:in_all`
+ `:in_any`
+ `:lt`
+ `:lt_all`
+ `:lt_any`
+ `:lteq`
+ `:lteq_all`
+ `:lteq_any`
+ `:matches`
+ `:matches_all`
+ `:matches_any`
+ `:not_between`
+ `:not_eq`
+ `:not_eq_all`
+ `:not_eq_any`
+ `:not_in`
+ `:not_in_all`
+ `:not_in_any`

+ `lamdba` wich take two arguments: a collection and a value, then return an Arel predicate.
  ```ruby
  filter_by :name, with: -> (collection, value) do
    collection.arel_table[:first_name].matches("%#{value}%").or(
      collection.arel_table[:last_name].matches("%#{value}%"),
    )
  end
  ```

You can also use an array as a parameter for some predicate

```ruby
class QuestionsController < ActionController::Base
  #
  # FetcheableOnApi
  #
  filter_by :id, with: :between

  # GET /questions
  def index
    questions = apply_fetcheable(Question.includes(:answer).all)
    render json: questions
  end
end
```

```bash
curl -X GET \
  'http://localhost:3000/questions?filter[id]=[1]'

[
    {
        "id": 1,
        "position": 1,
        "content": "Je peux boire ou cuisiner avec l'eau de pluie ?",
        "answer": "Faux : l'eau de pluie que vous récupérez est strictement interdite pour une consommation alimentaire car elle n'est pas potable.\nVous ne devez donc pas la boire, ni l'utiliser pour cuisiner ou laver la vaisselle.\n",
        "base_value": false
    }
]
```

Date manipulation is a special case and can be solved by specifically indicating the expected format for the parameter.

```ruby
class QuestionsController < ActionController::Base
  #
  # FetcheableOnApi
  #
  filter_by :created_at,
            with: :between,
            format: :datetime

  # GET /questions
  def index
    questions = apply_fetcheable(Question.includes(:answer).all)
    render json: questions
  end
end
```

```bash
curl -X GET \
  'http://localhost:3000/questions?filter[created_at]=[1541428932,1541428933]'
```

By default the format used is epoch time, but you can redefine it by overriding the method `foa_string_to_datetime`

```ruby
class QuestionsController < ActionController::Base
  #
  # FetcheableOnApi
  #
  filter_by :created_at,
            with: :between,
            format: :datetime

  # GET /questions
  def index
    questions = apply_fetcheable(Question.includes(:answer).all)
    render json: questions
  end

  protected

  def foa_string_to_datetime(string)
    DateTime.strptime(string, '%s')
  end
end


And that's all !

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/FabienPiette/fetcheable_on_api. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the FetcheableOnApi project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/FabienPiette/fetcheable_on_api/blob/master/CODE_OF_CONDUCT.md).
