// ==============================================================================
// Module: l1_icache_2way.v
// Architecture: 4 KB, 2-Way Set-Associative L1 Instruction Cache
// Target FPGA : Intel MAX 10 (DE10-Lite) using on-chip M9K Block RAM
//
// PARAMETERS & SPECIFICATIONS:
//   - Total Capacity : 4 KB (4,096 Bytes = 1,024 Instructions)
//   - Line Size      : 16 Bytes (128 bits = 4 Instructions per line)
//   - Associativity  : 2-Way Set-Associative (Way 0 and Way 1)
//   - Number of Sets : 128 Sets (128 Sets x 2 Ways = 256 Lines total)
//   - Per-Set Storage: 8 Instructions (32 Bytes) per Set (4 in Way 0, 4 in Way 1)
//   - Replacement    : 1-Bit True LRU (Least Recently Used) per Set
//
// ADDRESS DECODING (PCF[31:0]):
//   - PCF[1:0]   : Byte Offset (2 bits, ignored for 32-bit word alignment)
//   - PCF[3:2]   : Word Offset (2 bits -> selects 1 of 4 instructions in the line)
//   - PCF[10:4]  : Set Index   (7 bits -> selects 1 of 128 Sets)
//   - PCF[31:11] : Cache Tag   (21 bits -> matched against stored Tag)
// ==============================================================================

module l1_cache_2way