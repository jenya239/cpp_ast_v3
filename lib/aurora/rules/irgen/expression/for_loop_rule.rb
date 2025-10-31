# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # ForLoopRule: Transform AST for-loop expressions to CoreIR
        # Contains FULL logic (no delegation to transformer)
        # Wraps for-loop statement in block expression with unit result
        class ForLoopRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::ForLoop)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)

            # Transform as statement-level for-loop
            loop_stmt = expr_svc.transform_for_statement(node)

            # Wrap in block expression with unit result (for-loops return unit)
            unit_result = Aurora::CoreIR::Builder.unit_literal(origin: node.origin)
            Aurora::CoreIR::Builder.block_expr(
              [loop_stmt],
              unit_result,
              unit_result.type
            )
          end
        end
      end
    end
  end
end
