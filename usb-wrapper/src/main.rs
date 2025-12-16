use std::io;
use std::io::Read;
use std::time::Duration;

fn main() {
    let device_list = rusb::devices().unwrap();
    let mut eligible_devices = device_list.iter().filter(|device| {
        let device_descriptor = device.device_descriptor().unwrap();
        device_descriptor.vendor_id() == 0 && device_descriptor.product_id() == 0
    });

    let got_device = eligible_devices.next().expect("no eligible device found");
    if eligible_devices.next().is_some() {
        panic!("multiple eligible devices found");
    }

    let device_handle = got_device.open().unwrap();

    let mut stdin = io::stdin();
    let mut buffer = [0u8; 64];
    loop {
        if let Ok(got_bytes) = stdin.read(&mut buffer) {
            let _ = device_handle
                .write_control(
                    rusb::request_type(
                        rusb::Direction::Out,
                        rusb::RequestType::Vendor,
                        rusb::Recipient::Device,
                    ),
                    13, // this is a custom out request type
                    0,
                    0,
                    &buffer[0..got_bytes],
                    Duration::from_millis(500),
                );
        } else {
            break;
        }
    }
}
