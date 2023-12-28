# OpenSecurityTraining2 Arch1001: Lab RTFM & WTFI!

## Challenge Description
In this challenge we were asked to write raw bytecode to create the following assembly sequence:
```asm
mov eax, 0xAABBCCDD
sahf
jz mylabel
and eax, 0x31337
mylabel:
ret
```
## Read the F*n Intel Manual
In the Intel® 64 and IA-32 Architectures Software Developer’s Manual[^1], the object code (opcode) for each assembly instruction is provided. This opcode serves as the hexadecimal representation of the corresponding human-readable assembly instruction, which the processor interprets and executes. For instance, the human-readable assembly representation of `RET` is represented by the opcode `C3`.

## `mov eax, 0xAABBCCDD`
To begin, let's encode the instruction `mov eax, 0xAABBCCDD` into its corresponding machine code.
In the Intel manual under the `MOV` instruction (page 1211), various opcodes are listed, and the one that matches the `mov eax, 0xAABBCCDD` operation is `B8+ rd id`. Here's why: `EAX` is a doubleword general-purpose register, denoted as `r32` in instructions statements. The constant value `0xAABBCCDD` is directly specified in the instruction itself, known as an immediate operand (imm). Consequently, we require an instruction that moves a 4-byte immediate value (`0xAABBCCDD`) into an `r32`. This instruction is identified as `MOV r32, imm32`, or `B8+ rd id` in opcode.

![MOV](https://github.com/theokwebb/my-writeups/blob/main/LabRTFM%26WTFI/MOV.png)

To write this in hexadecimal opcode you use `db` (define byte) and `dd` (define dword) directives to declare the values:
```asm
db 0B8h
dd 0AABBCCDDh
```
`dd` is used because `0AABBCCDDh` is a 32-bit/4 byte value and not a byte (`db`). `MASM` also doesn't like immediates or raw bytes that start with an alphabet character, so the values must be preceded by a zero.

## `SAHF`
So, according to the Intel manual (page 1764), the SAHF instruction “loads SF, ZF, AF, PF, and CF from AH into EFLAGS register.” and is represented by `9E` in opcode. Therefore, we can simply write:
```asm
db 09Eh
```
`0xAABBCCDD` was moved into `EAX`, so `AH` is `0xCC` (BIN = 1100 1100). `AH`’s bit values (1100 1100) are loaded into the EFLAGS register. Therefore, as per the EFLAGS register below, `PF` (Parity), `ZF` (Zero) and `SF` (Sign) are set: 

![EFLAGS](https://github.com/theokwebb/my-writeups/blob/main/LabRTFM%26WTFI/EFLAGS.png)

I.e., bit 2 of 11001100 is 1, so its Parity Flag is set.

You can confirm this by looking at the Disassembly after the `SAHF` instruction executes:
```asm
OV = 0 UP = 0 EI = 1 PL = 1 ZR = 1 AC = 0 PE = 1 CY = 0
```
PL = Sign Flag. ZR = Zero Flag. PE = Parity Flag. 

## `jz mylabel`
`jz mylabel` needs to be converted to opcode. However, since we haven’t written the `AND` instruction, we don’t know how far it would need to jump to `mylabel`. Therefore, let’s write the `AND` instruction first so it’s easier to calculate.   

## `and eax, 0x31337`
Much like `MOV`, we need an `r32` for `EAX` and immediate of at least 3 bytes. Such instruction can be found on page 655 in the manual. `AND EAX, imm32` matches this, and its opcode is `25`. So, we write:
```asm
db 025h
dd 031337h
mylabel:
```
So, we also add `mylabel:` which serves as a reference point for the jump instruction. As per the Intel manual, such labels are always followed by a colon.

## `jz mylabel`
Now, with the `AND` opcode determined, the jump distance to `mylabel` is easy to calculate: one byte for `db` and four bytes for `dd`, totalling 5 bytes. Now, to search the manual for a `JZ` instruction which jumps 5 bytes.

There are several `JZ`’s, but only one which matches our target jump distance range: `JZ rel8` (page 1107):

![JZ](https://github.com/theokwebb/my-writeups/blob/main/LabRTFM%26WTFI/JZ.png)

`rel8` (relative offset) is a signed 8-bit immediate value which is added to the `RIP` register's address if `ZF = 1`. This is so it can calculate the target jump address. In summary, if the `ZF` is 1, a 1-byte value provided by us is added to the next instruction address (`RIP`), so it can jump to the `mylabel` address.

So, before the `AND` opcode we write:
```asm
db 074h
db 05h
```
`74` is for the `JZ rel8` instruction and `db 05h` is for the bytes to jump past the `AND` instruction.

In our case, `ZF` is set by `SAHF`, so it will jump.

## `ret`
Lastly, `RET` (page 1731) is simply replaced by its opcode `C3` to complete the assembly sequence:
```asm
db 0B8h
dd 0AABBCCDDh
db 09Eh
db 074h
db 05h
db 025h
dd 031337h
mylabel:
db 0C3h
```
Thank you to Xeno at [OpenSecurityTraining2](https://ost2.fyi) for this enjoyable lab and incredible course.

### References:
[^1]: https://ost2images.s3.amazonaws.com/Arch2001/CourseMaterials/325462-sdm-vol-1-2abcd-3abcd.pdf
