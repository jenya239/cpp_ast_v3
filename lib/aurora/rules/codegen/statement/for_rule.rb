# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/codegen/helpers"

module Aurora
  module Rules
    module CodeGen
      module Statement
        # Rule for lowering CoreIR for statements to C++ range-for loops
        class ForRule < BaseRule
          include Aurora::Backend::CodeGenHelpers

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::ForStmt)
          end

          def apply(node, context = {})
            build_range_for(node, context)
          end

          private

          def build_range_for(for_stmt, context)
            lowerer = context[:lowerer]

            # Lower container expression
            container = lowerer.send(:lower_expression, for_stmt.iterable)

            # Map variable type to C++ (using lowerer's map_type)
            var_type_str = lowerer.send(:map_type, for_stmt.var_type)
            variable = Aurora::Backend::ForLoopVariable.new(var_type_str, sanitize_identifier(for_stmt.var_name))

            # Lower body
            body_block = lower_for_body(for_stmt.body, lowerer)

            CppAst::Nodes::RangeForStatement.new(
              variable: variable,
              container: container,
              body: body_block
            )
          end

          def lower_for_body(body_ir, lowerer)
            if body_ir.is_a?(Aurora::CoreIR::BlockExpr)
              # Lower block statements without return
              stmts = lowerer.send(:lower_block_expr_statements, body_ir, emit_return: false)
              CppAst::Nodes::BlockStatement.new(
                statements: stmts,
                statement_trailings: Array.new(stmts.length, "\n"),
                lbrace_suffix: "\n",
                rbrace_prefix: ""
              )
            else
              # Single statement body
              stmt = lowerer.send(:lower_coreir_statement, body_ir)
              CppAst::Nodes::BlockStatement.new(
                statements: [stmt],
                statement_trailings: ["\n"],
                lbrace_suffix: "\n",
                rbrace_prefix: ""
              )
            end
          end
        end
      end
    end
  end
end
