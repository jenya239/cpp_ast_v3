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
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)
            type_inference = context.fetch(:type_inference)
            context_mgr = context.fetch(:context_manager)

            # Special case: IO functions have fixed return types
            if node.callee.is_a?(Aurora::AST::VarRef) && transformer.class::IO_RETURN_TYPES.key?(node.callee.name)
              callee = expr_svc.transform_expression(node.callee)
              args = node.args.map { |arg| expr_svc.transform_expression(arg) }
              type = type_checker.io_return_type(node.callee.name)
              return Aurora::CoreIR::Builder.call(callee, args, type)
            end

            # General case: determine callee type
            callee_ast = node.callee
            object_ir = nil
            member_name = nil

            if callee_ast.is_a?(Aurora::AST::MemberAccess)
              # Member access call: check if module function or instance method
              entry = context_mgr.module_member_function(callee_ast.object, callee_ast.member)
              if entry
                # Module function (e.g., Math.sqrt)
                canonical_name = entry.name
                callee = Aurora::CoreIR::Builder.var(canonical_name, type_checker.function_placeholder_type(canonical_name))
              else
                # Instance method call (e.g., arr.map)
                object_ir = expr_svc.transform_expression(callee_ast.object)
                member_name = callee_ast.member
                callee = Aurora::CoreIR::Builder.member(object_ir, member_name, type_checker.infer_member_type(object_ir.type, member_name))
              end
            elsif callee_ast.is_a?(Aurora::AST::VarRef)
              # Variable reference (function name)
              var_type = type_checker.function_placeholder_type(callee_ast.name)
              callee = Aurora::CoreIR::Builder.var(callee_ast.name, var_type)
            else
              # Complex expression (e.g., lambda call)
              callee = expr_svc.transform_expression(callee_ast)
            end

            # Transform arguments with lambda type inference
            args = []
            node.args.each_with_index do |arg, index|
              # For map/filter/fold: infer lambda parameter types
              expected_params = type_inference.expected_lambda_param_types(object_ir, member_name, args, index)

              transformed_arg = if arg.is_a?(Aurora::AST::Lambda)
                                  # Transform lambda with expected parameter types
                                  context_mgr.with_lambda_params(expected_params) do
                                    expr_svc.transform_expression(arg)
                                  end
                                else
                                  expr_svc.transform_expression(arg)
                                end
              args << transformed_arg
            end

            # Infer call return type and build call expression
            type = type_inference.infer_call_type(callee, args)
            Aurora::CoreIR::Builder.call(callee, args, type)
          end
        end
      end
    end
  end
end
