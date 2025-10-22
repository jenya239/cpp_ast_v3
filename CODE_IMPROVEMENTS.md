# Code Improvements

## Immediate Improvements

### 1. Fix Ruby Warnings
Current warnings in test output:
- Mismatched indentations
- Unused variables
- Method redefinitions

### 2. Code Quality Issues
- Duplicate method definitions
- Unused variables
- Inconsistent formatting

## Implementation Plan

### Phase 1: Fix Warnings
```ruby
# Fix indentation warnings
class Parser
  def parse_expression
    case current.type
    when :INTEGER
      parse_integer
    when :IDENTIFIER
      parse_identifier
    when :LPAREN
      parse_parenthesized
    else
      raise ParseError, "Unexpected token: #{current.type}"
    end
  end
end

# Remove unused variables
def parse_function
  return_type = parse_type
  name = parse_identifier
  params = parse_parameters
  body = parse_expression
  
  # Remove unused variable
  # previous = @last_token  # <-- Remove this line
end
```

### Phase 2: Refactor Duplicate Code
```ruby
# Extract common patterns
module ASTBuilder
  def self.create_function(return_type, name, params, body)
    Function.new(
      return_type: return_type,
      name: name,
      parameters: params,
      body: body
    )
  end
  
  def self.create_class(name, members)
    Class.new(
      name: name,
      members: members
    )
  end
end
```

### Phase 3: Improve Error Handling
```ruby
# Better error context
class Parser
  def parse_with_context(description)
    begin
      yield
    rescue => e
      raise ParseError.new(
        "#{description} failed: #{e.message}",
        location: current_location,
        context: build_context
      )
    end
  end
  
  private
  
  def build_context
    {
      current_token: current,
      previous_token: @last_token,
      position: @pos,
      remaining_tokens: @tokens[@pos..@pos+5]
    }
  end
end
```

## Code Quality Metrics

### Before Improvements
- **Warnings**: 25+ Ruby warnings
- **Duplication**: Multiple method definitions
- **Complexity**: High cyclomatic complexity

### After Improvements
- **Warnings**: 0 Ruby warnings
- **Duplication**: Eliminated duplicate code
- **Complexity**: Reduced complexity through refactoring

## Specific Files to Improve

1. **lib/aurora/passes/to_core.rb**
   - Fix indentation warnings
   - Remove unused variables
   - Simplify case statements

2. **lib/cpp_ast/builder/expr_builder.rb**
   - Fix indentation mismatches
   - Remove duplicate method definitions

3. **test/builder/roundtrip_test.rb**
   - Fix method redefinition warnings
   - Clean up test organization

## Expected Results
- **Clean Build**: No Ruby warnings
- **Maintainability**: Cleaner, more readable code
- **Performance**: Slightly faster due to reduced complexity
