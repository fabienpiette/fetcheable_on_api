# frozen_string_literal: true

ActiveRecord::Schema.define do
  # Set up any tables you need to exist for your test suite that don't belong
  # in migrations.
  create_table :categories, force: true do |t|
    t.string :name

    t.timestamps
  end

  create_table :questions, force: true do |t|
    t.text    :content, null: false
    t.integer :position

    t.belongs_to :category, index: true

    t.timestamps
  end

  create_table :answers, force: true do |t|
    t.text :content, null: false

    t.belongs_to :question, index: true

    t.timestamps
  end
end
