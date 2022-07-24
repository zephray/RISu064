# Bus Interconnect

The project uses 2 types of simple buses for on-chip and off-chip communication: KLink (on-chip) and MLink (off-chip). Both buses can be characterized:

- Pipelined, up to 1 transfer per cycle
- Optional bursting
- Directed, point-to-point connection from A-side (requestor) to B-side (responder)

See following for detailed signal definition

## KLink

KLink is the on-chip interconnect used through out the system.

It consists of a request port and a response port, with the following signals:

Request port:

- ```[AW-1:0] req_addr```: Byte address
- ```req_wen```: Indicate the request is a write request
- ```[DW-1:0] req_wdata```: Data to be written. Valid only if wen is 1
- ```[DW/8-1:0] req_wmask```: Data mask, 1 means byte lane valid. Valid only is wen is 1
- ```[SW-1:0] req_size```: (optional) Transfer size, in 2^n bytes
- ```[IW-1:0] req_srcid```: (optional) Source ID, used for routing responses
- ```req_valid```: Indicate request on port is valid this cycle
- ```req_ready```: B-side is able to receive request this cycle

Respond port:

- ```[DW-1:0] resp_rdata```: Requested read data
- ```resp_ren```: Indicate the response is a read response
- ```[SW-1:0] resp_size```: (optional) Transfer size, in 2^n bytes
- ```[IW-1:0] resp_dstid```: (optional) Destination ID, used for routing responses
- ```resp_valid```: Response is valid this cycle
- ```resp_ready```: (optional) A-side is able to receive response this cycle

Notes:

- Address should always be naturally aligned to bus width boundary. Byte masking is used to mask active byte lanes.
- Byte masking is required to mask only single byte/ half word/ word.
- Burst support is optional. If supported, req_size could be used to indicate the burst size.
- Burst should not cross 4KB boundary.
- During burst transfer, byte masking is ignored. However, buses supports burst should still support byte masking in non-burst transfers.
- Burst length is specified with 2^req_size. For example, req_size of 5 means 2^5 = 32 bytes burst, on a 64-bit bus this translates to 4 beats.
- Burst length less than bus width should also be supposed, knowing it would have have the same effect as having burst length same as bus width. (Data placement governed by byte masking and address aligning rules)
- resp_ready is optional:
    - B-side without resp_valid: does not support back pressure from A-side. Must connect to A-side without resp_valid.
    - A-side without resp_valid: response is always accepted. Could connect to B-side with or without resp_valid.
- Requests and responses from multiple devices may be interleaved on the bus if srcid and dstid field are supported.
- Size is typically configured to be 3 bits (up to 2^8= 256 bytes burst), and ID is typically configured to be 5 bits (up to 32 masters)
- A-side that's only expecting to receive its own messages may omit req_srcid, resp_dstid and resp_size (if burst is supported). B-side should route req_srcid and req_size back with resp_dstid and resp_size, to be processed by bus interconnect.

## MLink

MLink is the off-chip interconnect to connect to next level of memory (L2/ L3/ MMIO).

### Pinout

It consists of the following pins:

- ```clk```: Clock
- ```clkn```: (Optional) Inverted clock
- ```abr```: A-side bus request
- ```bbr```: B-side bus request
- ```[W-1:0] data```: Bidirectional data bus

Note: When wiring, do not swap abr and bbr.

### Request (A->B)

The request header is always 64bit, encoded as following:

- Bit 63: Fixed 0
- Bit 62:60: Opcode (see below)
- Bit 59:56: Parameter (see below)
- Bit 55:53: 3-bit Burst size (2^n)
- Bit 52:48: 5-bit Source ID
- Bit 47:0: 48-bit physical address

The data are sent in beats, with minimum size equals to data bus width. Byte masking is not supported. As a result, no address aligning is required. The request data width, if narrower than data bus, should be placed with LSB aligned.

Valid opcodes:

- 3'd0: Invalid, disgard this beat
- 3'd1: Data
- 3'd2: Dataless (read request or write ack)
- 3'd3: Atomic operation (RMW)
- 3'd4-3'd7: Reserved

For read/ write access:

Parameter bit 3: This is an instruction access (0) / data access (1)
Parameter bit 2: This is an cached access (0) / uncached access (1)
Parameter bit 1: This is an normal access (0) / strongly-ordered access (1)
Parameter bit 0: Reserved

For atomic access:

Paramater indicates the operation:

- 4'd0: SWAP
- 4'd1: MIN
- 4'd2: MAX
- 4'd3: MINU
- 4'd4: MAXU
- 4'd5: ADD
- 4'd6: AND
- 4'd7: OR
- 4'd8: XOR
- 4'd9-15: Reserved

### Response (B->A)

The response header is always 16bit, encoded as following:

- Bit 15: Fixed 1
- Bit 14:12: Opcode (see below)
- Bit 11:8: Parameter (see below)
- Bit 7:5: 3-bit Burst size (2^n)
- Bit 4:0: 5-bit Destination ID

The response header always exclusively take at least 1 beat, even if bus is wider. In case the bus is wider, the header should be aligned to MSB. The PHY may further expand it, for example if the MAC runs at 64bit beat size, PHY should extend it in case the bus is narrower.

One request should always correspond to one respond, though the length would likely differ.

Note write acknowledge means at least all future reads from any master from the address will return the new value. This could either mean the data has arrived at DRAM, or it has been cached by system level cache, or it's in the write-queue with W-to-R bypassing support.

Note current RISu implement doesn't utilize all features provided by MLink.

### Bus Arbitration

Because the data line is shared, both sides need to negotiate which side could use the bus. Each side has a bus request pin, called ABR and BBR.

By default, both should be low, meaning no one is owning the bus, and the data bus should be High-Z.

When one side wants to use the bus, it should set its own BR pin high for one cycle. If no collision happens (the other side's BR pin does't go high), it owns the bus as long as it keeps the BR pin high. Once it sets the BR pin low, the bus is released, and other side could take over the bus. If collision happened, the following rule should be observed:

- Rule 1: The side owned bus in the previous transfer should give up the ownership in case of an collision.
- Rule 2: If it's fresh out of reset where no previous transfer has occurred, A-side device takes precedence.
- Rule 3: Once a side has acquired the bus, it may pause an ongoing burst by setting BR pin low. The burst is a non-interruptable process, the other side doesn't get right of the bus even if the current burst is paused.

Additionally:

- Device may choose to set BR high even if other side is using the bus. In such as it will take over the bus once the other side finishes the current transfer.
- Rule 1 does not prevent one side from owning the bus for multiple transactions as long as there is no collision
- To resolve collision when out of reset, each side should be assigned as A and B side. (For pin assignment purpose as well) However, the bus itself does not enforce roles during operation. B side may choose to send request to A side and A side could respond to B side if both sides are dual-role.