# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # CallRule: Transform AST call expressions to CoreIR call expressions
        # Contains FULL logic (no delegation to transformer)
        # Handles IO functions, member calls, module functions, lambda type inference
        class CallRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::Call)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)

            # Special case: IO functions have fixed return types
            if node.callee.is_a?(Aurora::AST::VarRef) && transformer.class::IO_RETURN_TYPES.key?(node.callee.name)
              callee = transformer.send(:transform_expression, node.callee)
              args = node.args.map { |arg| transformer.send(:transform_expression, arg) }
              type = transformer.send(:io_return_type, node.callee.name)
              return Aurora::CoreIR::Builder.call(callee, args, type)
            end

            # General case: determine callee type
            callee_ast = node.callee
            object_ir = nil
            member_name = nil

            if callee_ast.is_a?(Aurora::AST::MemberAccess)
              # Member access call: check if module function or instance method
              entry = transformer.send(:module_member_function_entry, callee_ast.object, callee_ast.member)
              if entry
                # Module function (e.g., Math.sqrt)
                canonical_name = entry.name
                callee = Aurora::CoreIR::Builder.var(canonical_name, transformer.send(:function_placeholder_type, canonical_name))
              else
                # Instance method call (e.g., arr.map)
                object_ir = transformer.send(:transform_expression, callee_ast.object)
                member_name = callee_ast.member
                callee = Aurora::CoreIR::Builder.member(object_ir, member_name, transformer.send(:infer_member_type, object_ir.type, member_name))
              end
            elsif callee_ast.is_a?(Aurora::AST::VarRef)
              # Variable reference (function name)
              var_type = transformer.send(:function_placeholder_type, callee_ast.name)
              callee = Aurora::CoreIR::Builder.var(callee_ast.name, var_type)
            else
              # Complex expression (e.g., lambda call)
              callee = transformer.send(:transform_expression, callee_ast)
            end

            # Transform arguments with lambda type inference
            args = []
            node.args.each_with_index do |arg, index|
              # For map/filter/fold: infer lambda parameter types
              expected_params = transformer.send(:expected_lambda_param_types, object_ir, member_name, args, index)

              transformed_arg = if arg.is_a?(Aurora::AST::Lambda)
                                  # Transform lambda with expected parameter types
                                  transformer.send(:with_lambda_param_types, expected_params) do
                                    transformer.send(:transform_expression, arg)
                                  end
                                else
                                  transformer.send(:transform_expression, arg)
                                end
              args << transformed_arg
            end

            # Infer call return type and build call expression
            type = transformer.send(:infer_call_type, callee, args)
            Aurora::CoreIR::Builder.call(callee, args, type)
          end
        end
      end
    end
  end
end
