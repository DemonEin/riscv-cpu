/* This program takes an ELF binary and generates data suitable for loading
 * onto the processor
 *
 * ouputs files:
 *     memory_image: the initial memory image of the processor
 *     entry_point: the initial value of the program counter
 */

use std::fs::File;
use std::io::Write;

use clap::Parser;

use elf::abi::PT_LOAD;
use elf::endian::LittleEndian;
use elf::ElfBytes;

#[derive(Parser)]
struct Args {
    /// input ELF file
    elf: String,
    /// path of the memory image output file
    #[arg(short = 'o', long = "memory")]
    memory_image: String,
    /// path of the entry point ouptup file
    #[arg(long = "entry")]
    entry_point: String,
}

fn main() {
    let args = Args::parse();

    let file_data = std::fs::read(args.elf).unwrap();
    let elf = ElfBytes::<LittleEndian>::minimal_parse(&file_data).unwrap();
    let elf_header = elf.ehdr;

    let mut entry_point_file = File::create(args.entry_point).unwrap();
    let entry_address: u32 = elf_header.e_entry.try_into().unwrap();
    entry_point_file
        .write(entry_address.to_string().as_bytes())
        .unwrap();
    drop(entry_point_file);

    let mut memory_image_file = File::create(args.memory_image).unwrap();
    let mut memory_offset: u32 = 0;

    let mut write = |bytes: &[u8], offset: &mut u32| {
        memory_image_file.write_all(bytes).unwrap();
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
