# NoC-Based Multi-Core RISC-V SoC

A SystemVerilog RTL project implementing and evaluating a multi-core RISC-V subsystem connected through a mesh Network-on-Chip (NoC).

## Overview

This project explores on-chip communication between multiple processing cores using packet-based routing, router arbitration, buffering, and a shared-memory fabric. The design is verified through simulation and evaluated using performance benchmarks and generic logic synthesis.

## Key Features

- 2×2 mesh Network-on-Chip
- Router input buffering and output arbitration
- Round-robin arbitration optimization
- Contention handling and packet forwarding
- Multi-core RISC-V subsystem integration
- Shared-memory fabric and memory service
- Latency and throughput benchmarks
- Automated simulation regression
- Generic Yosys synthesis comparison

## Architecture

The system integrates processing cores, mesh routers, and a memory subsystem. Routers forward packets between nodes and arbitrate for shared output resources.

```text
+----------+       +----------+
|  Core 0  |-------|  Core 1  |
+----------+       +----------+
     |                   |
     |      Mesh NoC     |
     |                   |
+----------+       +----------+
|  Core 2  |-------|  Core 3  |
+----------+       +----------+
          |
   Shared Memory Fabric
```

This is a conceptual overview; consult the RTL for the exact connectivity.

## Tools

- SystemVerilog
- Icarus Verilog
- Verilator
- GTKWave
- Yosys
- PowerShell and Git

## Verification

Run the regression suite from the repository root:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\run_regression.ps1
```

The suite covers mesh operation, contention, memory-fabric integration, multi-core subsystem integration, latency, and throughput.

The latest previously recorded regression result was **7/7 tests passing**. Run the suite again before treating this as the final verification result.

## Recorded Performance Results

For a simulated workload with three sources sending 20 packets each to one destination:

| Metric | Result |
|---|---:|
| Packets accepted | 60 |
| Packets delivered | 60 |
| Packets lost | 0 |
| Duplicate packets | 0 |
| Minimum latency | 2 cycles |
| Maximum latency | 42 cycles |
| Average latency | 21.42 cycles |
| Measured throughput | 0.9677 packets/cycle |

These measurements apply to the tested traffic pattern and simulation configuration. They do not represent universal peak performance.

## Generic Synthesis Comparison

Recorded Yosys generic synthesis results before and after RTL optimization:

| Metric | Cell count |
|---|---:|
| Baseline | 409,529 |
| Optimized | 403,976 |
| Reduction | 5,553 (approximately 1.36%) |

These are generic synthesis cell counts, not physical standard-cell area. Technology-mapped area, routed timing, power, and physical-design results have not been established.

## Repository Structure

- `rtl/` — synthesizable RTL modules
- `tb/` — simulation testbenches
- `scripts/` — regression and utility scripts
- `sim/` — simulation outputs (normally excluded from Git)
- `synth/` — generic synthesis logs and netlists
- `constraints/` — design constraints
- `docs/` — project documentation

## Limitations and Future Work

The current scope focuses on RTL implementation, simulation-based verification, generic synthesis, and traffic benchmarks. Future work includes reliable standard-cell mapping, static timing analysis, physical implementation, and broader scalability experiments.

## Author

Developed as a hardware-design project focused on computer architecture, SystemVerilog RTL, on-chip interconnects, verification, and synthesis optimization.
