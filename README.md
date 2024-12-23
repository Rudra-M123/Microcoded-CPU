# Microcoded 8-Bit CPU
The *.VHDL* and *.MIF* files, as well as the `g104_lab7_final_ver.zip`, construct an 8-bit CPU. This CPU contains two general-purpose registers (R0 and R1), a Stack Pointer (SP), Program Counter (PC), Memory Address Register (MAR), a Memory Data Register (MDR), and a Z-flag (Z). Designed for the Altera DE2 FPGA Board, this system takes in SW0 as a clock pausing input, but is otherwise self-run. The systems outputs to all the seven-segment displays, LEDs, and the LCD screen. The LCD displays MAR, MDR, R0, and R1. The seven-segment displays produce PC, SP, IR, and Z (from left to right with HEX1 unprogrammed). The red LEDs displays the majority of the control signals from the microcode, while the green LEDs produce the next address as seen on the same line of the microcode (`lab7_urom.mif`). Finally, LEDG8 prints the MAP signal for the user to see. Using all these outputs, the user is effectively	able to see and trace the dataflow in each step of the fetch-decode-execute cycle when running their test programs.

## How to Run
Currently there are two ways to run this program:
### First Option
The easiest way is to use the zip file. Please note this will only work if you have an Altera DE2 Board as the pin assignments are declared exclusively for that. If this is your situation, just open the project, synthesize the board and run!
### Second Option
1) Make a project in the FPGA synthesis software of your choice containing all the *.VHD* and *.MIF* files. Note that `lab7_final.vhd` will be the top-level file.
2) Assign pins according to your board. Note that LCD-related pins are given according to those for the Hitachi HD44780-family LCD screen controllers.
3) Synthesize and run!

**Note:** Once the program is ran, the FPGA will run the program loaded in `lab7_uram.mif`! Please use the below ISA in order to learn what instructions are available to use in your programs.

## Instruction Set Architecture
| Instruction | Instruction Code | Operation                                    |
|-------------|------------------|----------------------------------------------|
| NOP         | 00000000         | No operation                                |
| LOADI Rn, X  | 0001000n x       | Rn ← X                                      |
| LOAD Rn, X   | 0010000n x       | Rn ← M[X]                                   |
| STORE X, Rm  | 0011000m x       | M[X] ← Rm                                   |
| MOVE Rn, Rm  | 0100000n         | Rn ← Rm, m ≠ n                              |
| ADD Rn, Rm   | 0101000n         | Rn ← Rn+Rm, m ≠ n                           |
| XOR Rn, Rm   | 0110000n         | Rn ← Rn xor Rm, m ≠ n                       |
| TESTNZ Rm   | 0111000m         | Z ← not V, V = OR of the bits of Rm         |
| TESTZ Rm    | 1000000m         | Z ← V, V = OR of the bits of Rm             |
| JUMP X      | 10010000 x       | PC ← X                                      |
| JUMPZ X     | 10100000 x       | If (Z = 1) then PC ← X                      |
| LOADSP X    | 10110000 x       | SP ← X                                      |
| PEEP Rn     | 1100000n         | Rn ← M[SP]                                  |
| CALL X      | 11010000 x       | M[--SP] ← PC, PC ← X                        |
| RETURN      | 11100000         | PC ← M[SP++]                                |
| HALT        | 11110000         | PC ← 0, stop microsequencer                 |

**Note:**  
- `x` = 8-bit data or address, depending on context.  
- `m`, `n` = 0 or 1, but always m ≠ n. This bit determines which register to use.
