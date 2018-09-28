
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
end

# == Schema Information
#
# Table name: questions
#
#  id         :bigint(8)        not null, primary key
#  content    :text             not null
#  position   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
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
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
    },
    {
        "id": 4,
        "position": 2,
        "content": "Is it so simple?",
        "answer": "Yes"
    },
    {
        "id": 5,
        "position": 3,
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
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
    },
    {
        "id": 4,
        "position": 2,
        "content": "Is it so simple?",
        "answer": "Yes"
    },
    {
        "id": 5,
        "position": 3,
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
        "content": "Is this real life?",
        "answer": "Yes this is real life"
    },
    {
        "id": 4,
        "position": 2,
        "content": "Is it so simple?",
        "answer": "Yes"
    },
    {
        "id": 3,
        "position": 1,
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
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
    },
    {
        "id": 4,
        "position": 2,
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
        "content": "Is this real life?",
        "answer": "Yes this is real life"
    }
]
```

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
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
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
        "content": "How to simply sort a collection with this gem ?",
        "answer": "Just add sort_by in your controller and call the apply_fetcheable method"
    }
]
```

And that's all !

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/fetcheable_on_api. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the FetcheableOnApi project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/fetcheable_on_api/blob/master/CODE_OF_CONDUCT.md).
