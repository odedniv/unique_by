require "unique_by/version"

module UniqueBy
  module Generator
    def unique_by(bits: nil, max: nil, base: 36, &group)
      raise ArgumentError, "both bits (#{bits.inspect}) and max (#{max.inspect}) passed to #unique_by" if bits and max
      raise ArgumentError, "must pass either bits or max to #unique_by" unless bits or max
      bits ||= (Math.log2(max) + 1).floor
      max = (2 ** bits) - 1 # actual max, no matter what's been given

      model_primary_key = primary_key # converting to a local variable

      define_singleton_method :"unique_#{model_primary_key}" do |value|
        unique_number = (value << bits) + group.call(self)
        base == 10 ? unique_number : unique_number.to_s(base)
      end

      define_singleton_method :"#{model_primary_key}_of" do |value|
        unique_number = case value
                          when String then value.to_i(base)
                          else value
                        end
        unique_number >> bits
      end

      define_singleton_method :"#{model_primary_key}_group_of" do |value|
        unique_number = case value
                          when String then value.to_i(base)
                          else value
                        end
        unique_number & (max - 1)
      end

      define_method :"unique_#{model_primary_key}" do
        self.class.send(:"unique_#{model_primary_key}", send(model_primary_key))
      end

      define_singleton_method :"find_by_unique_#{model_primary_key}" do |value|
        send(:"find_by_#{model_primary_key}". send(:"#{model_primary_key_of}_of", value))
      end

      define_singleton_method :"find_by_unique_#{model_primary_key}!" do |value|
        send(:"find_by_#{model_primary_key}!". send(:"#{model_primary_key_of}_of", value))
      end
    end
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend(UniqueBy::Generator)
end
