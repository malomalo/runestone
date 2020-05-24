# Runestone

Runestone provides full text search PostgreSQL's full text search capabilities.
It was inspired by [Postgres full-text search is Good Enough!][1] and
[Super Fuzzy Searching on PostgreSQL][2]

## Installation

Install Runestone from RubyGems:

``` sh
$ gem install runestone
```

Or include it in your project's `Gemfile` with Bundler:

``` ruby
gem 'runestone'
```

After installation, run the Runestone's migration to to enable the necessary database extensions and create the runestones and runestone corpus tables.

```sh
$ rails db:migrate
```

## Usage

### Indexing

To index your ActiveRecord Models:

```ruby
class Building < ApplicationRecord

  runestone do
    index 'name', 'addresses.global', 'addresses.national'
    
    attributes(:name)
    attributes(:size, :floors)
    attribute(:addresses) {
      addresses&.map{|address| {
        local: address.local,
        regional: address.regional,
        national: address.national,
        global: address.global
      } }
    }
  end

end
```

When searching the attribute(s) will be available in `data` on the result(s), but only the attributes specified by `index` will indexed and used for searching.

### Searching

To search for the Building:

```ruby
Building.search("Empire")
```

You can also search through all indexed models with:

```ruby
Runestone::Model.search("needle")
```

Additionally you can highlight the results. When this is done each result will have a `highlights` attribute which is the same as data, but with matches wrapped in a `<b>` tag:

```ruby
Runestone::Model.highlight(@results, "needle")
```

## Configuration

### Synonym

```ruby
Runestone.add_synonym('ten', '10')

Runestone.add_synonym('one hundred', '100')
Runestone.add_synonym('100', 'one hundred')
```

[1]: http://rachbelaid.com/postgres-full-text-search-is-good-enough/
[2]: http://www.www-old.bartlettpublishing.com/site/bartpub/blog/3/entry/350
