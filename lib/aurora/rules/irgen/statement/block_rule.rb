# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Statement
        # BlockRule: Transform AST block statements to CoreIR
        # Contains FULL logic (no delegation to transformer)
        # Flattens block statements into statement list
        class BlockRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::Block)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)

            # Transform block without requiring value (statement context)
            nested = expr_svc.transform_block(node, require_value: false)

            # Return flattened statements
            nested.statements
          end
        end
      end
    end
  end
end
