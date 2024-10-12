use std::io::Read;
use std::io::Write;

use elf::endian::LittleEndian;
use elf::ElfBytes;

const TARGET_LOAD_ADDRESS: u32 = 0x1000;

const PT_LOAD: u32 = 1;

fn main() {
    let mut file_data = Vec::new();
    std::io::stdin().lock().read_to_end(&mut file_data).unwrap();
    let elf = ElfBytes::<LittleEndian>::minimal_parse(&file_data).unwrap();
    let elf_header = elf.ehdr;

    let mut offset: u32 = 0;

    let mut stdout = std::io::stdout().lock();
    let mut write = |bytes: &[u8], offset: &mut u32| {
        stdout.write_all(bytes).unwrap();
        *offset += u32::try_from(std::mem::size_of_val(bytes)).unwrap();
    };

    let entry_address: u32 = elf_header.e_entry.try_into().unwrap();

    write(
        &make_set_stack_pointer_instruction().to_le_bytes(),
        &mut offset,
    );
    write(
        &make_jal_instruction(entry_address, 4).to_le_bytes(),
        &mut offset,
    );

    let program_headers = elf.segments().unwrap();
    let first_program_header = program_headers.iter().nth(0).unwrap();
    let destination_address: u32 = align_up(
        TARGET_LOAD_ADDRESS,
        first_program_header.p_align.try_into().unwrap(),
    );
    // offset from the v_addr listed in the program header to the destination address
    let target_address_offset: i64 =
        i64::from(destination_address) - i64::try_from(first_program_header.p_vaddr).unwrap();

    for program_header in program_headers
        .iter()
        .filter(|header| header.p_type == PT_LOAD)
    {
        let destination_address: u32 = (i64::try_from(program_header.p_vaddr).unwrap()
            + i64::try_from(target_address_offset).unwrap())
        .try_into()
        .unwrap();
        let pad_amount: u32 = destination_address - offset;
        for _ in 0..pad_amount {
            write(&[0], &mut offset);
        }
        let segment_data = &elf.segment_data(&program_header).unwrap();
        write(segment_data, &mut offset);
        let additional_zeros = u32::try_from(program_header.p_memsz).unwrap()
            - u32::try_from(segment_data.len()).unwrap();
        for _ in 0..additional_zeros {
            write(&[0], &mut offset);
        }
    }
}

fn align_up(target: u32, alignment: u32) -> u32 {
    target + (alignment - (target % alignment))
}

fn make_jal_instruction(entry: u32, jal_address: u32) -> u32 {
    let instruction_offset = entry - jal_address;
    let jal_opcode = 0b1101111;
    jal_opcode
        | (((instruction_offset >> 20) & 1) << 31)
        | (((instruction_offset >> 1) & 0b1111111111) << 21)
        | (((instruction_offset >> 11) & 1) << 20)
        | (((instruction_offset >> 12) & 0b11111111) << 12)
}

fn make_set_stack_pointer_instruction() -> u32 {
    let addi_opcode = 0b0010011;
    let register = 0b10;
    let immediate = 100000;
    addi_opcode | (register << 7) | (immediate << 20)
}
