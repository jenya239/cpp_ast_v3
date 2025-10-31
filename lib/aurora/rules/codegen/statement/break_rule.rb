# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module CodeGen
      module Statement
        # Rule for lowering CoreIR break statements to C++ break statements
        class BreakRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::BreakStmt)
          end

          def apply(node, context = {})
            CppAst::Nodes::BreakStatement.new
          end
        end
      end
    end
  end
end
