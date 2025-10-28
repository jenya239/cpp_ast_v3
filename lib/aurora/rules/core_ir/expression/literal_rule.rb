# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class LiteralRule < DelegatingRule
          handles [Aurora::AST::IntLit, Aurora::AST::FloatLit, Aurora::AST::StringLit,
                   Aurora::AST::RegexLit, Aurora::AST::UnitLit], method: :transform_literal
        end
      end
    end
  end
end
