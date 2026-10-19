library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_memory_configuration is end;
architecture test of tb_memory_configuration is
    signal d : std_logic_vector(15 downto 0) := (others => '1');
    signal bsc : std_logic_vector(6 downto 0) := (others => '1');
    signal ral, byte_n, bl_n, sob, wr, stm, ph2 : std_logic := '1';
    signal dip : std_logic_vector(11 downto 0) := (others => '1');
    signal base : std_logic_vector(3 downto 0) := (others => '1');
    signal diag : std_logic := '1';
    signal a : std_logic_vector(17 downto 0);
    signal flash_ce, ram_ce, oe, we, reset_n, ble, bhe, xc_oe, xc_dir, mip : std_logic;
begin
    dut : entity work.hp9835_unified_ram_rom_board port map (
        MEM_D => d, HP_BSC_N => bsc, HP_RAL_N => ral, HP_BYTE_N => byte_n,
        HP_BL_N => bl_n, HP_SOB_N => sob, HP_WRT_N => wr,
        HP_STM_N => stm, HP_PH2 => ph2, DIP_N => dip, BASE_N => base,
        DIAG_N => diag, MEM_A => a, FLASH_CE_N => flash_ce,
        SRAM_CE_N => ram_ce, MEM_OE_N => oe, MEM_WE_N => we,
        FLASH_RESET_N => reset_n, FLASH_RYBY_N => '1',
        SRAM_BLE_N => ble, SRAM_BHE_N => bhe, XCVR_OE_N => xc_oe,
        XCVR_DIR => xc_dir, HP_MIP_N => mip);
    process
        type addresses is array(natural range <>) of natural;
        constant probes : addresses := (0, 16#1ff#, 16#200#, 16#3ff#, 16#400#,
                                        16#7eff#, 16#7f00#, 16#7fff#);
        variable selected : boolean;
        variable expected, translated : natural;
        procedure tick is
        begin
            ph2 <= '0'; wait for 5 ns;
            ph2 <= '1'; wait for 5 ns;
        end;
        procedure access_word(block_no, addr : natural) is
        begin
            stm <= '1'; tick;
            bsc <= not std_logic_vector(to_unsigned(block_no, 7));
            d <= not std_logic_vector(to_unsigned(addr, 16));
            wait for 5 ns;
            stm <= '0'; wait for 5 ns;
        end;
    begin
        dip(10) <= '0'; -- RAM enable
        for setting in 0 to 15 loop
            base <= not std_logic_vector(to_unsigned(setting, 4));
            for block_no in 0 to 127 loop
                for k in probes'range loop
                    access_word(block_no, probes(k));
                    selected := (block_no mod 2 = 0 and block_no/2 >= setting and
                                 block_no/2 < setting+8) or (setting=0 and block_no=1);
                    assert (ram_ce='0') = selected report "RAM selection mismatch" severity failure;
                    assert flash_ce='1' report "Unrequested flash select" severity failure;
                    if selected then
                        if block_no=1 then
                            translated := probes(k);
                            if (translated/512) mod 2 = 0 then translated := translated+512; end if;
                            expected := translated;
                        else
                            expected := (block_no/2-setting)*32768+probes(k);
                        end if;
                        assert unsigned(a)=expected report "Relative SRAM address mismatch" severity failure;
                    end if;
                end loop;
            end loop;
        end loop;
        -- Exhaust all block-1 addresses against the original physical gate:
        -- active-low IDA9 forced LOW means logical address bit 9 HIGH.
        base <= "1111";
        for addr in 0 to 32767 loop
            access_word(1, addr);
            expected := addr;
            if (addr/512) mod 2 = 0 then expected := addr+512; end if;
            assert ram_ce='0' and unsigned(a)=expected report "Special alias mismatch" severity failure;
        end loop;
        ral <= '0'; access_word(0, 16#200#);
        assert ram_ce='1' and flash_ce='1' report "Register cycle claimed" severity failure;
        ral <= '1'; dip(10) <= '1'; access_word(1, 0);
        assert ram_ce='1' report "Disabled RAM claims special block" severity failure;
        -- Pole 10 no longer controls diagnostics; J4 does, independently of RAM enable.
        for model in 0 to 1 loop
            if model=0 then dip(9)<='1'; else dip(9)<='0'; end if;
            diag <= '1'; access_word(8#45#, 16#7fff#);
            assert ram_ce='1' and flash_ce='1' report "DIP pole enabled diagnostics" severity failure;
            diag <= '0'; access_word(8#45#, 16#7fff#);
            assert ram_ce='0' and flash_ce='1' and unsigned(a)=255 report "Diagnostic scratch mapping" severity failure;
            access_word(8#45#, 16#7eff#);
            assert ram_ce='1' and flash_ce='1' report "Diagnostic scratch extends too far" severity failure;
            access_word(8#45#, 0);
            assert flash_ce='0' and ram_ce='1' report "Diagnostic ROM select" severity failure;
        end loop;
        -- Preserve write pulse sequencing and STM release qualification.
        diag <= '1'; dip(10) <= '0'; base <= "1110"; wr <= '0';
        access_word(2, 16#1234#);
        assert unsigned(a)=16#1234# and ram_ce='0' and we='1' severity failure;
        tick; assert mip='0' and we='1' severity failure;
        tick; assert we='0' report "Missing SRAM write pulse" severity failure;
        tick; assert we='1' report "SRAM write pulse too long" severity failure;
        stm <= '1'; wait for 5 ns;
        assert ram_ce='1' and flash_ce='1' and we='1' and oe='1' and mip='1'
            report "STM release does not end memory strobes" severity failure;
        report "PASS: all bases/blocks, address boundaries, 32768 special aliases, diagnostics and write timing";
        stop;
        wait;
    end process;
end;
