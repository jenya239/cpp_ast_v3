# frozen_string_literal: true

module CppAst
  module Parsers
    # DeclarationParser - module with declaration parsing methods
    # Handles: namespace, class, struct, function, variable, using, enum, template
    module DeclarationParser
      def parse_namespace_declaration(leading_trivia)
        # Consume 'namespace'
        namespace_suffix = current_token.trailing_trivia
        expect(:keyword_namespace)
        
        # Check if anonymous namespace (no name)
        name = "".dup
        name_suffix = ""
        
        if current_token.kind == :identifier
          # Parse name (can be nested with ::)
          loop do
            name << current_token.lexeme
            trivia_before_colon = current_token.trailing_trivia
            advance_raw
            
            # Check for ::
            if current_token.kind == :colon_colon
              name << trivia_before_colon << current_token.lexeme
              advance_raw
            else
              # No more ::, this is the end of namespace name
              name_suffix = trivia_before_colon
              break
            end
          end
          
          # Collect additional trivia after name
          name_suffix = name_suffix + current_leading_trivia
        end
        
        # Parse body (block statement)
        push_context(:namespace, name: name)
        body, trailing = parse_block_statement("")
        pop_context
        
        stmt = Nodes::NamespaceDeclaration.new(
          leading_trivia: leading_trivia,
          name: name,
          body: body,
          namespace_suffix: namespace_suffix,
          name_suffix: name_suffix
        )
        
        [stmt, trailing]
      end
      
      # Check if current position looks like a declaration
      # Heuristics:
      # - Starts with type keyword (int, float, const, etc)
      # - Or identifier followed by identifier (CustomType varName)
      # - Followed by = or ; or ,
      def looks_like_declaration?
        # Type keywords
        type_keywords = [:keyword_int, :keyword_float, :keyword_double, :keyword_char, 
                        :keyword_bool, :keyword_void, :keyword_auto,
                        :keyword_const, :keyword_static, :keyword_extern,
                        :keyword_unsigned, :keyword_signed, :keyword_long, :keyword_short]
        
        return true if type_keywords.include?(current_token.kind)
        
        # Check pattern: identifier identifier (CustomType varName) or std::vector<int> varName
        return false unless current_token.kind == :identifier
        
        saved_pos = @position
        advance_raw
        current_leading_trivia
        
        # Skip :: for qualified names (std::vector)
        while current_token.kind == :colon_colon
          advance_raw
          current_leading_trivia
          if current_token.kind == :identifier
            advance_raw
            current_leading_trivia
          end
        end
        
        # Skip <...> for template types (vector<int>)
        if current_token.kind == :less
          depth = 1
          advance_raw
          
          while depth > 0 && !at_end?
            if current_token.kind == :less
              depth += 1
            elsif current_token.kind == :greater
              depth -= 1
            end
            advance_raw
          end
          
          current_leading_trivia
        end
        
        # Check if followed by identifier (variable name) or * & (pointers/refs)
        result = [:identifier, :asterisk, :ampersand].include?(current_token.kind)
        
        @position = saved_pos
        result
      end
      
      # Simple heuristic to detect function declarations
      # Look for pattern: type name ( or type ~name ( or std::vector<int> name (
      # Can have modifiers before: virtual, inline, static, explicit, constexpr
      def looks_like_function_declaration?
        return false unless current_token.kind == :identifier || current_token.kind.to_s.start_with?("keyword_")
        
        return true if looks_like_in_class_constructor?
        return true if looks_like_out_of_line_constructor?
        
        saved_pos = @position
        
        unless skip_function_modifiers_and_check
          @position = saved_pos
          return false
        end
        
        skip_type_specification
        return true if check_operator_overload_pattern(saved_pos)
        
        # Check for destructor ~
        advance_raw if current_token.kind == :tilde
        current_leading_trivia
        
        # Check for identifier followed by (
        is_func = current_token.kind == :identifier
        if is_func
          advance_raw
          current_leading_trivia
          is_func = current_token.kind == :lparen
        end
        
        @position = saved_pos
        is_func
      end
      
      # Parse function declaration: `type name(params);` or `type name(params) { ... }`
      # Or constructor: `[explicit] ClassName(params) [: initializers] ;` or `{ body }`
      # Returns (FunctionDeclaration, trailing) tuple
      def parse_function_declaration(leading_trivia)
        prefix_modifiers = parse_function_prefix_modifiers
        is_constructor, constructor_class_name = detect_constructor_pattern
        
        return_type, trivia_after = if is_constructor
          ["", ""]
        else
          parse_function_return_type
        end
        
        name, return_type_suffix = parse_function_name(is_constructor, trivia_after)
        _lparen_prefix = current_leading_trivia
        parameters, param_separators, lparen_suffix, rparen_suffix, after_rparen = parse_function_parameters
        modifiers_text, after_rparen = parse_function_modifiers_postfix(after_rparen, is_constructor)
        
        body, trailing = if current_token.kind == :lbrace
          parse_block_statement(after_rparen)
        else
          _semicolon_prefix = after_rparen + current_leading_trivia
          trailing = current_token.trailing_trivia
          expect(:semicolon)
          [nil, trailing]
        end
        
        stmt = Nodes::FunctionDeclaration.new(
          leading_trivia: leading_trivia,
          prefix_modifiers: prefix_modifiers,
          return_type: return_type,
          name: name,
          parameters: parameters,
          body: body,
          return_type_suffix: return_type_suffix,
          lparen_suffix: lparen_suffix,
          rparen_suffix: rparen_suffix,
          param_separators: param_separators,
          modifiers_text: modifiers_text
        )
        
        [stmt, trailing]
      end
      
      # Parse class or struct declaration (common logic)
      def parse_class_like_declaration(leading_trivia, keyword_kind, node_class)
        keyword_suffix = current_token.trailing_trivia
        expect(keyword_kind)
        
        raise ParseError, "Expected #{keyword_kind == :keyword_class ? 'class' : 'struct'} name" unless current_token.kind == :identifier
        
        name = current_token.lexeme
        name_suffix = current_token.trailing_trivia
        advance_raw
        
        # Parse inheritance
        base_classes_text = ""
        if current_token.kind == :colon
          base_classes_text = name_suffix.dup
          name_suffix = ""
          base_classes_text << current_token.lexeme << current_token.trailing_trivia
          advance_raw
          
          until current_token.kind == :lbrace || at_end?
            base_classes_text << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
        
        lbrace_suffix = current_token.trailing_trivia
        expect(:lbrace)
        
        push_context(:class, name: name)
        
        members = []
        member_trailings = []
        member_leading = ""
        
        until current_token.kind == :rbrace || at_end?
          member_leading += current_leading_trivia
          
          if [:keyword_public, :keyword_private, :keyword_protected].include?(current_token.kind)
            keyword = current_token.lexeme
            _colon_prefix = current_token.trailing_trivia
            advance_raw
            colon_suffix = current_token.trailing_trivia
            expect(:colon)
            
            members << Nodes::AccessSpecifier.new(
              leading_trivia: member_leading,
              keyword: keyword,
              colon_suffix: colon_suffix
            )
            member_trailings << ""
            member_leading = ""
          else
            member, trailing = parse_statement(member_leading)
            members << member
            member_trailings << trailing
            member_leading = ""
          end
        end
        
        pop_context
        
        rbrace_suffix = current_leading_trivia
        _semicolon_prefix = current_token.trailing_trivia
        expect(:rbrace)
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
        params = {
          leading_trivia: leading_trivia,
          name: name,
          members: members,
          member_trailings: member_trailings,
          name_suffix: name_suffix,
          lbrace_suffix: lbrace_suffix,
          rbrace_suffix: rbrace_suffix,
          base_classes_text: base_classes_text
        }
        params[keyword_kind == :keyword_class ? :class_suffix : :struct_suffix] = keyword_suffix
        
        [node_class.new(**params), trailing]
      end
      
      # Parse class declaration: `class Name { ... };`
      def parse_class_declaration(leading_trivia)
        parse_class_like_declaration(leading_trivia, :keyword_class, Nodes::ClassDeclaration)
      end
      
      # Parse struct declaration: `struct Name { ... };`
      def parse_struct_declaration(leading_trivia)
        parse_class_like_declaration(leading_trivia, :keyword_struct, Nodes::StructDeclaration)
      end
      
      # Parse variable declaration: `int x = 42;` or `const int* ptr, y = 5;`
      # Returns (VariableDeclaration, trailing) tuple
      def parse_variable_declaration(leading_trivia)
        type, type_suffix = parse_variable_type
        type_suffix = " " if type_suffix.empty?
        
        declarators = []
        declarator_separators = []
        
        loop do
          declarators << parse_variable_declarator
          
          if current_token.kind == :comma
            declarator_separators << current_token.lexeme + current_token.trailing_trivia
            advance_raw
          else
            break
          end
        end
        
        _semicolon_prefix = current_leading_trivia
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
        stmt = Nodes::VariableDeclaration.new(
          leading_trivia: leading_trivia,
          type: type,
          declarators: declarators,
          declarator_separators: declarator_separators,
          type_suffix: type_suffix
        )
        
        [stmt, trailing]
      end
      
      # Parse using declaration: `using namespace std;` or `using MyType = int;`
      # Returns (UsingDeclaration, trailing) tuple
      def parse_using_declaration(leading_trivia)
        # Consume 'using'
        using_suffix = current_token.trailing_trivia
        expect(:keyword_using)
        
        # Check if it's 'using namespace'
        if current_token.kind == :keyword_namespace
          namespace_suffix = current_token.trailing_trivia
          advance_raw  # consume 'namespace'
          
          # Parse namespace name (can be nested like std::chrono)
          name = "".dup
          name_suffix = ""
          loop do
            unless current_token.kind == :identifier
              raise ParseError, "Expected namespace name"
            end
            
            name << current_token.lexeme
            trivia_before_colon = current_token.trailing_trivia
            advance_raw
            
            # Check for ::
            if current_token.kind == :colon_colon
              name << trivia_before_colon << current_token.lexeme
              advance_raw
            else
              # No more ::, this is the end
              name_suffix = trivia_before_colon
              break
            end
          end
          
          # Consume semicolon
          _semicolon_prefix = current_leading_trivia
          trailing = current_token.trailing_trivia
          expect(:semicolon)
          
          stmt = Nodes::UsingDeclaration.new(
            leading_trivia: leading_trivia,
            kind: :namespace,
            name: name + name_suffix,
            using_suffix: using_suffix,
            namespace_suffix: namespace_suffix
          )
          
          return [stmt, trailing]
        end
        
        # Parse name (could be simple name or qualified name like std::vector)
        name = "".dup
        after_name = ""
        loop do
          unless current_token.kind == :identifier
            raise ParseError, "Expected identifier in using declaration"
          end
          
          name << current_token.lexeme
          trivia_before_colon = current_token.trailing_trivia
          advance_raw
          
          # Check for ::
          if current_token.kind == :colon_colon
            name << trivia_before_colon << current_token.lexeme
            advance_raw
          else
            # No more ::, this is the end
            after_name = trivia_before_colon
            break
          end
        end
        
        # Check if it's type alias: using MyType = int;
        after_name_extra = current_leading_trivia
        if current_token.kind == :equals
          equals_prefix = after_name + after_name_extra
          equals_suffix = current_token.trailing_trivia
          advance_raw  # consume '='
          
          # Parse target type (collect as string until semicolon)
          alias_target = "".dup
          until current_token.kind == :semicolon || at_end?
            alias_target << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
          
          # Consume semicolon
          _semicolon_prefix = current_leading_trivia
          trailing = current_token.trailing_trivia
          expect(:semicolon)
          
          stmt = Nodes::UsingDeclaration.new(
            leading_trivia: leading_trivia,
            kind: :alias,
            name: name,
            alias_target: alias_target,
            using_suffix: using_suffix,
            equals_prefix: equals_prefix,
            equals_suffix: equals_suffix
          )
          
          return [stmt, trailing]
        else
          # Simple using: using std::vector;
          _semicolon_prefix = after_name + after_name_extra + current_leading_trivia
          trailing = current_token.trailing_trivia
          expect(:semicolon)
          
          stmt = Nodes::UsingDeclaration.new(
            leading_trivia: leading_trivia,
            kind: :name,
            name: name,
            using_suffix: using_suffix
          )
          
          return [stmt, trailing]
        end
      end
      
      # Parse template declaration: `template<typename T> class Foo { ... };`
      # Returns (TemplateDeclaration, trailing) tuple
      def parse_template_declaration(leading_trivia)
        # Consume 'template'
        template_suffix = current_token.trailing_trivia
        expect(:keyword_template)
        
        # Consume '<'
        less_suffix = current_token.trailing_trivia
        expect(:less)
        
        # Collect template parameters as string (simplified approach)
        # Count < > to handle nested templates like template<typename T, typename U<V>>
        params = "".dup
        depth = 1
        
        loop do
          break if at_end?
          
          case current_token.kind
          when :less
            depth += 1
            params << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          when :greater
            depth -= 1
            if depth == 0
              break
            else
              params << current_token.lexeme << current_token.trailing_trivia
              advance_raw
            end
          else
            params << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
        
        # Consume '>'
        params_suffix = current_token.trailing_trivia
        expect(:greater)
        
        # Parse the templated declaration (function, class, struct)
        inner_leading = current_leading_trivia
        declaration, trailing = parse_statement(inner_leading)
        
        stmt = Nodes::TemplateDeclaration.new(
          leading_trivia: leading_trivia,
          template_params: params,
          declaration: declaration,
          template_suffix: template_suffix,
          less_suffix: less_suffix,
          params_suffix: params_suffix
        )
        
        [stmt, trailing]
      end
      
      # === Function Detection Helpers ===
      
      # Check if looks like in-class constructor
      def looks_like_in_class_constructor?
        return false unless in_context?(:class)
        
        saved_pos = @position
        advance_raw if current_token.kind == :keyword_explicit
        current_leading_trivia
        
        if current_token.kind == :identifier && current_token.lexeme == current_class_name
          advance_raw
          current_leading_trivia
          if current_token.kind == :lparen
            @position = saved_pos
            return true
          end
        end
        
        @position = saved_pos
        false
      end
      
      # Check if looks like out-of-line constructor (ClassName::ClassName)
      def looks_like_out_of_line_constructor?
        return false unless current_token.kind == :identifier
        
        saved_pos = @position
        class_name = current_token.lexeme
        advance_raw
        current_leading_trivia
        
        if current_token.kind == :colon_colon
          advance_raw
          current_leading_trivia
          if current_token.kind == :identifier && current_token.lexeme == class_name
            advance_raw
            current_leading_trivia
            if current_token.kind == :lparen
              @position = saved_pos
              return true
            end
          end
        end
        
        @position = saved_pos
        false
      end
      
      # Skip function modifiers and return true if valid
      def skip_function_modifiers_and_check
        modifier_keywords = [:keyword_virtual, :keyword_inline, :keyword_static, 
                             :keyword_explicit, :keyword_constexpr, :keyword_friend]
        while modifier_keywords.include?(current_token.kind)
          advance_raw
          current_leading_trivia
        end
        
        # Don't treat class/struct/enum/namespace/using/template as return type
        declaration_keywords = [:keyword_class, :keyword_struct, :keyword_enum, 
                               :keyword_namespace, :keyword_using, :keyword_template, :keyword_typedef]
        !declaration_keywords.include?(current_token.kind)
      end
      
      # Skip qualified name and template args
      def skip_type_specification
        advance_raw  # skip type
        current_leading_trivia
        
        # Skip :: for qualified names
        while current_token.kind == :colon_colon
          advance_raw
          current_leading_trivia
          advance_raw if current_token.kind == :identifier
          current_leading_trivia
        end
        
        # Skip <...> for templates
        if current_token.kind == :less
          depth = 1
          advance_raw
          while depth > 0 && !at_end?
            depth += 1 if current_token.kind == :less
            depth -= 1 if current_token.kind == :greater
            advance_raw
          end
          current_leading_trivia
        end
      end
      
      # Check if looks like operator overload
      def check_operator_overload_pattern(saved_pos)
        # Direct operator keyword
        if current_token.kind == :keyword_operator
          @position = saved_pos
          return true
        end
        
        # Check after * or &
        if [:asterisk, :ampersand].include?(current_token.kind)
          while [:asterisk, :ampersand].include?(current_token.kind)
            advance_raw
            current_leading_trivia
          end
          
          # Check for inline operator
          if current_token.kind == :keyword_operator
            skip_operator_symbol
            if current_token.kind == :lparen
              @position = saved_pos
              return true
            end
          end
          
          # Check for ClassName::operator
          if current_token.kind == :identifier
            saved_after_ptr = @position
            advance_raw
            current_leading_trivia
            if current_token.kind == :colon_colon
              advance_raw
              current_leading_trivia
              if current_token.kind == :keyword_operator
                @position = saved_pos
                return true
              end
            end
            @position = saved_after_ptr
          end
        elsif current_token.kind == :identifier
          # Check for ClassName::operator without pointer
          saved_op = @position
          advance_raw
          current_leading_trivia
          if current_token.kind == :colon_colon
            advance_raw
            current_leading_trivia
            if current_token.kind == :keyword_operator
              @position = saved_pos
              return true
            end
          end
          @position = saved_op
        end
        
        false
      end
      
      # Skip operator symbol in lookahead
      def skip_operator_symbol
        advance_raw  # skip 'operator'
        current_leading_trivia
        
        operator_symbols = [:plus, :minus, :asterisk, :slash, :percent, :equals,
                           :equals_equals, :exclamation_equals, :less, :greater,
                           :less_equals, :greater_equals, :plus_plus, :minus_minus,
                           :ampersand, :pipe, :caret, :tilde, :exclamation,
                           :ampersand_ampersand, :pipe_pipe, :less_less, :greater_greater,
                           :comma, :arrow, :arrow_asterisk]
        
        if operator_symbols.include?(current_token.kind)
          advance_raw
          current_leading_trivia
        elsif current_token.kind == :lparen
          advance_raw
          advance_raw if current_token.kind == :rparen
          current_leading_trivia
        elsif current_token.kind == :lbracket
          advance_raw
          advance_raw if current_token.kind == :rbracket
          current_leading_trivia
        end
      end
      
      # === Variable Declaration Helpers ===
      
      # Parse variable type (with template args, qualifiers, etc)
      # Returns [type, type_suffix]
      def parse_variable_type
        type = "".dup
        template_depth = 0
        
        loop do
          break unless current_token.kind.to_s.start_with?("keyword_") || 
                       current_token.kind == :identifier ||
                       [:asterisk, :ampersand, :less, :greater, :colon_colon, :comma, :lparen, :rparen].include?(current_token.kind)
          
          was_colon_colon = current_token.kind == :colon_colon
          
          # Track template depth
          template_depth += 1 if current_token.kind == :less
          template_depth -= 1 if current_token.kind == :greater
          
          # Don't include comma in type if not in template
          break if current_token.kind == :comma && template_depth == 0
          
          type << current_token.lexeme
          trivia = current_token.trailing_trivia
          advance_raw
          
          # Don't add trivia after :: if next is identifier/keyword
          next if was_colon_colon && (current_token.kind == :identifier || 
                                      current_token.kind.to_s.start_with?("keyword_"))
          
          # Don't add trivia if next token is template delimiter
          next if template_depth > 0 && [:comma, :greater, :lparen, :rparen].include?(current_token.kind)
          
          # Check if we're done with type (next is variable name)
          if current_token.kind == :identifier
            saved_pos = @position
            advance_raw
            next_kind = current_token.kind
            @position = saved_pos
            
            if [:equals, :semicolon, :comma, :lparen, :lbracket, :lbrace].include?(next_kind)
              type << trivia
              break
            end
          end
          
          type << trivia
        end
        
        # Extract trailing whitespace
        type_match = type.match(/^(.*?)(\s*)$/)
        type_match ? [type_match[1], type_match[2]] : [type, ""]
      end
      
      # Parse single variable declarator (name + initializer)
      # Returns declarator text
      def parse_variable_declarator
        decl_text = "".dup
        
        loop do
          break if at_end? || [:semicolon, :comma].include?(current_token.kind)
          
          case current_token.kind
          when :equals
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
            parse_variable_initializer(decl_text)
            break
          when :lparen
            # Function-style initialization: int x(42)
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
            collect_balanced_tokens(decl_text, :lparen, :rparen)
          when :lbrace
            # Brace initialization: int x{42}
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
            collect_balanced_tokens(decl_text, :lbrace, :rbrace)
          else
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
        
        decl_text
      end
      
      # Parse variable initializer after =
      def parse_variable_initializer(decl_text)
        loop do
          break if at_end? || [:semicolon, :comma].include?(current_token.kind)
          
          if current_token.kind == :lparen
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
            collect_balanced_tokens(decl_text, :lparen, :rparen)
          elsif current_token.kind == :lbrace
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
            collect_balanced_tokens(decl_text, :lbrace, :rbrace)
          else
            decl_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
      end
      
      # Collect balanced tokens (parens or braces)
      def collect_balanced_tokens(text, open_kind, close_kind)
        depth = 1
        loop do
          break if at_end?
          depth += 1 if current_token.kind == open_kind
          depth -= 1 if current_token.kind == close_kind
          text << current_token.lexeme << current_token.trailing_trivia
          advance_raw
          break if depth.zero?
        end
      end
      
      # === Function Declaration Helpers ===
      
      # Parse function prefix modifiers (virtual, inline, static, explicit, constexpr, friend)
      def parse_function_prefix_modifiers
        prefix_modifiers = "".dup
        modifier_keywords = [:keyword_virtual, :keyword_inline, :keyword_static, 
                             :keyword_explicit, :keyword_constexpr, :keyword_friend]
        while modifier_keywords.include?(current_token.kind)
          prefix_modifiers << current_token.lexeme << current_token.trailing_trivia
          advance_raw
        end
        prefix_modifiers
      end
      
      # Detect if current position is a constructor
      # Returns [is_constructor, class_name]
      def detect_constructor_pattern
        # In-class constructor: ClassName(...)
        if in_context?(:class) && current_token.kind == :identifier && 
           current_token.lexeme == current_class_name
          saved_pos = @position
          advance_raw
          current_leading_trivia
          
          if current_token.kind == :lparen || current_token.kind == :colon_colon
            @position = saved_pos
            return [true, current_class_name]
          end
          @position = saved_pos
        end
        
        # Out-of-line constructor: ClassName::ClassName(...)
        if current_token.kind == :identifier
          saved_pos = @position
          class_name = current_token.lexeme
          advance_raw
          current_leading_trivia
          
          if current_token.kind == :colon_colon
            advance_raw
            current_leading_trivia
            
            if current_token.kind == :identifier && current_token.lexeme == class_name
              @position = saved_pos
              return [true, class_name]
            end
          end
          @position = saved_pos
        end
        
        [false, nil]
      end
      
      # Parse function return type (with qualifiers, template args, pointers)
      # Returns [type, trivia_after_type]
      def parse_function_return_type
        return_type = current_token.lexeme.dup
        trivia_after = current_token.trailing_trivia
        advance_raw
        
        # Handle :: for qualified names (std::vector)
        while current_token.kind == :colon_colon
          return_type << trivia_after << current_token.lexeme
          trivia_after = current_token.trailing_trivia
          advance_raw
          
          if current_token.kind == :identifier
            return_type << trivia_after << current_token.lexeme
            trivia_after = current_token.trailing_trivia
            advance_raw
          end
        end
        
        # Handle <...> for template types
        if current_token.kind == :less
          return_type << trivia_after << current_token.lexeme << current_token.trailing_trivia
          advance_raw
          
          depth = 1
          while depth > 0 && !at_end?
            depth += 1 if current_token.kind == :less
            depth -= 1 if current_token.kind == :greater
            
            return_type << current_leading_trivia << current_token.lexeme
            trivia_after = current_token.trailing_trivia if depth == 0
            return_type << current_token.trailing_trivia unless depth == 0
            advance_raw
            break if depth == 0
          end
        end
        
        # Handle * and & for pointers/references
        while [:asterisk, :ampersand].include?(current_token.kind)
          return_type << trivia_after << current_token.lexeme
          trivia_after = current_token.trailing_trivia
          advance_raw
        end
        
        [return_type, trivia_after]
      end
      
      # Parse function name (handles constructor, destructor, operator overload, regular name)
      # Takes is_constructor flag and trivia_after_type
      # Returns [name, return_type_suffix]
      def parse_function_name(is_constructor, trivia_after)
        return_type_suffix = trivia_after
        name = "".dup
        
        if is_constructor
          parse_constructor_name_into(name, return_type_suffix)
        elsif current_token.kind == :identifier
          parse_identifier_function_name_into(name, trivia_after)
          return_type_suffix = trivia_after
        elsif current_token.kind == :keyword_operator
          name << current_token.lexeme
          advance_raw
          name << current_leading_trivia
          parse_operator_symbol(name)
        elsif current_token.kind == :tilde
          name << current_token.lexeme
          advance_raw
          raise ParseError, "Expected class name after ~" unless current_token.kind == :identifier
          name << current_token.lexeme
          advance_raw
        else
          raise ParseError, "Expected function name" unless current_token.kind == :identifier
          name << current_token.lexeme
          advance_raw
        end
        
        [name, return_type_suffix]
      end
      
      # Parse constructor name (ClassName or ClassName::ClassName)
      def parse_constructor_name_into(name, return_type_suffix)
        name << current_token.lexeme
        advance_raw
        
        scope_trivia = current_leading_trivia
        if current_token.kind == :colon_colon
          name << scope_trivia << current_token.lexeme
          advance_raw
          name << current_leading_trivia << current_token.lexeme
          advance_raw
        else
          return_type_suffix << scope_trivia if scope_trivia.length > 0
        end
      end
      
      # Parse identifier-based function name (can be Class::method or Class::operator+)
      def parse_identifier_function_name_into(name, trivia_after)
        saved_pos = @position
        class_name = current_token.lexeme
        scope_trivia = current_token.trailing_trivia
        advance_raw
        
        if current_token.kind == :colon_colon
          after_colon = current_token.trailing_trivia
          advance_raw
          
          if current_token.kind == :keyword_operator
            # Out-of-line operator: ClassName::operator+
            name << class_name << scope_trivia << "::" << after_colon << current_token.lexeme
            advance_raw
            name << current_leading_trivia
            parse_operator_symbol(name)
          else
            # Regular method: ClassName::method
            @position = saved_pos
            name << current_token.lexeme
            scope_trivia2 = current_token.trailing_trivia
            advance_raw
            name << scope_trivia2 << current_token.lexeme  # ::
            advance_raw
            name << current_token.trailing_trivia
            name << current_token.lexeme  # method
            advance_raw
          end
        else
          # Regular function name
          @position = saved_pos
          name << current_token.lexeme
          advance_raw
        end
      end
      
      # Parse operator symbol (handles +, -, [], (), new, delete, etc)
      def parse_operator_symbol(name)
        operator_symbols = [:plus, :minus, :asterisk, :slash, :percent, :equals,
                           :equals_equals, :exclamation_equals, :less, :greater,
                           :less_equals, :greater_equals, :plus_plus, :minus_minus,
                           :ampersand, :pipe, :caret, :tilde, :exclamation,
                           :ampersand_ampersand, :pipe_pipe, :less_less, :greater_greater,
                           :comma, :arrow, :arrow_asterisk]
        
        if operator_symbols.include?(current_token.kind)
          name << current_token.lexeme
          advance_raw
        elsif current_token.kind == :lparen
          # operator()
          name << current_token.lexeme  # '('
          advance_raw
          name << current_token.lexeme  # ')'
          advance_raw
        elsif current_token.kind == :lbracket
          # operator[]
          name << current_token.lexeme  # '['
          advance_raw
          name << current_token.lexeme  # ']'
          advance_raw
        elsif current_token.kind == :keyword_new || current_token.kind == :keyword_delete
          # operator new, operator delete
          name << " " << current_token.lexeme
          advance_raw
          if current_token.kind == :lbracket
            name << current_token.lexeme  # '['
            advance_raw
            name << current_token.lexeme  # ']'
            advance_raw
          end
        else
          # Conversion operator
          while current_token.kind != :lparen && !at_end?
            name << current_token.lexeme
            advance_raw
          end
        end
      end
      
      # Parse function parameters
      # Returns [parameters, param_separators, lparen_suffix, rparen_suffix]
      def parse_function_parameters
        lparen_suffix = current_token.trailing_trivia
        expect(:lparen)
        
        parameters = []
        param_separators = []
        
        until current_token.kind == :rparen || at_end?
          param_text = "".dup
          paren_depth = 0
          
          loop do
            break if at_end?
            param_text << current_leading_trivia
            
            if current_token.kind == :lparen
              paren_depth += 1
              param_text << current_token.lexeme << current_token.trailing_trivia
              advance_raw
            elsif current_token.kind == :rparen
              break if paren_depth.zero?
              paren_depth -= 1
              param_text << current_token.lexeme << current_token.trailing_trivia
              advance_raw
            elsif current_token.kind == :comma && paren_depth.zero?
              break
            else
              param_text << current_token.lexeme << current_token.trailing_trivia
              advance_raw
            end
          end
          
          parameters << param_text unless param_text.empty?
          
          if current_token.kind == :comma
            param_separators << current_token.lexeme + current_token.trailing_trivia
            advance_raw
          end
        end
        
        rparen_suffix = current_leading_trivia
        after_rparen = current_token.trailing_trivia
        expect(:rparen)
        
        [parameters, param_separators, lparen_suffix, rparen_suffix, after_rparen]
      end
      
      # Parse function modifiers after parameters (const, override, final, noexcept, = default)
      # Returns [modifiers_text, trivia_after]
      def parse_function_modifiers_postfix(after_rparen, is_constructor)
        modifiers_text = "".dup
        
        until [:lbrace, :semicolon, :colon].include?(current_token.kind) || at_end?
          modifiers_text << after_rparen unless after_rparen.empty?
          after_rparen = ""
          modifiers_text << current_token.lexeme << current_token.trailing_trivia
          advance_raw
        end
        
        # Handle constructor initializer list
        if is_constructor && current_token.kind == :colon
          modifiers_text << after_rparen unless after_rparen.empty?
          after_rparen = ""
          
          while ![:lbrace, :semicolon].include?(current_token.kind) && !at_end?
            modifiers_text << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
          after_rparen = current_leading_trivia
        end
        
        [modifiers_text, after_rparen]
      end
      
      # === End Function Declaration Helpers ===
      
      # Parse enum declaration: `enum Color { Red, Green };` or `enum class Color { Red, Green };`
      # Returns (EnumDeclaration, trailing) tuple
      def parse_enum_declaration(leading_trivia)
        # Consume 'enum'
        enum_suffix = current_token.trailing_trivia
        expect(:keyword_enum)
        
        # Check for 'class' or 'struct' keyword
        class_keyword = ""
        class_suffix = ""
        if [:keyword_class, :keyword_struct].include?(current_token.kind)
          class_keyword = current_token.lexeme
          class_suffix = current_token.trailing_trivia

          advance_raw
        end
        
        # Parse name (optional for anonymous enums)
        name = ""
        name_suffix = ""
        if current_token.kind == :identifier
          name = current_token.lexeme
          name_suffix = current_token.trailing_trivia

          advance_raw
        end
        
        # Check for base type: `: int`
        if current_token.kind == :colon
          name_suffix << current_token.lexeme << current_token.trailing_trivia
          advance_raw
          
          # Collect base type until {
          until current_token.kind == :lbrace || at_end?
            name_suffix << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
        
        # Consume '{'
        lbrace_suffix = current_token.trailing_trivia
        expect(:lbrace)
        
        # Collect enumerators as text until '}'
        enumerators = "".dup
        until current_token.kind == :rbrace || at_end?
          enumerators << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
          advance_raw
        end
        
        # Collect trivia before '}'
        rbrace_suffix = current_leading_trivia
        
        # Consume '}'
        _semicolon_prefix = current_token.trailing_trivia
        expect(:rbrace)
        
        # Consume ';'
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
        stmt = Nodes::EnumDeclaration.new(
          leading_trivia: leading_trivia,
          name: name,
          enumerators: enumerators,
          enum_suffix: enum_suffix,
          class_keyword: class_keyword,
          class_suffix: class_suffix,
          name_suffix: name_suffix,
          lbrace_suffix: lbrace_suffix,
          rbrace_suffix: rbrace_suffix
        )
        
        [stmt, trailing]
      end
    end
  end
end
