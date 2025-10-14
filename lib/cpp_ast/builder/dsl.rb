# frozen_string_literal: true

module CppAst
  module Builder
    module DSL
      # Literals
      def int(value)
        Nodes::NumberLiteral.new(value: value.to_s)
      end
      
      def float(value)
        Nodes::NumberLiteral.new(value: value.to_s)
      end
      
      def string(value)
        Nodes::StringLiteral.new(value: value)
      end
      
      def char(value)
        Nodes::CharLiteral.new(value: value)
      end
      
      # Identifiers
      def id(name)
        Nodes::Identifier.new(name: name)
      end
      
      # Binary operators
      def binary(operator, left, right)
        Nodes::BinaryExpression.new(
          left: left,
          operator: operator,
          right: right,
          operator_prefix: " ",
          operator_suffix: " "
        )
      end
      
      # Unary operators (prefix)
      def unary(operator, operand)
        Nodes::UnaryExpression.new(
          operator: operator,
          operand: operand,
          prefix: true
        )
      end
      
      # Unary operators (postfix)
      def unary_post(operator, operand)
        Nodes::UnaryExpression.new(
          operator: operator,
          operand: operand,
          prefix: false
        )
      end
      
      # Parenthesized expression
      def paren(expression)
        Nodes::ParenthesizedExpression.new(expression: expression)
      end
      
      # Function call
      def call(callee, *args)
        separators = args.size > 1 ? Array.new(args.size - 1, ", ") : []
        Nodes::FunctionCallExpression.new(
          callee: callee,
          arguments: args,
          argument_separators: separators
        )
      end
      
      # Member access
      def member(object, operator, member_name)
        Nodes::MemberAccessExpression.new(
          object: object,
          operator: operator,
          member: id(member_name)
        )
      end
      
      # Array subscript
      def subscript(array, index)
        Nodes::ArraySubscriptExpression.new(
          array: array,
          index: index
        )
      end
      
      # Ternary operator
      def ternary(condition, true_expr, false_expr)
        Nodes::TernaryExpression.new(
          condition: condition,
          true_expression: true_expr,
          false_expression: false_expr,
          question_prefix: " ",
          question_suffix: " ",
          colon_prefix: " ",
          colon_suffix: " "
        )
      end
      
      # Statements
      def expr_stmt(expression)
        Nodes::ExpressionStatement.new(expression: expression)
      end
      
      def return_stmt(expression)
        Nodes::ReturnStatement.new(expression: expression)
      end
      
      def block(*statements)
        trailings = statements.map { "\n" }
        Nodes::BlockStatement.new(
          statements: statements,
          statement_trailings: trailings,
          lbrace_suffix: "\n",
          rbrace_prefix: ""
        )
      end
      
      def if_stmt(condition, then_statement, else_statement = nil)
        Nodes::IfStatement.new(
          condition: condition,
          then_statement: then_statement,
          else_statement: else_statement,
          if_suffix: " ",
          else_prefix: " ",
          else_suffix: " "
        )
      end
      
      def while_stmt(condition, body)
        Nodes::WhileStatement.new(
          condition: condition,
          body: body,
          while_suffix: " "
        )
      end
      
      def for_stmt(init, condition, increment, body)
        Nodes::ForStatement.new(
          init: init,
          condition: condition,
          increment: increment,
          body: body,
          for_suffix: " ",
          lparen_suffix: "",
          init_trailing: " ",
          condition_trailing: " ",
          rparen_suffix: ""
        )
      end
      
      def break_stmt
        Nodes::BreakStatement.new
      end
      
      def continue_stmt
        Nodes::ContinueStatement.new
      end
      
      # Declarations
      def var_decl(type, *declarators)
        separators = declarators.size > 1 ? Array.new(declarators.size - 1, ", ") : []
        Nodes::VariableDeclaration.new(
          type: type,
          declarators: declarators,
          declarator_separators: separators,
          type_suffix: " "
        )
      end
      
      def function_decl(return_type, name, parameters = [], body = nil)
        param_separators = parameters.size > 1 ? Array.new(parameters.size - 1, ", ") : []
        Nodes::FunctionDeclaration.new(
          return_type: return_type,
          name: name,
          parameters: parameters,
          body: body,
          return_type_suffix: " ",
          param_separators: param_separators,
          rparen_suffix: body ? " " : ""
        )
      end
      
      def namespace_decl(name, body)
        Nodes::NamespaceDeclaration.new(
          name: name,
          body: body,
          namespace_suffix: " ",
          name_suffix: " "
        )
      end
      
      def class_decl(name, *members)
        member_trailings = members.map { "\n" }
        Nodes::ClassDeclaration.new(
          name: name,
          members: members,
          member_trailings: member_trailings,
          class_suffix: " ",
          name_suffix: " ",
          lbrace_suffix: "\n"
        )
      end
      
      def struct_decl(name, *members)
        member_trailings = members.map { "\n" }
        Nodes::StructDeclaration.new(
          name: name,
          members: members,
          member_trailings: member_trailings,
          struct_suffix: " ",
          name_suffix: " ",
          lbrace_suffix: "\n"
        )
      end
      
      def do_while_stmt(body, condition)
        Nodes::DoWhileStatement.new(
          body: body,
          condition: condition,
          do_suffix: " ",
          while_prefix: " ",
          while_suffix: " "
        )
      end
      
      def switch_stmt(expression, *cases)
        Nodes::SwitchStatement.new(
          expression: expression,
          cases: cases,
          switch_suffix: " ",
          lparen_suffix: "",
          rparen_suffix: "",
          lbrace_prefix: "",
          lbrace_suffix: "\n",
          rbrace_prefix: ""
        )
      end
      
      def case_clause(value, *statements)
        statement_trailings = statements.map { "\n" }
        Nodes::CaseClause.new(
          value: value,
          statements: statements,
          statement_trailings: statement_trailings,
          case_suffix: " ",
          colon_suffix: "\n"
        )
      end
      
      def default_clause(*statements)
        statement_trailings = statements.map { "\n" }
        Nodes::DefaultClause.new(
          statements: statements,
          statement_trailings: statement_trailings,
          colon_suffix: "\n"
        )
      end
      
      def enum_decl(name, enumerators, class_keyword: "")
        Nodes::EnumDeclaration.new(
          name: name,
          enumerators: enumerators,
          enum_suffix: " ",
          class_keyword: class_keyword,
          class_suffix: class_keyword.empty? ? "" : " ",
          name_suffix: " ",
          lbrace_suffix: "",
          rbrace_suffix: ""
        )
      end
      
      # Enum Class DSL - Phase 3
      def enum_class(name, values, underlying_type: nil)
        Nodes::EnumDeclaration.new(
          name: name,
          enumerators: values.map { |v| v.is_a?(Array) ? v : [v, nil] },
          enum_suffix: " ",
          class_keyword: "class",
          class_suffix: " ",
          name_suffix: " ",
          lbrace_suffix: "",
          rbrace_suffix: "",
          underlying_type: underlying_type
        )
      end
      
      def using_namespace(name)
        Nodes::UsingDeclaration.new(
          kind: :namespace,
          name: name,
          using_suffix: " ",
          namespace_suffix: " "
        )
      end
      
      def using_name(name)
        Nodes::UsingDeclaration.new(
          kind: :name,
          name: name,
          using_suffix: " "
        )
      end
      
      def using_alias(name, alias_target)
        Nodes::UsingDeclaration.new(
          kind: :alias,
          name: name,
          alias_target: alias_target,
          using_suffix: " ",
          equals_prefix: " ",
          equals_suffix: " "
        )
      end
      
      # Template DSL - Phase 1
      def template_class(name, template_params, *members)
        class_node = class_decl(name, *members)
        Nodes::TemplateDeclaration.new(
          template_params: template_params.join(", "),
          declaration: class_node,
          template_suffix: " ",
          less_suffix: "",
          params_suffix: "\n"
        )
      end
      
      def template_method(return_type, name, template_params, params, body)
        func_node = function_decl(return_type, name, params, body)
        Nodes::TemplateDeclaration.new(
          template_params: template_params.join(", "),
          declaration: func_node,
          template_suffix: " ",
          less_suffix: "",
          params_suffix: "\n"
        )
      end
      
      def access_spec(keyword)
        Nodes::AccessSpecifier.new(
          keyword: keyword,
          colon_suffix: ""
        )
      end
      
      def brace_init(type, *arguments)
        argument_separators = arguments.length > 1 ? Array.new(arguments.length - 1, ", ") : []
        Nodes::BraceInitializerExpression.new(
          type: type,
          arguments: arguments,
          argument_separators: argument_separators
        )
      end
      
      def range_for_stmt(init_text, range, body)
        # Range-based for: for (auto x : vec)
        Nodes::ForStatement.new(
          init: Nodes::Identifier.new(name: init_text),
          condition: range,
          increment: nil,
          body: body,
          for_suffix: " ",
          lparen_suffix: "",
          init_trailing: ": ",
          condition_trailing: "",
          rparen_suffix: ""
        )
      end
      
      # Lambda expression
      def lambda_expr(capture, parameters, body, specifiers: "")
        Nodes::LambdaExpression.new(
          capture: capture,
          parameters: parameters,
          body: body,
          specifiers: specifiers,
          capture_suffix: "",
          params_suffix: "  "
        )
      end
      
      # Template declaration
      def template_decl(template_params, declaration)
        Nodes::TemplateDeclaration.new(
          template_params: template_params,
          declaration: declaration,
          template_suffix: " ",
          less_suffix: "",
          params_suffix: ""
        )
      end
      
      # Error statement (unparsed code)
      def error_stmt(text)
        Nodes::ErrorStatement.new(error_text: text)
      end
      
      # Program
      def program(*statements)
        # All statements have "\n" trailing by default
        trailings = Array.new(statements.length, "\n")
        Nodes::Program.new(
          statements: statements,
          statement_trailings: trailings
        )
      end

      # Ownership types
      def owned(inner_type)
        Nodes::OwnedType.new(inner_type: inner_type)
      end

      def borrowed(inner_type)
        Nodes::BorrowedType.new(inner_type: inner_type)
      end

      def mut_borrowed(inner_type)
        Nodes::MutBorrowedType.new(inner_type: inner_type)
      end

      def span_of(inner_type)
        Nodes::SpanType.new(inner_type: inner_type)
      end

      # Helper for function parameters with ownership types
      def param(type, name, default: nil)
        type_str = type.respond_to?(:to_source) ? type.to_source : type.to_s
        result = "#{type_str} #{name}"
        result += " = #{default}" if default
        result
      end

      # Dereference operator
      def deref(expr)
        unary("*", expr)
      end

      # Result/Option types
      def result_of(ok_type, err_type)
        Nodes::ExpectedType.new(ok_type: ok_type, err_type: err_type)
      end

      def option_of(inner_type)
        Nodes::OptionalType.new(inner_type: inner_type)
      end

      # Result/Option constructors
      def ok(value)
        Nodes::OkValue.new(value: value)
      end

      def err(error)
        Nodes::ErrValue.new(error: error)
      end

      def some(value)
        Nodes::SomeValue.new(value: value)
      end

      def none
        Nodes::NoneValue.new
      end

      # Product types (alias for struct)
      def product_type(name, *fields)
        field_declarations = fields.map do |field|
          if field.is_a?(Array) && field.length == 2
            "#{field[1]} #{field[0]};"
          else
            field.to_s.end_with?(';') ? field.to_s : "#{field};"
          end
        end
        
        struct_decl(name, *field_declarations)
      end

      # Helper for field definitions
      def field_def(name, type)
        [name, type]
      end

      # Sum types (variant-based ADT)
      def sum_type(name, *cases)
        case_trailings = cases.map { "\n" }
        Nodes::SumTypeDeclaration.new(
          name: name,
          cases: cases,
          case_trailings: case_trailings
        )
      end

      # Helper for case struct definitions
      def case_struct(name, *fields)
        field_trailings = fields.map { "\n" }
        Nodes::VariantCase.new(
          name: name,
          fields: fields,
          field_trailings: field_trailings
        )
      end

      # Pattern matching
      def match_expr(value, *arms)
        arm_separators = arms.size > 1 ? Array.new(arms.size - 1, ",\n") : []
        Nodes::MatchExpression.new(
          value: value,
          arms: arms,
          arm_separators: arm_separators
        )
      end

      # Helper for match arms
      def arm(case_name, bindings = [], body)
        Nodes::MatchArm.new(
          case_name: case_name,
          bindings: bindings,
          body: body
        )
      end
    end
  end
end

