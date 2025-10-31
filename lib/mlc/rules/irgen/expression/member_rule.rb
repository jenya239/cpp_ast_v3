# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Expression
        # MemberRule: Transform AST member access to HighIR member expressions
        # Contains FULL logic (no delegation to transformer)
        class MemberRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::MemberAccess)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)
            context_mgr = context.fetch(:context_manager)

            # Check if this is a module member function (e.g., Math.sqrt)
            entry = context_mgr.module_member_function(node.object, node.member) rescue nil
            if entry
              # Module function - create variable reference with canonical name
              canonical_name = entry.name
              type = type_checker.function_placeholder_type(canonical_name)
              return MLC::HighIR::Builder.var(canonical_name, type)
            end

            # Regular member access - transform object and infer member type
            object = expr_svc.transform_expression(node.object)
            type = type_checker.infer_member_type(object.type, node.member)

            # Build HighIR member access expression
            MLC::HighIR::Builder.member(object, node.member, type)
          end
        end
      end
    end
  end
end
