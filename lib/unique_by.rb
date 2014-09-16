require "unique_by/version"

module UniqueBy
  module Generator
    # For a primary_key 'id', generates:
    #   ::unique_id_from(group, id) => unique_id
    #   ::id_from(unique_id) => id
    #   ::id_group_from(unique_id) => group
    #   #id_group => group
    #   #unique_id => unique_id
    #   ::find_by_unique_id(unique_id) => find_by_id(id_from(unique_id))
    #   ::find_by_unique_id!(unique_id) => find_by_id!(id_from(unique_id))
    def unique_by(*group_block_names, total: nil, bits: nil, &group_block)
      bits, total = Array(bits), Array(total)

      raise ArgumentError, "must pass either bits or total to #unique_by" \
        unless bits.any? or total.any?
      raise ArgumentError, "both bits (#{bits.inspect}) and total (#{total.inspect}) passed to #unique_by" \
        if bits.any? and total.any?
      raise ArgumentError, "must pass a group generator block" \
        unless group_block_names.any? or block_given?
      raise ArgumentError, "amount of group names (#{group_block_names.length}) doesn't match amount of bits/total (#{bits.length + total.length})" \
        if group_block_names.any? and not block_given? and group_block_names.length != bits.length + total.length

      bits = total.map { |t| Math.log2(t).ceil } if bits.empty?
      total = bits.map { |b| 2 ** b }

      pk = primary_key # converting to a local variable

      define_singleton_method :"unique_#{pk}_from" do |group_value, value|
        (value.to_i << bits.sum) + group_value.to_i
      end

      define_singleton_method :"#{pk}_from" do |value|
        value.to_i >> bits
      end

      define_singleton_method :"#{pk}_group_from" do |value|
        value.to_i & ((2 ** bits.sum) - 1)
      end

      define_method :"#{pk}_group" do
        group_values = group_block_names.map { |group_block_name| send(group_block_name) }
        group_values.push(*Array(instance_eval(group_block))) if group_block
        raise "amount of groups (#{group_values.length}) doesn't match amount of bits/total (#{bits.length})" if group_values.length != bits.length
        group_values.each_with_index.reduce(0) do |group, (group_value, i)|
          raise "group must implement #to_i, #{group_value} given" \
            unless group_value.respond_to?(&:to_i)
          (group << bits[i]) + (group_value.to_i % total[i])
        end
      end

      define_method :"unique_#{pk}" do
        primary_key = send(pk)
        raise "#{pk} must implement #to_i, #{primary_key.inspect} given" \
          unless primary_key.respond_to?(:to_i)
        self.class.send(:"unique_#{pk}_from", send(:"#{pk}_group"), primary_key.to_i)
      end

      define_singleton_method :"find_by_unique_#{pk}" do |value|
        send(:"find_by_#{pk}". send(:"#{pk}_from", value))
      end

      define_singleton_method :"find_by_unique_#{pk}!" do |value|
        send(:"find_by_#{pk}!". send(:"#{pk}_from", value))
      end
    end
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend(UniqueBy::Generator)
end
