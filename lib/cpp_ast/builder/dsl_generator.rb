# frozen_string_literal: true

module CppAst
  module Builder
    # Генератор Ruby DSL кода из AST
    class DSLGenerator
      def initialize(indent: "  ", mode: :pretty)
        @indent = indent
        @level = 0
        @mode = mode
      end
      
      def generate(node)
        case node
        when Nodes::Program
          generate_program(node)
        when Nodes::FunctionDeclaration
          generate_function_declaration(node)
        when Nodes::VariableDeclaration
          generate_variable_declaration(node)
        when Nodes::BlockStatement
          generate_block_statement(node)
        when Nodes::ReturnStatement
          generate_return_statement(node)
        when Nodes::ExpressionStatement
          generate_expression_statement(node)
        when Nodes::IfStatement
          generate_if_statement(node)
        when Nodes::WhileStatement
          generate_while_statement(node)
        when Nodes::DoWhileStatement
          generate_do_while_statement(node)
        when Nodes::ForStatement
          generate_for_statement(node)
        when Nodes::SwitchStatement
          generate_switch_statement(node)
        when Nodes::CaseClause
          generate_case_clause(node)
        when Nodes::DefaultClause
          generate_default_clause(node)
        when Nodes::BreakStatement
          generate_break_statement(node)
        when Nodes::ContinueStatement
          generate_continue_statement(node)
        when Nodes::BinaryExpression
          generate_binary_expression(node)
        when Nodes::UnaryExpression
          generate_unary_expression(node)
        when Nodes::FunctionCallExpression
          generate_function_call_expression(node)
        when Nodes::MemberAccessExpression
          generate_member_access_expression(node)
        when Nodes::ParenthesizedExpression
          generate_parenthesized_expression(node)
        when Nodes::TernaryExpression
          generate_ternary_expression(node)
        when Nodes::ArraySubscriptExpression
          generate_array_subscript_expression(node)
        when Nodes::BraceInitializerExpression
          generate_brace_initializer_expression(node)
        when Nodes::Identifier
          generate_identifier(node)
        when Nodes::NumberLiteral
          generate_number_literal(node)
        when Nodes::StringLiteral
          generate_string_literal(node)
        when Nodes::CharLiteral
          generate_char_literal(node)
        when Nodes::EnumDeclaration
          generate_enum_declaration(node)
        when Nodes::UsingDeclaration
          generate_using_declaration(node)
        when Nodes::AccessSpecifier
          generate_access_specifier(node)
        when Nodes::NamespaceDeclaration
          generate_namespace_declaration(node)
        when Nodes::ClassDeclaration
          generate_class_declaration(node)
        when Nodes::StructDeclaration
          generate_struct_declaration(node)
        when Nodes::LambdaExpression
          generate_lambda_expression(node)
        when Nodes::TemplateDeclaration
          generate_template_declaration(node)
        when Nodes::ErrorStatement
          generate_error_statement(node)
        when Nodes::InlineComment
          generate_inline_comment(node)
        when Nodes::BlockComment
          generate_block_comment(node)
        when Nodes::DoxygenComment
          generate_doxygen_comment(node)
        when Nodes::DefineDirective
          generate_define_directive(node)
        when Nodes::IfdefDirective
          generate_ifdef_directive(node)
        when Nodes::IfndefDirective
          generate_ifndef_directive(node)
        when Nodes::FriendDeclaration
          generate_friend_declaration(node)
        when Nodes::ConceptDeclaration
          generate_concept_declaration(node)
        when Nodes::ModuleDeclaration
          generate_module_declaration(node)
        when Nodes::ImportDeclaration
          generate_import_declaration(node)
        when Nodes::ExportDeclaration
          generate_export_declaration(node)
        when Nodes::CoAwaitExpression
          generate_co_await_expression(node)
        when Nodes::CoYieldExpression
          generate_co_yield_expression(node)
        when Nodes::CoReturnStatement
          generate_co_return_statement(node)
        when MLC::AST::Program
          generate_aurora_program(node)
        else
          raise "Unsupported node type: #{node.class}"
        end
      end
      
      private
      
      attr_reader :indent, :level
      
      def current_indent
        indent * level
      end
      
      def with_indent
        @level += 1
        result = yield
        @level -= 1
        result
      end
      
      # Literals
      def generate_number_literal(node)
        "int(#{node.value.inspect})"
      end
      
      def generate_string_literal(node)
        "string(#{node.value.inspect})"
      end
      
      def generate_char_literal(node)
        "char(#{node.value.inspect})"
      end
      
      def generate_identifier(node)
        "id(#{node.name.inspect})"
      end
      
      # Expressions
      def generate_binary_expression(node)
        left = generate(node.left)
        right = generate(node.right)
        result = "binary(#{node.operator.inspect}, #{left}, #{right})"
        
        # Add fluent calls if trivia is non-default
        if node.operator_prefix != " "
          result += "\n#{current_indent}.with_operator_prefix(#{node.operator_prefix.inspect})"
        end
        if node.operator_suffix != " "
          result += "\n#{current_indent}.with_operator_suffix(#{node.operator_suffix.inspect})"
        end
        
        result
      end
      
      def generate_unary_expression(node)
        operand = generate(node.operand)
        if node.prefix
          result = "unary(#{node.operator.inspect}, #{operand})"
        else
          result = "unary_post(#{node.operator.inspect}, #{operand})"
        end
        
        if node.operator_suffix != ""
          result += "\n#{current_indent}.with_operator_suffix(#{node.operator_suffix.inspect})"
        end
        
        result
      end
      
      def generate_parenthesized_expression(node)
        expr = generate(node.expression)
        result = "paren(#{expr})"
        
        if node.open_paren_suffix != ""
          result += "\n#{current_indent}.with_open_paren_suffix(#{node.open_paren_suffix.inspect})"
        end
        if node.close_paren_prefix != ""
          result += "\n#{current_indent}.with_close_paren_prefix(#{node.close_paren_prefix.inspect})"
        end
        
        result
      end
      
      def generate_function_call_expression(node)
        callee = generate(node.callee)
        args = node.arguments.map { |arg| generate(arg) }
        
        if args.empty?
          result = "call(#{callee})"
        else
          result = "call(#{callee},\n"
          with_indent do
            args.each_with_index do |arg, i|
              result += "#{current_indent}#{arg}"
              result += "," unless i == args.length - 1
              result += "\n"
            end
          end
          result += "#{current_indent})"
        end
        
        # Add fluent calls for non-default separators
        default_seps = args.length > 1 ? Array.new(args.length - 1, ", ") : []
        if node.argument_separators != default_seps
          result += "\n#{current_indent}.with_argument_separators(#{node.argument_separators.inspect})"
        end
        
        if node.lparen_suffix != ""
          result += "\n#{current_indent}.with_lparen_suffix(#{node.lparen_suffix.inspect})"
        end
        if node.rparen_prefix != ""
          result += "\n#{current_indent}.with_rparen_prefix(#{node.rparen_prefix.inspect})"
        end
        
        result
      end
      
      def generate_member_access_expression(node)
        obj = generate(node.object)
        member = node.member.name
        result = "member(#{obj}, #{node.operator.inspect}, #{member.inspect})"
        
        if node.operator_prefix != ""
          result += "\n#{current_indent}.with_operator_prefix(#{node.operator_prefix.inspect})"
        end
        if node.operator_suffix != ""
          result += "\n#{current_indent}.with_operator_suffix(#{node.operator_suffix.inspect})"
        end
        
        result
      end
      
      # Statements
      def generate_expression_statement(node)
        expr = generate(node.expression)
        result = "expr_stmt(#{expr})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_return_statement(node)
        expr = generate(node.expression)
        result = "return_stmt(#{expr})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        if node.keyword_suffix != " "
          result += "\n#{current_indent}.with_keyword_suffix(#{node.keyword_suffix.inspect})"
        end
        
        result
      end
      
      def generate_block_statement(node)
        if node.statements.empty?
          result = "block()"
          
          # Fluent calls for empty block
          if node.lbrace_suffix != "\n"
            result += "\n#{current_indent}.with_lbrace_suffix(#{node.lbrace_suffix.inspect})"
          end
          if node.rbrace_prefix != ""
            result += "\n#{current_indent}.with_rbrace_prefix(#{node.rbrace_prefix.inspect})"
          end
          
          return result
        end
        
        result = "block(\n"
        with_indent do
          node.statements.each do |stmt|
            result += "#{current_indent}#{generate(stmt)},\n"
          end
        end
        result += "#{current_indent})"
        
        # Add fluent calls for trivia
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        # Check if statement_trailings are non-default
        default_trailings = Array.new(node.statements.length, "\n")
        if node.statement_trailings != default_trailings
          result += "\n#{current_indent}.with_statement_trailings(#{node.statement_trailings.inspect})"
        end
        
        if node.lbrace_suffix != "\n"
          result += "\n#{current_indent}.with_lbrace_suffix(#{node.lbrace_suffix.inspect})"
        end
        if node.rbrace_prefix != ""
          result += "\n#{current_indent}.with_rbrace_prefix(#{node.rbrace_prefix.inspect})"
        end
        
        result
      end
      
      def generate_if_statement(node)
        cond = generate(node.condition)
        then_stmt = generate(node.then_statement)
        
        if node.else_statement
          else_stmt = generate(node.else_statement)
          result = "if_stmt(#{cond},\n"
          with_indent do
            result += "#{current_indent}#{then_stmt},\n"
            result += "#{current_indent}#{else_stmt}\n"
          end
          result += "#{current_indent})"
        else
          result = "if_stmt(#{cond},\n"
          with_indent do
            result += "#{current_indent}#{then_stmt}\n"
          end
          result += "#{current_indent})"
        end
        
        # Fluent calls for trivia
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        if node.if_suffix != " "
          result += "\n#{current_indent}.with_if_suffix(#{node.if_suffix.inspect})"
        end
        if node.else_statement && node.else_prefix != " "
          result += "\n#{current_indent}.with_else_prefix(#{node.else_prefix.inspect})"
        end
        if node.else_statement && node.else_suffix != " "
          result += "\n#{current_indent}.with_else_suffix(#{node.else_suffix.inspect})"
        end
        
        result
      end
      
      # Declarations
      def generate_variable_declaration(node)
        result = "var_decl(#{node.type.inspect}"
        node.declarators.each do |decl|
          result += ", #{decl.inspect}"
        end
        result += ")"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        if node.type_suffix != " "
          result += "\n#{current_indent}.with_type_suffix(#{node.type_suffix.inspect})"
        end
        
        result
      end
      
      def generate_function_declaration(node)
        params = node.parameters.map(&:inspect).join(", ")
        
        if node.body
          body = generate(node.body)
          result = "function_decl(#{node.return_type.inspect}, #{node.name.inspect}, [#{params}],\n"
          with_indent do
            result += "#{current_indent}#{body}\n"
          end
          result += "#{current_indent})"
        else
          result = "function_decl(#{node.return_type.inspect}, #{node.name.inspect}, [#{params}])"
        end
        
        # Fluent calls
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        if node.return_type_suffix != " "
          result += "\n#{current_indent}.with_return_type_suffix(#{node.return_type_suffix.inspect})"
        end
        if node.body && node.rparen_suffix != " "
          result += "\n#{current_indent}.with_rparen_suffix(#{node.rparen_suffix.inspect})"
        end
        if node.modifiers_text != ""
          result += "\n#{current_indent}.with_modifiers_text(#{node.modifiers_text.inspect})"
        end
        if node.prefix_modifiers != ""
          result += "\n#{current_indent}.with_prefix_modifiers(#{node.prefix_modifiers.inspect})"
        end
        
        result
      end
      
      # Control flow statements
      def generate_while_statement(node)
        cond = generate(node.condition)
        body = generate(node.body)
        result = "while_stmt(#{cond},\n"
        with_indent do
          result += "#{current_indent}#{body}\n"
        end
        result += "#{current_indent})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        if node.while_suffix != " "
          result += "\n#{current_indent}.with_while_suffix(#{node.while_suffix.inspect})"
        end
        if node.condition_lparen_suffix != ""
          result += "\n#{current_indent}.with_condition_lparen_suffix(#{node.condition_lparen_suffix.inspect})"
        end
        if node.condition_rparen_suffix != ""
          result += "\n#{current_indent}.with_condition_rparen_suffix(#{node.condition_rparen_suffix.inspect})"
        end
        
        result
      end
      
      def generate_do_while_statement(node)
        body = generate(node.body)
        cond = generate(node.condition)
        result = "do_while_stmt(#{body},\n"
        with_indent do
          result += "#{current_indent}#{cond}\n"
        end
        result += "#{current_indent})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_for_statement(node)
        # Handle both classic and range-based for
        if node.init_trailing.start_with?(":")
          # Range-based for: for (auto x : vec)
          init_text = node.init ? node.init.to_source : ""
          range = node.condition ? generate(node.condition) : "nil"
          result = "range_for_stmt(#{init_text.inspect}, #{range},\n"
          with_indent do
            result += "#{current_indent}#{generate(node.body)}\n"
          end
          result += "#{current_indent})"
        else
          # Classic for: for (init; cond; inc)
          init = node.init ? generate(node.init) : "nil"
          cond = node.condition ? generate(node.condition) : "nil"
          inc = node.increment ? generate(node.increment) : "nil"
          result = "for_stmt(#{init}, #{cond}, #{inc},\n"
          with_indent do
            result += "#{current_indent}#{generate(node.body)}\n"
          end
          result += "#{current_indent})"
        end
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_switch_statement(node)
        expr = generate(node.expression)
        result = "switch_stmt(#{expr}"
        
        if node.cases.any?
          result += ",\n"
          with_indent do
            node.cases.each_with_index do |case_node, i|
              result += "#{current_indent}#{generate(case_node)}"
              result += "," unless i == node.cases.length - 1
              result += "\n"
            end
          end
          result += "#{current_indent})"
        else
          result += ")"
        end
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_case_clause(node)
        value = generate(node.value)
        result = "case_clause(#{value}"
        
        if node.statements.any?
          result += ",\n"
          with_indent do
            node.statements.each_with_index do |stmt, i|
              result += "#{current_indent}#{generate(stmt)}"
              result += "," unless i == node.statements.length - 1
              result += "\n"
            end
          end
          result += "#{current_indent})"
        else
          result += ")"
        end
        
        result
      end
      
      def generate_default_clause(node)
        result = "default_clause("
        
        if node.statements.any?
          result += "\n"
          with_indent do
            node.statements.each_with_index do |stmt, i|
              result += "#{current_indent}#{generate(stmt)}"
              result += "," unless i == node.statements.length - 1
              result += "\n"
            end
          end
          result += "#{current_indent})"
        else
          result += ")"
        end
        
        result
      end
      
      def generate_break_statement(node)
        result = "break_stmt"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_continue_statement(node)
        result = "continue_stmt"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      # Additional expressions
      def generate_ternary_expression(node)
        cond = generate(node.condition)
        true_expr = generate(node.true_expression)
        false_expr = generate(node.false_expression)
        result = "ternary(#{cond}, #{true_expr}, #{false_expr})"
        
        if node.question_prefix != " " || node.question_suffix != " " ||
           node.colon_prefix != " " || node.colon_suffix != " "
          result += "\n#{current_indent}.with_trivia(#{node.question_prefix.inspect}, #{node.question_suffix.inspect}, #{node.colon_prefix.inspect}, #{node.colon_suffix.inspect})"
        end
        
        result
      end
      
      def generate_array_subscript_expression(node)
        arr = generate(node.array)
        idx = generate(node.index)
        result = "subscript(#{arr}, #{idx})"
        
        if node.lbracket_suffix != ""
          result += "\n#{current_indent}.with_lbracket_suffix(#{node.lbracket_suffix.inspect})"
        end
        if node.rbracket_prefix != ""
          result += "\n#{current_indent}.with_rbracket_prefix(#{node.rbracket_prefix.inspect})"
        end
        
        result
      end
      
      def generate_brace_initializer_expression(node)
        type = generate(node.type)
        args = node.arguments.map { |arg| generate(arg) }
        
        if args.empty?
          result = "brace_init(#{type})"
        else
          result = "brace_init(#{type},\n"
          with_indent do
            args.each_with_index do |arg, i|
              result += "#{current_indent}#{arg}"
              result += "," unless i == args.length - 1
              result += "\n"
            end
          end
          result += "#{current_indent})"
        end
        
        result
      end
      
      # Declarations
      def generate_enum_declaration(node)
        result = "enum_decl(#{node.name.inspect}, #{node.enumerators.inspect}"
        result += ", class_keyword: #{node.class_keyword.inspect}" unless node.class_keyword.empty?
        result += ")"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_using_declaration(node)
        case node.kind
        when :namespace
          result = "using_namespace(#{node.name.inspect})"
        when :name
          result = "using_name(#{node.name.inspect})"
        when :alias
          result = "using_alias(#{node.name.inspect}, #{node.alias_target.inspect})"
        end
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_access_specifier(node)
        result = "access_spec(#{node.keyword.inspect})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_namespace_declaration(node)
        body = generate(node.body)
        result = "namespace_decl(#{node.name.inspect},\n"
        with_indent do
          result += "#{current_indent}#{body}\n"
        end
        result += "#{current_indent})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_class_declaration(node)
        members = node.members.map { |m| generate(m) }
        result = "class_decl(#{node.name.inspect}"
        
        if members.any?
          result += ",\n"
          with_indent do
            members.each_with_index do |m, i|
              result += "#{current_indent}#{m}"
              result += "," unless i == members.length - 1
              result += "\n"
            end
          end
          result += "#{current_indent})"
        else
          result += ")"
        end
        
        # Add base_classes if present
        unless node.base_classes_text.empty?
          result += "\n#{current_indent}.with_base_classes(#{node.base_classes_text.inspect})"
        end
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_struct_declaration(node)
        members = node.members.map { |m| generate(m) }
        result = "struct_decl(#{node.name.inspect}"
        
        if members.any?
          result += ",\n"
          with_indent do
            members.each_with_index do |m, i|
              result += "#{current_indent}#{m}"
              result += "," unless i == members.length - 1
              result += "\n"
            end
          end
          result += "#{current_indent})"
        else
          result += ")"
        end
        
        unless node.base_classes_text.empty?
          result += "\n#{current_indent}.with_base_classes(#{node.base_classes_text.inspect})"
        end
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_lambda_expression(node)
        result = "lambda_expr(#{node.capture.inspect}, #{node.parameters.inspect}, #{node.body.inspect}"
        result += ", specifiers: #{node.specifiers.inspect}" unless node.specifiers.empty?
        result += ")"
        
        if node.capture_suffix != ""
          result += "\n#{current_indent}.with_capture_suffix(#{node.capture_suffix.inspect})"
        end
        if node.params_suffix != ""
          result += "\n#{current_indent}.with_params_suffix(#{node.params_suffix.inspect})"
        end
        
        result
      end
      
      def generate_template_declaration(node)
        decl = generate(node.declaration)
        result = "template_decl(#{node.template_params.inspect},\n"
        with_indent do
          result += "#{current_indent}#{decl}\n"
        end
        result += "#{current_indent})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        if node.template_suffix != " "
          result += "\n#{current_indent}.with_template_suffix(#{node.template_suffix.inspect})"
        end
        if node.less_suffix != ""
          result += "\n#{current_indent}.with_less_suffix(#{node.less_suffix.inspect})"
        end
        if node.params_suffix != ""
          result += "\n#{current_indent}.with_params_suffix(#{node.params_suffix.inspect})"
        end
        
        result
      end
      
      def generate_error_statement(node)
        result = "error_stmt(#{node.error_text.inspect})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_program(node)
        if node.statements.empty?
          return "program()"
        end
        
        result = "program(\n"
        with_indent do
          node.statements.each do |stmt|
            result += "#{current_indent}#{generate(stmt)},\n"
          end
        end
        result += ")"
        
        # Check statement_trailings
        default_trailings = Array.new(node.statements.length, "\n")
        if node.statement_trailings != default_trailings
          result += "\n.with_statement_trailings(#{node.statement_trailings.inspect})"
        end
        
        result
      end
      
      # Comment generators - Phase 2
      def generate_inline_comment(node)
        result = "inline_comment(#{node.text.inspect})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_block_comment(node)
        result = "block_comment(#{node.text.inspect})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_doxygen_comment(node)
        result = "doxygen_comment(#{node.text.inspect}, style: #{node.style.inspect})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      # Preprocessor generators - Phase 2
      def generate_define_directive(node)
        result = "define_directive(#{node.name.inspect}"
        result += ", #{node.value.inspect}" unless node.value.empty?
        result += ")"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_ifdef_directive(node)
        body = node.body.map { |stmt| generate(stmt) }
        result = "ifdef_directive(#{node.name.inspect}"
        
        if body.any?
          result += ",\n"
          with_indent do
            body.each_with_index do |stmt, i|
              result += "#{current_indent}#{stmt}"
              result += "," unless i == body.length - 1
              result += "\n"
            end
          end
        end
        
        result += ")"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_ifndef_directive(node)
        body = node.body.map { |stmt| generate(stmt) }
        result = "ifndef_directive(#{node.name.inspect}"
        
        if body.any?
          result += ",\n"
          with_indent do
            body.each_with_index do |stmt, i|
              result += "#{current_indent}#{stmt}"
              result += "," unless i == body.length - 1
              result += "\n"
            end
          end
        end
        
        result += ")"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      # Friend declaration generator - Phase 3
      def generate_friend_declaration(node)
        result = "friend_decl(#{node.type.inspect}"
        result += ", #{node.name.inspect}" unless node.name.empty?
        result += ")"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      # Concept declaration generator - Phase 4
      def generate_concept_declaration(node)
        result = "concept_decl(#{node.name.inspect}, #{node.template_params.inspect}, #{node.requirements.inspect})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      # C++20 Modules generators - Phase 4
      def generate_module_declaration(node)
        body = node.body.map { |stmt| generate(stmt) }
        result = "module_decl(#{node.name.inspect}"
        
        if body.any?
          result += ",\n"
          with_indent do
            body.each_with_index do |stmt, i|
              result += "#{current_indent}#{stmt}"
              result += "," unless i == body.length - 1
              result += "\n"
            end
          end
        end
        
        result += ")"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_import_declaration(node)
        result = "import_decl(#{node.module_name.inspect})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_export_declaration(node)
        declarations = node.declarations.map { |decl| generate(decl) }
        result = "export_decl("
        
        if declarations.any?
          result += "\n"
          with_indent do
            declarations.each_with_index do |decl, i|
              result += "#{current_indent}#{decl}"
              result += "," unless i == declarations.length - 1
              result += "\n"
            end
          end
        end
        
        result += ")"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      # C++20 Coroutines generators - Phase 4
      def generate_co_await_expression(node)
        expr = generate(node.expression)
        result = "co_await(#{expr})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_co_yield_expression(node)
        expr = generate(node.expression)
        result = "co_yield(#{expr})"
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_co_return_statement(node)
        if node.expression
          expr = generate(node.expression)
          result = "co_return(#{expr})"
        else
          result = "co_return()"
        end
        
        if node.leading_trivia != ""
          result += "\n#{current_indent}.with_leading(#{node.leading_trivia.inspect})"
        end
        
        result
      end
      
      def generate_aurora_program(program)
        result = "#include <iostream>\n"
        result += "#include <memory>\n"
        result += "#include <vector>\n\n"
        
        # Generate imports
        program.imports.each do |import|
          result += "#include \"#{import.path}.hpp\"\n"
        end
        
        if program.imports.any?
          result += "\n"
        end
        
        # Generate module declaration
        if program.module_decl
          result += "namespace #{program.module_decl.name} {\n"
        end
        
        # Generate declarations
        program.declarations.each do |decl|
          result += generate_aurora_declaration(decl)
          result += "\n"
        end
        
        if program.module_decl
          result += "}\n"
        end
        
        result
      end
      
      def generate_aurora_declaration(decl)
        case decl
        when MLC::AST::FuncDecl
          generate_aurora_function(decl)
        when MLC::AST::TypeDecl
          generate_aurora_type(decl)
        else
          "// Unsupported declaration type: #{decl.class}"
        end
      end
      
      def generate_aurora_function(func)
        result = ""
        result += "int #{func.name}("
        result += func.params.map { |p| "int #{p.name}" }.join(", ")
        result += ") {\n"
        if func.body
          result += "  return #{generate_aurora_expression(func.body)};\n"
        else
          result += "  return 0;\n"
        end
        result += "}"
        result
      end
      
      def generate_aurora_expression(expr)
        case expr
        when MLC::AST::IntLit
          expr.value.to_s
        when MLC::AST::FloatLit
          expr.value.to_s
        when MLC::AST::VarRef
          expr.name
        when MLC::AST::BinaryOp
          left = generate_aurora_expression(expr.left)
          right = generate_aurora_expression(expr.right)
          if expr.op == "+" && is_string_expression(expr.left) && is_string_expression(expr.right)
            # String concatenation
            "aurora::String(#{left}) + aurora::String(#{right})"
          else
            "#{left} #{expr.op} #{right}"
          end
        else
          "0" # fallback
        end
      end
      
      def generate_aurora_type(type)
        "// Type declaration: #{type.name}"
      end
      
      private
      
      def is_string_expression(expr)
        case expr
        when MLC::AST::StringLit
          true
        when MLC::AST::VarRef
          # Without type context, we can't determine if a variable is a string
          # Conservative approach: assume it's not a string
          false
        when MLC::AST::BinaryOp
          # Check if this is a string concatenation
          expr.op == "+" && is_string_expression(expr.left) && is_string_expression(expr.right)
        else
          false
        end
      end

      # Aurora-specific generation methods
      def generate_aurora_program(program)
        result = []
        
        # Add includes
        result << '#include "aurora_match.hpp"'
        result << ""
        
        # Generate module namespace if present
        if program.module_decl
          result << "namespace #{program.module_decl.name} {"
          result << ""
        end
        
        # Generate declarations
        program.declarations.each do |decl|
          result << generate_aurora_declaration(decl)
          result << ""
        end
        
        # Close module namespace if present
        if program.module_decl
          result << "} // namespace #{program.module_decl.name}"
        end
        
        result.join("\n")
      end

      def generate_aurora_declaration(decl)
        case decl
        when MLC::AST::FuncDecl
          generate_aurora_function(decl)
        when MLC::AST::TypeDecl
          generate_aurora_type(decl)
        else
          "#{decl.class} // TODO: implement"
        end
      end

      def generate_aurora_function(func)
        result = []
        
        # Function signature
        signature = "auto #{func.name}("
        if func.params && !func.params.empty?
          signature += func.params.map { |param| "#{param.name}: #{generate_aurora_type(param.type)}" }.join(", ")
        end
        signature += ") -> #{generate_aurora_type(func.ret_type)}"
        
        result << signature
        result << "  = #{generate_aurora_expression(func.body)}"
        
        result.join("\n")
      end

      def generate_aurora_type(type)
        case type
        when MLC::AST::PrimType
          case type.name
          when "i32" then "int"
          when "f32" then "float"
          when "bool" then "bool"
          when "str" then "std::string"
          when "void" then "void"
          else type.name
          end
        when MLC::AST::ArrayType
          "std::vector<#{generate_aurora_type(type.element_type)}>"
        when MLC::AST::OptionType
          "std::optional<#{generate_aurora_type(type.inner_type)}>"
        else
          type.class.name # fallback
        end
      end

      def generate_aurora_expression(expr)
        case expr
        when MLC::AST::IntLit
          expr.value.to_s
        when MLC::AST::FloatLit
          expr.value.to_s
        when MLC::AST::StringLit
          "\"#{expr.value}\""
        when MLC::AST::VarRef
          expr.name
        when MLC::AST::BinaryOp
          left = generate_aurora_expression(expr.left)
          right = generate_aurora_expression(expr.right)
          if expr.op == "+" && is_string_expression(expr.left) && is_string_expression(expr.right)
            # String concatenation
            "aurora::String(#{left}) + aurora::String(#{right})"
          else
            "#{left} #{expr.op} #{right}"
          end
        when MLC::AST::UnaryOp
          "#{expr.op}#{generate_aurora_expression(expr.operand)}"
        when MLC::AST::IfExpr
          condition = generate_aurora_expression(expr.condition)
          then_expr = generate_aurora_expression(expr.then_expr)
          else_expr = generate_aurora_expression(expr.else_expr)
          "#{condition} ? #{then_expr} : #{else_expr}"
        when MLC::AST::FuncCall
          args = expr.args.map { |arg| generate_aurora_expression(arg) }.join(", ")
          "#{expr.name}(#{args})"
        when MLC::AST::ArrayLit
          elements = expr.elements.map { |elem| generate_aurora_expression(elem) }.join(", ")
          "{#{elements}}"
        when MLC::AST::ArrayAccess
          array = generate_aurora_expression(expr.array)
          index = generate_aurora_expression(expr.index)
          "#{array}[#{index}]"
        when MLC::AST::MemberAccess
          object = generate_aurora_expression(expr.object)
          "#{object}.#{expr.member}"
        when MLC::AST::Lambda
          params = expr.params.map { |param| "#{param.name}: #{generate_aurora_type(param.type)}" }.join(", ")
          body = generate_aurora_expression(expr.body)
          "(#{params}) => #{body}"
        else
          "0" # fallback
        end
      end
    end
  end
end

