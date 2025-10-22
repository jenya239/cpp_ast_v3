# Error Handling Improvements

## Current Issues

### 1. Generic Error Messages
- **Problem**: "Parse error: unexpected token" without context
- **Solution**: Rich error reporting with source location

### 2. No Error Recovery
- **Problem**: Single error stops entire compilation
- **Solution**: Error recovery with multiple error reporting

### 3. Poor Type Error Messages
- **Problem**: "Type mismatch" without explanation
- **Solution**: Detailed type error diagnostics

## Implementation Plan

### Phase 1: Rich Error Reporting
```ruby
class AuroraError < StandardError
  attr_reader :location, :suggestion, :context
  
  def initialize(message, location: nil, suggestion: nil, context: nil)
    super(message)
    @location = location
    @suggestion = suggestion
    @context = context
  end
  
  def formatted_message
    lines = []
    lines << "#{@location}: #{message}" if @location
    lines << "  Suggestion: #{@suggestion}" if @suggestion
    lines << "  Context: #{@context}" if @context
    lines.join("\n")
  end
end
```

### Phase 2: Error Recovery
```ruby
class Parser
  def parse_with_recovery
    errors = []
    declarations = []
    
    while !eof?
      begin
        declarations << parse_declaration
      rescue ParseError => e
        errors << e
        recover_from_error
      end
    end
    
    { declarations: declarations, errors: errors }
  end
  
  private
  
  def recover_from_error
    # Skip to next declaration boundary
    while !eof? && current.type != :FN && current.type != :TYPE
      @pos += 1
    end
  end
end
```

### Phase 3: Type Error Diagnostics
```ruby
class TypeChecker
  def check_type_compatibility(expected, actual, location)
    if expected != actual
      suggestion = suggest_type_fix(expected, actual)
      context = build_type_context(expected, actual)
      
      raise TypeError.new(
        "Type mismatch: expected #{expected}, got #{actual}",
        location: location,
        suggestion: suggestion,
        context: context
      )
    end
  end
  
  private
  
  def suggest_type_fix(expected, actual)
    case [expected, actual]
    when ["int", "float"]
      "Consider using #{expected} or casting with #{actual}(value)"
    when ["bool", "int"]
      "Use comparison operators (==, !=, <, >) for boolean logic"
    else
      "Check variable declarations and function signatures"
    end
  end
end
```

## Expected Results
- **Better UX**: Clear, actionable error messages
- **Faster Development**: Multiple errors shown at once
- **Learning Aid**: Helpful suggestions for common mistakes
