# frozen_string_literal: true

require_relative "../../../rules/base_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class DoRule < DelegatingRule
          handles Aurora::AST::DoExpr, method: :transform_do_expr
        end
      end
    end
  end
end
