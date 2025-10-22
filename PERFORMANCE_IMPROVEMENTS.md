# Performance Improvements for cpp_ast_v3

## Current Performance Issues

### 1. Parser Performance
- **Issue**: Recursive descent parser can be slow on large files
- **Solution**: Implement memoization for frequently parsed constructs
- **Impact**: 2-3x speedup on large Aurora files

### 2. AST Generation
- **Issue**: Deep object creation overhead
- **Solution**: Object pooling for AST nodes
- **Impact**: 30-50% memory reduction

### 3. C++ Code Generation
- **Issue**: String concatenation in to_source methods
- **Solution**: StringBuilder pattern with pre-allocated buffers
- **Impact**: 40-60% faster code generation

## Implementation Plan

### Phase 1: Parser Optimizations
```ruby
# Add memoization to parser
class Parser
  def initialize(source, filename: nil)
    @memo = {}
    # ... existing code
  end
  
  def parse_expression
    key = "#{@pos}_expression"
    return @memo[key] if @memo[key]
    
    result = parse_expression_impl
    @memo[key] = result
    result
  end
end
```

### Phase 2: AST Node Pooling
```ruby
# Object pool for AST nodes
class ASTNodePool
  def self.get_node(type)
    @pools ||= {}
    @pools[type] ||= []
    @pools[type].pop || type.new
  end
  
  def self.return_node(node)
    @pools[node.class] ||= []
    @pools[node.class] << node.reset
  end
end
```

### Phase 3: Code Generation Optimization
```ruby
# StringBuilder for efficient code generation
class CodeBuilder
  def initialize(initial_capacity = 1024)
    @buffer = String.new(capacity: initial_capacity)
  end
  
  def append(str)
    @buffer << str
    self
  end
  
  def to_s
    @buffer.freeze
  end
end
```

## Expected Results
- **Parser**: 2-3x faster on large files
- **Memory**: 30-50% reduction
- **Code Generation**: 40-60% faster
- **Overall**: 2-4x performance improvement
