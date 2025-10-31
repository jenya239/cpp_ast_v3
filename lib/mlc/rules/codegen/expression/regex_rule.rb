# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/codegen/helpers"

module MLC
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering HighIR regex expressions to C++ aurora::Regex objects
        # Pure function - all logic contained, no delegation
        class RegexRule < BaseRule
          include MLC::Backend::CodeGenHelpers

          def applies?(node, _context = {})
            node.is_a?(MLC::HighIR::RegexExpr)
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
