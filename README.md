# Elevator_FSM

# FPGA-Based Elevator Control System

An FPGA-based elevator controller implemented in **Verilog HDL** and designed for the **Xilinx ZedBoard**. The project models an 8-floor elevator system using a finite state machine (FSM), floor request handling, request queuing, and timer-based control logic.

## Features

- **8-Floor Control:** Supports floors 0 through 7.
- **Finite State Machine (FSM):** Implements Idle, Moving Up, Moving Down, and Door Open states.
- **Floor Request Detection:** Detects switch transitions from OFF to ON.
- **Request Management:** Uses a pending-request bitmap and a priority encoder to select floor requests.
- **FIFO Queue:** Stores selected floor requests for sequential servicing.
- **Timer-Based Movement:** Controls floor transitions using a configurable movement timer.
- **Automatic Return:** Returns the elevator to Floor 0 after a configurable idle timeout.
- **Door Control:** Keeps the door open for a configurable number of enabled cycles.
- **Overload Indication:** Activates an LED when the request queue reaches the configured threshold.
- **Clock Enable Generation:** Generates a periodic enable pulse to control the FSM's operating rate.

## Hardware and Tools

- **HDL:** Verilog
- **FPGA Board:** Xilinx ZedBoard
- **Design and Synthesis:** Xilinx Vivado
- **Simulation:** Icarus Verilog / Vivado Simulator

## System Architecture

The design consists of three main modules:

### 1. Clock Divider — `my_clock_divider`

Generates a periodic clock-enable pulse from the input FPGA clock. The FSM uses this pulse to update its registers at a slower rate while retaining the original clock.

### 2. Elevator FSM — `elevator_fsm`

Implements the elevator's control logic and manages:

- Current floor and destination floor
- Movement direction
- Door operation
- Floor request processing
- Request queue and pointers
- Idle timeout and overload timers

### 3. Top-Level Module — `zedboard_elevator_top`

Connects the clock divider, elevator FSM, physical switches, reset button, and LEDs on the FPGA board.

## FSM States

| State | Encoding | Description |
|---|---|---|
| IDLE | `00` | Waits for a valid destination or pending request |
| MOVING UP | `01` | Moves the elevator toward a higher-numbered floor |
| MOVING DOWN | `10` | Moves the elevator toward a lower-numbered floor |
| DOOR OPEN | `11` | Opens the door when the destination is reached |

### State Transition Overview

- **IDLE → MOVING UP:** Destination floor is above the current floor.
- **IDLE → MOVING DOWN:** Destination floor is below the current floor.
- **IDLE → DOOR OPEN:** Destination is the current floor.
- **MOVING UP/DOWN → DOOR OPEN:** The elevator reaches its destination.
- **DOOR OPEN → IDLE:** The door timer expires.

## Floor Request Processing

Floor requests are represented by an 8-bit vector, where each bit corresponds to a floor.

For example:

```verilog
floor_request = 8'b00001010;
```

This represents requests for Floors 1 and 3.

The request-processing logic:

1. Combines new requests with previously pending requests using bitwise OR.
2. Uses a priority encoder to select the lowest-numbered pending floor.
3. Clears the selected request bit.
4. Adds the selected floor to the request queue when queue capacity permits.
5. Uses an overload timer and LED to indicate that the queue threshold has been reached.

**Note:** The priority encoder selects requests by floor number, not by arrival time. Consequently, simultaneous requests are not necessarily handled in first-come-first-served order.

## Request Queue

The controller uses a memory array to store destination floors:

```verilog
reg [3:0] queue [0:QUEUE_DEPTH-1];
```

The queue uses:

- `head`: Points to the next queued request to be serviced.
- `tail`: Points to the next insertion position.
- `count`: Tracks the number of queued requests.

A request is enqueued when a selected floor is accepted. A request is dequeued when the controller transitions into the door-open state.

> **Implementation note:** The current implementation requires pointer wrap-around logic for a robust circular FIFO. Queue capacity and overload behavior should also be verified against the intended design requirements.

## FPGA Input and Output Mapping

### Inputs

| Signal | Width | Description |
|---|---:|---|
| `clk` | 1 bit | FPGA system clock |
| `rst_btn` | 1 bit | Active-high asynchronous reset |
| `switches` | 8 bits | Floor request switches |

### Outputs

| LED Signal | Description |
|---|---|
| `leds[3:0]` | Current floor in binary |
| `leds[5:4]` | Direction: `00` Idle, `01` Up, `10` Down |
| `leds[6]` | Door-open indicator |
| `leds[7]` | Overload indicator |

The floor is displayed in binary. For example, Floor 5 is represented by `0101` on `leds[3:0]`.

## Configurable Parameters

| Parameter | Purpose |
|---|---|
| `FLOOR_0` | Lowest floor |
| `FLOOR_7` | Highest floor |
| `DOOR_OPEN_CYCLES` | Door-open duration in enabled cycles |
| `MOVE_CYCLES_PER_FLOOR` | Movement interval per floor |
| `QUEUE_DEPTH` | Declared queue storage depth |
| `IDLE_TIMEOUT_CYCLES` | Idle timeout before returning to Floor 0 |
| `OVERload_led_cycles` | Duration of overload indication |

The effective timing depends on the input clock frequency and the clock-enable generation.

## Getting Started

### 1. Clone the Repository

```bash
git clone <your-repository-url>
cd <your-repository-folder>
```

### 2. Open the Project in Vivado

1. Create or open a Vivado project for the ZedBoard.
2. Add the Verilog source files.
3. Select the correct FPGA part or board configuration.
4. Add the appropriate XDC constraints for the clock, switches, reset button, and LEDs.
5. Run synthesis and implementation.
6. Generate the bitstream and program the FPGA.

### 3. Simulation

The design can be simulated using Vivado Simulator or Icarus Verilog.

For Icarus Verilog, after creating a testbench such as `tb_elevator.v`:

```bash
iverilog -o elevator_sim *.v
vvp elevator_sim
```

Ensure that the source files and testbench are included correctly in the compilation command.

For simulation, reduce the clock-divider and timer parameters so the elevator behavior can be observed quickly.

## Suggested Verification Scenarios

- Reset initializes the controller to Floor 0 and IDLE.
- Requesting a higher floor causes upward movement.
- Requesting a lower floor causes downward movement.
- Requesting the current floor opens the door.
- The door closes after its configured timer expires.
- Multiple pending requests are processed.
- Queue threshold and overload indication behave as expected.
- The elevator returns to Floor 0 after the idle timeout.
- Requests arriving near clock-enable pulses are detected correctly.

## Future Improvements

- Implement circular FIFO pointer wrap-around.
- Correctly handle simultaneous enqueue and dequeue operations.
- Define and verify the intended overload and queue-full behavior.
- Synchronize and debounce physical switch inputs.
- Improve request scheduling to support direction-aware or first-come-first-served service.
- Add self-checking and randomized stress testbenches.
- Perform FPGA timing analysis and hardware validation.

## Learning Outcomes

- FSM design and state-transition logic in Verilog
- Sequential and combinational logic
- Clock-enable generation
- Priority encoding and bitwise request management
- FIFO implementation and queue control
- Timer-based control systems
- FPGA synthesis, simulation, and hardware integration

## Author

Developed as an FPGA-based digital design project using Verilog HDL and the Xilinx ZedBoard.
