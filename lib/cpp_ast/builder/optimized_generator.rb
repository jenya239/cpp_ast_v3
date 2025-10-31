# frozen_string_literal: true

require_relative "dsl_generator"

module CppAst
  module Builder
    # Optimized code generator with StringBuilder and caching
    class OptimizedGenerator < DSLGenerator
      def initialize(indent: "  ", mode: :pretty)
        super(indent: indent, mode: mode)
        @string_builder = StringBuilder.new
        @generation_cache = {}
        @template_cache = {}
      end
      
      def generate(ast)
        cache_key = ast.object_id
        return @generation_cache[cache_key] if @generation_cache[cache_key]
        
        @string_builder.clear
        result = generate_optimized(ast)
        @generation_cache[cache_key] = result
        result
      end
      
      private
      
      def generate_optimized(ast)
        case ast
        when Nodes::Program
          generate_program_optimized(ast)
        when Nodes::ClassDeclaration
          generate_class_optimized(ast)
        when Nodes::FunctionDeclaration
          generate_function_optimized(ast)
        when Nodes::NamespaceDeclaration
          generate_namespace_optimized(ast)
        when MLC::AST::Program
          generate_aurora_program_optimized(ast)
        else
          super(ast)
        end
      end
      
      def generate_program_optimized(program)
        @string_builder.append("#pragma once\n")
        @string_builder.append("#include <iostream>\n")
        @string_builder.append("#include <memory>\n")
        @string_builder.append("#include <vector>\n")
        @string_builder.append("\n")
        
        program.declarations.each do |decl|
          @string_builder.append(generate_optimized(decl))
          @string_builder.append("\n")
        end
        
        @string_builder.to_s
      end
      
      def generate_class_optimized(klass)
        # Use template cache for common class patterns
        template_key = "#{klass.name}_#{klass.members.length}"
        if @template_cache[template_key]
          return @template_cache[template_key].gsub("CLASS_NAME", klass.name)
        end
        
        # Don't clear here - let the caller manage the buffer
        @string_builder.append("class CLASS_NAME")
        
        if klass.inheritance && !klass.inheritance.empty?
          @string_builder.append(" : ")
          @string_builder.append(klass.inheritance.join(", "))
        end
        
        @string_builder.append(" {\n")
        
        # Generate members with optimized formatting
        klass.members.each do |member|
          @string_builder.append(generate_member_optimized(member))
        end
        
        @string_builder.append("};\n")
        
        result = @string_builder.to_s
        @template_cache[template_key] = result
        result
      end
      
      def generate_function_optimized(func)
        # Don't clear here - let the caller manage the buffer
        
        # Generate attributes
        func.attributes.each do |attr|
          @string_builder.append("[[#{attr}]]\n")
        end
        
        # Generate modifiers
        modifiers = []
        modifiers << "static" if func.static?
        modifiers << "virtual" if func.virtual?
        modifiers << "const" if func.const?
        modifiers << "noexcept" if func.noexcept?
        
        @string_builder.append(modifiers.join(" ")) unless modifiers.empty?
        @string_builder.append(" ") unless modifiers.empty?
        
        # Generate return type and name
        @string_builder.append("#{func.return_type} #{func.name}(")
        
        # Generate parameters
        params = func.parameters.map { |param| generate_parameter_optimized(param) }
        @string_builder.append(params.join(", "))
        @string_builder.append(")")
        
        # Generate body
        if func.body
          @string_builder.append(" {\n")
          @string_builder.append(generate_body_optimized(func.body))
          @string_builder.append("\n}")
        else
          @string_builder.append(";")
        end
        
        @string_builder.to_s
      end
      
      def generate_member_optimized(member)
        case member
        when Nodes::VariableDeclaration
          generate_variable_optimized(member)
        when Nodes::FunctionDeclaration
          generate_function_optimized(member)
        when Nodes::AccessSpecifier
          generate_access_specifier_optimized(member)
        else
          super(member)
        end
      end
      
      def generate_namespace_optimized(namespace)
        @string_builder.clear
        @string_builder.append("namespace #{namespace.name} {\n")
        namespace.declarations.each do |decl|
          @string_builder.append(generate_optimized(decl))
          @string_builder.append("\n")
        end
        @string_builder.append("}\n")
        @string_builder.to_s
      end
      
      def generate_aurora_program_optimized(program)
        @string_builder.clear
        @string_builder.append("#include <iostream>\n")
        @string_builder.append("#include <memory>\n")
        @string_builder.append("#include <vector>\n")
        @string_builder.append("\n")
        
        # Generate imports
        program.imports.each do |import|
          @string_builder.append("#include \"#{import.path}.hpp\"\n")
        end
        
        if program.imports.any?
          @string_builder.append("\n")
        end
        
        # Generate module declaration
        if program.module_decl
          @string_builder.append("namespace #{program.module_decl.name} {\n")
        end
        
        # Generate declarations
        program.declarations.each do |decl|
          @string_builder.append(generate_aurora_declaration_optimized(decl))
          @string_builder.append("\n")
        end
        
        if program.module_decl
          @string_builder.append("}\n")
        end
        
        @string_builder.to_s
      end
      
      def generate_aurora_declaration_optimized(decl)
        case decl
        when MLC::AST::FuncDecl
          generate_aurora_function_optimized(decl)
        when MLC::AST::TypeDecl
          generate_aurora_type_optimized(decl)
        else
          "// Unsupported declaration type: #{decl.class}"
        end
      end
      
      def generate_aurora_function_optimized(func)
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
          "mlc::String(#{left}) + mlc::String(#{right})"
        else
          "#{left} #{expr.op} #{right}"
        end
      else
        "0" # fallback
      end
    end
    
    private
    
    def is_string_expression(expr)
      case expr
      when MLC::AST::StringLit
        true
      when MLC::AST::VarRef
        # TODO: Check variable type from context
        true # Assume string for now
      when MLC::AST::BinaryOp
        # Check if this is a string concatenation
        expr.op == "+" && is_string_expression(expr.left) && is_string_expression(expr.right)
      else
        false
      end
    end
      
      def generate_aurora_type_optimized(type)
        "// Type declaration: #{type.name}"
      end
      
      def generate_access_specifier_optimized(access_spec)
        "#{access_spec.level}:\n"
      end
      
      def generate_parameter_optimized(param)
        "#{param.type} #{param.name}"
      end
      
      def generate_body_optimized(body)
        if body.is_a?(Array)
          body.map { |stmt| generate_optimized(stmt) }.join("\n")
        else
          generate_optimized(body)
        end
      end
      
      def generate_variable_optimized(var)
        # Don't clear here - let the caller manage the buffer
        @string_builder.append("#{var.type} #{var.name}")
        
        if var.initializer
          @string_builder.append(" = ")
          @string_builder.append(generate_expression_optimized(var.initializer))
        end
        
        @string_builder.append(";")
        @string_builder.to_s
      end
      
      def generate_expression_optimized(expr)
        case expr
        when Nodes::Identifier
          expr.name
        when Nodes::NumberLiteral
          expr.value
        when Nodes::StringLiteral
          "\"#{expr.value}\""
        when Nodes::BinaryExpression
          generate_binary_optimized(expr)
        when Nodes::CallExpression
          generate_call_optimized(expr)
        else
          super(expr)
        end
      end
      
      def generate_binary_optimized(binary)
        left = generate_expression_optimized(binary.left)
        right = generate_expression_optimized(binary.right)
        "#{left} #{binary.operator} #{right}"
      end
      
      def generate_call_optimized(call)
        callee = generate_expression_optimized(call.callee)
        args = call.arguments.map { |arg| generate_expression_optimized(arg) }
        "#{callee}(#{args.join(", ")})"
      end
    end
    
    # High-performance string builder
    class StringBuilder
      def initialize(initial_capacity = 1024)
        @buffer = String.new(capacity: initial_capacity)
        @indent_level = 0
      end
      
      def append(str)
        @buffer << str
        self
      end
      
      def append_line(str = "")
        @buffer << str << "\n"
        self
      end
      
      def indent
        @indent_level += 1
        self
      end
      
      def unindent
        @indent_level -= 1 if @indent_level > 0
        self
      end
      
      def append_indented(str)
        @buffer << "  " * @indent_level << str
        self
      end
      
      def clear
        @buffer.clear
        @indent_level = 0
        self
      end
      
      def to_s
        @buffer.dup
      end
      
      def length
        @buffer.length
      end
      
      def empty?
        @buffer.empty?
      end
    end
  end
end
