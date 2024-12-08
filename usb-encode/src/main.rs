use std::io::Read;
use std::io::Write;

fn main() {
    let mut stdin = std::io::stdin();
    let mut buffer = String::new();

    let mut stdout = std::io::stdout();
    stdin.read_to_string(&mut buffer).unwrap();

    // the last bit in the sync pattern is 0
    let mut previous_output = false;

    let mut output = String::new();
    for bit in buffer.split_whitespace().map(|substring| match substring {
        "0" => false,
        "1" => true,
        _ => panic!(),
    }) {
        // 1 is represented by no change in level, 0 is represented by a change in level
        if !(bit ^ previous_output) {
            previous_output = true;
            output.push_str("1 ");
        } else {
            previous_output = false;
            output.push_str("0 ");
        }
    }

    stdout.write(output.as_bytes()).unwrap();
}
