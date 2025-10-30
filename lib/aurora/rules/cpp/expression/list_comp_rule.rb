# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/cpp_lowering/helpers"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR list comprehension expressions to C++ loops in IIFE
        # Example: [x * 2 for x in nums if x > 0] ->
        # [&]() { std::vector<int> result; for(auto x : nums) { if(!(x > 0)) continue; result.push_back(x * 2); } return result; }()
        class ListCompRule < BaseRule
          include Aurora::Backend::CppLoweringHelpers

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::ListCompExpr)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]
            type_map = context[:type_map] || {}
            type_registry = context[:type_registry]

            # Map element type to C++
            element_cpp_type = map_type(
              node.element_type,
              type_map: type_map,
              type_registry: type_registry
            )
            vector_type = "std::vector<#{element_cpp_type}>"

            # Create result vector declaration
            result_decl = CppAst::Nodes::VariableDeclaration.new(
              type: vector_type,
              declarators: ["result"],
              declarator_separators: [],
              type_suffix: " "
            )

            lambda_statements = [result_decl]

            # Build loop body: filters + push_back
            body_statements = build_filter_statements(node, lowerer)
            body_statements << build_push_back_statement(node, lowerer)

            # Wrap in block
            body_block = CppAst::Nodes::BlockStatement.new(
              statements: body_statements,
              statement_trailings: Array.new(body_statements.length, "\n"),
              lbrace_suffix: "\n",
              rbrace_prefix: ""
            )

            # Build nested range-for loops (reversed to get proper nesting)
            current_body = body_block
            outer_range_stmt = nil

            node.generators.reverse_each do |generator|
              var_type_str = map_type(
                generator[:var_type],
                type_map: type_map,
                type_registry: type_registry
              )
              variable = Aurora::Backend::ForLoopVariable.new(var_type_str, generator[:var_name])
              container_expr = lowerer.send(:lower_expression, generator[:iterable])

              range_stmt = CppAst::Nodes::RangeForStatement.new(
                variable: variable,
                container: container_expr,
                body: current_body
              )

              outer_range_stmt = range_stmt
              current_body = CppAst::Nodes::BlockStatement.new(
                statements: [range_stmt],
                statement_trailings: ["\n"],
                lbrace_suffix: "\n",
                rbrace_prefix: ""
              )
            end

            # Add loops or body to lambda statements
            if outer_range_stmt
              lambda_statements << outer_range_stmt
            else
              lambda_statements.concat(body_statements)
            end

            # Add return statement
            lambda_statements << CppAst::Nodes::ReturnStatement.new(
              expression: CppAst::Nodes::Identifier.new(name: "result")
            )

            # Generate IIFE lambda body
            body_str = lambda_statements.map(&:to_source).join("\n")

            lambda_expr = CppAst::Nodes::LambdaExpression.new(
              capture: "&",
              parameters: "",
              specifiers: "",
              body: body_str,
              capture_suffix: "",
              params_suffix: ""
            )

            # Return immediately invoked lambda
            CppAst::Nodes::FunctionCallExpression.new(
              callee: lambda_expr,
              arguments: [],
              argument_separators: []
            )
          end

          private

          # Build filter statements as if-continue guards
          def build_filter_statements(node, lowerer)
            node.filters.map do |filter_expr|
              # Lower filter expression
              condition_expr = lowerer.send(:lower_expression, filter_expr)

              # Negate: if (!(condition)) continue;
              parenthesized = CppAst::Nodes::ParenthesizedExpression.new(
                expression: condition_expr
              )
              negated = CppAst::Nodes::UnaryExpression.new(
                operator: "!",
                operand: parenthesized,
                prefix: true,
                operator_suffix: ""
              )

              # Build continue block
              continue_stmt = CppAst::Nodes::ContinueStatement.new
              continue_block = CppAst::Nodes::BlockStatement.new(
                statements: [continue_stmt],
                statement_trailings: ["\n"],
                lbrace_suffix: "\n",
                rbrace_prefix: ""
              )

              # Build if statement
              CppAst::Nodes::IfStatement.new(
                condition: negated,
                then_statement: continue_block,
                else_statement: nil,
                if_suffix: " ",
                condition_lparen_suffix: "",
                condition_rparen_suffix: "",
                else_prefix: "",
                else_suffix: ""
              )
            end
          end

          # Build result.push_back(output_expr) statement
          def build_push_back_statement(node, lowerer)
            push_call = CppAst::Nodes::FunctionCallExpression.new(
              callee: CppAst::Nodes::MemberAccessExpression.new(
                object: CppAst::Nodes::Identifier.new(name: "result"),
                operator: ".",
                member: CppAst::Nodes::Identifier.new(name: "push_back")
              ),
              arguments: [lowerer.send(:lower_expression, node.output_expr)],
              argument_separators: []
            )

            CppAst::Nodes::ExpressionStatement.new(expression: push_call)
          end
        end
      end
    end
  end
end
