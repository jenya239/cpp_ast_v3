# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/codegen/helpers"

module MLC
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering HighIR match expressions to C++ switch/if chains or std::visit
        # Handles two main strategies:
        # 1. Regex patterns -> if-else chain in IIFE
        # 2. Sum type patterns -> std::visit with overloaded lambdas
        class MatchRule < BaseRule
          include MLC::Backend::CodeGenHelpers

          def applies?(node, _context = {})
            node.is_a?(MLC::HighIR::MatchExpr)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            # Lower scrutinee expression
            scrutinee = lowerer.send(:lower_expression, node.scrutinee)

            # Check if any arms have regex patterns
            has_regex = node.arms.any? { |arm| arm[:pattern][:kind] == :regex }

            if has_regex
              # Generate if-else chain for regex matching
              lower_match_with_regex(node, scrutinee, lowerer)
            else
              # Generate MatchExpression with std::visit
              arms = node.arms.map { |arm| lower_match_arm(arm, lowerer) }

              CppAst::Nodes::MatchExpression.new(
                value: scrutinee,
                arms: arms,
                arm_separators: Array.new([arms.size - 1, 0].max, ",\n")
              )
            end
          end

          private

          # Lower match with regex patterns to IIFE with if-else chain
          def lower_match_with_regex(match_expr, scrutinee, lowerer)
            # Generate an IIFE (Immediately Invoked Function Expression) lambda
            # that contains if-else chain for regex matching:
            # [&]() {
            #   if (regex1.test(scrutinee)) return value1;
            #   if (regex2.test(scrutinee)) return value2;
            #   return default_value;
            # }()

            statements = []

            match_expr.arms.each do |arm|
              pattern = arm[:pattern]
              body = lowerer.send(:lower_expression, arm[:body])

              case pattern[:kind]
              when :regex
                statements.concat(build_regex_arm_statements(pattern, body, scrutinee))

              when :wildcard, :var
                # Default case - just return
                statements << CppAst::Nodes::ReturnStatement.new(expression: body)

              else
                # Other patterns not yet supported in regex match
                # Treat as wildcard for now
                statements << CppAst::Nodes::ReturnStatement.new(expression: body)
              end
            end

            # Build body string from statements
            body_str = statements.map { |stmt| stmt.to_source }.join(" ")

            # Create IIFE lambda: [&]() { ... }()
            CppAst::Nodes::FunctionCallExpression.new(
              callee: CppAst::Nodes::LambdaExpression.new(
                capture: "&",
                parameters: "",
                specifiers: "",
                body: body_str,
                capture_suffix: "",
                params_suffix: ""
              ),
              arguments: [],
              argument_separators: []
            )
          end

          # Build if statements for regex arm
          def build_regex_arm_statements(pattern, body, scrutinee)
            regex_pattern = pattern[:pattern]
            regex_flags = pattern[:flags] || ""
            bindings = pattern[:bindings] || []

            # Create regex object
            pattern_string = build_aurora_string(regex_pattern)
            func_name = regex_flags.include?("i") ? "aurora::regex_i" : "aurora::regex"
            regex_obj = CppAst::Nodes::FunctionCallExpression.new(
              callee: CppAst::Nodes::Identifier.new(name: func_name),
              arguments: [pattern_string],
              argument_separators: []
            )

            if bindings.empty?
              # No capture groups - use test()
              test_call = CppAst::Nodes::MemberAccessExpression.new(
                object: regex_obj,
                member: CppAst::Nodes::Identifier.new(name: "test"),
                operator: "."
              )

              test_result = CppAst::Nodes::FunctionCallExpression.new(
                callee: test_call,
                arguments: [scrutinee],
                argument_separators: []
              )

              return_stmt = CppAst::Nodes::ReturnStatement.new(expression: body)
              if_stmt = CppAst::Nodes::IfStatement.new(
                condition: test_result,
                then_statement: return_stmt,
                else_statement: nil
              )
              [if_stmt]
            else
              # Has capture groups - use match() and extract captures
              # Generate: if (auto match_opt = regex.match(text)) { auto match = *match_opt; auto user = match.get(1).text(); ... return body; }

              regex_src = regex_obj.to_source
              scrutinee_src = scrutinee.to_source
              body_src = body.to_source

              # Build capture variable declarations
              capture_decls = []
              bindings.each_with_index do |binding, idx|
                next if binding == "_"  # Skip wildcards
                # Generate: auto user = match.get(1).text();
                capture_decls << "auto #{binding} = match.get(#{idx}).text();"
              end

              # Build if statement with match and captures
              if_body = [
                "auto match = *match_opt;",
                *capture_decls,
                "return #{body_src};"
              ].join(" ")

              # Create raw if statement as string
              if_str = "if (auto match_opt = #{regex_src}.match(#{scrutinee_src})) { #{if_body} }"

              # Add as raw statement
              [CppAst::Nodes::RawStatement.new(code: if_str)]
            end
          end

          # Lower match arm to MatchArm node
          def lower_match_arm(arm, lowerer)
            pattern = arm[:pattern]
            body = lowerer.send(:lower_expression, arm[:body])

            case pattern[:kind]
            when :constructor
              # Generate MatchArm with constructor pattern
              case_name = pattern[:name]
              bindings = pattern[:bindings] || pattern[:fields] || []

              CppAst::Nodes::MatchArm.new(
                case_name: case_name,
                bindings: bindings.reject { |f| f == "_" },  # Filter out wildcards
                body: body
              )

            when :wildcard, :var
              # For wildcard or variable patterns, generate catch-all arm
              var_name = pattern[:kind] == :var ? pattern[:name] : "_unused"

              CppAst::Nodes::WildcardMatchArm.new(
                var_name: var_name,
                body: body
              )

            when :literal
              # Literal patterns need special handling
              # For now, treat as wildcard with a check
              CppAst::Nodes::WildcardMatchArm.new(
                var_name: "_v",
                body: body
              )

            when :regex
              # Regex pattern matching in std::visit context
              # Generate wildcard arm (actual matching handled elsewhere)
              CppAst::Nodes::WildcardMatchArm.new(
                var_name: "_text",
                body: body
              )

            else
              raise "Unknown pattern kind: #{pattern[:kind]}"
            end
          end
        end
      end
    end
  end
end
