# frozen_string_literal: true

require_relative "../nodes/base"
require_relative "../nodes/expressions"
require_relative "../nodes/statements"

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
      
      def assign(left, right)
        binary("=", left, right)
      end
      
      def stream_output(left, right)
        binary("<<", left, right)
      end
      
      def address_of(expression)
        unary("&", expression)
      end
      
      def array(size)
        Nodes::ArrayExpression.new(size: size)
      end
      
      def bool(value)
        Nodes::BooleanLiteral.new(value: value)
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
        # Если передан один массив, развернуть его
        arguments = (args.size == 1 && args.first.is_a?(Array)) ? args.first : args
        separators = arguments.size > 1 ? Array.new(arguments.size - 1, ", ") : []
        Nodes::FunctionCallExpression.new(
          callee: callee,
          arguments: arguments,
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
          leading_trivia: "",  # Architecture: caller sets leading_trivia via with_leading_trivia()
          lbrace_suffix: "\n",  # Default: newline after { (standard C++ formatting)
          rbrace_prefix: ""
        )
      end

      def inline_block(*statements)
        trailings = statements.map { "" }
        Nodes::BlockStatement.new(
          statements: statements,
          statement_trailings: trailings,
          leading_trivia: "",
          lbrace_suffix: "",  # Inline: no newline after {
          rbrace_prefix: ""
        ).tap { |b| b.instance_variable_set(:@inline, true) }
      end

      def if_stmt(condition, then_statement, else_statement = nil)
        Nodes::IfStatement.new(
          condition: condition,
          then_statement: then_statement,
          else_statement: else_statement,
          if_suffix: " ",
          condition_rparen_suffix: "",
          else_prefix: " ",
          else_suffix: " "
        )
      end

      def while_stmt(condition, body)
        Nodes::WhileStatement.new(
          condition: condition,
          body: body,
          while_suffix: " ",
          condition_rparen_suffix: ""
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
          rparen_suffix: " "  # Space before body
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
        # Handle single declarator case: var_decl("int", "name") -> var_decl("int", "name")
        if declarators.length == 1 && declarators[0].is_a?(String)
          declarators = [declarators[0]]
        end
        
        separators = declarators.size > 1 ? Array.new(declarators.size - 1, ", ") : []
        Nodes::VariableDeclaration.new(
          type: type,
          declarators: declarators,
          declarator_separators: separators,
          type_suffix: " "
        )
      end
      
      def function_decl(return_type, name, parameters = [], body = nil)
        raise ArgumentError, "parameters cannot be nil" if parameters.nil?
        parameters = [] if parameters.nil?
        
        param_separators = parameters.size > 1 ? Array.new(parameters.size - 1, ", ") : []
        Nodes::FunctionDeclaration.new(
          return_type: return_type,
          name: name,
          parameters: parameters,
          body: body,
          return_type_suffix: " ",
          param_separators: param_separators,
          rparen_suffix: FormattingContext.get(:rparen_suffix)
        )
      end
      
      def namespace_decl(name, *members)
        body = members.length == 1 ? members[0] : program(*members)
        Nodes::NamespaceDeclaration.new(
          name: name,
          body: body,
          namespace_suffix: " ",
          name_suffix: " "
        )
      end
      
      def class_decl(name, *members)
        member_trailings = members.map { "\n" }
        lbrace_suffix = members.empty? ? "" : "\n"
        Nodes::ClassDeclaration.new(
          name: name,
          members: members,
          member_trailings: member_trailings,
          class_suffix: " ",
          name_suffix: members.empty? ? "" : " ",
          lbrace_suffix: lbrace_suffix
        )
      end
      
      # Class inheritance helper - Phase 1
      def class_with_inheritance(name, base_classes, *members)
        # Build inheritance text
        inheritance_text = ""
        if base_classes.any?
          inheritance_text = " : " + base_classes.join(", ")
        end
        
        member_trailings = members.map { "\n" }
        Nodes::ClassDeclaration.new(
          name: name,
          members: members,
          member_trailings: member_trailings,
          class_suffix: " ",
          name_suffix: " ",
          lbrace_suffix: "\n",
          base_classes_text: inheritance_text
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
        name_suffix = underlying_type ? FormattingContext.get(:name_suffix_with_underlying) : ""
        Nodes::EnumDeclaration.new(
          name: name,
          enumerators: values.map { |v| v.is_a?(Array) ? v : [v, nil] },
          enum_suffix: " ",
          class_keyword: "class",
          class_suffix: " ",
          name_suffix: name_suffix,
          lbrace_suffix: "",
          rbrace_suffix: "",
          underlying_type: underlying_type,
          colon_suffix: underlying_type ? " " : ""
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
      
      def friend_decl(type, name = nil)
        Nodes::FriendDeclaration.new(
          type: type,
          name: name,
          friend_suffix: FormattingContext.get(:friend_suffix)
        )
      end
      
      # Template DSL - Phase 1
      def template_class(name, template_params, *members)
        class_node = class_decl(name, *members)
        Nodes::TemplateDeclaration.new(
          template_params: template_params.join(", "),
          declaration: class_node,
          template_suffix: FormattingContext.get(:template_suffix),
          less_suffix: "",
          params_suffix: FormattingContext.get(:template_params_suffix)
        )
      end
      
      def template_method(return_type, name, template_params, params, body)
        func_node = function_decl(return_type, name, params, body)
        Nodes::TemplateDeclaration.new(
          template_params: template_params.join(", "),
          declaration: func_node,
          template_suffix: FormattingContext.get(:template_suffix),
          less_suffix: "",
          params_suffix: FormattingContext.get(:template_params_suffix)
        )
      end
      
      def access_spec(keyword)
        Nodes::AccessSpecifier.new(
          access_type: keyword,
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
          template_suffix: FormattingContext.get(:template_suffix),
          less_suffix: "",
          params_suffix: FormattingContext.get(:template_params_suffix)
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
        Nodes::Parameter.new(
          type: type,
          name: name,
          default_value: default,
          type_suffix: " "
        )
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
          elsif field.respond_to?(:to_source)
            field.to_source
          else
            field.to_s.end_with?(';') ? field.to_s : "#{field};"
          end
        end
        
        struct_decl(name, *field_declarations)
      end

      # Helper for field definitions
      def field_def(name, type, default: nil)
        # Aurora DSL convention: name comes first, then type
        Nodes::FieldDeclaration.new(
          type: type,
          name: name,
          default_value: default
        )
      end
      
      # Helper for const declarations
      def const_decl(type, name, value)
        Nodes::ConstDeclaration.new(
          type: type,
          name: name,
          value: value
        )
      end
      
      # Helper for number literals
      def number(value)
        Nodes::NumberLiteral.new(value: value.to_s)
      end
      
      # Helper for binary expressions
      def binary_expr(left, operator, right)
        Nodes::BinaryExpression.new(
          left: left,
          operator: operator,
          right: right,
          operator_prefix: " ",
          operator_suffix: " "
        )
      end
      
      # Helper for brace initializer
      def brace_initializer(*values)
        Nodes::BraceInitializerExpression.new(
          type: "auto",
          arguments: values.flatten,
          argument_separators: Array.new(values.flatten.size - 1, ", ")
        )
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
      
      # Include directive
      def include_directive(path, system: true)
        Nodes::IncludeDirective.new(
          path: path,
          system: system
        )
      end
      
      # Pragma directive
      def pragma_once()
        Nodes::PragmaDirective.new(directive: "once")
      end
      
      # Access specifiers
      def public_section(*members)
        [Nodes::AccessSpecifier.new(access_type: "public")] + members.flatten
      end
      
      def private_section(*members)
        [Nodes::AccessSpecifier.new(access_type: "private")] + members.flatten
      end
      
      def protected_section(*members)
        [Nodes::AccessSpecifier.new(access_type: "protected")] + members.flatten
      end
      
      # Comment DSL - Phase 2
      def inline_comment(text)
        Nodes::InlineComment.new(text: text)
      end
      
      def block_comment(text)
        Nodes::BlockComment.new(text: text)
      end
      
      def doxygen_comment(text, style: :inline)
        Nodes::DoxygenComment.new(text: text, style: style)
      end
      
      def doc_comment(text)
        doxygen_comment(text, style: :block)
      end
      
      # Preprocessor DSL - Phase 2
      def define_directive(name, value = "")
        Nodes::DefineDirective.new(name: name, value: value)
      end
      
      def ifdef_directive(name, *body)
        Nodes::IfdefDirective.new(name: name, body: body)
      end
      
      def ifndef_directive(name, *body)
        Nodes::IfndefDirective.new(name: name, body: body)
      end
      
      # Stream operations helper - Phase 2
      def stream_chain(stream, *args)
        # Start with the stream
        result = id(stream)
        
        # Chain all arguments with << operator
        args.each do |arg|
          result = binary("<<", result, arg)
        end
        
        result
      end
      
      def cerr_chain(*args)
        stream_chain("std::cerr", *args)
      end
      
      def cout_chain(*args)
        stream_chain("std::cout", *args)
      end
      
      def endl
        id("std::endl")
      end
      
      # Nested types helpers - Phase 3
      def nested_class(name, *members)
        class_decl(name, *members)
      end
      
      def nested_struct(name, *members)
        struct_decl(name, *members)
      end
      
      def nested_enum(name, *enumerators)
        enum_decl(name, enumerators)
      end
      
      def nested_enum_class(name, *enumerators)
        enum_class(name, enumerators)
      end
      
      def nested_namespace(name, *body)
        namespace_decl(name, *body)
      end
      
      # Static members helpers - Phase 3
      def static_constexpr(type, name, value)
        Nodes::VariableDeclaration.new(
          type: type,
          declarators: [name, value],
          declarator_separators: [", "],
          type_suffix: " ",
          prefix_modifiers: "constexpr static "
        )
      end
      
      def static_const(type, name, value)
        Nodes::VariableDeclaration.new(
          type: type,
          declarators: [name, value],
          declarator_separators: [", "],
          type_suffix: " ",
          prefix_modifiers: "const static "
        )
      end
      
      def inline_var(type, name, value)
        Nodes::VariableDeclaration.new(
          type: type,
          declarators: [name, value],
          declarator_separators: [", "],
          type_suffix: " ",
          prefix_modifiers: "inline "
        )
      end
      
      def static_inline_var(type, name, value)
        Nodes::VariableDeclaration.new(
          type: type,
          declarators: [name, value],
          declarator_separators: [", "],
          type_suffix: " ",
          prefix_modifiers: "inline static "
        )
      end
      
      # Advanced templates helpers - Phase 4
      def variadic_template_class(name, *params)
        template_params = params.map { |p| "typename #{p}" }
        template_params << "typename... Args"
        template_decl(template_params, class_decl(name))
      end
      
      def variadic_template_function(return_type, name, *params)
        template_params = params.map { |p| "typename #{p}" }
        template_params << "typename... Args"
        template_decl(template_params, function_decl(return_type, name))
      end
      
      def template_template_param(name, template_params)
        "template <#{template_params.join(', ')}> class #{name}"
      end
      
      def sfinae_requires(concept_name, *types)
        "requires #{concept_name}<#{types.join(', ')}>"
      end
      
      def concept_decl(name, template_params, requirements)
        Nodes::ConceptDeclaration.new(
          name: name,
          template_params: template_params,
          requirements: requirements
        )
      end
      
      # C++20 Modules - Phase 4
      def module_decl(name, *body)
        Nodes::ModuleDeclaration.new(
          name: name,
          body: body
        )
      end
      
      def import_decl(module_name)
        Nodes::ImportDeclaration.new(
          module_name: module_name
        )
      end
      
      def export_decl(*declarations)
        Nodes::ExportDeclaration.new(
          declarations: declarations
        )
      end
      
      # C++20 Coroutines - Phase 4
      def coroutine_function(return_type, name, parameters = [], body = nil)
        function_decl(return_type, name, parameters, body).coroutine()
      end
      
      def co_await(expression)
        Nodes::CoAwaitExpression.new(
          expression: expression
        )
      end
      
      def co_yield(expression)
        Nodes::CoYieldExpression.new(
          expression: expression
        )
      end
      
      def co_return(expression = nil)
        Nodes::CoReturnStatement.new(
          expression: expression
        )
      end
    end
  end
end

