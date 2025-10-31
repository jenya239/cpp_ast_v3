# frozen_string_literal: true

require_relative "../../high_ir/builder"
require_relative "../../rules/base_rule"

module MLC
  module Rules
    module IRGen
      class MatchRule < BaseRule
        def applies?(node, _context = {})
          node.is_a?(MLC::AST::MatchExpr)
        end

        def apply(match_ast, context = {})
          scrutinee = context.fetch(:scrutinee)
          analyzer = context.fetch(:match_analyzer)
          transform_arm = context.fetch(:transform_arm)

          analysis = analyzer.analyze(
            scrutinee_type: scrutinee.type,
            arms: match_ast.arms,
            transform_arm: transform_arm
          )

          MLC::HighIR::Builder.match_expr(scrutinee, analysis.arms, analysis.result_type)
        end
      end
    end
  end
end
