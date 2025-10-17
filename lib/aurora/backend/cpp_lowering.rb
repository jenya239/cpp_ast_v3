# frozen_string_literal: true

require_relative "../../cpp_ast"
require_relative "../core_ir/nodes"

module Aurora
  module Backend
    class CppLowering
      def initialize
        @type_map = {
          "i32" => "int",
          "f32" => "float", 
          "bool" => "bool",
          "void" => "void"
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
        
        CppAst::Nodes::FunctionDeclaration.new(
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
      end
      
      def lower_type_decl(type_decl)
        case type_decl.type
        when CoreIR::RecordType
          lower_record_type(type_decl.name, type_decl.type)
        when CoreIR::SumType
          lower_sum_type(type_decl.name, type_decl.type)
        else
          # For primitive types, we don't need to generate anything
          CppAst::Nodes::Comment.new(text: "// Type alias: #{type_decl.name}")
        end
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

      def lower_sum_type(name, sum_type)
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
          @type_map[type.name] || type.name
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
