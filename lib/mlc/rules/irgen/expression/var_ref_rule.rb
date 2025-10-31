# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Expression
        # VarRefRule: Transform AST variable references to HighIR variables
        # Contains FULL logic (no delegation to transformer)
        class VarRefRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::VarRef)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            type_inference = context.fetch(:type_inference)

            # Infer variable type from transformer's type context
            type = type_inference.infer_variable_type(node.name)

            # Build HighIR variable reference
            MLC::HighIR::Builder.var(node.name, type)
          end
        end
      end
    end
  end
end
