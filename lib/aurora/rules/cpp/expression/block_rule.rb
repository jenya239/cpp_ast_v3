# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/cpp_lowering/helpers"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR block expressions to C++ blocks
        # Supports multiple strategies: IIFE, GCC extensions, inline
        class BlockRule < BaseRule
          include Aurora::Backend::CppLoweringHelpers

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::BlockExpr)
          end

          def apply(node, context = {})
            runtime_policy = context[:runtime_policy]
            lowerer = context[:lowerer]

            # Analyze block complexity to choose lowering strategy
            analyzer = Aurora::Backend::BlockComplexityAnalyzer.new(node)
            strategy = runtime_policy.strategy_for_block(analyzer)

            case strategy
            when :iife
              lower_as_iife(node, lowerer)
            when :scope_tmp
              lower_as_scope_tmp(node, lowerer, runtime_policy)
            when :gcc_expr
              lower_as_gcc_expr(node, lowerer)
            when :inline
              # For trivial blocks, just return the result expression
              node.result ? lowerer.send(:lower_expression, node.result) : nil
            else
              # Fallback to IIFE (conservative)
              lower_as_iife(node, lowerer)
            end
          end

          private

          # IIFE strategy: [&]() { ... return val; }()
          def lower_as_iife(block_expr, lowerer)
            statements = lower_statements(block_expr, lowerer, emit_return: true)
            body_lines = statements.map { |stmt| "  #{stmt.to_source}" }
            lambda_body = "\n#{body_lines.join("\n")}\n"

            lambda_expr = CppAst::Nodes::LambdaExpression.new(
              capture: "&",
              parameters: "",
              specifiers: "",
              body: lambda_body,
              capture_suffix: "",
              params_suffix: ""
            )

            CppAst::Nodes::FunctionCallExpression.new(
              callee: lambda_expr,
              arguments: [],
              argument_separators: []
            )
          end

          # Scope + tmp strategy: ({ ... val; })
          def lower_as_scope_tmp(block_expr, lowerer, runtime_policy)
            # For expression context, we need GCC extension or IIFE
            # Prefer GCC extension if enabled
            if runtime_policy.use_gcc_extensions
              lower_as_gcc_expr(block_expr, lowerer)
            else
              # For standard C++, use IIFE (compiler will optimize)
              lower_as_iife(block_expr, lowerer)
            end
          end

          # GCC expression statement: ({ ... })
          def lower_as_gcc_expr(block_expr, lowerer)
            # GCC/Clang extension: ({ statement; ... value; })
            # This creates a compound statement that returns a value
            # Example: ({ int x = 1; int y = 2; x + y; })

            statements = []

            # Lower all statements
            block_expr.statements.each do |stmt|
              statements << lowerer.send(:lower_coreir_statement, stmt)
            end

            # Add result expression as final statement (no return needed in GCC expr)
            if block_expr.result && !block_expr.result.is_a?(CoreIR::UnitLiteral)
              result_expr = lowerer.send(:lower_expression, block_expr.result)
              statements << CppAst::Nodes::ExpressionStatement.new(expression: result_expr)
            end

            # Generate compound expression: ({ ... })
            # Format with proper indentation
            body_lines = statements.map { |stmt| "  #{stmt.to_source}" }
            compound_body = "\n#{body_lines.join("\n")}\n"

            # Return as raw code wrapped in parentheses
            CppAst::Nodes::RawExpression.new(code: "(#{compound_body})")
          end

          # Helper to lower block statements with optional return
          def lower_statements(block_expr, lowerer, emit_return: true)
            statements = block_expr.statements.map { |stmt|
              lowerer.send(:lower_coreir_statement, stmt)
            }

            if block_expr.result
              # Skip unit literals - they represent void/no value
              unless block_expr.result.is_a?(CoreIR::UnitLiteral)
                result_expr = lowerer.send(:lower_expression, block_expr.result)
                if emit_return
                  statements << CppAst::Nodes::ReturnStatement.new(expression: result_expr)
                else
                  statements << CppAst::Nodes::ExpressionStatement.new(expression: result_expr)
                end
              end
            end

            statements
          end
        end
      end
    end
  end
end
