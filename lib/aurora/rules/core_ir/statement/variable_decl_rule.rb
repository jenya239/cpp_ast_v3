# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Statement
        class VariableDeclRule < DelegatingRule
          handles Aurora::AST::VariableDecl, method: :transform_variable_decl_statement
        end
      end
    end
  end
end
