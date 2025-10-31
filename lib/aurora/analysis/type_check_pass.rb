# frozen_string_literal: true

require_relative "base_pass"

module Aurora
  module Analysis
    # TypeCheckPass - validates type consistency in CoreIR
    # This pass walks through the CoreIR and validates type consistency.
    # This is a simplified initial version that demonstrates the pass pattern.
    #
    # Results stored in context[:type_errors] = [error_messages]
    #
    # TODO: Fully implement type checking for all CoreIR node types
    class TypeCheckPass < BasePass
      def initialize(type_registry:, name: "type_check")
        super(name: name)
        @type_registry = type_registry
      end

      def required_keys
        [:core_ir]
      end

      def produced_keys
        [:type_errors, :type_check_passed]
      end

      def run(context)
        core_ir = context[:core_ir]
        return unless core_ir

        @errors = []

        # Basic pass: just verify functions exist
        core_ir.items.each do |item|
          next unless item.is_a?(CoreIR::Func)

          # Basic validation: check if function has a body
          if item.external && item.body
            @errors << "External function '#{item.name}' should not have a body"
          elsif !item.external && !item.body
            @errors << "Function '#{item.name}' must have a body or be declared external"
          end
        end

        # Store results in context
        context[:type_errors] = @errors
        context[:type_check_passed] = @errors.empty?
      end
    end
  end
end
