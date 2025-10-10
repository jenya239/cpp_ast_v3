# frozen_string_literal: true

module CppAst
  module Nodes
    # ExpressionStatement: `foo;`
    class ExpressionStatement < Statement
      attr_accessor :expression
      
      def initialize(leading_trivia: "", expression:)
        super(leading_trivia: leading_trivia)
        @expression = expression
      end
      
      def to_source
        "#{leading_trivia}#{expression.to_source};"
      end
    end
    
    # ReturnStatement: `return 42;`
    class ReturnStatement < Statement
      attr_accessor :expression, :keyword_suffix
      
      def initialize(leading_trivia: "", expression:, keyword_suffix: " ")
        super(leading_trivia: leading_trivia)
        @expression = expression
        @keyword_suffix = keyword_suffix
      end
      
      def to_source
        "#{leading_trivia}return#{keyword_suffix}#{expression.to_source};"
      end
    end
    
    # BlockStatement: `{ stmt1; stmt2; }`
    class BlockStatement < Statement
      attr_accessor :statements, :statement_trailings
      attr_accessor :lbrace_suffix, :rbrace_prefix
      
      def initialize(leading_trivia: "", statements:, statement_trailings:, lbrace_suffix: "", rbrace_prefix: "")
        super(leading_trivia: leading_trivia)
        @statements = statements
        @statement_trailings = statement_trailings
        @lbrace_suffix = lbrace_suffix
        @rbrace_prefix = rbrace_prefix
      end
      
      def to_source
        result = "#{leading_trivia}{#{lbrace_suffix}"
        
        statements.zip(statement_trailings).each do |stmt, trailing|
          result << stmt.to_source << trailing
        end
        
        result << "#{rbrace_prefix}}"
        result
      end
    end
    
    # IfStatement: `if (cond) { ... } else { ... }`
    class IfStatement < Statement
      attr_accessor :condition, :then_statement, :else_statement
      attr_accessor :if_suffix, :condition_lparen_suffix, :condition_rparen_suffix
      attr_accessor :else_prefix, :else_suffix
      
      def initialize(leading_trivia: "", condition:, then_statement:, else_statement: nil,
                     if_suffix: "", condition_lparen_suffix: "", condition_rparen_suffix: "",
                     else_prefix: "", else_suffix: "")
        super(leading_trivia: leading_trivia)
        @condition = condition
        @then_statement = then_statement
        @else_statement = else_statement
        @if_suffix = if_suffix
        @condition_lparen_suffix = condition_lparen_suffix
        @condition_rparen_suffix = condition_rparen_suffix
        @else_prefix = else_prefix
        @else_suffix = else_suffix
      end
      
      def to_source
        result = "#{leading_trivia}if#{if_suffix}(#{condition_lparen_suffix}"
        result << condition.to_source
        result << "#{condition_rparen_suffix})#{then_statement.to_source}"
        
        if else_statement
          result << "#{else_prefix}else#{else_suffix}#{else_statement.to_source}"
        end
        
        result
      end
    end
    
    # WhileStatement: `while (cond) { ... }`
    class WhileStatement < Statement
      attr_accessor :condition, :body
      attr_accessor :while_suffix, :condition_lparen_suffix, :condition_rparen_suffix
      
      def initialize(leading_trivia: "", condition:, body:,
                     while_suffix: "", condition_lparen_suffix: "", condition_rparen_suffix: "")
        super(leading_trivia: leading_trivia)
        @condition = condition
        @body = body
        @while_suffix = while_suffix
        @condition_lparen_suffix = condition_lparen_suffix
        @condition_rparen_suffix = condition_rparen_suffix
      end
      
      def to_source
        "#{leading_trivia}while#{while_suffix}(#{condition_lparen_suffix}" \
        "#{condition.to_source}#{condition_rparen_suffix})#{body.to_source}"
      end
    end
    
    # DoWhileStatement: `do { ... } while (cond);`
    class DoWhileStatement < Statement
      attr_accessor :body, :condition
      attr_accessor :do_suffix, :while_prefix, :while_suffix
      attr_accessor :condition_lparen_suffix, :condition_rparen_suffix
      
      def initialize(leading_trivia: "", body:, condition:,
                     do_suffix: "", while_prefix: "", while_suffix: "",
                     condition_lparen_suffix: "", condition_rparen_suffix: "")
        super(leading_trivia: leading_trivia)
        @body = body
        @condition = condition
        @do_suffix = do_suffix
        @while_prefix = while_prefix
        @while_suffix = while_suffix
        @condition_lparen_suffix = condition_lparen_suffix
        @condition_rparen_suffix = condition_rparen_suffix
      end
      
      def to_source
        "#{leading_trivia}do#{do_suffix}#{body.to_source}#{while_prefix}while#{while_suffix}" \
        "(#{condition_lparen_suffix}#{condition.to_source}#{condition_rparen_suffix});"
      end
    end
    
    # ForStatement: `for (init; cond; inc) { ... }`
    class ForStatement < Statement
      attr_accessor :init, :condition, :increment, :body
      attr_accessor :for_suffix, :lparen_suffix
      attr_accessor :init_trailing, :condition_trailing, :rparen_suffix
      
      def initialize(leading_trivia: "", init:, condition:, increment:, body:,
                     for_suffix: "", lparen_suffix: "",
                     init_trailing: "", condition_trailing: "", rparen_suffix: "")
        super(leading_trivia: leading_trivia)
        @init = init
        @condition = condition
        @increment = increment
        @body = body
        @for_suffix = for_suffix
        @lparen_suffix = lparen_suffix
        @init_trailing = init_trailing
        @condition_trailing = condition_trailing
        @rparen_suffix = rparen_suffix
      end
      
      def to_source
        result = "#{leading_trivia}for#{for_suffix}(#{lparen_suffix}"
        result << (init ? init.to_source : "")
        result << ";#{init_trailing}"
        result << (condition ? condition.to_source : "")
        result << ";#{condition_trailing}"
        result << (increment ? increment.to_source : "")
        result << "#{rparen_suffix})#{body.to_source}"
        result
      end
    end
    
    # SwitchStatement: `switch (expr) { case 1: ...; default: ...; }`
    class SwitchStatement < Statement
      attr_accessor :expression, :cases
      attr_accessor :switch_suffix, :lparen_suffix, :rparen_suffix
      attr_accessor :lbrace_prefix, :lbrace_suffix, :rbrace_prefix
      
      def initialize(leading_trivia: "", expression:, cases:,
                     switch_suffix: "", lparen_suffix: "", rparen_suffix: "",
                     lbrace_prefix: "", lbrace_suffix: "", rbrace_prefix: "")
        super(leading_trivia: leading_trivia)
        @expression = expression
        @cases = cases
        @switch_suffix = switch_suffix
        @lparen_suffix = lparen_suffix
        @rparen_suffix = rparen_suffix
        @lbrace_prefix = lbrace_prefix
        @lbrace_suffix = lbrace_suffix
        @rbrace_prefix = rbrace_prefix
      end
      
      def to_source
        result = "#{leading_trivia}switch#{switch_suffix}(#{lparen_suffix}"
        result << "#{expression.to_source}#{rparen_suffix})#{lbrace_prefix}{#{lbrace_suffix}"
        cases.each { |c| result << c.to_source }
        result << "#{rbrace_prefix}}"
        result
      end
    end
    
    # CaseClause: `case value: statements`
    class CaseClause < Node
      attr_accessor :value, :statements, :statement_trailings
      attr_accessor :leading_trivia, :case_suffix, :colon_suffix
      
      def initialize(leading_trivia: "", value:, statements:, statement_trailings:,
                     case_suffix: "", colon_suffix: "")
        @leading_trivia = leading_trivia
        @value = value
        @statements = statements
        @statement_trailings = statement_trailings
        @case_suffix = case_suffix
        @colon_suffix = colon_suffix
      end
      
      def to_source
        result = "#{leading_trivia}case#{case_suffix}#{value.to_source}:#{colon_suffix}"
        statements.zip(statement_trailings).each do |stmt, trailing|
          result << stmt.to_source << trailing
        end
        result
      end
    end
    
    # DefaultClause: `default: statements`
    class DefaultClause < Node
      attr_accessor :statements, :statement_trailings
      attr_accessor :leading_trivia, :colon_suffix
      
      def initialize(leading_trivia: "", statements:, statement_trailings:, colon_suffix: "")
        @leading_trivia = leading_trivia
        @statements = statements
        @statement_trailings = statement_trailings
        @colon_suffix = colon_suffix
      end
      
      def to_source
        result = "#{leading_trivia}default:#{colon_suffix}"
        statements.zip(statement_trailings).each do |stmt, trailing|
          result << stmt.to_source << trailing
        end
        result
      end
    end
    
    # BreakStatement: `break;`
    class BreakStatement < Statement
      def initialize(leading_trivia: "")
        super(leading_trivia: leading_trivia)
      end
      
      def to_source
        "#{leading_trivia}break;"
      end
    end
    
    # ContinueStatement: `continue;`
    class ContinueStatement < Statement
      def initialize(leading_trivia: "")
        super(leading_trivia: leading_trivia)
      end
      
      def to_source
        "#{leading_trivia}continue;"
      end
    end
    
    # NamespaceDeclaration: `namespace name { ... }`
    class NamespaceDeclaration < Statement
      attr_accessor :name, :body
      attr_accessor :namespace_suffix, :name_suffix
      
      def initialize(leading_trivia: "", name:, body:,
                     namespace_suffix: "", name_suffix: "")
        super(leading_trivia: leading_trivia)
        @name = name
        @body = body
        @namespace_suffix = namespace_suffix
        @name_suffix = name_suffix
      end
      
      def to_source
        "#{leading_trivia}namespace#{namespace_suffix}#{name}#{name_suffix}#{body.to_source}"
      end
    end
    
    # FunctionDeclaration: `type name(params);` or `type name(params) override { ... }`
    class FunctionDeclaration < Statement
      attr_accessor :return_type, :name, :parameters, :body
      attr_accessor :return_type_suffix, :lparen_suffix, :rparen_suffix
      attr_accessor :param_separators, :modifiers_text, :prefix_modifiers
      
      def initialize(leading_trivia: "", return_type:, name:, parameters:, body: nil,
                     return_type_suffix: "", lparen_suffix: "", rparen_suffix: "",
                     param_separators: [], modifiers_text: "", prefix_modifiers: "")
        super(leading_trivia: leading_trivia)
        @return_type = return_type
        @name = name
        @parameters = parameters
        @body = body
        @return_type_suffix = return_type_suffix
        @lparen_suffix = lparen_suffix
        @rparen_suffix = rparen_suffix
        @param_separators = param_separators
        @modifiers_text = modifiers_text
        @prefix_modifiers = prefix_modifiers
      end
      
      def to_source
        result = "#{leading_trivia}#{prefix_modifiers}#{return_type}#{return_type_suffix}#{name}(#{lparen_suffix}"
        
        parameters.each_with_index do |param, i|
          result << param
          result << param_separators[i] if i < parameters.size - 1
        end
        
        result << "#{rparen_suffix})#{modifiers_text}"
        result << (body ? body.to_source : ";")
        result
      end
    end
    
    # ClassDeclaration: `class Name { ... };` or `class Name : public Base { ... };`
    class ClassDeclaration < Statement
      attr_accessor :name, :members, :member_trailings
      attr_accessor :class_suffix, :name_suffix, :lbrace_suffix, :rbrace_suffix
      attr_accessor :base_classes_text
      
      def initialize(leading_trivia: "", name:, members:, member_trailings:,
                     class_suffix: "", name_suffix: "", lbrace_suffix: "", rbrace_suffix: "",
                     base_classes_text: "")
        super(leading_trivia: leading_trivia)
        @name = name
        @members = members
        @member_trailings = member_trailings
        @class_suffix = class_suffix
        @name_suffix = name_suffix
        @lbrace_suffix = lbrace_suffix
        @rbrace_suffix = rbrace_suffix
        @base_classes_text = base_classes_text
      end
      
      def to_source
        result = "#{leading_trivia}class#{class_suffix}#{name}#{name_suffix}"
        result << base_classes_text unless base_classes_text.empty?
        result << "{#{lbrace_suffix}"
        
        members.zip(member_trailings).each do |member, trailing|
          result << member.to_source << trailing
        end
        
        result << "#{rbrace_suffix}};"
        result
      end
    end
    
    # StructDeclaration: `struct Name { ... };` or `struct Name : public Base { ... };`
    class StructDeclaration < Statement
      attr_accessor :name, :members, :member_trailings
      attr_accessor :struct_suffix, :name_suffix, :lbrace_suffix, :rbrace_suffix
      attr_accessor :base_classes_text
      
      def initialize(leading_trivia: "", name:, members:, member_trailings:,
                     struct_suffix: "", name_suffix: "", lbrace_suffix: "", rbrace_suffix: "",
                     base_classes_text: "")
        super(leading_trivia: leading_trivia)
        @name = name
        @members = members
        @member_trailings = member_trailings
        @struct_suffix = struct_suffix
        @name_suffix = name_suffix
        @lbrace_suffix = lbrace_suffix
        @rbrace_suffix = rbrace_suffix
        @base_classes_text = base_classes_text
      end
      
      def to_source
        result = "#{leading_trivia}struct#{struct_suffix}#{name}#{name_suffix}"
        result << base_classes_text unless base_classes_text.empty?
        result << "{#{lbrace_suffix}"
        
        members.zip(member_trailings).each do |member, trailing|
          result << member.to_source << trailing
        end
        
        result << "#{rbrace_suffix}};"
        result
      end
    end
    
    # AccessSpecifier: `public:`, `private:`, `protected:`
    class AccessSpecifier < Statement
      attr_accessor :keyword, :colon_suffix
      
      def initialize(leading_trivia: "", keyword:, colon_suffix: "")
        super(leading_trivia: leading_trivia)
        @keyword = keyword
        @colon_suffix = colon_suffix
      end
      
      def to_source
        "#{leading_trivia}#{keyword}:#{colon_suffix}"
      end
    end
    
    # VariableDeclaration: `int x = 42;` or `const int* ptr = nullptr;`
    class VariableDeclaration < Statement
      attr_accessor :type, :declarators, :declarator_separators
      attr_accessor :type_suffix
      
      def initialize(leading_trivia: "", type:, declarators:, declarator_separators: [], type_suffix: "")
        super(leading_trivia: leading_trivia)
        @type = type
        @declarators = declarators
        @declarator_separators = declarator_separators
        @type_suffix = type_suffix
      end
      
      def to_source
        result = "#{leading_trivia}#{type}#{type_suffix}"
        
        declarators.each_with_index do |decl, i|
          result << decl
          result << declarator_separators[i] if i < declarators.size - 1
        end
        
        result << ";"
        result
      end
    end
    
    # EnumDeclaration: `enum Color { Red, Green };` or `enum class Color { Red, Green };`
    class EnumDeclaration < Statement
      attr_accessor :name, :enumerators
      attr_accessor :enum_suffix, :class_keyword, :class_suffix, :name_suffix
      attr_accessor :lbrace_suffix, :rbrace_suffix
      
      def initialize(leading_trivia: "", name:, enumerators:,
                     enum_suffix: "", class_keyword: "", class_suffix: "", name_suffix: "",
                     lbrace_suffix: "", rbrace_suffix: "")
        super(leading_trivia: leading_trivia)
        @name = name
        @enumerators = enumerators
        @enum_suffix = enum_suffix
        @class_keyword = class_keyword
        @class_suffix = class_suffix
        @name_suffix = name_suffix
        @lbrace_suffix = lbrace_suffix
        @rbrace_suffix = rbrace_suffix
      end
      
      def to_source
        result = "#{leading_trivia}enum#{enum_suffix}"
        result << "#{class_keyword}#{class_suffix}" unless class_keyword.empty?
        result << "#{name}#{name_suffix}{#{lbrace_suffix}"
        result << enumerators
        result << "#{rbrace_suffix}};"
        result
      end
    end
    
    # TemplateDeclaration: `template<typename T> class Foo { ... };`
    class TemplateDeclaration < Statement
      attr_accessor :template_params, :declaration
      attr_accessor :template_suffix, :params_suffix
      
      def initialize(leading_trivia: "", template_params:, declaration:,
                     template_suffix: "", params_suffix: "")
        super(leading_trivia: leading_trivia)
        @template_params = template_params
        @declaration = declaration
        @template_suffix = template_suffix
        @params_suffix = params_suffix
      end
      
      def to_source
        "#{leading_trivia}template#{template_suffix}<#{template_params}>#{params_suffix}#{declaration.to_source}"
      end
    end
    
    # ErrorStatement: represents unparseable code that was recovered
    class ErrorStatement < Statement
      attr_accessor :error_text
      
      def initialize(leading_trivia: "", error_text:)
        super(leading_trivia: leading_trivia)
        @error_text = error_text
      end
      
      def to_source
        "#{leading_trivia}#{error_text}"
      end
    end
    
    # UsingDeclaration: `using namespace std;` or `using MyType = int;`
    class UsingDeclaration < Statement
      attr_accessor :kind, :name, :alias_target
      attr_accessor :using_suffix, :namespace_suffix, :equals_prefix, :equals_suffix
      
      # kind: :namespace, :name, :alias
      def initialize(leading_trivia: "", kind:, name:, alias_target: nil,
                     using_suffix: "", namespace_suffix: "", equals_prefix: "", equals_suffix: "")
        super(leading_trivia: leading_trivia)
        @kind = kind
        @name = name
        @alias_target = alias_target
        @using_suffix = using_suffix
        @namespace_suffix = namespace_suffix
        @equals_prefix = equals_prefix
        @equals_suffix = equals_suffix
      end
      
      def to_source
        result = "#{leading_trivia}using#{using_suffix}"
        
        case kind
        when :namespace
          result << "namespace#{namespace_suffix}#{name};"
        when :name
          result << "#{name};"
        when :alias
          result << "#{name}#{equals_prefix}=#{equals_suffix}#{alias_target};"
        end
        
        result
      end
    end
    
    # Program: Top-level container
    # Manages spacing between statements
    class Program < Node
      attr_accessor :statements, :statement_trailings
      
      def initialize(statements:, statement_trailings:)
        @statements = statements
        @statement_trailings = statement_trailings
      end
      
      def to_source
        statements.zip(statement_trailings).map { |stmt, trailing|
          stmt.to_source + trailing
        }.join
      end
    end
  end
end

