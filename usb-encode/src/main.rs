use std::io::Read;
use std::io::Write;

fn main() {
    let mut stdin = std::io::stdin();
    let mut buffer = String::new();

    let mut stdout = std::io::stdout();
    stdin.read_to_string(&mut buffer).unwrap();

    let mut output = String::new();
    for bit in UsbEncoder::from(buffer.split_whitespace().map(|substring| match substring {
        "0" => false,
        "1" => true,
        _ => panic!(),
    })) {
        if bit {
            output.push_str("1 ");
        } else {
            output.push_str("0 ");
        }
    }

    stdout.write(output.as_bytes()).unwrap();
}

struct UsbEncoder<I: Iterator<Item=bool>> {
    inner: I,
    consecutive_input_ones: i32,
    previous_output: bool,
}

impl<I: Iterator<Item=bool>> From<I> for UsbEncoder<I> {
    fn from(iterator: I) -> Self {
        UsbEncoder {
            inner: iterator,
            consecutive_input_ones: 1, // since the sync packet ends with an encoded one
            previous_output: false, // since the sync packet ends at low level
        }
    }

}

impl<I: Iterator<Item=bool>> Iterator for UsbEncoder<I> {
    type Item = bool;

    fn next(&mut self) -> Option<bool> {
        let output = match self.consecutive_input_ones {
            7.. => panic!(),
            6 => {
                self.consecutive_input_ones = 0;
                Some(!self.previous_output)
            }
            _ => if let Some(inner_next) = self.inner.next() {
                    self.consecutive_input_ones = if inner_next {
                        self.consecutive_input_ones + 1 
                    } else {
                        0
                    };
                    Some(!(inner_next ^ self.previous_output))
                } else {
                    None
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
    })).map(|bit| if bit { '1' } else { '0' }).collect()
}
