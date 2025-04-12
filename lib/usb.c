#include "cpulib.h"

enum bRequest : uint8_t {
    BREQUEST_GET_STATUS = 0,
    BREQUEST_CLEAR_FEATURE = 1,
    BREQUEST_SET_FEATURE = 3,
    BREQUEST_SET_ADDRESS = 5,
    BREQUEST_GET_DESCRIPTOR = 6,
    BREQUEST_SET_DESCRIPTOR = 7,
    BREQUEST_GET_CONFIGURATION = 8,
    BREQUEST_SET_CONFIGURATION = 9,
    BREQUEST_GET_INTERFACE = 10,
    BREQUEST_SET_INTERFACE = 11,
    BREQUEST_SYNCH_FRAME = 12,
};

enum bDescriptorType : uint8_t {
    DESCRIPTOR_TYPE_DEVICE = 1,
    DESCRIPTOR_TYPE_CONFIGURATION = 2,
    DESCRIPTOR_TYPE_STRING = 3,
    DESCRIPTOR_TYPE_INTERFACE = 4,
    DESCRIPTOR_TYPE_ENDPOINT = 5,
    DESCRIPTOR_TYPE_DEVICE_QUALIFIER = 6,
};

struct setup_data {
    uint8_t bmRequestType;
    enum bRequest bRequest;
    uint16_t wValue;
    uint16_t wIndex;
    uint16_t wLength;
};

struct bConfiguration {
    uint8_t bLength;
    enum bDescriptorType bDescriptorType;
    uint16_t wTotalLength;
    uint8_t bNumInterfaces;
    uint8_t bConfigurationValue;
    uint8_t iConfiguration;
    uint8_t bmAttributes;
    uint8_t bMaxPower;
};

enum token {
    TOKEN_OUT = 0b00,
    TOKEN_IN = 0b10,
    TOKEN_SETUP = 0b11,
};

enum handshake {
    HANDSHAKE_ACK = 0b00,
    HANDSHAKE_NAK = 0b10,
    HANDSHAKE_STALL = 0b11,
};

extern volatile uint8_t usb_data_buffer[1023];

/* bits 0-9: length of data in bytes
 * bits 10-16: address
 * bits 17-20: endpoint
 * bits 21-22: when receiving an interrupt:
 *                 00 for OUT
 *                 10 for IN
 *                 11 for SETUP
 *
 *             when writing the handshake to send:
 *                 00 for ACK
 *                 10 for NAK
 *                 11 for STALL
 *
 *             (the top two bits of the PID)
 * bit 23: when writing, 1 to ignore the transaction
 *         and 0 to respond (either with handshake or data)
 *             
 * writing to this signals to the gateware to continue
 */
extern volatile uint32_t usb_control;

static enum control_transfer_state {
    CONTROL_TRANSFER_STATE_NONE,
    CONTROL_TRANSFER_STATE_IN,
    CONTROL_TRANSFER_STATE_OUT,
    CONTROL_TRANSFER_STATE_SET_ADDRESS,
} control_transfer_state;

static bool has_pending_device_address = false;
static uint8_t pending_device_address;

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

struct data_response {
    bool ignore;
    enum handshake handshake;
};

static struct data_response handle_setup_transaction(uint16_t data_length) {
    if (data_length != 8) {
        simulation_print("got bad number of bytes for setup transaction");
        return (struct data_response) { true, 0 };
    }

    struct setup_data* setup_data = (struct setup_data*) usb_data_buffer;

    control_transfer_state = (setup_data->bmRequestType & (1 << 7))
            ? CONTROL_TRANSFER_STATE_IN
            : CONTROL_TRANSFER_STATE_OUT;

    switch (setup_data->bRequest) {
        case BREQUEST_SET_ADDRESS:
            pending_device_address = setup_data->wValue;
            has_pending_device_address = true;
            simulation_print("got set address packet");
            return (struct data_response) { false, HANDSHAKE_ACK };
        case BREQUEST_GET_CONFIGURATION:
            break;
    }

    control_transfer_state = CONTROL_TRANSFER_STATE_NONE;
    return (struct data_response) { true, 0 };
}

static struct data_response handle_out_transaction(uint16_t data_length) {
    return (struct data_response) { true, 0 };
}

// returns the number of bytes to send from usb_data_buffer
static uint16_t handle_in_transaction() {
    simulation_print("handle_in_transaction");
    if (control_transfer_state == CONTROL_TRANSFER_STATE_OUT) {
        // this is the status stage of the control transfer

        // needed because setting the address needs to be delayed until the status stage
        if (has_pending_device_address) {
            device_address = pending_device_address;
            has_pending_device_address = false;
        }

        control_transfer_state = CONTROL_TRANSFER_STATE_NONE;
        return 0;
    }

    return 0;
}

/* an usb external interrupt is triggered when receiving the data packet of an OUT transaction
 * and the token packet of an IN transaction
 *
 * in both, usb_control contains the address, endpoint, and token type
 *
 * in an OUT transaction:
 *     usb_control contains the length of the data section
 *     usb_data_buffer contains the data
 *     any write to usb_control clears the interrupt, signals to
 *         the gateware it now owns the data buffer, and causes the gateware
 *         to send a handshake of the type specified by usb_control
 *
 * in an IN transaction:
 *     any write to usb_control clears the interrupt and causes the
 *         gateware to send the numbers of bytes specified by usb_control
 *        in usb_data_buffer in a data packet
 */
#define USB_CONTROL_IGNORE (1 << 23)

static uint32_t make_usb_response(const uint32_t usb_control_copy) {
    if (((usb_control_copy >> 10) & 0x7f) != device_address) {
        simulation_print("ignoring due to address");
        return USB_CONTROL_IGNORE;
    }

    const unsigned int token = usb_control_copy >> 21 & 0b11;
    if (token == TOKEN_SETUP || token == TOKEN_OUT) {
        const uint16_t data_length = usb_control_copy & 0x3ff;
        const struct data_response data_response = token == TOKEN_SETUP
                ? handle_setup_transaction(data_length)
                : handle_out_transaction(data_length);
        if (data_response.ignore) {
            return USB_CONTROL_IGNORE;
        } else {
            return data_response.handshake << 21;
        }
    } else if (token == TOKEN_IN) {
        return handle_in_transaction();
    } else {
        simulation_print("invalid token bits");
        return USB_CONTROL_IGNORE;
    }
}

void handle_usb_transaction() {
    usb_control = make_usb_response(usb_control);
}
