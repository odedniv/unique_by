require "unique_by/version"
require "generate_method"

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
    def unique_by(primary_key: self.primary_key, **group_totals, &group_block)
      raise ArgumentError, "must pass a group definition (Hash of name => total)" if group_totals.empty?
      raise ArgumentError, "group definition must be a Hash of name => Fixnum, #{group_totals.inspect} given" unless group_totals.values.all? { |t| t.is_a?(Fixnum) }

      generate_singleton_methods do
        define_method :"#{primary_key}_group" do |**group|
          raise ArgumentError, "unknown #{primary_key} group keys: #{group.keys - group_totals.keys}" if (group.keys - group_totals.keys).any?
          next group if (group_totals.keys - group.keys).none?

          group_from_block = group_block ? instance_eval(&group_block) : {}
          raise TypeError, "#{primary_key} group block must return a Hash with any of the following keys: #{group_totals.keys}, #{group_from_block.inspect} given" unless group_from_block.is_a?(Hash)
          raise ArgumentError, "unknown #{primary_key} group passed to block: #{group_from_block.keys - group_totals.keys}" if (group_from_block.keys - group_totals.keys).any?
          group.update(group_from_block)
          next group if (group_totals.keys - group.keys).none?

          group.update(Hash[(group_totals.keys - group.keys).map { |group_name| [group_name, send(group_name)] }])

          group
        end

        define_method :"#{primary_key}_group_value_from" do |**group|
          group = send(:"#{primary_key}_group", **group)
          group_totals.keys.reduce(0) do |group_value, group_name|
            g = group[group_name]
            raise TypeError, "#{primary_key} group #{group_name} must not be nil" if g.nil?
            raise TypeError, "#{primary_key} group #{group_name} must implement #to_i, #{g.inspect} given" unless g.respond_to?(:to_i)
            (group_value * group_totals[group_name]) + (g.to_i % group_totals[group_name])
          end
        end

        define_method :"unique_#{primary_key}_from" do |id, **group|
          break nil if id.nil?
          raise TypeError, "#{primary_key} must implement #to_i, #{id.inspect} given" unless id.respond_to?(:to_i)
          (id.to_i * group_totals.values.inject(&:*)) + send(:"#{primary_key}_group_value_from", **group)
        end

        define_method :"#{primary_key}_from" do |unique_id|
          break nil if unique_id.nil?
          raise TypeError, "unique_#{primary_key} must implement #to_i, #{unique_id.inspect} given" unless unique_id.respond_to?(:to_i)
          unique_id.to_i / group_totals.values.inject(&:*)
        end

        define_method :"#{primary_key}_group_from" do |unique_id|
          break nil if unique_id.nil?
          raise TypeError, "unique_#{primary_key} must implement #to_i, #{unique_id.inspect} given" unless unique_id.respond_to?(:to_i)
          Hash[group_totals.keys.reverse.map do |group_name|
            g = unique_id % group_totals[group_name]
            unique_id /= group_totals[group_name]
            [group_name, g]
          end.reverse]
        end
      end

      generate_methods do
        define_method :"#{primary_key}_group" do
          group_from_block = group_block ? instance_eval(&group_block) : {}
          raise TypeError, "#{primary_key} group block must return a Hash with any of the following keys: #{group_totals.keys}, #{group_from_block.inspect} given" unless group_from_block.is_a?(Hash)
          raise ArgumentError, "unknown #{primary_key} group passed to block: #{group_from_block.keys - group_totals.keys}" if (group_from_block.keys - group_totals.keys).any?
          group = group_from_block.merge( # like reverse_merge, as we don't set keys that were in the block
            Hash[
              (group_totals.keys - group_from_block.keys).map do |group_name|
                [
                  group_name,
                  (respond_to?(group_name) or not self.class.respond_to?(group_name)) ? send(group_name) : self.class.send(group_name) # would rather crash on instance method missing
                ]
              end
            ]
          )
          group
        end

        define_method :"unique_#{primary_key}" do
          self.class.send(:"unique_#{primary_key}_from", send(primary_key), **send(:"#{primary_key}_group"))
        end
      end
    end
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend(UniqueBy::Generator)
end
