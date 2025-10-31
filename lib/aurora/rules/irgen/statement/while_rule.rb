# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Statement
        # WhileRule: Transform AST while statements to CoreIR
        # Contains FULL logic (no delegation to transformer)
        # Manages loop depth for break/continue validation
        class WhileRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::WhileStmt)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)
            context_mgr = context.fetch(:context_manager)

            # Transform condition and validate boolean type
            condition_ir = expr_svc.transform_expression(node.condition)
            type_checker.ensure_boolean(condition_ir.type, "while condition", node: node.condition)

            # Transform body within loop scope (for break/continue validation)
            body_ir = context_mgr.within_loop do
              expr_svc.transform_statement_block(node.body, preserve_scope: true)
            end

            # Build while statement
            [Aurora::CoreIR::Builder.while_stmt(condition_ir, body_ir)]
          end
        end
      end
    end
  end
end
