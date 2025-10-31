# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # VarRefRule: Transform AST variable references to CoreIR variables
        # Contains FULL logic (no delegation to transformer)
        class VarRefRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::VarRef)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)

            # Infer variable type from transformer's type context
            type = transformer.send(:infer_type, node.name)

            # Build CoreIR variable reference
            Aurora::CoreIR::Builder.var(node.name, type)
          end
        end
      end
    end
  end
end
