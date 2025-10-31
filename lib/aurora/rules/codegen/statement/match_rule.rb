# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/codegen/helpers"

module Aurora
  module Rules
    module CodeGen
      module Statement
        # Rule for lowering CoreIR match statements to C++ std::visit
        class MatchRule < BaseRule
          include Aurora::Backend::CodeGenHelpers

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::MatchStmt)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            # Lower scrutinee expression
            scrutinee = lowerer.send(:lower_expression, node.scrutinee)

            # Lower match arms
            arms = node.arms.map { |arm| lower_match_arm_statement(arm, lowerer) }

            CppAst::Nodes::MatchStatement.new(
              value: scrutinee,
              arms: arms,
              arm_separators: Array.new([arms.length - 1, 0].max, ",\n")
            )
          end

          private

          def lower_match_arm_statement(arm, lowerer)
            pattern = arm[:pattern]
            body_block = lowerer.send(:lower_statement_block, arm[:body])

            case pattern[:kind]
            when :constructor
              case_name = pattern[:name]
              var_name = sanitize_identifier(case_name.downcase)
              bindings = Array(pattern[:bindings] || pattern[:fields]).compact.reject { |name| name == "_" }
              sanitized_bindings = bindings.map { |name| sanitize_identifier(name) }

              # Add structured binding if there are bindings
              block_with_binding = sanitized_bindings.any? ? add_structured_binding(body_block, sanitized_bindings, var_name) : body_block

              CppAst::Nodes::MatchArmStatement.new(
                case_name: case_name,
                var_name: var_name,
                body: block_with_binding
              )

            when :wildcard
              CppAst::Nodes::WildcardMatchArmStatement.new(
                var_name: "_unused",
                body: body_block
              )

            when :var
              var_name = sanitize_identifier(pattern[:name])
              CppAst::Nodes::WildcardMatchArmStatement.new(
                var_name: var_name,
                body: body_block
              )

            else
              raise "Unsupported pattern kind for statement match: #{pattern[:kind]}"
            end
          end

          def add_structured_binding(block_stmt, bindings, source_var)
            binding_list = bindings.join(", ")
            declarator = "[#{binding_list}] = #{source_var}"
            declaration = CppAst::Nodes::VariableDeclaration.new(
              type: "auto",
              declarators: [declarator],
              declarator_separators: [],
              type_suffix: " ",
              prefix_modifiers: ""
            )

            # Prepend structured binding declaration to block
            statements = [declaration] + block_stmt.statements
            trailings = ["\n"] + block_stmt.statement_trailings

            CppAst::Nodes::BlockStatement.new(
              statements: statements,
              statement_trailings: trailings,
              lbrace_suffix: block_stmt.lbrace_suffix,
              rbrace_prefix: block_stmt.rbrace_prefix
            )
          end
        end
      end
    end
  end
end
