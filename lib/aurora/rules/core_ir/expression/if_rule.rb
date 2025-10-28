# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class IfRule < DelegatingRule
          handles Aurora::AST::IfExpr, method: :transform_if_expr
        end
      end
    end
  end
end
