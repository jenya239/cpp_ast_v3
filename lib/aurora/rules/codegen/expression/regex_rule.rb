# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/cpp_lowering/helpers"

module Aurora
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering CoreIR regex expressions to C++ aurora::Regex objects
        # Pure function - all logic contained, no delegation
        class RegexRule < BaseRule
          include Aurora::Backend::CppLoweringHelpers

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::RegexExpr)
          end

          def apply(node, _context = {})
            # Generate: aurora::regex_i(String("pattern")) or aurora::regex(String("pattern"))
            pattern_string = build_aurora_string(node.pattern)

            # Choose function based on flags
            func_name = if node.flags.include?("i")
                          "aurora::regex_i"
                        else
                          "aurora::regex"
                        end

            CppAst::Nodes::FunctionCallExpression.new(
              callee: CppAst::Nodes::Identifier.new(name: func_name),
              arguments: [pattern_string],
              argument_separators: []
            )
          end
        end
      end
    end
  end
end
