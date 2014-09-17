require "unique_by/version"

module UniqueBy
  module Generator
    # For a primary_key 'id', generates:
    #   ::id_group_value_from(group) => group_value
    #   ::unique_id_from(id, group) => unique_id
    #   ::id_from(unique_id) => id
    #   ::id_group_from(unique_id) => group
    #   #id_group => group
    #   #unique_id => unique_id
    #   ::find_by_unique_id(unique_id) => find_by_id(id_from(unique_id))
    #   ::find_by_unique_id!(unique_id) => find_by_id!(id_from(unique_id))
    def unique_by(*group_block_names, total: nil, bits: nil, &group_block)
      bits, total = Array(bits), Array(total)

      raise ArgumentError, "must pass either total or bits to #unique_by" \
        unless total.any? or bits.any?
      raise ArgumentError, "both total (#{total.inspect}) and bits (#{bits.inspect}) passed to #unique_by" \
        if total.any? and bits.any?
      raise ArgumentError, "must pass a group generator block" \
        unless group_block_names.any? or block_given?
      raise ArgumentError, "amount of group names (#{group_block_names.length}) doesn't match total/bits (#{total.length + bits.length})" \
        if (not block_given? and group_block_names.length != total.length + bits.length) or \
           (block_given? and group_block_names.length > total.length + bits.length)

      bits = total.map { |t| Math.log2(t).ceil } if bits.empty?
      total = bits.map { |b| 2 ** b }

      pk = primary_key # converting to a local variable

      define_singleton_method :"#{pk}_group_value_from" do |group|
        Array(group).each_with_index.reduce(0) do |group_value, (g, i)|
          raise TypeError, "group must implement #to_i, #{g.inspect} given" \
            unless g.respond_to?(:to_i)
          (group_value << bits[i]) + (g.to_i % total[i])
        end
      end

      define_singleton_method :"unique_#{pk}_from" do |id, group|
        (id.to_i << bits.inject(&:+)) + send(:"#{pk}_group_value_from", group)
      end

      define_singleton_method :"#{pk}_from" do |id|
        id.to_i >> bits.inject(&:+)
      end

      define_singleton_method :"#{pk}_group_from" do |id|
        group = bits.reverse.zip(total.reverse).map do |b, t|
          g = id & (t - 1)
          id >>= b
          g
        end.reverse
        group.length == 1 ? group[0] : group
      end

      define_method :"#{pk}_group" do
        group = group_block_names.map { |group_block_name| send(group_block_name) }
        group.push(*Array(instance_eval(&group_block))) if group_block
        raise ArgumentError, "amount of groups (#{group.length}) doesn't match amount of bits/total (#{bits.length})" if group.length != bits.length
        group.length == 1 ? group[0] : group
      end

      define_method :"unique_#{pk}" do
        primary_key = send(pk)
        raise TypeError, "#{pk} must implement #to_i, #{primary_key.inspect} given" \
          unless primary_key.respond_to?(:to_i)
        self.class.send(:"unique_#{pk}_from", primary_key.to_i, send(:"#{pk}_group"))
      end

      define_singleton_method :"find_by_unique_#{pk}" do |id|
        send(:"find_by_#{pk}", send(:"#{pk}_from", id))
      end

      define_singleton_method :"find_by_unique_#{pk}!" do |id|
        send(:"find_by_#{pk}!", send(:"#{pk}_from", id))
      end
    end
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend(UniqueBy::Generator)
end
