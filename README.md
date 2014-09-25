# unique_by [![Gem Version](https://badge.fury.io/rb/unique_by.svg)](http://badge.fury.io/rb/unique_by)

This simple gem allows specifying uniqueness groups for an attribute, giving
you something to expose to the outside world.

When do you need this?

- If you're sharding your database.
- If you have multiple tables that you want to expose a unique ID for.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'unique_by'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install unique_by

## Usage

### Sharding example

You first need to specify a unique group in your model:

```ruby
# == Schema Info
#
# Table name: medical_bills
#
#  id                  :integer(11)    not null, primary key
#  client_id           :integer(11)
#

class MedicalBill < ActiveRecord::Base
  unique_by client_id: 50 # total of 50 clients
end
```

then, you can use these basic methods:

```ruby
bill1 = MedicalBill.find(123) # from a DB shard for client_id = 1
bill2 = MedicalBill.find(123) # from a DB shard for client_id = 2

bill1.unique_id
=> 7873
bill2.unique_id
=> 7874
MedicalBill.find_by_unique_id(7873) # from DB shard for client_id = 1
=> #<MedicalBill id: 123, client_id: 1>
MedicalBill.find_by_unique_id(7874) # from DB shard for client_id = 2
=> #<MedicalBill id: 123, client_id: 2>
```

You can use the internal methods:

```ruby
MedicalBill.unique_id_from(123, client_id: 1) # gives the unique_id
=> 7873
MedicalBill.id_from(7873) # gives the id
=> 123
MedicalBill.id_group_from(7874) # gives the client_id
=> { client_id: 2 }
```

You can specify multiple unique group attributes:

```ruby
class MedicalBill < ActiveRecord::Base
  unique_by client_id: 50, client_part: 5 # total of 50 clients and 5 parts
end
```

### Multiple tables example

You can supply a block to give a custom mechanism for determining the group:

```ruby
class MedicalBill < ActiveRecord::Base
  unique_by(type: 2) { { type: 1 } }
end
class UtilityBill < ActiveRecord::Base
  unique_by(type: 2) { { type: 2 } }
end
```

You can supply both group attributes and a block, and the block can also
return more than one field:

```ruby
class MedicalBill < ActiveRecord::Base
  unique_by(client_id: 50, client_part: 5, xy: 10, halfz: 20) do
    { xy: self.x * self.y, halfz: self.z / 2 }
  end
end
```

## Not ActiveRecord

The generator module is already included in `ActiveRecord::Base`, but if
you want the above methods in another class you can extend it:

```ruby
class MyClass
  extend UniqueBy::Generator

  def self.primary_key
    :id # or 'id'
  end
end
```

## See also

After adding the unique groups to the id, the unique_id might turn out pretty
large. You could use [rebase_attr](https://github.com/odedniv/rebase_attr) to
fix that:

```ruby
class MedicalBill < ActiveRecord::Base
  unique_by client_id: 500
  rebase_attr :unique_id, to: 32, readable: true
end

bill = MedicalBill.find(3528918) # from a DB shard for client_id = 1
bill.unique_id
=> "ywr3bxx"
MedicalBill.find_by_unique_id(MedicalBill.decode_unique_id("ywr3bxx"))
=> #<MedicalBill id: 3528918, client_id: 1>
```

## Contributing

1. Fork it ( https://github.com/odedniv/unique_by/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
