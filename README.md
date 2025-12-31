# mini-RISC

mini-RISC is a simple, educational Reduced Instruction Set Computer (RISC) processor
designed to demonstrate fundamental concepts of computer architecture and digital
design.

This project is intended for academic learning and experimentation, particularly
for understanding instruction execution, datapath design, and control logic.

---

## 🔧 Features

- Simple RISC-style instruction set
- Register file with multiple general-purpose registers
- Arithmetic and Logic Unit (ALU)
- Instruction Fetch, Decode, Execute flow
- Basic control logic
- Designed using Verilog HDL
- Simulation-ready with testbench support

---

## Repository Structure

mini-RISC/
├── rtl/ # Verilog RTL source files
├── sim/ # Testbench files
├── report/ # Simulation outputs (VCD, logs)
├── synth/ # Synthesis scripts and reports
├── docs/ # Architecture diagrams and documentation
└── README.md


---

## Getting Started

### Prerequisites
- Verilog simulator (Icarus Verilog / Verilator / ModelSim)
- GTKWave (for waveform viewing)

### Simulation Example
```bash
iverilog -o mini_risc rtl/*.v sim/*.v
vvp mini_risc
gtkwave mini_risc.vcd


