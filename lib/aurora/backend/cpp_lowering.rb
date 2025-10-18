# frozen_string_literal: true

require_relative "../../cpp_ast"
require_relative "../core_ir/nodes"

module Aurora
  module Backend
    # Simple variable representation for range-based for loops
    ForLoopVariable = Struct.new(:type_str, :name) do
      def to_source
        "#{type_str} #{name}"
      end
    end

    class CppLowering
      def initialize
        @type_map = {
          "i32" => "int",
          "f32" => "float",
          "bool" => "bool",
          "void" => "void",
          "string" => "std::string"
        }
      end
      
      def lower(core_ir)
        case core_ir
        when CoreIR::Module
          lower_module(core_ir)
        when CoreIR::Func
          lower_function(core_ir)
        when CoreIR::TypeDecl
          lower_type_decl(core_ir)
        else
          raise "Unknown CoreIR node: #{core_ir.class}"
        end
      end
      
      private
      
      def lower_module(module_node)
        items = module_node.items.flat_map do |item|
          result = lower(item)
          # If result is a Program (from sum types), extract its statements
          result.is_a?(CppAst::Nodes::Program) ? result.statements : [result]
        end
        CppAst::Nodes::Program.new(statements: items, statement_trailings: Array.new(items.size, ""))
      end
      
      def lower_function(func)
        return_type = map_type(func.ret_type)
        name = func.name
        parameters = func.params.map { |param| "#{map_type(param.type)} #{param.name}" }
        body = lower_expression(func.body)

        # Create function body as block
        block_body = CppAst::Nodes::BlockStatement.new(
          statements: [CppAst::Nodes::ReturnStatement.new(expression: body)],
          statement_trailings: [""],
          lbrace_suffix: "",
          rbrace_prefix: ""
        )

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
        # Generate: template<typename T, typename E> func_decl
        template_params_str = type_params.map { |tp| "typename #{tp}" }.join(", ")

        CppAst::Nodes::TemplateDeclaration.new(
          template_params: template_params_str,
          declaration: func_decl,
          template_suffix: "",
          less_suffix: "",
          params_suffix: "\n"
        )
      end
      
      def lower_type_decl(type_decl)
        result = case type_decl.type
                 when CoreIR::RecordType
                   lower_record_type(type_decl.name, type_decl.type)
                 when CoreIR::SumType
                   lower_sum_type(type_decl.name, type_decl.type, type_decl.type_params)
                 else
                   # For primitive types, we don't need to generate anything
                   CppAst::Nodes::Comment.new(text: "// Type alias: #{type_decl.name}")
                 end

        # If type has type parameters and result is a Program, wrap each statement with template
        if type_decl.type_params.any? && result.is_a?(CppAst::Nodes::Program)
          wrap_statements_with_template(type_decl.type_params, result)
        else
          result
        end
      end

      def wrap_statements_with_template(type_params, program)
        # Wrap each statement (struct declarations, using) with template
        template_params_str = type_params.map { |tp| "typename #{tp}" }.join(", ")

        wrapped_statements = program.statements.map do |stmt|
          CppAst::Nodes::TemplateDeclaration.new(
            template_params: template_params_str,
            declaration: stmt,
            template_suffix: "",
            less_suffix: "",
            params_suffix: "\n"
          )
        end

        CppAst::Nodes::Program.new(
          statements: wrapped_statements,
          statement_trailings: Array.new(wrapped_statements.size, "")
        )
      end
      
      def lower_record_type(name, record_type)
        # Generate struct declaration
        members = record_type.fields.map do |field|
          field_type = map_type(field[:type])
          CppAst::Nodes::VariableDeclaration.new(
            type: field_type,
            declarators: [field[:name]],
            declarator_separators: [],
            type_suffix: " ",
            prefix_modifiers: ""
          )
        end

        CppAst::Nodes::StructDeclaration.new(
          name: name,
          members: members,
          member_trailings: Array.new(members.size, ""),
          struct_suffix: " ",
          name_suffix: " ",
          lbrace_suffix: "",
          rbrace_suffix: "",
          base_classes_text: ""
        )
      end

      def lower_sum_type(name, sum_type, type_params = [])
        # Generate structs for each variant
        variant_structs = sum_type.variants.map do |variant|
          if variant[:fields].empty?
            # Empty variant - generate empty struct
            CppAst::Nodes::StructDeclaration.new(
              name: variant[:name],
              members: [],
              member_trailings: [],
              struct_suffix: " ",
              name_suffix: " ",
              lbrace_suffix: "",
              rbrace_suffix: "",
              base_classes_text: ""
            )
          else
            # Variant with fields
            members = variant[:fields].map do |field|
              field_type = map_type(field[:type])
              CppAst::Nodes::VariableDeclaration.new(
                type: field_type,
                declarators: [field[:name]],
                declarator_separators: [],
                type_suffix: " ",
                prefix_modifiers: ""
              )
            end

            CppAst::Nodes::StructDeclaration.new(
              name: variant[:name],
              members: members,
              member_trailings: Array.new(members.size, ""),
              struct_suffix: " ",
              name_suffix: " ",
              lbrace_suffix: "",
              rbrace_suffix: "",
              base_classes_text: ""
            )
          end
        end

        # Generate using declaration for std::variant
        variant_type_names = sum_type.variants.map { |v| v[:name] }.join(", ")
        using_decl = CppAst::Nodes::UsingDeclaration.new(
          kind: :alias,
          name: name,
          alias_target: "std::variant<#{variant_type_names}>",
          using_suffix: " ",
          equals_prefix: " ",
          equals_suffix: " "
        )

        # Return program with all structs + using declaration
        all_statements = variant_structs + [using_decl]
        CppAst::Nodes::Program.new(
          statements: all_statements,
          statement_trailings: Array.new(all_statements.size, "")
        )
      end
      
      def lower_expression(expr)
        return CppAst::Nodes::NumberLiteral.new(value: "0") if expr.nil?

        case expr
        when CoreIR::LiteralExpr
          lower_literal(expr)
        when CoreIR::VarExpr
          lower_variable(expr)
        when CoreIR::BinaryExpr
          lower_binary(expr)
        when CoreIR::CallExpr
          lower_call(expr)
        when CoreIR::MemberExpr
          lower_member(expr)
        when CoreIR::LetExpr
          lower_let(expr)
        when CoreIR::RecordExpr
          lower_record(expr)
        when CoreIR::IfExpr
          lower_if(expr)
        when CoreIR::MatchExpr
          lower_match(expr)
        when CoreIR::LambdaExpr
          lower_lambda(expr)
        when CoreIR::ArrayLiteralExpr
          lower_array_literal(expr)
        when CoreIR::IndexExpr
          lower_index(expr)
        when CoreIR::ForLoopExpr
          lower_for_loop(expr)
        else
          raise "Unknown expression: #{expr.class}"
        end
      end
      
      def lower_literal(lit)
        case lit.type.name
        when "i32"
          CppAst::Nodes::NumberLiteral.new(value: lit.value.to_s)
        when "f32"
          CppAst::Nodes::NumberLiteral.new(value: lit.value.to_s)
        when "bool"
          CppAst::Nodes::BooleanLiteral.new(value: lit.value)
        when "string"
          CppAst::Nodes::StringLiteral.new(value: lit.value)
        else
          CppAst::Nodes::NumberLiteral.new(value: lit.value.to_s)
        end
      end
      
      def lower_variable(var)
        CppAst::Nodes::Identifier.new(name: var.name)
      end
      
      def lower_binary(binary)
        left = lower_expression(binary.left)
        right = lower_expression(binary.right)
        
        CppAst::Nodes::BinaryExpression.new(
          left: left,
          operator: binary.op,
          right: right,
          operator_prefix: " ",
          operator_suffix: " "
        )
      end
      
      def lower_call(call)
        # Check if this is an array method call that needs translation
        if call.callee.is_a?(CoreIR::MemberExpr) && call.callee.object.type.is_a?(CoreIR::ArrayType)
          # Translate array method names to C++ std::vector equivalents
          method_name = call.callee.member
          cpp_method_name = case method_name
                            when "length"
                              "size"
                            when "push"
                              "push_back"
                            when "pop"
                              "pop_back"
                            else
                              method_name
                            end

          # Lower the array object
          array_obj = lower_expression(call.callee.object)

          # Create member access with translated method name
          member_access = CppAst::Nodes::MemberAccessExpression.new(
            object: array_obj,
            operator: ".",
            member: CppAst::Nodes::Identifier.new(name: cpp_method_name)
          )

          # Lower arguments
          args = call.args.map { |arg| lower_expression(arg) }
          num_separators = [args.size - 1, 0].max

          CppAst::Nodes::FunctionCallExpression.new(
            callee: member_access,
            arguments: args,
            argument_separators: Array.new(num_separators, ", ")
          )
        else
          # Regular function call
          callee = lower_expression(call.callee)
          args = call.args.map { |arg| lower_expression(arg) }

          # Calculate separators - need n-1 separators for n arguments, minimum 0
          num_separators = [args.size - 1, 0].max

          CppAst::Nodes::FunctionCallExpression.new(
            callee: callee,
            arguments: args,
            argument_separators: Array.new(num_separators, ", ")
          )
        end
      end
      
      def lower_member(member)
        object = lower_expression(member.object)

        CppAst::Nodes::MemberAccessExpression.new(
          object: object,
          operator: ".",
          member: CppAst::Nodes::Identifier.new(name: member.member)
        )
      end
      
      def lower_let(let)
        # For let expressions, we need to create a block with variable declaration
        # and then the body. This is a simplification - in real implementation
        # we'd need to handle this more carefully.
        _value = lower_expression(let.value)
        body = lower_expression(let.body)

        # Create a block that declares the variable and returns the body
        # This is a simplified approach - real implementation would be more complex
        body
      end
      
      def lower_record(record)
        # For record literals, we need to create a constructor call
        # This is simplified - real implementation would handle this properly
        type_name = record.type_name
        fields = record.fields

        # Create constructor call with field values
        args = fields.values.map { |value| lower_expression(value) }

        CppAst::Nodes::FunctionCallExpression.new(
          callee: CppAst::Nodes::Identifier.new(name: type_name),
          arguments: args,
          argument_separators: Array.new(args.size - 1, ", ")
        )
      end

      def lower_if(if_expr)
        condition = lower_expression(if_expr.condition)
        then_branch = lower_expression(if_expr.then_branch)
        else_branch = if_expr.else_branch ? lower_expression(if_expr.else_branch) : CppAst::Nodes::NumberLiteral.new(value: "0")

        # Generate ternary operator for if expressions
        CppAst::Nodes::TernaryExpression.new(
          condition: condition,
          true_expression: then_branch,
          false_expression: else_branch,
          question_prefix: " ",
          colon_prefix: " ",
          question_suffix: " ",
          colon_suffix: " "
        )
      end

      def lower_match(match_expr)
        scrutinee = lower_expression(match_expr.scrutinee)

        # Generate MatchArm for each arm
        arms = match_expr.arms.map do |arm|
          lower_match_arm(arm)
        end

        # Use MatchExpression which generates std::visit with overloaded
        CppAst::Nodes::MatchExpression.new(
          value: scrutinee,
          arms: arms,
          arm_separators: Array.new([arms.size - 1, 0].max, ",\n")
        )
      end

      def lower_array_literal(array_lit)
        # Generate C++ std::vector initializer list
        # Example: std::vector<int>{1, 2, 3}

        # Get element type
        element_type = map_type(array_lit.type.element_type)

        # Lower each element
        elements = array_lit.elements.map { |elem| lower_expression(elem) }

        # Generate brace initializer: std::vector<int>{1, 2, 3}
        CppAst::Nodes::BraceInitializerExpression.new(
          type: "std::vector<#{element_type}>",
          arguments: elements,
          argument_separators: elements.size > 1 ? Array.new(elements.size - 1, ", ") : []
        )
      end

      def lower_index(index_expr)
        # Generate C++ array subscript: arr[index]
        array = lower_expression(index_expr.object)
        index = lower_expression(index_expr.index)

        CppAst::Nodes::ArraySubscriptExpression.new(
          array: array,
          index: index
        )
      end

      def lower_for_loop(for_loop)
        # Generate C++ range-based for: for (type var : container) { body }

        # Lower the container/iterable
        container = lower_expression(for_loop.iterable)

        # Create variable representation for range-for
        var_type_str = map_type(for_loop.var_type)
        variable = ForLoopVariable.new(var_type_str, for_loop.var_name)

        # Lower the body - wrap in BlockStatement if needed
        body_expr = lower_expression(for_loop.body)

        # Wrap body in block statement
        # Note: For now, for loop body is an expression, so we create a statement from it
        body_stmt = CppAst::Nodes::ExpressionStatement.new(expression: body_expr)
        compound_body = CppAst::Nodes::BlockStatement.new(
          statements: [body_stmt],
          statement_trailings: [";"]
        )

        # Create range-based for statement
        CppAst::Nodes::RangeForStatement.new(
          variable: variable,
          container: container,
          body: compound_body
        )
      end

      def lower_lambda(lambda_expr)
        # Generate C++ lambda: [captures](params) { return body; }

        # Build capture clause (without brackets)
        if lambda_expr.captures.empty?
          capture = ""
        else
          # Build capture list
          captures = lambda_expr.captures.map do |cap|
            case cap[:mode]
            when :ref
              "&#{cap[:name]}"
            when :value
              cap[:name]
            else
              cap[:name]
            end
          end
          capture = captures.join(', ')
        end

        # Build parameter list
        params_str = lambda_expr.params.map do |param|
          "#{map_type(param.type)} #{param.name}"
        end.join(", ")

        # Lower body
        body_expr = lower_expression(lambda_expr.body)

        # Build body string with return statement
        body_str = "return #{body_expr.to_source};"

        # Create C++ lambda expression
        # LambdaExpression expects strings for parameters, not array
        CppAst::Nodes::LambdaExpression.new(
          capture: capture,
          parameters: params_str,
          specifiers: "",
          body: body_str,
          capture_suffix: "",
          params_suffix: " "
        )
      end

      def lower_match_arm(arm)
        pattern = arm[:pattern]
        body = lower_expression(arm[:body])

        case pattern[:kind]
        when :constructor
          # Generate MatchArm with constructor pattern
          case_name = pattern[:name]
          bindings = pattern[:fields] || []

          CppAst::Nodes::MatchArm.new(
            case_name: case_name,
            bindings: bindings.reject { |f| f == "_" },  # Filter out wildcards
            body: body
          )
        when :wildcard, :var
          # For wildcard or variable patterns, we need a generic lambda
          # This is tricky - we'll treat as a default case
          # Generate a lambda that matches anything
          var_name = pattern[:kind] == :var ? pattern[:name] : "_unused"

          # Create a catch-all arm using a generic type
          # We'll use a helper that generates: [&](auto&&) { return body; }
          CppAst::Nodes::WildcardMatchArm.new(
            var_name: var_name,
            body: body
          )
        when :literal
          # Literal patterns need special handling
          # For now, treat as wildcard with a check
          CppAst::Nodes::WildcardMatchArm.new(
            var_name: "_v",
            body: body
          )
        else
          raise "Unknown pattern kind: #{pattern[:kind]}"
        end
      end

      def map_type(type)
        case type
        when CoreIR::Type
          # Check if it's a known primitive type, otherwise treat as type parameter
          mapped = @type_map[type.name]
          if mapped
            mapped
          elsif type.name =~ /^[A-Z][a-zA-Z0-9]*$/  # Uppercase name - likely type parameter
            type.name  # Keep as-is (e.g., "T", "E", "Result")
          else
            @type_map[type.name] || type.name
          end
        when CoreIR::RecordType
          type.name
        when CoreIR::SumType
          type.name
        when CoreIR::FunctionType
          "auto" # Simplified - real implementation would be more complex
        else
          "auto"
        end
      end
    end
  end
end
