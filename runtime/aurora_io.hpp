#ifndef AURORA_IO_HPP
#define AURORA_IO_HPP

#include <iostream>
#include <cstdlib>
#include "aurora_string.hpp"

namespace io {

// Basic console output
inline void print(const aurora::String& s) {
    std::cout << s.as_std_string();
}

inline void println(const aurora::String& s) {
    std::cout << s.as_std_string() << std::endl;
}

// Error output
inline void eprint(const aurora::String& s) {
    std::cerr << s.as_std_string();
}

inline void eprintln(const aurora::String& s) {
    std::cerr << s.as_std_string() << std::endl;
}

// Process control
inline void exit(int code) {
    std::exit(code);
}

} // namespace io

#endif // AURORA_IO_HPP
