# frozen_string_literal: true

# EnumAliases provides a way to create unprefixed aliases for prefixed enum predicates
# This allows both `loan.state_pending?` and `loan.pending?` to work while keeping
# the string-backed enum implementation with prefixes for clarity.
#
# Example:
#   class Loan < ApplicationRecord
#     include EnumAliases
#
#     enum :state, { pending: "pending", approved: "approved" }, prefix: :state
#     alias_unprefixed_enum_predicates :state
#   end
#
#   loan = Loan.new(state: "pending")
#   loan.state_pending?  # => true (Rails default with prefix)
#   loan.pending?        # => true (alias created by this concern)
#
module EnumAliases
  extend ActiveSupport::Concern

  class_methods do
    # Creates unprefixed aliases for prefixed enum predicates
    # Only creates aliases if the unprefixed method doesn't already exist
    #
    # @param enum_name [Symbol] The name of the enum attribute
    # @param prefix [Symbol] The prefix used in the enum definition (defaults to enum_name)
    def alias_unprefixed_enum_predicates(enum_name, prefix: nil)
      prefix ||= enum_name
      enum_values = public_send(enum_name.to_s.pluralize)

      enum_values.each_key do |value|
        prefixed_method = :"#{prefix}_#{value}?"
        unprefixed_method = :"#{value}?"

        # Only create alias if the unprefixed method doesn't exist
        # This prevents overriding existing methods
        next if method_defined?(unprefixed_method) || private_method_defined?(unprefixed_method)

        define_method(unprefixed_method) do
          public_send(prefixed_method)
        end
      end
    end
  end
end
