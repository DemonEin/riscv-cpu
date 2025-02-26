use std::io::Read;
use std::io::Write;

fn main() {
    std::io::stdout()
        .write(
            &BitsToLittleEndianBytes::from(UsbEncoder::from(LittleEndianBytesToBits::from(
                std::io::stdin()
                    .bytes()
                    .map(|byte_result| byte_result.unwrap()),
            )))
            .collect::<Vec<u8>>(),
        )
        .unwrap();
}

struct BitsToLittleEndianBytes<I> {
    inner: I,
}

impl<I: Iterator<Item = bool>> From<I> for BitsToLittleEndianBytes<I> {
    fn from(iterator: I) -> Self {
        Self { inner: iterator }
    }
}

impl<I: Iterator<Item = bool>> Iterator for BitsToLittleEndianBytes<I> {
    type Item = u8;

    fn next(&mut self) -> Option<u8> {
        let mut byte: u8 = 0;
        let mut got_bit = false;
        for bit_index in 0..8 {
            if let Some(bit) = self.inner.next() {
                byte |= if bit { 1 } else { 0 } << bit_index;
                got_bit = true;
            } else {
                break;
            }
        }

        if !got_bit {
            None
        } else {
            Some(byte)
        }
    }
}

struct LittleEndianBytesToBits<I> {
    inner: I,
    current_index: u8,
    current_byte: u8,
}

impl<I: Iterator<Item = u8>> Iterator for LittleEndianBytesToBits<I> {
    type Item = bool;

    fn next(&mut self) -> Option<bool> {
        if self.current_index < 8 {
            let result = Some(self.current_byte & (1 << self.current_index) > 0);
            self.current_index += 1;
            result
        } else {
            if let Some(next) = self.inner.next() {
                self.current_byte = next;
                let result = Some(self.current_byte & 1 > 0);
                self.current_index = 1;
                result
            } else {
                None
            }
        }
    }
}

impl<I: Iterator<Item = u8>> From<I> for LittleEndianBytesToBits<I> {
    fn from(iterator: I) -> Self {
        Self {
            inner: iterator,
            current_index: 8,
            current_byte: 0,
        }
    }
}

struct UsbEncoder<I: Iterator<Item = bool>> {
    inner: I,
    consecutive_input_ones: i32,
    previous_output: bool,
}

impl<I: Iterator<Item = bool>> From<I> for UsbEncoder<I> {
    fn from(iterator: I) -> Self {
        UsbEncoder {
            inner: iterator,
            consecutive_input_ones: 1, // since the sync packet ends with an encoded one
            previous_output: false,    // since the sync packet ends at low level
        }
    }
}

impl<I: Iterator<Item = bool>> Iterator for UsbEncoder<I> {
    type Item = bool;

    fn next(&mut self) -> Option<bool> {
        let output = match self.consecutive_input_ones {
            7.. => panic!(),
            6 => {
                self.consecutive_input_ones = 0;
                Some(!self.previous_output)
            }
            _ => {
                if let Some(inner_next) = self.inner.next() {
                    self.consecutive_input_ones = if inner_next {
                        self.consecutive_input_ones + 1
                    } else {
                        0
                    };
                    Some(!(inner_next ^ self.previous_output))
                } else {
                    None
                }
            }
        };

        if let Some(output) = output {
            self.previous_output = output;
        }

        output
    }
}

#[test]
fn encode_test() {
    assert_eq!(encode_str("1111"), "0000");
    assert_eq!(encode_str("11111"), "000001");
    assert_eq!(encode_str("0011"), "1000");
    assert_eq!(encode_str("111111"), "0000011");
}

fn encode_str(s: &str) -> String {
    UsbEncoder::from(s.chars().map(|c| match c {
        '0' => false,
        '1' => true,
        _ => panic!(),
    }))
    .map(|bit| if bit { '1' } else { '0' })
    .collect()
}

#[test]
fn iterate_bit_test() {
    assert!(LittleEndianBytesToBits::from([0b011].into_iter())
        .eq([true, true, false, false, false, false, false, false].into_iter()))
}
