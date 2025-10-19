#include "../runtime/aurora_buffer.hpp"
#include <iostream>
#include <iomanip>

using namespace aurora;

// BMP file format parser - demonstrates real binary format parsing

struct BMPHeader {
    uint16_t signature;      // "BM" = 0x4D42
    uint32_t file_size;
    uint16_t reserved1;
    uint16_t reserved2;
    uint32_t data_offset;
};

struct BMPInfoHeader {
    uint32_t header_size;
    int32_t width;
    int32_t height;
    uint16_t planes;
    uint16_t bits_per_pixel;
    uint32_t compression;
    uint32_t image_size;
    int32_t x_pixels_per_meter;
    int32_t y_pixels_per_meter;
    uint32_t colors_used;
    uint32_t important_colors;
};

BMPHeader read_bmp_header(BinaryReader& reader) {
    BMPHeader header;
    
    header.signature = reader.read_u16();
    header.file_size = reader.read_u32();
    header.reserved1 = reader.read_u16();
    header.reserved2 = reader.read_u16();
    header.data_offset = reader.read_u32();
    
    return header;
}

BMPInfoHeader read_bmp_info_header(BinaryReader& reader) {
    BMPInfoHeader info;
    
    info.header_size = reader.read_u32();
    info.width = reader.read_i32();
    info.height = reader.read_i32();
    info.planes = reader.read_u16();
    info.bits_per_pixel = reader.read_u16();
    info.compression = reader.read_u32();
    info.image_size = reader.read_u32();
    info.x_pixels_per_meter = reader.read_i32();
    info.y_pixels_per_meter = reader.read_i32();
    info.colors_used = reader.read_u32();
    info.important_colors = reader.read_u32();
    
    return info;
}

void write_bmp_header(BinaryWriter& writer, const BMPHeader& header) {
    writer.write_u16(header.signature);
    writer.write_u32(header.file_size);
    writer.write_u16(header.reserved1);
    writer.write_u16(header.reserved2);
    writer.write_u32(header.data_offset);
}

void write_bmp_info_header(BinaryWriter& writer, const BMPInfoHeader& info) {
    writer.write_u32(info.header_size);
    writer.write_i32(info.width);
    writer.write_i32(info.height);
    writer.write_u16(info.planes);
    writer.write_u16(info.bits_per_pixel);
    writer.write_u32(info.compression);
    writer.write_u32(info.image_size);
    writer.write_i32(info.x_pixels_per_meter);
    writer.write_i32(info.y_pixels_per_meter);
    writer.write_u32(info.colors_used);
    writer.write_u32(info.important_colors);
}

int main() {
    std::cout << "=== BMP File Format Parser ===" << std::endl << std::endl;

    // Create a minimal BMP file in memory
    std::cout << "Creating a minimal BMP file structure..." << std::endl;
    
    // Prepare headers
    BMPHeader header;
    header.signature = 0x4D42;  // "BM"
    header.file_size = 70;      // Header + info + minimal data
    header.reserved1 = 0;
    header.reserved2 = 0;
    header.data_offset = 54;    // Standard offset for 24-bit BMP
    
    BMPInfoHeader info;
    info.header_size = 40;      // BITMAPINFOHEADER size
    info.width = 2;
    info.height = 2;
    info.planes = 1;
    info.bits_per_pixel = 24;
    info.compression = 0;       // No compression
    info.image_size = 16;       // 2x2x3 + padding
    info.x_pixels_per_meter = 0;
    info.y_pixels_per_meter = 0;
    info.colors_used = 0;
    info.important_colors = 0;
    
    // Write to buffer (BMP is little-endian)
    Buffer buf;
    BinaryWriter writer(buf, Endian::Little);
    
    write_bmp_header(writer, header);
    write_bmp_info_header(writer, info);
    
    // Add minimal pixel data (2x2 RGB image)
    // Row 0: Red, Green
    writer.write_u8(0);    writer.write_u8(0);    writer.write_u8(255);  // Red
    writer.write_u8(0);    writer.write_u8(255);  writer.write_u8(0);    // Green
    writer.write_u16(0);   // Row padding
    
    // Row 1: Blue, White
    writer.write_u8(255);  writer.write_u8(0);    writer.write_u8(0);    // Blue
    writer.write_u8(255);  writer.write_u8(255);  writer.write_u8(255);  // White
    writer.write_u16(0);   // Row padding
    
    std::cout << "Created " << buf.size() << " byte BMP file" << std::endl << std::endl;
    
    // Now parse it back
    std::cout << "Parsing BMP file..." << std::endl;
    BinaryReader reader(buf, Endian::Little);
    
    auto read_header = read_bmp_header(reader);
    
    // Validate signature
    if (read_header.signature != 0x4D42) {
        std::cerr << "Error: Not a valid BMP file!" << std::endl;
        return 1;
    }
    
    std::cout << "✓ Valid BMP signature" << std::endl;
    std::cout << "File size: " << read_header.file_size << " bytes" << std::endl;
    std::cout << "Data offset: " << read_header.data_offset << std::endl << std::endl;
    
    auto read_info = read_bmp_info_header(reader);
    
    std::cout << "Image Info:" << std::endl;
    std::cout << "  Dimensions: " << read_info.width << "x" << read_info.height << std::endl;
    std::cout << "  Bits per pixel: " << read_info.bits_per_pixel << std::endl;
    std::cout << "  Compression: " << (read_info.compression == 0 ? "None" : "Compressed") << std::endl;
    std::cout << "  Image size: " << read_info.image_size << " bytes" << std::endl << std::endl;
    
    // Read pixel data
    std::cout << "Pixel data (BGR format):" << std::endl;
    reader.set_position(read_header.data_offset);
    
    for (int row = 0; row < read_info.height; row++) {
        std::cout << "  Row " << row << ": ";
        for (int col = 0; col < read_info.width; col++) {
            uint8_t b = reader.read_u8();
            uint8_t g = reader.read_u8();
            uint8_t r = reader.read_u8();
            std::cout << "RGB(" << (int)r << "," << (int)g << "," << (int)b << ") ";
        }
        // Skip padding
        reader.skip(2);
        std::cout << std::endl;
    }
    
    std::cout << std::endl << "✓ Successfully parsed BMP file!" << std::endl;

    return 0;
}
