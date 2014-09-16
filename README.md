# unique_by [![Gem Version](https://badge.fury.io/rb/unique_by.svg)](http://badge.fury.io/rb/unique_by)

This simple gem allows specifying uniqueness groups for an attribute, giving
you something to expose to the outside world.

When do you need this?

- If you're sharding your database.
- If you have multiple tables that you want to expose a unique ID for.

## Installation

Add this line to your application's Gemfile:

    gem 'unique_by'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install unique_by

## Usage

### Sharding example

You first need to specify a unique group in your model:

    # == Schema Info
    #
    # Table name: medical_bills
    #
    #  id                  :integer(11)    not null, primary key
    #  client_id           :integer(11)
    #

    class MedicalBill < ActiveRecord::Base
      unique_by :client_id, total: 50
    end

then, you can use these basic methods:

    bill1 = MedicalBill.find(123) # from a DB shard for client_id = 1
    bill2 = MedicalBill.find(123) # from a DB shard for client_id = 2

    bill1.unique_id
    => "62p"
    bill2.unique_id
    => "62q"
    MedicalBill.find_by_unique_id("62p") # from DB shard for client_id = 1
    => #<MedicalBill id: 123, client_id: 1>
    MedicalBill.find_by_unique_id("62q") # from DB shard for client_id = 2
    => #<MedicalBill id: 123, client_id: 2>

You can use the internal methods:

    MedicalBill.unique_id_from(1, 123) # gives the unique_id from client_id, id
    => "62p"
    MedicalBill.id_from("62p") # gives the id
    => 123
    MedicalBill.id_group_from("62q") # gives the client_id
    => 2

And use bits instead of total:

    class MedicalBill < ActiveRecord::Base
      unique_by :client_id, bits: 6 # equivalent to total: 64
    end

You can specify multiple unique group attributes:

    class MedicalBill < ActiveRecord::Base
      unique_by :client_id, :client_part, total: [50, 5]
    end

### Multiple tables example

You can supply a block to give your own mechanism for determining the
group:

    class MedicalBill < ActiveRecord::Base
      unique_by(total: 2) { 1 }
    end
    class UtilityBill < ActiveRecord::Base
      unique_by(total: 2) { 2 }
    end

You can supply both group attributes and a block, and the block can also
return an array:

    class MedicalBill < ActiveRecord::Base
      unique(:client_id, :client_part, total: [50, 5, 10, 20]) { [self.x * self.y, self.z / 2] }
    end

## Not ActiveRecord

The generator module is already included in `ActiveRecord::Base`, but if
you want the above methods in another class you can extend it:

    class MyClass
      extend UniqueBy::Generator

      def self.primary_key
        :id # or 'id'
      end
    end

## Contributing

1. Fork it ( https://github.com/odedniv/unique_by/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
