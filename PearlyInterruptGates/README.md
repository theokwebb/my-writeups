# Labs: Pearly Interrupt Gates 1 & 2

This writeup covers the Pearly Interrupt Gates lab from Xeno’s [Architecture 2001: x86-64 OS Internals](https://ost2.fyi/Arch2001) course at [OpenSecurityTraining2](https://ost2.fyi).

Xeno made the lab to help deepen students' understanding of interrupt and exception-handling mechanisms.

On question 5 I struggled to understand stack switching and how a target RSP address is found. Therefore, I have also attempted to clearly describe this process with the help of Xeno’s slides and the Intel manual [here](#interrupts).

## Disclaimer

I am new to x86-64 OS Internals, so if there are any mistakes or necessary additions, please let me know on [X](https://twitter.com/theokwebb).

# Part 1 Instructions

#### 1. Use the WinDBG command `dq idtr L10` and hand-parse the first 8 IDT descriptors, according to the Interrupt Descriptor format in the slides.

![Screenshot1](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot1.png)

`dq` = quadwords (8 bytes).

In entry one, the value `00107100` corresponds to bytes `3:0`, `5fe18e00` to bytes `7:4`, `fffff805` to bytes `11:8`, and `00000000` to bytes `15:12` as shown below:

![Screenshot2](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot2.png)

# Part 1 Questions
#### 1. Why is a `dq idtr L10` printing out `8` descriptors, not `16`?

`dq` represents a quadword which is `8` bytes, and an IDT descriptor is `16` bytes, so each descriptor takes up two lines. Therefore, it will only print out `8` descriptors instead of `16` (`L10` is hex, which is `16` in decimal).

#### 2. Which entries (if any) are Interrupt Gates and which are Trap Gates?

~~~
0x00 - 5fe18e00`00107100 00000000`fffff805
0x01 - 5fe18e04`00107180 00000000`fffff805
0x02 - 5fe18e03`00107240 00000000`fffff805
0x03 - 5fe1ee00`001072c0 00000000`fffff805
0x04 - 5fe1ee00`00107340 00000000`fffff805
0x05 - 5fe18e00`001073c0 00000000`fffff805
0x06 - 5fe18e00`00107440 00000000`fffff805
0x07 - 5fe18e00`001074c0 00000000`fffff805
~~~

As illustrated in Figure 6-8, the `type` field is represented by bits `11:8` within bytes `7:4`. For entry `0x00` (`5fe18e00`), the binary representation of bytes `7:4` is as follows:

~~~
0101 1111 1110 0001 1000 1110 0000 0000
~~~

Here, `bits 31:16` define the offset, and bits `11:8` (`1110`) determine the type. The value `1110` indicates an Interrupt Gate, while `1111` would signify a Trap Gate. Therefore, with the type bits set to `0xE` (`1110`) for entry `0x00`, it is as an Interrupt Gate. This suggests that all entries with type bits of `0xE` (`1110`) are Interrupt Gates.

#### 3. What is the target far pointer for each entry?

A logical address (far pointer) is a 16-bit segment selector + 32/64 bit offset. For entry `0x00`, the segment selector is defined by bits `31:16` of bytes `0:3` (`0010`), while the offset within the segment is determined by combining bits `15:0` in bytes `0:3` (`7100`), bits `31:16` in bytes `7:4` (`5fe1`), bits `63:32` in bytes `11:8` (`fffff805`). Therefore, the logical address for entry `0x00` is as follows:

- Segment Selector: `0010`
- Offset: `fffff805 5fe17100`

~~~
0x00 - 5fe18e00`00107100 00000000`fffff805 = 0010 fffff805 5fe17100
0x01 - 5fe18e04`00107180 00000000`fffff805 = 0010 fffff805 5fe17180
0x02 - 5fe18e03`00107240 00000000`fffff805 = 0010 fffff805 5fe17240
0x03 - 5fe1ee00`001072c0 00000000`fffff805 = 0010 fffff805 5fe172c0 
0x04 - 5fe1ee00`00107340 00000000`fffff805 = 0010 fffff805 5fe17340
0x05 - 5fe18e00`001073c0 00000000`fffff805 = 0010 fffff805 5fe173c0
0x06 - 5fe18e00`00107440 00000000`fffff805 = 0010 fffff805 5fe17440
0x07 - 5fe18e00`001074c0 00000000`fffff805 = 0010 fffff805 5fe174c0
~~~

#### 4. Which entries (if any) use the IST?

In the case of bytes `7:4` (`5fe18e00`), bits `2:0` designate the Interrupt Stack Table (IST) index. For entries `0x00`, `0x03`, `0x04`, `0x05`, `0x06`, and `0x07`, these bits are all set to `000`. This means that these entries do not use an IST entry. Instead, they use the traditional TSS entries (highlighted in blue in the below) to determine the appropriate stack for transitioning to rings `R0-2`.

![Screenshot3](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot3.png)

Entry `0x01`’s bits are set to `100`, and entry `0x02`’s bits are set to `011`. These values, `100` for entry `0x01` and `011` for entry `0x02`, specify the IST index that the processor uses to find the stack for the RSP. Therefore, entry `0x01` and entry `0x02` use the IST for stack selection:

![Screenshot4](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot4.png)

#### 5. What is the target RSP address where saved state will be stored for each entry?

The Descriptor Privilege Level (DPL) is determined by bits `14:13` in the highlighted portion of bytes `7:4`:

- 0x00: 5fe1**8**e00 00107100 00000000 fffff805
- 0x01: 5fe1**8**e04 00107180 00000000 fffff805
- 0x02: 5fe1**8**e03 00107240 00000000 fffff805
- 0x03: 5fe1**e**e00 001072c0 00000000 fffff805
- 0x04: 5fe1**e**e00 00107340 00000000 fffff805
- 0x05: 5fe1**8**e00 001073c0 00000000 fffff805
- 0x06: 5fe1**8**e00 00107440 00000000 fffff805
- 0x07: 5fe1**8**e00 001074c0 00000000 fffff805

In binary, `0x8` translates to 1**00**0, and `0xE` translates to 1**11**0.
-	00 (binary) = Ring 0.
-	01 (binary) = Ring 1.
-	10 (binary) = Ring 2.
-	11 (binary) = Ring 3.

This means that those with `0x8` are for `R0`, and those with `0xE` are for `R3`:
- 0x00 - RSP0
- 0x01 - IST4
- 0x02 - IST3
- 0x03 - RSP3
- 0x04 - RSP3
- 0x05 - RSP0
- 0x06 - RSP0
- 0x07 - RSP0

Entries `0x00`, `0x05`, `0x06`, and `0x07` are executed at `R0`. If an attempt is made to invoke these handlers through a software interrupt - noting that the processor ignores the DPL for hardware-generated interrupts - and the Current Privilege Level (CPL) is greater than the DPL (`R0`) of the interrupt or trap gate, typically, the processor would not permit transfer of execution to the exception- or interrupt-handler procedure, resulting in a general-protection exception (#GP). Conversely, if the CPL is equal to the DPL (`R0`) and the handler is called, then the current stack is used.

For entries `0x03` and `0x04` which are executed at `R3`, a stack switch is **not** required because `R3` is accessible from all privilege levels.

For entries `0x01` and `0x02`, their IST values are non-zero. Therefore, these entries use their IST bits to pinpoint an index within the Interrupt Descriptor Table (IDT) that corresponds to a specific stack to use for the RSP. Specifically, the IST index for entry `0x01` is set to `0x4` (`100` in binary), and for entry `0x02`, it's `0x3` (`011` in binary). Thus, the processor fetches the corresponding stack from the Task State Segment (TSS) based on these IST indices for the current task.

So, what is the CPL of the currently executing code? This can be determined by looking at the current Code-Segment and Code-Segment Descriptor.

In order to display the value of the CS register, you can use the WinDBG register command `r cs`:
~~~
0: kd> r cs
cs=0010
~~~
![Screenshot8](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot8.png)

The Code Segment (CS) register contains an RPL (Requested Privilege Level), a TI (Table Indicator), and an index. Specifically, the RPL field, represented by the least significant bits (`0` and `1`) of **any** segment selector, specifies the requested privilege level of a segment selector. However, in the context of the CS segment register, bits `0` and `1` indicate the privilege level of the currently executing program or procedure.

`TI` is set to zero, so it points to the Global Descriptor Table (GDT). Specifically, it points at index `2` (`00010000`). The GDT indicates the memory location for the code segment. However, in 64-bit environments, it does not take a base or limit from there but assumes zero. Therefore, the information taken from the GDT is access information, specifying who is allowed to access this memory for this particular code segment, whether the kernel or user space. 

In order to view the GDT, you can use `!ms_gdt` command with the SwishDBGExt plugin in WinDBG:

![Screenshot9](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot9.png)

Here, we can see the `DPL` for index `2` is `R0`. The privilege level of the segment that the CS register points to (its `DPL`) is effectively the CPL of the currently executing code (`R0`).

So, back to the original question. In order to find the specific RSP address of each index, we can use the address of a 64-bit TSS from the GDT:

![Screenshot5](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot5.png)

Then, we can run `dt -b nt!_KTSS64 {TSS address}` to see the TSS contents:

![Screenshot6](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot6.png)

As entry `0x01`’s index is `0x4`, the RSP address where it's saved state will be stored is:
~~~
[04] 0xfffff805`6326c9d0
~~~
For entry `0x02`, whose index is `0x3`, it is:
~~~
[03] 0xfffff805`6326c7d0
~~~

In addition to this, we can also see the RSP address for `R0:`
~~~
Rsp0 : 0xfffff805`6326c200
~~~

`RSP1` and `RSP2` are empty, which shows Microsoft does not expect to use `R1` or `R2`. 

This information allows us to fill out the target RSP address table:
~~~
0x00 - RSP0 - 0xfffff805`6326c200
0x01 - IST4 - 0xfffff805`6326c9d0
0x02 - IST3 - 0xfffff805`6326c7d0
0x03 - RSP3 - Current stack is used
0x04 - RSP3 - Current stack is used 
0x05 - RSP0 - 0xfffff805`6326c200
0x06 - RSP0 - 0xfffff805`6326c200
0x07 - RSP0 - 0xfffff805`6326c200 
~~~

#### 6. Which entries have a DPL of `3` so userspace can call them?
Entry `0x03` and `0x04` (shown above). 

# Part 2 Instructions

1.	Use the built-in WinDBG `!idt` command to dump out the full IDT.

![Screenshot7](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot7.png)

# Part 2 Questions

#### 1.	Did you interpret the first `8` interrupt descriptors correctly according to the `!idt` output?

:+1:

#### 2.	Did you get any IST targets correct according to the `!idt` output?

:+1:

# Understanding Stack Switching and Target RSP Address Determination in x86-64 Architecture
<a name="interrupts"></a>

#### How is the Interrupt Descriptor Table (IDT) Found?

The IDT is located by the IDT Register (IDTR), and the LIDT (load IDT register) instruction (a privileged instruction) loads the IDTR register with the base address and limit held in a memory operand (Section 6-10 Vol. 3A). This base address points at the start of the Interrupt Descriptor Table (IDT), and the limit specifies the size of the IDT:

![Screenshot10](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot10.png)

In order to access a specific descriptor in the IDT (in response to an exception or interrupt), the processor uses “the exception or interrupt vector as an index to a descriptor in the IDT” (shown in Figure 6-3 below). These exception/interrupt vectors can be found in Section 6-2 Vol. 3A of the Intel manual.

The descriptors in the IDT can be either Interrupt or Trap Gates, and each contain a segment selector and a 64-bit offset which tells the processor where the code for the exception- or interrupt-handler is located.

Xeno said “you can think of the IDT as an array of function (far) pointers, and when interrupt (vector) n is invoked by software or hardware, execution transfers to the address pointed to by the nth descriptor in the table”. However, there will be checks for access control on the interrupt gate itself (in the IDT), as well as on the ultimate destination segment to which that interrupt gate points (Interrupt Procedure).

Therefore, before the processor can call the interrupt or exception handler (shown as the Interrupt Procedure in Figure 6-3), it needs to check that the privilege levels are appropriate.
-	If the handler is at the same privilege level, the current stack is used.
-	If the handler is at a lower privilege level, the processor performs a stack switch. This switch involves the Task State Segment (TSS).

![Screenshot11](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot11.png)

In the case of a stack switch (according to Section 6.12.1 Vol. 3A of the Intel manual):

- “The segment selector and stack pointer for the stack to be used by the handler are obtained from the TSS (Task State Segment) for the currently executing task. On this new stack, the processor pushes the stack segment selector and stack pointer of the interrupted procedure.
- The processor then saves the current state of the EFLAGS, CS, and EIP registers on the new stack (see Figure 6-4 below).
- If an exception causes an error code to be saved, it is pushed on the new stack after the EIP value.”

![Screenshot12](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot12.png)

After the stack switch, the processor uses the segment selector and offset (from the IDT entry) to locate and execute the interrupt or exception handler. This handler code will operate on the new stack. 

In order to return from the handler, the `IRET` instruction is used, which will restore the state of the processor to what it was before the interrupt or exception, which includes a switch back to the original stack.

That all being said, in Section 6.12.1.2 Vol. 3A of the Intel manual says “the processor does not permit transfer of execution to an exception- or interrupt-handler procedure in a less privileged code segment (numerically greater privilege level) than the CPL”. That means that if the handler is at a lower privilege level than the CPL, the interrupt is NOT allowed, and no stack switch occurs. So, **WHEN** does a stack switch actually occur?

One situation (like we saw in Question 5) is if the IDG’s IST is non-zero, it uses the IST bits to specify a specific index from the Interrupt Descriptor Table (IDT) to use for the RSP. This stack is obtained from the TSS through a stack switch.

I have yet to test this but in Section 6.12.1.2 Vol. 3A of the Intel manual also says that the following situations apply:
If the handler is placed in a non-confirming code segment with DPL of `0`, it will always execute regardless of the CPL. Therefore, if the CPL at the time of the interrupt or exception is higher than `0` (a less privileged level), the processor will perform a stack switch to a `R0` stack.

In addition, if the handler is placed in a conforming code segment, it will also execute regardless of the CPL. This makes sense because conforming code segments are designed to be accessible by code running at any privilege level. However, in this case, I don’t believe a stack switch will occur. This is because in Section 5.8.1.2 Vol. 3A of Intel manual says that “when program control is transferred to a conforming code segment, the CPL does not change”; therefore, no stack switch occurs.

#### The Task State Segment (TSS) was referenced multiple times in relation to a stack switch. So, how does the processor actually locate the TSS?

The TSS is accessed through the Task Register (TR). The processor uses the segment selector in the TR to find the TSS descriptor in the GDT, and from this descriptor, it retrieves the base address of the TSS and can then access the TSS itself in memory.

![Screenshot13](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot13.png)

This is what the TSS look at on 64-bit mode:

![Screenshot14](https://github.com/theokwebb/my-writeups/blob/main/PearlyInterruptGates/Images/Screenshot14.png)

It includes RSPn which are the 64-bit stack pointers for privilege levels `0-2`. RSPn are the addresses that will be used as the RSP in the case of a stack switch and point to the stack to be used when an interrupt occurs that transitions the processor into a lower privilege level (like Ring `0`). This address specifies the top of the stack where the processor can push the stack segment selector, stack pointer, etc.

The TSS also includes 64-bit interrupt stack table (IST) pointers (ISTn). There are seven possible stack locations for specific interrupts (such as NMI, double-fault, and machine-check) in the Interrupt Descriptor Table (IDT) highlighted above.

#

Thank you to Xeno at [OpenSecurityTraining2](https://ost2.fyi) for this lab and the incredible x86-64 OS Internals course.
