/* This program takes an ELF binary and generates data suitable for loading
 * onto the processor
 *
 * Output format:
 *     bytes 0-3: initial value of program counter
 *     bytes 4+: initial memory image, what the ELF file expects to have in
 *               memory
 */

use std::io::Read;
use std::io::Write;

use elf::endian::LittleEndian;
use elf::ElfBytes;
use elf::abi::PT_LOAD;

fn main() {
    let mut file_data = Vec::new();
    std::io::stdin().lock().read_to_end(&mut file_data).unwrap();
    let elf = ElfBytes::<LittleEndian>::minimal_parse(&file_data).unwrap();
    let elf_header = elf.ehdr;

    let mut stdout = std::io::stdout().lock();

    let entry_address: u32 = elf_header.e_entry.try_into().unwrap();
    stdout.write(entry_address.to_le_bytes().as_slice()).unwrap();

    let mut memory_offset: u32 = 0;

    let mut write = |bytes: &[u8], offset: &mut u32| {
        stdout.write_all(bytes).unwrap();
        *offset += u32::try_from(std::mem::size_of_val(bytes)).unwrap();
    };

    let program_headers = elf.segments().unwrap();

    for program_header in program_headers
        .iter()
        .filter(|header| header.p_type == PT_LOAD)
    {
        let destination_address: u32 = program_header.p_vaddr.try_into().unwrap();
        assert!(destination_address >= memory_offset);

        let pad_amount: u32 = destination_address - memory_offset;
        for _ in 0..pad_amount {
            write(&[0], &mut memory_offset);
        }

        let segment_data = &elf.segment_data(&program_header).unwrap();
        write(segment_data, &mut memory_offset);

        let additional_zeros = u32::try_from(program_header.p_memsz).unwrap()
            - u32::try_from(segment_data.len()).unwrap();
        for _ in 0..additional_zeros {
            write(&[0], &mut memory_offset);
        }
    }
}
