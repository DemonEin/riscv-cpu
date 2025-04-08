#include "cpulib.h"

#define BREQUEST_GET_STATUS 0
#define BREQUEST_CLEAR_FEATURE 1
#define BREQUEST_SET_FEATURE 3
#define BREQUEST_SET_ADDRESS 5
#define BREQUEST_GET_DESCRIPTOR 6
#define BREQUEST_SET_DESCRIPTOR 7
#define BREQUEST_GET_CONFIGURATION 8
#define BREQUEST_SET_CONFIGURATION 9
#define BREQUEST_GET_INTERFACE 10
#define BREQUEST_SET_INTERFACE 11
#define BREQUEST_SYNCH_FRAME 12

#define DESCRIPTOR_TYPE_DEVICE 1
#define DESCRIPTOR_TYPE_CONFIGURATION 2
#define DESCRIPTOR_TYPE_STRING 3
#define DESCRIPTOR_TYPE_INTERFACE 4
#define DESCRIPTOR_TYPE_ENDPOINT 5
#define DESCRIPTOR_TYPE_DEVICE_QUALIFIER 6

struct setup_data {
    uint8_t bmRequestType;
    uint8_t bRequest;
    uint16_t wValue;
    uint16_t wIndex;
    uint16_t wLength;
};

struct bConfiguration {
    uint8_t bLength;
    uint8_t bDescriptorType;
    uint16_t wTotalLength;
    uint8_t bNumInterfaces;
    uint8_t bConfigurationValue;
    uint8_t iConfiguration;
    uint8_t bmAttributes;
    uint8_t bMaxPower;
};

extern volatile char usb_packet_buffer[1024];
extern volatile uint16_t usb_data_length;
extern const volatile uint16_t usb_token; // bits 0-1: 00 for OUT token, 10 for IN, 11 for SETUP
                                          //     (the top two bits of the PID)
                                          // bits 2-8: address
                                          // bits 9-12: endpoint
                                          // rest of bits undefined

static bool in_control_transfer = false;
static uint8_t device_address = 0;
static struct bConfiguration configuration = {
    sizeof(configuration),
    DESCRIPTOR_TYPE_CONFIGURATION,
    sizeof(configuration),
    1,
    0,
    0,
    0b10000000,
    0 // TODO come up with a real number for this
};

// an usb external interrupt is trigger when receiving the data packet of an OUT transaction
// and the token packet of an IN transaction
//
// in an OUT transaction:
//     usb_token contains other data the address, endpoint, and token type
//     usb_data_length contains the length in bytes of the data section
//     usb_packet_buffer contains the data
//     any write to usb_data_length clears the interrupt, signals to
//         the gateware it now owns the data buffer, and causes the gateware
//         to send a handshake of the type specified by usb_token
//
// in an IN transaction:
//     usb_token contains other data the address, endpoint, and token type
//     any write to usb_data_length clears the interrupt and causes the
//         gateware to send the first usb_data_length bytes in usb_packet_buffer
//         in a data packet
static uint16_t make_usb_response() {
    if (((usb_token & 0b11111110) >> 1) != device_address) {
        return 0;
    }

    if (usb_token & 1) {
        // setup transaction
        struct setup_data* setup_data = (struct setup_data*) usb_packet_buffer;
        switch (setup_data->bRequest) {
            case BREQUEST_SET_ADDRESS:
                device_address = setup_data->wValue;
                simulation_print("got set address packet");
                break;
            case BREQUEST_GET_CONFIGURATION:
                if (device_address == 0) { // device is in address state
                    usb_packet_buffer[0] = 0;
                    return 1;
                } else {
                    // device is in configured state
                    *(struct bConfiguration*) usb_packet_buffer = configuration;
                    return sizeof(configuration);
                }
            /*
            case BREQUEST_GET_INTERFACE: // device to host (read) transaction
                                         // send request error by sending stall
                                         // so I need a way to control whether the
                                         // usb module should respond with STALL or ACK
                                         // in the handshake of an out transaction
                // always send request error
            */
        }

        in_control_transfer = true;
    } else {
        // in transaction
    }
    return 0;
}

void handle_usb_transaction() {
    usb_data_length = make_usb_response();
}
