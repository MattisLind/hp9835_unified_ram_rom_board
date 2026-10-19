-- HP 9835 unified RAM/ROM replacement card - Rev F
-- Target: ATF1508AS-100TQFP, 5 V
--
-- This logic is derived from the timing and decode behaviour in the supplied
-- PALCE/GAL reference designs. The HP IDA bus is active-low during the address
-- phase. HP_STM_N is raw STM/ from memory connector contact 42. Its falling
-- edge is the address-latch event (formerly rising edge of inverted ALE).
--
-- DIP switch assignment (switch ON = input pulled low):
--   SW1   98331B Mass Storage option (two ROM modules)
--   SW2   98332A I/O option (all four ROM modules)
--   SW3   98335A Structured Programming
--   SW4   98336A Advanced Programming
--   SW5   98337A Plotter option (both ROM modules)
--   SW6   98338A Assembly Execution
--   SW7   98339A Assembly Development & Execution (both ROM modules)
--   SW8   98317A Basic Datacomm (all four ROM modules)
--   SW9   98318A Bisync Datacomm (both ROM modules)
--   SW10  Reserved for A/B model selection; no effect until maps are confirmed
--   J4    Short pins 1-2 for CE diagnostic ROM + scratch RAM
--   SW11  Enable 512 KiB RAM at SW3 base (64 KiB steps, 0..15).
--         Base zero also enables original block-1 special-mode aliasing.
--   SW12  System ROM replacement (LPU block 3 and PPU portions of block 5)
--
-- Rev D bus change: the CPLD no longer connects directly to HP IDA. Its 16
-- bidirectional bus pins connect to MEM_D[15:0], on the memory side of two
-- non-inverting 74HCT245 transceivers. HP IDA is an active-low representation,
-- so MEM_D carries that same physical/complemented representation. During the
-- HP address phase the CPLD therefore latches NOT MEM_D as the logical address.
-- During normal data transfers the CPLD leaves MEM_D high-Z. During JTAG EXTEST
-- the same 16 I/O cells can drive/capture flash data while the HCT245s isolate
-- the HP bus. Flash words are stored bitwise complemented relative to CPU-visible
-- HP ROM words. SRAM requires no explicit conversion because both writes and
-- reads traverse the same non-inverting data path.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hp9835_unified_ram_rom_board is
    port (
        -- Shared physical memory data bus. Because the external 74HCT245s are
        -- non-inverting, MEM_D carries the same active-low/complemented bit
        -- representation as HP IDA. Normal CPLD logic only samples MEM_D and
        -- otherwise leaves it high-Z. JTAG EXTEST can drive/capture these I/O
        -- cells directly for flash programming and verification.
        MEM_D          : inout std_logic_vector(15 downto 0);
        HP_BSC_N       : in    std_logic_vector(6 downto 0);
        HP_RAL_N         : in    std_logic;
        HP_BYTE_N      : in    std_logic;
        HP_BL_N        : in    std_logic;
        HP_SOB_N         : in    std_logic;
        HP_WRT_N       : in    std_logic;

        -- Raw STM/ from contact 42: capture on its falling edge, cycle active low.
        -- STME/ on contact 33 is separately buffered and must not be tied to STM/.
        -- PH2 is the native HP phase-2 clock.
        HP_STM_N        : in    std_logic;
        HP_PH2         : in    std_logic;

        -- Twelve configuration poles on SW2. Each has a pull-up; ON grounds it.
        -- Pole 10 (DIP_N(9)) is reserved; A/B ROM differences are pending.
        DIP_N          : in    std_logic_vector(11 downto 0);

        -- Four base-address poles: ON pulls low and encodes a binary 1.
        BASE_N         : in    std_logic_vector(3 downto 0);
        -- External diagnostic switch/header: short to GND to enable.
        DIAG_N         : in    std_logic;

        -- Shared 18-bit address bus to both memories.
        MEM_A          : out   std_logic_vector(17 downto 0);

        -- Separate chip enables select FLASH or SRAM. OE# and WE# are shared
        -- physically by both memories; an unselected device ignores them.
        FLASH_CE_N     : out   std_logic;
        SRAM_CE_N      : out   std_logic;
        MEM_OE_N       : out   std_logic;
        MEM_WE_N       : out   std_logic;

        -- Remaining Macronix MX29F400C control/status. BYTE# is tied high
        -- externally for x16 operation.
        FLASH_RESET_N  : out   std_logic;
        FLASH_RYBY_N   : in    std_logic;

        -- CY62146ELL byte-lane controls.
        SRAM_BLE_N     : out   std_logic;
        SRAM_BHE_N     : out   std_logic;

        -- Two 74HCT245 devices share these controls. A side is HP IDA and B
        -- side is MEM_D. The parts are non-inverting, so both sides carry the
        -- HP bus physical (active-low/complemented) representation.
        XCVR_OE_N      : out   std_logic;
        XCVR_DIR       : out   std_logic;

        -- HP MIP/ acknowledge line (contact 40; called UMC in the RAM reference), connected directly to an ATF1508 I/O.
        -- IMPORTANT: configure this physical pin as OPEN COLLECTOR and disable
        -- its pin keeper. Logic '0' asserts MIP; logic '1' releases the line.
        HP_MIP_N       : out   std_logic
    );
end entity;

architecture rtl of hp9835_unified_ram_rom_board is
    signal addr_q          : unsigned(14 downto 0) := (others => '0');
    signal block_q         : unsigned(6 downto 0)  := (others => '0');
    signal byte_n_q        : std_logic := '1';
    signal bl_n_q          : std_logic := '1';
    signal wr_n_q          : std_logic := '1';

    signal phase1          : std_logic := '0';
    signal phase2          : std_logic := '0';
    signal phase3          : std_logic := '0';

    signal sel_ram_exp     : std_logic;
    signal sel_diag_ram    : std_logic;
    signal sel_system_rom  : std_logic;
    signal sel_option_rom  : std_logic;
    signal sel_diag_rom    : std_logic;
    signal sel_ram         : std_logic;
    signal sel_flash       : std_logic;
    signal sel_any         : std_logic;

    signal sw_mass         : std_logic;
    signal sw_io           : std_logic;
    signal sw_structured   : std_logic;
    signal sw_advanced     : std_logic;
    signal sw_plotter      : std_logic;
    signal sw_assy_exec    : std_logic;
    signal sw_assy_dev     : std_logic;
    signal sw_basic_dc     : std_logic;
    signal sw_bisync_dc    : std_logic;
    signal sw_diag         : std_logic;
    signal sw_ram          : std_logic;
    signal sw_system       : std_logic;

    signal ram_bank        : unsigned(2 downto 0);
    signal ram_special     : std_logic;
    signal rom_bank        : unsigned(2 downto 0);
    signal segment_q       : unsigned(2 downto 0);

    -- HP ROM block numbers are written in decimal here, with octal names in
    -- comments. BSC inputs are active-low and are inverted when latched.
    constant BLK_LPU_SYS   : natural := 3;   -- octal 003
    constant BLK_PPU_SYS   : natural := 5;   -- octal 005
    constant BLK_PLOTTER   : natural := 7;   -- octal 007
    constant BLK_IO        : natural := 9;   -- octal 011
    constant BLK_PROG      : natural := 11;  -- octal 013
    constant BLK_DATACOMM  : natural := 17;  -- octal 021
    constant BLK_DIAG      : natural := 37;  -- octal 045
begin
    -- Normal CPLD logic never drives MEM_D. Boundary-scan EXTEST can still
    -- take control of these I/O cells for standalone flash programming.
    MEM_D <= (others => 'Z');

    -- Human-readable switch states. One switch enables one complete HP option
    -- carrier/set, regardless of whether that option comprises 1, 2 or 4 ROMs.
    sw_mass       <= not DIP_N(0);
    sw_io         <= not DIP_N(1);
    sw_structured <= not DIP_N(2);
    sw_advanced   <= not DIP_N(3);
    sw_plotter    <= not DIP_N(4);
    sw_assy_exec  <= not DIP_N(5);
    sw_assy_dev   <= not DIP_N(6);
    sw_basic_dc   <= not DIP_N(7);
    sw_bisync_dc  <= not DIP_N(8);
    sw_diag       <= not DIAG_N;
    sw_ram        <= not DIP_N(10);
    sw_system     <= not DIP_N(11);

    segment_q <= addr_q(14 downto 12);

    -- Latch the logical address at the same event used by the original
    -- 12BIT/BLKSEL PALs. Since the 74HCT245s are non-inverting, MEM_D still
    -- carries the active-low HP address representation, so it is complemented
    -- here. BYTE, BL and WRT are latched too; the RAM-card notes explicitly
    -- report that latching BYTE/BL fixed failures.
    process (HP_STM_N)
    begin
        if falling_edge(HP_STM_N) then
            addr_q   <= unsigned(not MEM_D(14 downto 0));
            block_q  <= unsigned(not HP_BSC_N);
            byte_n_q <= HP_BYTE_N;
            bl_n_q   <= HP_BL_N;
            wr_n_q   <= HP_WRT_N;
        end if;
    end process;

    -- Eight consecutive 64 KiB RAM banks. BASE_N is the active-low physical
    -- switch input: ON=1 in the logical base. BSC[6:1] is the RAM bank index;
    -- BSC0 distinguishes ordinary even RAM blocks from odd ROM blocks.
    -- Six-bit subtraction avoids truncating the top settings (base 15 ends
    -- at bank index 22). Values below the base cannot pass the delta < 8 test.
    process (block_q, BASE_N, sw_ram, HP_RAL_N)
        variable delta : unsigned(5 downto 0);
    begin
        delta := block_q(6 downto 1) - resize(unsigned(not BASE_N), 6);
        ram_bank <= delta(2 downto 0);
        ram_special <= '0';
        sel_ram_exp <= '0';
        if sw_ram = '1' and HP_RAL_N = '1' then
            if block_q(0) = '0' and delta(5 downto 3) = "000" then
                sel_ram_exp <= '1';
            elsif BASE_N = "1111" and block_q = to_unsigned(1, 7) then
                -- Only block 1 aliases bank 0; never claim odd ROM blocks.
                sel_ram_exp <= '1';
                ram_bank <= "000";
                ram_special <= '1';
            end if;
        end if;
    end process;

    -- Diagnostic scratch occupies the top 256 words of octal block 045.
    -- With the full 512 KiB exposed, it shares physical words 0..255 with
    -- the first configured RAM bank. Diagnostic writes can overwrite them;
    -- this is an intentional alias, not extra or protected memory.
    sel_diag_ram <= '1' when
        sw_diag = '1' and HP_RAL_N = '1' and
        to_integer(block_q) = BLK_DIAG and
        addr_q(14 downto 8) = "1111111"
        else '0';

    -- System ROM decode. HP 9835 LPU system ROM fills block 3. PPU system ROM
    -- occupies segments 0 and 3..7 in block 5; segments 1 and 2 are the
    -- mass-storage option-ROM hole.
    process (block_q, segment_q, sw_system, HP_RAL_N)
        variable b : natural;
        variable s : natural;
    begin
        b := to_integer(block_q);
        s := to_integer(segment_q);
        sel_system_rom <= '0';

        if sw_system = '1' and HP_RAL_N = '1' then
            if b = BLK_LPU_SYS then
                sel_system_rom <= '1';
            elsif b = BLK_PPU_SYS and
                  (s = 0 or s = 3 or s = 4 or s = 5 or s = 6 or s = 7) then
                sel_system_rom <= '1';
            end if;
        end if;
    end process;

    -- Option-ROM decode based on the published HP 9835A/B option-ROM map.
    -- Each switch controls exactly one HP option carrier/set. This intentionally
    -- separates options that happen to share the same HP block.
    process (block_q, segment_q, sw_mass, sw_io, sw_structured, sw_advanced,
             sw_plotter, sw_assy_exec, sw_assy_dev, sw_basic_dc, sw_bisync_dc,
             HP_RAL_N)
        variable b : natural;
        variable s : natural;
    begin
        b := to_integer(block_q);
        s := to_integer(segment_q);
        sel_option_rom <= '0';

        if HP_RAL_N = '1' then
            -- 98331B Mass Storage: block 5, segments 1 and 2.
            -- Both ROM modules are always enabled together by SW1.
            if b = BLK_PPU_SYS and sw_mass = '1' and
               (s = 1 or s = 2) then
                sel_option_rom <= '1';

            -- 98337A Plotter: block 7, segments 6 and 7.
            elsif b = BLK_PLOTTER and sw_plotter = '1' and
                  (s = 6 or s = 7) then
                sel_option_rom <= '1';

            -- 98332A I/O: block 11, segments 1 through 4.
            elsif b = BLK_IO and sw_io = '1' and
                  (s >= 1 and s <= 4) then
                sel_option_rom <= '1';

            -- Programming and assembler options share block 13 but each option
            -- receives its own independent switch.
            elsif b = BLK_PROG then
                if sw_advanced = '1' and s = 1 then
                    sel_option_rom <= '1';       -- 98336A Advanced Programming
                elsif sw_structured = '1' and s = 2 then
                    sel_option_rom <= '1';       -- 98335A Structured Programming
                elsif sw_assy_exec = '1' and s = 5 then
                    sel_option_rom <= '1';       -- 98338A Assembly Execution
                elsif sw_assy_dev = '1' and (s = 6 or s = 7) then
                    sel_option_rom <= '1';       -- 98339A Assembly Dev & Execute
                end if;

            -- The two datacomm products share block 21 but are independent.
            elsif b = BLK_DATACOMM then
                if sw_basic_dc = '1' and s <= 3 then
                    sel_option_rom <= '1';       -- 98317A Basic Datacomm
                elsif sw_bisync_dc = '1' and (s = 4 or s = 5) then
                    sel_option_rom <= '1';       -- 98318A Bisync Datacomm
                end if;
            end if;
        end if;
    end process;

    -- CE diagnostic ROM, octal block 45, bottom 4K words (segment 0).
    sel_diag_rom <= '1' when
        sw_diag = '1' and HP_RAL_N = '1' and
        to_integer(block_q) = BLK_DIAG and segment_q = "000"
        else '0';

    sel_ram   <= sel_ram_exp or sel_diag_ram;
    sel_flash <= sel_system_rom or sel_option_rom or sel_diag_rom;
    sel_any   <= sel_ram or sel_flash;

    -- Convert HP logical ROM blocks into one of the eight 32K-word physical
    -- flash banks. This is the key simplification of the design: lower 15
    -- address bits remain unchanged, so only three flash address bits need
    -- block translation.
    process (block_q)
    begin
        case to_integer(block_q) is
            when BLK_LPU_SYS  => rom_bank <= "000"; -- flash words 00000-07FFF
            when BLK_PPU_SYS  => rom_bank <= "001"; -- flash words 08000-0FFFF
            when BLK_PLOTTER  => rom_bank <= "010"; -- flash words 10000-17FFF
            when BLK_IO       => rom_bank <= "011"; -- flash words 18000-1FFFF
            when BLK_PROG     => rom_bank <= "100"; -- flash words 20000-27FFF
            when BLK_DATACOMM => rom_bank <= "101"; -- flash words 28000-2FFFF
            when BLK_DIAG     => rom_bank <= "110"; -- flash words 30000-37FFF
            when others       => rom_bank <= "111"; -- spare bank
        end case;
    end process;

    -- Expansion addresses are relative to the configured base.
    process (sel_diag_ram, sel_ram_exp, sel_flash, addr_q, ram_bank,
             ram_special, rom_bank)
        variable ram_addr : std_logic_vector(14 downto 0);
    begin
        ram_addr := std_logic_vector(addr_q);
        if ram_special = '1' then
            -- Original U13 gate: physical IDA9 AND physical BSC0. For block 1
            -- BSC0 is LOW, forcing physical IDA9 LOW. Our address latch has
            -- already complemented IDA, so logical SRAM A9 must be HIGH.
            -- This aliases pairs separated by 512 WORDS (1024 bytes).
            ram_addr(9) := '1';
        end if;
        if sel_diag_ram = '1' then
            MEM_A <= (17 downto 8 => '0') & std_logic_vector(addr_q(7 downto 0));
        elsif sel_ram_exp = '1' then
            MEM_A <= std_logic_vector(ram_bank) & ram_addr;
        elsif sel_flash = '1' then
            MEM_A <= std_logic_vector(rom_bank) & std_logic_vector(addr_q);
        else
            MEM_A <= (others => '0');
        end if;
    end process;

    -- Three PH2 stages reproduce the sequencing in RAMMISC2.PDS. The first
    -- PH2 edge after selection asserts the memory-complete handshake and data
    -- path. The SRAM write pulse occupies one PH2 interval between phase2 and
    -- phase3, giving ample width for a 45 ns SRAM.
    process (HP_PH2)
    begin
        if rising_edge(HP_PH2) then
            if HP_STM_N = '0' then
                phase1 <= sel_any;
                phase2 <= phase1;
                phase3 <= phase2;
            else
                phase1 <= '0';
                phase2 <= '0';
                phase3 <= '0';
            end if;
        end if;
    end process;

    -- Assert the wired MIP/ acknowledge after the first PH2 stage.
    -- HP_MIP_N is connected directly to an ATF1508 pin configured as an
    -- open-collector output (pin keeper disabled). Therefore '0' pulls the
    -- shared HP line low and '1' releases it to the backplane pull-up.
    HP_MIP_N <= '0' when
        phase1 = '1' and sel_any = '1' and HP_STM_N = '0'
        else '1';

    -- 74HCT245 direction: 1 = HP A-side to MEM_D B-side, 0 = MEM_D to HP.
    -- Rev D deliberately leaves the transceivers HP->MEM while idle and during
    -- the address phase. This is essential: the CPLD now captures the address
    -- from MEM_D rather than from separate HP_IDA pins. Only a selected read
    -- reverses direction, after the first PH2 pipeline stage.
    XCVR_DIR <= '0' when
        phase1 = '1' and sel_any = '1' and wr_n_q = '1'
        else '1';

    -- Keep HP->MEM enabled before/during the address latch and for writes. For
    -- a selected read, disable the transceivers while direction changes and
    -- only enable MEM->HP once SOB/ is high (the reference SMC read-data condition). Unselected cycles simply
    -- mirror HP IDA onto MEM_D; both memories remain disabled. EXTEST must set
    -- XCVR_OE_N high before driving MEM_D for flash programming.
    XCVR_OE_N <= '1' when
        phase1 = '1' and sel_any = '1' and wr_n_q = '1' and HP_SOB_N = '0'
        else '0';

    -- Device chip enables remain separate, while OE# and WE# are shared by
    -- FLASH and SRAM. This saves two ATF1508 I/O pins. Mutual exclusion is
    -- provided by the decode: only the selected device sees an active CE#.
    SRAM_CE_N  <= '0' when sel_ram = '1' and HP_STM_N = '0' else '1';
    FLASH_CE_N <= '0' when sel_flash = '1' and HP_STM_N = '0' else '1';

    -- SOB/ is the original CPU name for contact 32 (reference name SMC).
    -- Preserve the reference equation: read outputs enabled when this pin is HIGH.
    -- The suffix describes the original signal, not an instruction to invert it.
    -- RAL/ similarly qualifies memory cycles HIGH; LOW denotes register access.
    -- Shared read strobe. It may go low for either selected memory, but only
    -- the device with CE# asserted can drive MEM_D.
    MEM_OE_N <= '0' when
        sel_any = '1' and HP_STM_N = '0' and wr_n_q = '1' and HP_SOB_N = '1'
        else '1';

    -- Shared write strobe. Normal HP operation writes SRAM only; FLASH_CE# is
    -- high during RAM writes, so the flash ignores MEM_WE#. During JTAG EXTEST
    -- the boundary-scan cells can take direct control of CE#/OE#/WE# to program
    -- the MX29F400C.
    MEM_WE_N <= '0' when
        sel_ram = '1' and HP_STM_N = '0' and wr_n_q = '0' and
        phase2 = '1' and phase3 = '0'
        else '1';

    -- BYTE# high means a full 16-bit word. For an 8-bit write, BL# low selects
    -- the left/MSB lane and BL# high selects the right/LSB lane, matching the
    -- equations in the supplied BLKSEL3.PDS reference.
    SRAM_BLE_N <= '0' when
        sel_ram = '1' and (byte_n_q = '1' or
        (byte_n_q = '0' and bl_n_q = '1'))
        else '1';
    SRAM_BHE_N <= '0' when
        sel_ram = '1' and (byte_n_q = '1' or
        (byte_n_q = '0' and bl_n_q = '0'))
        else '1';

    -- Flash is read-only during normal HP operation. Because MEM_D is the
    -- physical active-low HP representation, flash contents are stored bitwise
    -- complemented relative to logical HP ROM words. EXTEST can override MEM_A,
    -- MEM_D and shared memory-control boundary cells for erase/program/verify. JTAG
    -- programming software must likewise drive/capture complemented data. The
    -- HCT245s must be disabled while boundary scan drives MEM_D.
    FLASH_RESET_N <= '1';

    -- FLASH_RYBY_N is intentionally available to the CPLD/JTAG boundary scan.
    -- Normal HP cycles do not need it because the flash is never programmed by
    -- the host processor.

end architecture;
