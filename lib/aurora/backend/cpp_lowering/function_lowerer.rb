# frozen_string_literal: true

module Aurora
  module Backend
    class CppLowering
      # FunctionLowerer
      # Function and module lowering to C++
      # Auto-extracted from cpp_lowering.rb during refactoring
      module FunctionLowerer
      def lower_module(module_node)
              include_stmt = CppAst::Nodes::IncludeDirective.new(
                path: "aurora_match.hpp",
                system: false
              )
      
              items = module_node.items.flat_map do |item|
                result = lower(item)
                # If result is a Program (from sum types), extract its statements
                result.is_a?(CppAst::Nodes::Program) ? result.statements : [result]
              end
              statements = [include_stmt] + items
              trailings = ["\n"] + Array.new(items.size, "")
              CppAst::Nodes::Program.new(statements: statements, statement_trailings: trailings)
            end

      def lower_function(func)
              return_type = map_type(func.ret_type)
              name = func.name
              parameters = func.params.map { |param| "#{map_type(param.type)} #{param.name}" }
      
              block_body = if func.body.is_a?(CoreIR::BlockExpr)
                             stmts = lower_block_expr_statements(func.body, emit_return: true)
                             CppAst::Nodes::BlockStatement.new(
                               statements: stmts,
                               statement_trailings: Array.new(stmts.length, "\n"),
                               lbrace_suffix: "\n",
                               rbrace_prefix: ""
                             )
                           else
                             body_expr = lower_expression(func.body)
                             CppAst::Nodes::BlockStatement.new(
                               statements: [CppAst::Nodes::ReturnStatement.new(expression: body_expr)],
                               statement_trailings: [""],
                               lbrace_suffix: "",
                               rbrace_prefix: ""
                             )
                           end
      
              func_decl = CppAst::Nodes::FunctionDeclaration.new(
                return_type: return_type,
                name: name,
                parameters: parameters,
                body: block_body,
                return_type_suffix: " ",
                lparen_suffix: "",
                rparen_suffix: "",
                param_separators: parameters.size > 1 ? Array.new(parameters.size - 1, ", ") : [],
                modifiers_text: "",
                prefix_modifiers: ""
              )
      
              # If function has type parameters, wrap with template declaration
              if func.type_params.any?
                generate_template_function(func.type_params, func_decl)
              else
                func_decl
              end
            end

      def generate_template_function(type_params, func_decl)
              template_params_str, params_suffix = build_template_signature(type_params)
      
              CppAst::Nodes::TemplateDeclaration.new(
                template_params: template_params_str,
                declaration: func_decl,
                template_suffix: "",
                less_suffix: "",
                params_suffix: params_suffix
              )
            end

      end
    end
  end
end
