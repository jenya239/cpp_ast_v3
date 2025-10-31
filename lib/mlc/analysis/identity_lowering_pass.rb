# frozen_string_literal: true

require_relative "base_pass"

module MLC
  module Analysis
    # IdentityLoweringPass - proof of concept for High IR → Mid IR transformation
    #
    # This is a simple pass that demonstrates the multi-level IR architecture.
    # It performs an identity transformation: High IR → Mid IR (currently same structure)
    #
    # In the future, this will be replaced by actual lowering passes:
    # - LowerMatchPass (match → if/else)
    # - LowerComprehensionsPass (comprehensions → loops)
    # - LowerPatternsPass (patterns → predicates)
    #
    # Usage:
    #   pass = IdentityLoweringPass.new
    #   pass.run(context)
    #   mid_ir = context[:mid_ir]
    class IdentityLoweringPass < BasePass
      def initialize(name: "identity_lowering")
        super(name: name)
      end

      # This is a transformation pass: changes IR level
      def input_level
        :high_ir
      end

      def output_level
        :mid_ir
      end

      def required_keys
        [:core_ir]  # High IR is stored as :core_ir
      end

      def produced_keys
        [:mid_ir]
      end

      def run(context)
        validate_context!(context)

        high_ir = context[:core_ir]
        return unless high_ir

        # For now, Mid IR is just a reference to the same HighIR structure
        # In the future, this will be an actual lowering transformation
        mid_ir = high_ir  # Identity transformation

        # Store Mid IR in context
        context[:mid_ir] = mid_ir
        context[:current_ir_level] = :mid_ir
      end
    end
  end
end
