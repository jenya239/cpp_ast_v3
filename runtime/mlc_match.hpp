#ifndef AURORA_MATCH_HPP
#define AURORA_MATCH_HPP

#include <utility>

namespace mlc {

// Helper for building overloaded lambda sets for std::visit
template <class... Ts>
struct overloaded : Ts... {
  using Ts::operator()...;
};

template <class... Ts>
overloaded(Ts...) -> overloaded<Ts...>;

}  // namespace mlc

// Provide the helper in the global namespace to match existing codegen
using mlc::overloaded;

#endif  // AURORA_MATCH_HPP
