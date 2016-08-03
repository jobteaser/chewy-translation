# Chewy::Translation

Chewy::Translation is an easy integration of Translation within Chewy.

Chewy::Translation handles translated content in elasticsearch.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'chewy-translation'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install chewy-translation

## Usage

### Indexing translated content

Add a new field in `/app/chewy/user_index.rb`

```ruby
class UserIndex < Chewy::Index

  define_type User, name: :global do
    field :translations, type: 'nested' do
      field :locale, type: 'string'
      field :name, type: 'string' # add analysers if needed
    end
  end

end
```

If you need to handle an activation status for your translations, add an `active` column in the translation table and index it as follow:

```ruby
class UserIndex < Chewy::Index

  define_type User, name: :global do
    field :active_locales, mode: 'arrayed', value:
      -> (c) { c.translations.select { |t| t.active == true }.map(&:locale) }
  end

end
```

### Querying and filtering translated content

#### Autocomplete:
The autocomplete method searches only in the wanted locale.
For example the following query will return all the users with a name starting with 'Idefix' in french:

```ruby
UserIndex::Global.autocomplete(fields: ['name'], query: 'Idefix', locale: :fr)
```
It's possible to perform an autocomplete on more than one simple field, for example you can imagine for Users an autocomplete on first_name and last_name: `fields: ['first_name', 'last_name']`.

## Search:
If the field is translated, the search_by will search in all the available locales in the context.
For example the following query will return all the users with 'Getafix' in their names (in any available locale).
```ruby
UserIndex::Global.search_by(name: 'Getafix')
```

Let's assume we have an object named 'Getafix' in english and 'Panoramix' in french, if a user with a french interface perform the query above, it will return 'Panoramix'.

It's also possible to search on different fiels on the same query:
```ruby
UserIndex::Global.search_by(name: 'Getafix', job: 'druid')
```

The search_by method can also be used on numeric fields, and it is possible to give an array of numbers to those fields (and it will perform a 'or' between those numbers).
```ruby
UserIndex::Global.search_by(name: 'Getafix', some_id: 123, another_id: [123, 456, 789])
```
It will display the object with:
- 'Getafix' in their name
- 'sickle_id' = 123
- 'mistletoe_id' in [123, 456, 789]

An other way to perform a search is tu use `search_by_fields`, it allows to search a single string in different fields. For example to search a object containing 'Getafix' in the name or in the character_description: 
```ruby
UserIndex::Global.search_by_fields(fields: [:name, :character_description], query: 'Getafix')
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jobteaser/chewy-translation. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

