#include "cpulib.h"
#include <assert.h>
#include <string.h>

static int min(int x, int y) {
    return x < y ? x : y;
}

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
    BREQUEST_CUSTOM_OUT = 13,
    BREQUEST_CUSTOM_IN = 14,
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

struct device_descriptor {
    uint8_t bLength;
    enum bDescriptorType bDescriptorType;
    uint16_t bcdUSB;
    uint8_t bDeviceClass;
    uint8_t bDeviceSubClass;
    uint8_t bDeviceProtocol;
    uint8_t bMaxPacketSize0;
    uint16_t idVendor;
    uint16_t idProduct;
    uint16_t bcdDevice;
    uint8_t iManufacturer;
    uint8_t iProduct;
    uint8_t iSerialNumber;
    uint8_t bNumConfigurations;
};
// can't use sizeof because it includes padding at the end
#define DEVICE_DESCRIPTOR_SIZE 18

struct configuration_descriptor {
    uint8_t bLength;
    enum bDescriptorType bDescriptorType;
    uint16_t wTotalLength;
    uint8_t bNumInterfaces;
    uint8_t bConfigurationValue;
    uint8_t iConfiguration;
    uint8_t bmAttributes;
    uint8_t bMaxPower;
};
#define CONFIGURATION_DESCRIPTOR_SIZE 9

struct interface_descriptor {
    uint8_t bLength;
    enum bDescriptorType bDescriptorType;
    uint8_t bInterfaceNumber;
    uint8_t bAlternateSetting;
    uint8_t bNumEndpoints;
    uint8_t bInterfaceClass;
    uint8_t bInterfaceSubClass;
    uint8_t bInterfaceProtocol;
    uint8_t iInterface;
};
#define INTERFACE_DESCRIPTOR_SIZE 9

enum transaction {
    TRANSACTION_OUT = 0b00,
    TRANSACTION_IN = 0b10,
    TRANSACTION_SETUP = 0b11,
};

enum handshake {
    HANDSHAKE_ACK = 0b00,
    HANDSHAKE_NAK = 0b10,
    HANDSHAKE_STALL = 0b11,
};

// maximum data payload size, 64 is the maximum for the
// default control pipe
#define MAX_PACKET_SIZE 64

#define USB_DATA_BUFFER_LENGTH 1023
extern uint8_t usb_data_buffer[USB_DATA_BUFFER_LENGTH];

/* bits 0-9: length of data in bytes, bidirectional
 * bits 10-11: when receiving an interrupt, an enum transaction that is the transaction that was just done
 *             when writing the response to send, an enum response_type
 * bits 12-15: when receiving an interrupt, endpoint of the received transaction
 *
 * writing to this clear the interrupt and signals the gateware to continue
 */
extern volatile uint16_t usb_control;
// only set by software, used by the gatware to filter transactions to only the specified address
extern volatile uint8_t usb_device_address;

static bool in_control_transfer;
static struct setup_data setup_data;
static uint16_t data_bytes_sent;

static uint8_t bConfigurationValue = 0;

static const struct device_descriptor device_descriptor = {
    .bLength = DEVICE_DESCRIPTOR_SIZE,
    .bDescriptorType = DESCRIPTOR_TYPE_DEVICE,
    .bcdUSB = 0x0200, // indictes usb version 2.0.0
    .bDeviceClass = 0xff, // vendor-specific device class
    .bDeviceSubClass = 0,
    .bDeviceProtocol = 0xff, // vender-specific protocol on a device basis
    .bMaxPacketSize0 = MAX_PACKET_SIZE,
    .idVendor = 0,
    .idProduct = 0,
    .bcdDevice = 0,
    .iManufacturer = 0, // TODO add
    .iProduct = 0, // TODO add
    .iSerialNumber = 0, // TODO add
    .bNumConfigurations = 1,
};

static const struct configuration_descriptor configuration = {
    CONFIGURATION_DESCRIPTOR_SIZE,
    DESCRIPTOR_TYPE_CONFIGURATION,
    CONFIGURATION_DESCRIPTOR_SIZE + INTERFACE_DESCRIPTOR_SIZE,
    1,
    1,
    0,
    0b10000000,
    0 // TODO come up with a real number for this
};

static const struct interface_descriptor interface = {
    .bLength = INTERFACE_DESCRIPTOR_SIZE,
    .bDescriptorType = DESCRIPTOR_TYPE_INTERFACE,
    .bInterfaceNumber = 0,
    .bAlternateSetting = 0,
    .bNumEndpoints = 0,
    .bInterfaceClass = 0xff, // vendor-specific
    .bInterfaceSubClass = 0xff,
    .bInterfaceProtocol = 0xff, //vendor-specific
    .iInterface = 0,
};

struct response {
    enum response_type {
        // tells the gateware there is no data to send and the buffer can be written with new data
        RESPONSE_TYPE_EMPTY = 0b00,
        // tells the gateware to respond with the data in the next IN
        RESPONSE_TYPE_DATA = 0b01,
        // tells the gateware to send a STALL in the next transaction
        RESPONSE_TYPE_STALL = 0b10,
    } type;
    uint16_t data_length; // only defined for RESPONSE_TYPE_EMPTY
};

#define RESPONSE_EMPTY ((struct response){ RESPONSE_TYPE_EMPTY, 0 })
#define RESPONSE_DATA(LENGTH) ((struct response){ RESPONSE_TYPE_DATA, LENGTH })
#define RESPONSE_STALL ((struct response){ RESPONSE_TYPE_STALL, 0 })

#define BULK_READ_BUFFER_LENGTH 64
struct bulk_read_ring_buffer {
    const size_t length;
    atomic_size_t read_index;
    atomic_size_t write_index;
    uint8_t buffer[BULK_READ_BUFFER_LENGTH];
} bulk_read_ring_buffer = {
    BULK_READ_BUFFER_LENGTH,
    0,
    0,
};

static struct response send_device_descriptor() {
    // send device descriptor (only)
    const uint16_t total_transaction_bytes = min(setup_data.wLength, DEVICE_DESCRIPTOR_SIZE);
    assert(data_bytes_sent <= total_transaction_bytes);
    const uint16_t bytes_to_send_this_packet =
        min(total_transaction_bytes - data_bytes_sent, MAX_PACKET_SIZE);

    memcpy(
        usb_data_buffer,
        (const uint8_t*)&device_descriptor + data_bytes_sent,
        bytes_to_send_this_packet
    );
    data_bytes_sent += bytes_to_send_this_packet;
    return RESPONSE_DATA(bytes_to_send_this_packet);
}

static struct response send_configuration() {
    // send configuration and interface descriptors
    const uint16_t total_transaction_bytes = min(setup_data.wLength, configuration.wTotalLength);
    assert(data_bytes_sent <= total_transaction_bytes);
    const uint16_t bytes_to_send_this_packet =
        min(total_transaction_bytes - data_bytes_sent, MAX_PACKET_SIZE);

    const uint16_t configuration_bytes_to_send = data_bytes_sent < CONFIGURATION_DESCRIPTOR_SIZE
        ? min(bytes_to_send_this_packet, CONFIGURATION_DESCRIPTOR_SIZE - data_bytes_sent)
        : 0;
    const uint8_t interface_bytes_to_send = bytes_to_send_this_packet - configuration_bytes_to_send;
    memcpy(
        usb_data_buffer,
        (const uint8_t*)&configuration + data_bytes_sent,
        configuration_bytes_to_send
    );
    memcpy(
        usb_data_buffer + configuration_bytes_to_send,
        (const uint8_t*)&interface + (INTERFACE_DESCRIPTOR_SIZE - interface_bytes_to_send),
        interface_bytes_to_send
    );
    data_bytes_sent += bytes_to_send_this_packet;
    return RESPONSE_DATA(bytes_to_send_this_packet);
}

static struct response send_descriptor() {
    switch (setup_data.wValue >> 8) { // this is the descriptor type
        case DESCRIPTOR_TYPE_DEVICE:
            return send_device_descriptor();
        case DESCRIPTOR_TYPE_CONFIGURATION:
            return send_configuration();
        default:
            return RESPONSE_STALL;
    }
}

static struct response
make_default_control_endpoint_response(enum transaction transaction, uint16_t data_length) {
    if (transaction == TRANSACTION_SETUP) {
        in_control_transfer = true;
        // TODO consider whether I need all the data
        setup_data = *(struct setup_data*)usb_data_buffer;
    }

    switch (setup_data.bRequest) {
        // control write transfers
        case BREQUEST_CLEAR_FEATURE: {
            return RESPONSE_STALL;
        }
        case BREQUEST_SET_ADDRESS:
            switch (transaction) {
                case TRANSACTION_SETUP:
                    return RESPONSE_DATA(0);
                case TRANSACTION_OUT:
                    return RESPONSE_STALL;
                case TRANSACTION_IN:
                    usb_device_address = setup_data.wValue;
                    in_control_transfer = false;
                    return RESPONSE_EMPTY;
            }
        case BREQUEST_SET_CONFIGURATION:
            switch (transaction) {
                case TRANSACTION_SETUP:
                    if (setup_data.wValue <= 1) {
                        bConfigurationValue = setup_data.wValue;
                        return RESPONSE_DATA(0);
                    } else {
                        return RESPONSE_STALL;
                    }
                case TRANSACTION_OUT:
                    return RESPONSE_STALL;
                case TRANSACTION_IN:
                    in_control_transfer = false;
                    return RESPONSE_EMPTY;
            }
        case BREQUEST_SET_DESCRIPTOR:
            return RESPONSE_STALL;
        case BREQUEST_SET_FEATURE:
            return RESPONSE_STALL;
        case BREQUEST_SET_INTERFACE:
            return RESPONSE_STALL;

        // control read transfers
        case BREQUEST_GET_CONFIGURATION:
            switch (transaction) {
                case TRANSACTION_SETUP:
                    usb_data_buffer[0] = bConfigurationValue;
                    return RESPONSE_DATA(1);
                case TRANSACTION_IN:
                    return RESPONSE_EMPTY;
                case TRANSACTION_OUT:
                    in_control_transfer = false;
                    return RESPONSE_EMPTY;
            }
        case BREQUEST_GET_DESCRIPTOR:
            switch (transaction) {
                case TRANSACTION_SETUP:
                    data_bytes_sent = 0;
                    return send_descriptor();
                case TRANSACTION_IN:
                    return send_descriptor();
                case TRANSACTION_OUT:
                    in_control_transfer = false;
                    return RESPONSE_EMPTY;
            }
        case BREQUEST_GET_INTERFACE:
            return RESPONSE_STALL;
        case BREQUEST_GET_STATUS:
            switch (transaction) {
                case TRANSACTION_SETUP:
                    switch (setup_data.bmRequestType & 0b11) {
                        case 0b00: // device
                            usb_data_buffer[0] = 0;
                            usb_data_buffer[1] = 0;
                            return RESPONSE_DATA(2);
                        case 0b01: // interface
                            usb_data_buffer[0] = 0;
                            usb_data_buffer[1] = 0;
                            return RESPONSE_DATA(2);
                        case 0b10: // endpoint
                            usb_data_buffer[0] = 0;
                            usb_data_buffer[1] = 0;
                            return RESPONSE_DATA(2);
                        default:
                            return RESPONSE_STALL;
                    }
                case TRANSACTION_IN:
                    return RESPONSE_EMPTY;
                case TRANSACTION_OUT:
                    in_control_transfer = false;
                    return RESPONSE_EMPTY;
            }
        case BREQUEST_SYNCH_FRAME:
            return RESPONSE_STALL;

        // custom transfers
        case BREQUEST_CUSTOM_OUT:
            switch (transaction) {
                case TRANSACTION_SETUP:
                    return RESPONSE_EMPTY;
                case TRANSACTION_OUT:
                    const size_t bytes_written = ring_buffer_write(
                        (struct ring_buffer*)&bulk_read_ring_buffer,
                        usb_data_buffer,
                        data_length
                    );
                    if (bytes_written == data_length) {
                        return RESPONSE_DATA(0);
                    } else {
                        return RESPONSE_STALL;
                    }
                case TRANSACTION_IN:
                    in_control_transfer = false;
                    return RESPONSE_EMPTY;
            }

        default:
            return RESPONSE_STALL;
    }
}

// a usb external interrupt is triggered when a transaction is completed
static struct response make_usb_response(const uint32_t usb_control_copy) {
    const enum transaction transaction = usb_control_copy >> 10 & 0b11;
    assert(transaction != 0b01);
    const uint16_t data_length = usb_control_copy & 0x3ff;
    assert(data_length <= USB_DATA_BUFFER_LENGTH);

    uint8_t endpoint = (usb_control_copy >> 12) & 0xf;
    // at one point I had another endpoint so keep this as a switch if I add an endpoint later
    switch (endpoint) {
        case 0:
            return make_default_control_endpoint_response(transaction, data_length);
        default:
            return RESPONSE_STALL;
    }
}

void handle_usb_transaction() {
    const struct response response = make_usb_response(usb_control);
    uint32_t result_usb_control = response.type << 10;
    if (response.type == RESPONSE_TYPE_DATA) {
        result_usb_control |= response.data_length & 0x3ff;
    }

    // barrier to make sure the volatile write is after all writes
    // to usb_data_buffer
    __asm__ volatile ("" : : : "memory");
    
    usb_control = result_usb_control;
}
