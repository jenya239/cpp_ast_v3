# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # MemberRule: Transform AST member access to CoreIR member expressions
        # Contains FULL logic (no delegation to transformer)
        class MemberRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::MemberAccess)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)

            # Check if this is a module member function (e.g., Math.sqrt)
            entry = transformer.send(:module_member_function_entry, node.object, node.member)
            if entry
              # Module function - create variable reference with canonical name
              canonical_name = entry.name
              type = transformer.send(:function_placeholder_type, canonical_name)
              return Aurora::CoreIR::Builder.var(canonical_name, type)
            end

            # Regular member access - transform object and infer member type
            object = transformer.send(:transform_expression, node.object)
            type = transformer.send(:infer_member_type, object.type, node.member)

            # Build CoreIR member access expression
            Aurora::CoreIR::Builder.member(object, node.member, type)
          end
        end
      end
    end
  end
end
