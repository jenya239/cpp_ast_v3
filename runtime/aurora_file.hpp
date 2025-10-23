#ifndef AURORA_FILE_HPP
#define AURORA_FILE_HPP

#include <fstream>
#include <string>
#include <vector>
#include <optional>
#include "aurora_string.hpp"

namespace aurora::file {

// File handle wrapper with RAII
class File {
private:
    std::fstream stream_;
    std::string path_;
    bool is_open_;

public:
    File() : is_open_(false) {}

    explicit File(const std::string& path)
        : path_(path), is_open_(false) {}

    ~File() {
        close();
    }

    // Delete copy, allow move
    File(const File&) = delete;
    File& operator=(const File&) = delete;

    File(File&& other) noexcept
        : stream_(std::move(other.stream_))
        , path_(std::move(other.path_))
        , is_open_(other.is_open_) {
        other.is_open_ = false;
    }

    File& operator=(File&& other) noexcept {
        if (this != &other) {
            close();
            stream_ = std::move(other.stream_);
            path_ = std::move(other.path_);
            is_open_ = other.is_open_;
            other.is_open_ = false;
        }
        return *this;
    }

    bool open_read() {
        close();
        stream_.open(path_, std::ios::in);
        is_open_ = stream_.is_open();
        return is_open_;
    }

    bool open_write() {
        close();
        stream_.open(path_, std::ios::out | std::ios::trunc);
        is_open_ = stream_.is_open();
        return is_open_;
    }

    bool open_append() {
        close();
        stream_.open(path_, std::ios::out | std::ios::app);
        is_open_ = stream_.is_open();
        return is_open_;
    }

    void close() {
        if (is_open_ && stream_.is_open()) {
            stream_.close();
            is_open_ = false;
        }
    }

    bool is_open() const {
        return is_open_;
    }

    const std::string& path() const {
        return path_;
    }

    // Read entire file as string
    std::optional<aurora::String> read_all() {
        if (!is_open_) return std::nullopt;

        stream_.seekg(0, std::ios::end);
        size_t size = stream_.tellg();
        stream_.seekg(0, std::ios::beg);

        std::string content(size, '\0');
        stream_.read(&content[0], size);

        return aurora::String(content);
    }

    // Read one line
    std::optional<aurora::String> read_line() {
        if (!is_open_) return std::nullopt;

        std::string line;
        if (std::getline(stream_, line)) {
            return aurora::String(line);
        }
        return std::nullopt;
    }

    // Read all lines
    std::vector<aurora::String> read_lines() {
        std::vector<aurora::String> lines;
        if (!is_open_) return lines;

        std::string line;
        while (std::getline(stream_, line)) {
            lines.push_back(aurora::String(line));
        }
        return lines;
    }

    // Write string to file
    bool write(const aurora::String& content) {
        if (!is_open_) return false;
        stream_ << content.as_std_string();
        return stream_.good();
    }

    // Write line to file (adds newline)
    bool write_line(const aurora::String& line) {
        if (!is_open_) return false;
        stream_ << line.as_std_string() << '\n';
        return stream_.good();
    }

    // Write multiple lines
    bool write_lines(const std::vector<aurora::String>& lines) {
        if (!is_open_) return false;
        for (const auto& line : lines) {
            stream_ << line.as_std_string() << '\n';
            if (!stream_.good()) return false;
        }
        return true;
    }

    // Check if at end of file
    bool eof() const {
        return stream_.eof();
    }

    // Flush the stream
    void flush() {
        if (is_open_) {
            stream_.flush();
        }
    }
};

// Convenience functions for reading files

inline aurora::String read_to_string(const aurora::String& path) {
    std::ifstream file(path.as_std_string());
    if (!file.is_open()) {
        return aurora::String("");
    }

    file.seekg(0, std::ios::end);
    size_t size = file.tellg();
    file.seekg(0, std::ios::beg);

    std::string content(size, '\0');
    file.read(&content[0], size);

    return aurora::String(content);
}

inline std::vector<aurora::String> read_lines(const aurora::String& path) {
    std::vector<aurora::String> lines;
    std::ifstream file(path.as_std_string());
    if (!file.is_open()) {
        return lines;
    }

    std::string line;
    while (std::getline(file, line)) {
        lines.push_back(aurora::String(line));
    }

    return lines;
}

// Convenience functions for writing files

inline bool write_string(const aurora::String& path, const aurora::String& content) {
    std::ofstream file(path.as_std_string(), std::ios::out | std::ios::trunc);
    if (!file.is_open()) {
        return false;
    }

    file << content.as_std_string();
    return file.good();
}

inline bool write_lines(const aurora::String& path, const std::vector<aurora::String>& lines) {
    std::ofstream file(path.as_std_string(), std::ios::out | std::ios::trunc);
    if (!file.is_open()) {
        return false;
    }

    for (const auto& line : lines) {
        file << line.as_std_string() << '\n';
        if (!file.good()) return false;
    }

    return true;
}

inline bool append_string(const aurora::String& path, const aurora::String& content) {
    std::ofstream file(path.as_std_string(), std::ios::out | std::ios::app);
    if (!file.is_open()) {
        return false;
    }

    file << content.as_std_string();
    return file.good();
}

inline bool append_line(const aurora::String& path, const aurora::String& line) {
    std::ofstream file(path.as_std_string(), std::ios::out | std::ios::app);
    if (!file.is_open()) {
        return false;
    }

    file << line.as_std_string() << '\n';
    return file.good();
}

// File system operations

inline bool exists(const aurora::String& path) {
    std::ifstream file(path.as_std_string());
    return file.good();
}

inline bool remove_file(const aurora::String& path) {
    return std::remove(path.as_std_string().c_str()) == 0;
}

inline bool rename_file(const aurora::String& old_path, const aurora::String& new_path) {
    return std::rename(old_path.as_std_string().c_str(),
                      new_path.as_std_string().c_str()) == 0;
}

} // namespace aurora::file

#endif // AURORA_FILE_HPP
